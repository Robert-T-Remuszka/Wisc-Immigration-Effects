clear all
do globals

eststo clear

/*************
1930 Census
*************/
use "${data}/AnalysisFile1930.dta", clear

* Indicators so that means represent sample proportions
gen female       = sex == 2
gen unemployed = empstat == 2

* Foreign-born indicator, defined exactly as in CleanIpums.do
* (gen foreign = substr(bpl, 1, 1) != "0" after 3-digit tostring, i.e. bpl >= 100)
gen foreign = bpl >= 100 if !missing(bpl)

* Non-white indicator (IPUMS RACE == 1 is White in both the 1930 and 2000 schemes)
gen nonwhite = race != 1 if !missing(race)

* 1930 IPUMS has no income question (income wasn't asked until 1940), so we
* use occscore (occupational income score) as a proxy - not comparable in
* levels to incwage below. OCCSCORE is coded in hundreds of 1950 dollars,
* so multiply by 100 to report in dollar levels.
gen income = occscore * 100

la var age        "Age"
la var income     "Income"
la var female     "Female"
la var unemployed "Unemployed"
la var foreign    "Foreign-born"
la var nonwhite   "Non-white"

qui count
local natN = r(N)
eststo Nat1930: qui estpost summarize age income female unemployed foreign nonwhite [aw = perwt]
estadd scalar N `natN', replace

qui count if statefip == "55"
local wiN = r(N)
eststo Wisc1930: qui estpost summarize age income female unemployed foreign nonwhite [aw = perwt] if statefip == "55"
estadd scalar N `wiN', replace

/*************
2000 Census
*************/
use "${data}/AnalysisFile2000.dta", clear

gen female       = sex == 2
gen unemployed = empstat == 2
gen foreign    = bpl >= 100 if !missing(bpl)
gen nonwhite   = race != 1 if !missing(race)
gen income     = incwage

la var age        "Age"
la var income     "Income"
la var female     "Female"
la var unemployed "Unemployed"
la var foreign    "Foreign-born"
la var nonwhite   "Non-white"

qui count
local natN = r(N)
eststo Nat2000: qui estpost summarize age income female unemployed foreign nonwhite [aw = perwt]
estadd scalar N `natN', replace

qui count if statefip == "55"
local wiN = r(N)
eststo Wisc2000: qui estpost summarize age income female unemployed foreign nonwhite [aw = perwt] if statefip == "55"
estadd scalar N `wiN', replace

/*************
Table
*************/
* LaTeX fragment (booktabs rules, no surrounding table environment) meant to
* be \input{} into a \begin{table}...\end{table} in the paper
esttab Nat1930 Wisc1930 Nat2000 Wisc2000 using "${tables}/SummaryTable.tex", replace ///
    booktabs nonumbers ///
    label mtitles("National 1930" "Wisconsin 1930" "National 2000" "Wisconsin 2000") ///
    cells("mean(fmt(%12.2fc))") collabels(none) ///
    stats(N, fmt(%12.0fc) labels("Observations")) ///
    varwidth(24) modelwidth(14)

esttab Nat1930 Wisc1930 Nat2000 Wisc2000, ///
    label mtitles("National 1930" "Wisconsin 1930" "National 2000" "Wisconsin 2000") ///
    cells("mean(fmt(%12.2fc))") collabels(none) ///
    stats(N, fmt(%12.0fc) labels("Observations"))
