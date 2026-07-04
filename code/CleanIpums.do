clear all
do globals

loc startyearold 1900
loc stopyearold  1930

loc cleanperiod1 1
loc cleanperiod2 0

/************************************************************************************
        CLEANING
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