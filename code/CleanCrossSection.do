clear all
do globals


/*************
1930 Census
*************/
use "${Ipums}/CrossSections/Acs1930.dta", clear

* Lowercase variable names
qui ds
foreach v in `r(varlist)' {

    loc newname = strlower("`v'")
    ren `v' `newname'
}

* Drop some of the extra vars, including the detailed "D" companion codes
* IPUMS auto-attaches alongside bpl/mbpl/fbpl/empstat/classwkr/race
drop sample serial cluster strata bpld mbpld fbpld empstatd classwkrd raced

* Recode IPUMS's own missing/NIU/unknown/illegible sentinel codes to Stata
* missing, so downstream cleaning can just use missing()/mvdecode logic
* instead of re-remembering these codes. Codes taken from this extract's own
* codebook (usa_00400.xml), not guessed from memory.
mvdecode sex,       mv(9)
mvdecode age,       mv(999)
mvdecode stateicp,  mv(99)
mvdecode statefip,  mv(99)
mvdecode bpl,       mv(997 999)
mvdecode mbpl,      mv(0 997 999)
mvdecode fbpl,      mv(0 997 998 999)
mvdecode citizen,   mv(0 5 8 9)
mvdecode yrimmig,   mv(0 996)
mvdecode empstat,   mv(0 9)
mvdecode classwkr,  mv(0 9)
mvdecode occ1950,   mv(997 999)
mvdecode ind1950,   mv(0 998 999)
mvdecode occscore,  mv(0)
mvdecode sei,       mv(0)

* Setting the sample
drop if age < 16 | missing(age)
drop if !inlist(gq, 1, 2)
drop if mi(empstat) | empstat == 3 // Keep only those people who are in the labor force

* generate historic counties
tostring countyicp stateicp statefip, replace
replace statefip = "0" + statefip if strlen(statefip) == 1
replace countyicp = "000" + countyicp if strlen(countyicp) == 1
replace countyicp = "00"  + countyicp if strlen(countyicp) == 2
replace countyicp = "0"   + countyicp if strlen(countyicp) == 3
replace stateicp = "0" + stateicp if strlen(stateicp) == 1
gen county = statefip + countyicp
replace county = "0" + county if strlen(county) == 5


* --- Bring in the 1990-equivalent county code ---
* Modal assignment: pick each historic county's single largest-share destination
frame create County_Crosswalk
frame County_Crosswalk {

    use "${data}/CountyTransitions/TransitionMatrix_HistoricCounties_1930.dta", clear
    tostring county_1930, gen(county)
    replace county = "0" + county if strlen(county) == 5
    drop county_1930

    reshape long state_county_, i(county) j(county_1990) s

    * Keep the modal county
    bys county (state_county_): keep if _n == _N

    replace county_1990 = "0" + county_1990 if strlen(county_1990) == 5

    drop state_county_

    tempfile county_1990
    save `county_1990', replace
    
}

* 345,866 in master unmatched, 0 in using and 1,950,237 in both
merge m:1 county using `county_1990', keep(3) nogen
frame drop County_Crosswalk

* Merge in the flows from 1920-1930
frame create MigFlows
frame MigFlows {

    use "${data}/ImmigrationFlows1900to1930.dta", clear
    ren countyfip county_1990
    order county_1990 bpl origin year
    sort county_1990 bpl year

    * Compute totals for each county
    egen totforeign = total(foreign), by(year county_1990)
    egen totdomestic = total(domestic), by(year county_1990)
    egen totimm = total(imm), by(year county_1990)
    gen pop = totforeign + totdomestic
    gen share = foreign / pop

    * Create constant 1900 shares
    bys county_1990 bpl (year): gen s_1900 = share if year == 1900
    egen s_1900_fill = min(s_1900), by(county_1990 bpl)
    drop s_1900
    ren s_1900_fill s_1900
    replace s_1900 = 0 if mi(s_1900)

    * Compute total immigrate rate
    bys county_1990 bpl (year): gen PopL1 = pop[_n-1]
    bys county_1990 bpl (year): gen foreignL1 = foreign[_n-1]
    gen TotImmRate = totimm / PopL1

    * For each bpl, year compute total imm and total pop outside the state
    gen state = substr(county_1990, 1, 2)
    egen immagg = total(imm), by(year bpl)         // national immigration
    egen stateimm = total(imm), by(year bpl state) // state immigration
    gen immLo = immagg - stateimm                  // total immigration with own state left out
    egen foreignagg = total(foreignL1), by(year bpl) // national foreign stock by birthplace
    egen foreignsta = total(foreignL1), by(year bpl state) // the state's own stock by bithplace
    gen foreignLo = foreignagg - foreignsta
    gen immrateLo = immLo / foreignLo

    sort county year bpl

    keep if year == 1930

    * Compute Bartik
    gen bartik_term = s_1900 * immrateLo
    collapse (sum) BartikLo = bartik_term  (mean) TotImmRate pop totforeign, by(county_1990 year)

    tempfile BAndImm
    save `BAndImm', replace
    


}

// all unmatched were from using (to be expected, 2,315)
merge m:1 county_1990 using `BAndImm', keep(3) nogen
save "${data}/AnalysisFile1930.dta", replace

/*************
2000 Census
*************/


