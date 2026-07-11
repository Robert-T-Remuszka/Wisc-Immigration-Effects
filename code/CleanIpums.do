clear all
do globals

loc startyearold 1900
loc stopyearold  1930

loc cleanperiod1 0
loc cleanperiod2 1

/************************************************************************************
        CLEANING - Aggregate foreign-born stocks and migration flows
We will clean the Census waves in two groups following the geographic identifiers used by Burchardi
et al.

The `cleanperiod1' switch is for 1900-1930
The `cleanperiod2' switch is for 1970-2000
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


    forv yyyy = 1970(10)1970 { // Unecessary, this part only cleans the 1970 wave.

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

            use "${data}/CountyTransitions/TransitionMatrix_CountyGroup_`yyyy'.dta", clear
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

    
    * Clean 1980 next - again, sorry for the confusing for loop above, was hoping the 70 and 80 waves would be more similar
    use "${Ipums}/Decadal/Acs1980.dta", clear

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

    tostring CNTY, gen(cg)
    replace cg = "00" + cg if strlen(cg) == 2
    replace cg = "000" + cg if strlen(cg) == 1

    tostring STATEFIP, gen(statefip)
    replace statefip = "0" + statefip if strlen(statefip) == 1

    gen county = statefip + cg

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
    collapse (sum) imm foreign domestic [aw = perwt], by(year county bpl)

    * Transition these in two steps, county groups then historic counties
    frame create transit1
    frame transit1 {

        use "${data}/CountyTransitions/TransitionMatrix_CountyGroup_1980.dta", clear
        tostring countygroup_1980, gen(county)
        drop countygroup
        replace county = "0" + county if strlen(county) == 5

        tempfile county_group_trans
        save `county_group_trans'
    }
    frame drop transit1

    * Bring in the historic county shares - 34 in master not matched, 0 in using not matched, 64,397 matched
    merge m:1 county using `county_group_trans', keep(3) nogen
    
    * Divvy up the variables among historic counties
    reshape long state_county_, i(county year bpl) j(county_historic) string

    * Length six
    replace county_historic = "0" + county_historic if strlen(county_historic) == 5

    gen foreign_divvied  = state_county_ * foreign
    gen domestic_divvied = state_county_ * domestic
    gen imm_divvied      = state_county_ * imm
    drop state_county_ foreign domestic imm

    collapse (sum) foreign_divvied imm_divvied domestic_divvied, by(year county_historic bpl)
    ren (foreign_divvied domestic_divvied imm_divvied) (foreign domestic imm)
    
    * Drop the zero-mass rows created by the fan-out above so the next
    * reshape (another 3,141-county-wide transition matrix) doesn't
    * have to expand rows that carry no population anyway
    drop if foreign == 0 & domestic == 0 & imm == 0

    * Transition these counties into 1990 equivalents
    frame create county_trans
    frame county_trans {

        use "${data}/CountyTransitions/TransitionMatrix_HistoricCounties_1980.dta", clear
        tostring county_1980, gen(county_historic)
        replace county_hist = "0" + county_hist if strlen(county_hist) == 5
        drop county_1980

        tempfile county_trans_1980
        save `county_trans_1980'

    }
    frame drop county_trans

    * Bring in the 1990 county - 6 from using undmatched 0 from master
    merge m:1 county_historic using `county_trans_1980', nogen keep(3)
    
    * Divvy up the variables among 1990 counties
    reshape long  state_county_, i(county_historic year bpl) j(countyfip) string
    gen foreign_divvied = state_county_ * foreign
    gen domestic_divvied = state_county_ * domestic
    gen imm_divvied     = state_county_ * imm
    drop state_county_ foreign domestic imm

    collapse (sum) foreign_divvied imm_divvied domestic_divvied, by(year countyfip bpl)
    ren (foreign_divvied domestic_divvied imm_divvied) (foreign domestic imm)

    frame mid: xframeappend default




    *** 1990 next
    use "${Ipums}/Decadal/Acs1990.dta", clear

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

    * Uniform length county codes
    tostring STATEFIP COUNTYFIP, replace
    replace STATEFIP = "0" + STATEFIP if strlen(STATEFIP) == 1
    replace COUNTYFIP = "00" + COUNTYFIP if strlen(COUNTYFIP) == 1
    replace COUNTYFIP = "0" + COUNTYFIP if strlen(COUNTYFIP ) == 2
    gen countyfip = STATEFIP + COUNTYFIP + "0"
    drop STATEFIP COUNTYFIP

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
    collapse (sum) imm foreign domestic [aw = perwt], by(year countyfip bpl)

    frame mid: xframeappend default
    
    ******* Lastly, clean year 2000
    use "${Ipums}/Decadal/Acs2000.dta", clear

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

    * Construct the Burchardi equivalent
    tostring STATEFIP PUMA, replace
    replace STATEFIP = "0" + STATEFIP if strlen(STATEFIP) ==  1
    replace PUMA = "0" + PUMA if strlen(PUMA) == 3
    gen countygroup_2000 = STATEFIP + PUMA

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
    collapse (sum) imm foreign domestic [aw = perwt], by(year countygroup bpl)

    * Transition to 1990 equivalent
    frame create burch
    frame burch {
        
        use "${data}/CountyTransitions/TransitionMatrix_CountyGroup_2000.dta", clear
        tostring countygroup_2000, replace
        replace countygroup_2000 = "0" + countygroup if strlen(countygroup) == 5

        tempfile burch
        save `burch', replace

    }

    * Everything matched
    merge m:1 countygroup_2000 using `burch', nogen

    * Reshape long then collapse into 1990
    reshape long state_county_, i(year bpl countygroup_2000) j(countyfip)

    gen foreign_divvied  = state_county_ * foreign
    gen domestic_divvied = state_county_ * domestic
    gen imm_divvied      = state_county_ * imm
    drop state_county_ foreign domestic imm

    collapse (sum) foreign_divvied imm_divvied domestic_divvied, by(year countyfip bpl)
    ren (foreign_divvied domestic_divvied imm_divvied) (foreign domestic imm)

    tostring countyfip, replace

    frame mid: xframeappend default

    frame mid {

        replace countyfip = "0" + countyfip if strlen(countyfip) == 5

        * Get country names
        merge m:1 bpl using "${data}/BplCodes.dta", keep(1 3) nogen

        * Save
        compress
        save "${data}/ImmigrationFlows1970to2000.dta", replace
    }
}