clear all
do globals

* Set graphics on if you wish to see the output in the stata window
set graphics off

use "${data}/ImmigrationFlows1900to1930.dta", clear
append using "${data}/ImmigrationFlows1970to2010.dta"
sort county year bpl

* Compute number of domestics in each county
preserve

    keep if substr(bpl, 1, 1) == "0"
    collapse (sum) domestic, by(year countyfip)

    tempfile totdom
    save `totdom'
    
restore

drop if substr(bpl, 1, 1) == "0"
drop domestic
merge m:1 year countyfip using `totdom', nogen

* Compute foreign-born shares
gen pop   = domestic + foreign
gen share = foreign / pop

* Organize the data
order countyfip year bpl
sort countyfip year share

* Drop the extra zero at the end of countyfip
replace countyfip = substr(countyfip, 1, 5)

* ==============================================================================
* MAPS
* ==============================================================================

local n_groups 4

* ---- Set up shapefile ----
* Generates co99_d90.dta (attributes) and co99_d90_shp.dta (coordinates)
preserve
    local cwd "`c(pwd)'"
    cd "${data}/shapefiles"
    spshape2dta co99_d90, replace
    use co99_d90.dta, clear
    gen countyfip = ST + CO
    save co99_d90.dta, replace
    cd "`cwd'"
restore

* ---- Copy cleaning frame and map ----
frame copy default maps
loc maptyears 1900 1910 1920 1930 1970

frame maps {

    foreach yr of local maptyears {

        * Top N groups in Wisconsin this year by total immigrant count
        preserve
            keep if year == `yr' & substr(countyfip, 1, 2) == "55"
            collapse (sum) foreign, by(bpl origin_name)
            gsort -foreign
            keep in 1/`n_groups'
            levelsof bpl, local(top_bpls)
        restore

        foreach bpl_code of local top_bpls {

            * Save county-level shares for this group to a tempfile
            preserve
                keep if year == `yr' & bpl == "`bpl_code'"
                levelsof origin_name, local(oname) clean
                keep countyfip share
                tempfile mapdata
                save `mapdata'
            restore

            * Merge onto shapefile and plot in a disposable frame
            cap frame drop _maptmp
            frame create _maptmp
            frame _maptmp {

                use "${data}/shapefiles/co99_d90.dta", clear
                merge m:1 countyfip using `mapdata', nogen
                sort _ID

                replace share = round(share * 1e+6)

                * Counties with a genuine zero share get their own break so they don't
                * get absorbed into (and visually vanish inside) the bottom quantile bin.
                * True missing (unmerged) counties remain "No data" via ndfcolor below.
                qui sum share if !missing(share)
                local mx = string(r(max), "%12.0fc")
                local b5_num = r(max)

                qui _pctile share if !missing(share) & share > 0, p(25 50 75)
                local p1 = string(r(r1), "%12.0fc")
                local p2 = string(r(r2), "%12.0fc")
                local p3 = string(r(r3), "%12.0fc")
                local b2_num = r(r1)
                local b3_num = r(r2)
                local b4_num = r(r3)

                * Enforce strictly increasing break points (protects against ties
                * when a group has very few counties with positive shares)
                local b1_num = 0.5
                foreach i in 2 3 4 5 {
                    local j = `i' - 1
                    if (`b`i'_num' <= `b`j'_num') local b`i'_num = `b`j'_num' + 1e-6
                }

                spmap share using "${data}/shapefiles/co99_d90_shp.dta"    ///
                    if ST != "02" & ST != "15",     ///
                    id(_ID)                         ///
                    clmethod(custom) clbreaks(0 `b1_num' `b2_num' `b3_num' `b4_num' `b5_num') ///
                    fcolor("222 226 230%80" "232 155 158%50" "220 105 109%50" "209 55 61%50" "197 5 12%50") /// CROWE badgerred (197 5 12); first color is the "zero" bin
                    ocolor("0 0 0%50" ..)            ///
                    osize(vvthin ..)                ///
                    ndfcolor(gs14) ndocolor(none)   ///
                    title("`oname'") ///
                    legend(position(6) ring(1) rows(1) size(1.6) title("", size(1.6)) ///
                        label(2 "0")  label(3 "1 - `p1'")    ///
                        label(4 "`p1' - `p2'")  label(5 "`p2' - `p3'")    ///
                        label(6 "`p3' - `mx'")) ///
                    name(g`yr'_`bpl_code')

                graph export "../output/graphs/g`yr'_`bpl_code'.pdf", ///
                    replace name(g`yr'_`bpl_code')

            }
            frame drop _maptmp

        }

        * Combine the four maps for 1900, 1920, and 1970 into a single 2x2 grid
        if inlist(`yr', 1900, 1920, 1970) {

            loc combined_graphs
            foreach bpl_code of local top_bpls {
                loc combined_graphs `combined_graphs' g`yr'_`bpl_code'
            }

            graph combine `combined_graphs', cols(2) name(g`yr'_combined, replace)
            graph export "../output/graphs/g`yr'_combined.pdf", replace name(g`yr'_combined)
        }
    }
}
