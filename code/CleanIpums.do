clear all
do globals

loc startyearold 1900
loc stopyearold  1930

loc startyearmid 1970
loc stopyearmid  1970

loc cleanperiod1 0
loc cleanperiod2 1

/************************************************************************************
        CLEANING - Aggregate foreign-born stocks and migration flows
We will clean the Census waves in three groups depending on geographic
identifier is used.

1. COUNTYICP 1880-1930
2. 1970-1980; County Groups
3. 1990 to 2010 PUMA
************************************************************************************/

* The old period based on icp county codes
if `cleanperiod1' {

    frame create old

    forv yyyy = `startyearold'(10)`stopyearold' {


        use "${Ipums}/Decadal/Acs`yyyy'.dta", clear

        * Drop some of the administrative variables
        cap drop SAMPLE SERIAL HHWT GQ PERNUM COUNTYNHG 
        if _rc drop SAMPLE SERIAL HHWT GQ PERNUM

        drop CLUSTER STRATA

        ren YEAR year
        la var year "Census year"
        ren PERWT perwt
        la var perwt "Person weight [IPUMS]"

        * Create uniform-length BPL vars
        loc bplvars BPL MBPL FBPL
        foreach V in `bplvars' {

            loc v = strlower("`V'")
            tostring `V', gen(`v')
            drop `V'

            forv len = 1/2 {
                
                loc leading = 3 - `len'
                replace `v' = "0" * `leading' + `v' if strlen(`v') == `len'
            }

        }

        * Dorp if missing bpl
        drop if inlist(bpl, "099", "199", "299", "403", "413", "419", "429", "549") | ///
        inlist(bpl , "440", "458", "459", "463", "499", "509", "519", "547", "800") | ///
        substr(bpl, 1, 1) == "9"

        * Create uniform-length geographic codes
        loc geovars_st STATEICP STATEFIP
        foreach v in `geovars_st' {

            * Rename the variable so that it is not screaming
            loc newname = strlower("`v'")
            tostring `v', gen(`newname')
            drop `v'

            * These are each two-digit coding schemes, make them uniform length
            replace `newname' = "0" + `newname' if strlen(`newname') == 1


        }

        tostring COUNTYICP, gen(countyicp)
        replace countyicp = "000" + countyicp if strlen(countyicp) == 1
        replace countyicp = "00"  + countyicp if strlen(countyicp) == 2
        replace countyicp = "0"   + countyicp if strlen(countyicp) == 3
        gen county = statefip + countyicp
        la var county "County [ICPSR]"
        drop COUNTYICP stateicp countyicp

        * Generate an immigrant indicator - follow Burchardi et al here
        gen imm = year - YRIMMIG < 10

        * Generate foreign indicator - not born in the US
        gen foreign = substr(bpl, 1, 1) != "0"
        gen domestic = 1 - foreign

        * Tidy up the presentation of the dataframe
        drop BPLD MBPLD FBPLD
        order county year

        * Aggregate to county-year-bpl level, get immigrant counts
        collapse (sum) imm foreign domestic [aw = perwt], by(year county bpl)

        * Transition these counties into 1990 equivalents
        frame create county_trans
        frame county_trans {

            use "${data}/CountyTransitions/TransitionMatrix_HistoricCounties_`yyyy'.dta", clear
            tostring county_`yyyy', gen(county)
            replace county = "0" + county if strlen(county) == 5
            drop county_`yyyy'

            tempfile county_trans_`yyyy'
            save `county_trans_`yyyy''
        }
        frame drop county_trans

        * Bring in the 1990 county
        merge m:1 county using `county_trans_`yyyy'', nogen keep(3)
        
        * Divvy up the variables among 1990 counties
        reshape long  state_county_, i(county year bpl) j(countyfip) string
        gen foreign_divvied = state_county_ * foreign
        gen domestic_divvied = state_county * domestic
        gen imm_divvied     = state_county_ * imm
        drop state_county_ foreign domestic imm

        collapse (sum) foreign_divvied imm_divvied domestic_divvied, by(year countyfip bpl)
        ren (foreign_divvied domestic_divvied imm_divvied) (foreign domestic imm)

        frame old: xframeappend default

        
    }

    frame old {
        
        * Make uniform length
        replace county = "0" + county if strlen(county) == 5

        * Get country names
        merge m:1 bpl using "${data}/BplCodes.dta", keep(1 3) nogen

        * Save
        compress
        save "${data}/ImmigrationFlows1900to1930.dta", replace

    }

}

* the second period; use county group transition then historic county, both from Buchardi et al
if `cleanperiod2' {

    frame create mid

    forv yyyy = `startyearmid'(10)`stopyearmid' {

        use "${Ipums}/Decadal/Acs`yyyy'.dta", clear

        drop SAMPLE SERIAL HHWT GQ PERNUM CLUSTER STRATA STATEICP COUNTYICP

        ren YEAR year
        la var year "Census year"
        ren PERWT perwt
        la var perwt "Person weight [IPUMS]"

        * Create uniform-length BPL vars
        loc bplvars BPL
        foreach V in `bplvars' {

            loc v = strlower("`V'")
            tostring `V', gen(`v')
            drop `V'

            forv len = 1/2 {
                
                loc leading = 3 - `len'
                replace `v' = "0" * `leading' + `v' if strlen(`v') == `len'
            }

        }

        * Drop if missing bpl
        drop if inlist(bpl, "099", "199", "299", "403", "413", "419", "429", "549") | ///
        inlist(bpl , "440", "458", "459", "463", "499", "509", "519", "547", "800") | ///
        substr(bpl, 1, 1) == "9"

        * Create uniform-length county groups (5 digits)
        tostring CNTY, gen(cg)
        drop CNTY
        forv len = 3/4 {

            loc leading = 5 - `len'
            replace cg = "0" * `leading' + cg if strlen(cg) == `len'

        }

        * Uniform length MIGPLAC5
        tostring MIG, gen(origin5)
        replace origin5 = "0"  + origin5 if strlen(origin5) == 2
        replace origin5 = "00" + origin5 if strlen(origin5) == 1
        drop if substr(origin5, 1, 1) == "9" | origin5 == "000"

        * Immigrant indicator
        gen imm = substr(origin5, 1, 1) != "0"

        * Gen foreign-born indicator
        gen foreign = substr(bpl, 1, 1) != "0"
        gen domestic = 1 - foreign

        * Aggregate to county-year-bpl level, get foreign born stocks
        collapse (sum) imm foreign domestic [aw = perwt], by(year cg bpl)

        * Transition these in two steps, county groups then historic counties
        frame create transit1
        frame transit1 {

            use "${data}/CountyTransitions/TransitionMatrix_CountyGroup_1970.dta", clear
            tostring countygroup, gen(cg)
            drop countygroup
            replace cg = "00" + cg if strlen(cg) == 3
            replace cg = "0"  + cg if strlen(cg) == 4

            tempfile county_group_trans
            save `county_group_trans'
        }
        frame drop transit1

        * Bring in the historic county shares - check the merge quality first
        merge m:1 cg using `county_group_trans', nogen

        * Divvy up the variables among historic counties
        reshape long state_county_, i(cg year bpl) j(county) string

        * Make historic county codes uniform length (six, as in the Burchardi data)
        replace county = "0" + county if strlen(county) == 5

        gen foreign_divvied  = state_county_ * foreign
        gen domestic_divvied = state_county_ * domestic
        gen imm_divvied      = state_county_ * imm
        drop state_county_ foreign domestic imm

        collapse (sum) foreign_divvied imm_divvied domestic_divvied, by(year county bpl)
        ren (foreign_divvied domestic_divvied imm_divvied) (foreign domestic imm)

        * Drop the zero-mass rows created by the fan-out above so the next
        * reshape (another 3,141-county-wide transition matrix) doesn't
        * have to expand rows that carry no population anyway
        drop if foreign == 0 & domestic == 0 & imm == 0

        * Transition these counties into 1990 equivalents
        frame create county_trans
        frame county_trans {

            use "${data}/CountyTransitions/TransitionMatrix_HistoricCounties_`yyyy'.dta", clear
            tostring county_`yyyy', gen(county)
            replace county = "0" + county if strlen(county) == 5
            drop county_`yyyy'

            tempfile county_trans_`yyyy'
            save `county_trans_`yyyy''
        }
        frame drop county_trans

        * Bring in the 1990 county
        merge m:1 county using `county_trans_`yyyy'', nogen keep(3)
        
        * Divvy up the variables among 1990 counties
        reshape long  state_county_, i(county year bpl) j(countyfip) string
        gen foreign_divvied = state_county_ * foreign
        gen domestic_divvied = state_county_ * domestic
        gen imm_divvied     = state_county_ * imm
        drop state_county_ foreign domestic imm

        collapse (sum) foreign_divvied imm_divvied domestic_divvied, by(year countyfip bpl)
        ren (foreign_divvied domestic_divvied imm_divvied) (foreign domestic imm)

        frame mid: xframeappend default

    }

    frame mid {

        replace countyfip = "0" + countyfip if strlen(countyfip) == 5

        * Get country names
        merge m:1 bpl using "${data}/BplCodes.dta", keep(1 3) nogen

        * Save
        compress
        save "${data}/ImmigrationFlows1970to2010.dta", replace
    }
}