clear all
do globals

* Set graphics on if you wish to see the output in the stata window
set graphics off

* ==============================================================================
* Cross-tab heatmaps of industry x occupation for Wisconsin, 1930 vs 2000,
* split by nativity (domestic- vs foreign-born). Output is a combined 2x2
* graph: rows = year (1930, 2000), columns = nativity (domestic, foreign).
*
* OCC1950 (245 detailed codes) and IND1950 (146 detailed codes) are too
* granular to plot directly, so both are collapsed to the standard 1950
* Census Bureau major groups before cross-tabbing. Code ranges below are
* taken directly from the OCC1950/IND1950 category lists in the extract
* codebook (usa_00400.xml), which lists detailed codes in contiguous blocks
* by major group.
* ==============================================================================

loc years 1930 2000
loc combined_graphs

foreach yr of local years {

    use "${data}/AnalysisFile`yr'.dta", clear
    keep if statefip == "55"

    * ---- Value labels for the major-group recodes ----
    * Defined inside the loop: "use, clear" above discards any label
    * definitions from memory, so defining these before the loop leaves
    * "label values" pointing at a label that no longer exists (this fails
    * silently - the axes just fall back to showing the raw numeric codes).
    cap label drop occ_major_lbl
    label define occ_major_lbl ///
        1  "Professional & technical"    ///
        2  "Farmers & farm managers"     ///
        3  "Managers & proprietors"      ///
        4  "Clerical workers"            ///
        5  "Sales workers"               ///
        6  "Craftsmen & foremen"         ///
        7  "Operatives"                  ///
        8  "Private household workers"   ///
        9  "Service workers"             ///
        10 "Farm laborers"               ///
        11 "Laborers (nonfarm)"

    cap label drop ind_major_lbl
    label define ind_major_lbl ///
        1  "Agriculture, forestry & fishing"    ///
        2  "Mining"                             ///
        3  "Construction"                       ///
        4  "Manufacturing"                      ///
        5  "Transportation & utilities"         ///
        6  "Wholesale trade"                    ///
        7  "Retail trade"                       ///
        8  "Finance, insurance & real estate"   ///
        9  "Business & repair services"         ///
        10 "Personal services"                  ///
        11 "Entertainment & recreation"         ///
        12 "Professional services"              ///
        13 "Public administration"

    * Foreign-born indicator, defined exactly as in SummaryTable.do
    gen foreign = bpl >= 100 if !missing(bpl)

    * ---- Collapse to 1950 Census major occupation groups ----
    recode occ1950              ///
        (0/99    = 1)           ///
        (100/123 = 2)           ///
        (200/290 = 3)           ///
        (300/390 = 4)           ///
        (400/490 = 5)           ///
        (500/595 = 6)           ///
        (600/690 = 7)           ///
        (700/720 = 8)           ///
        (730/790 = 9)           ///
        (810/840 = 10)          ///
        (910/970 = 11)          ///
        (else    = .)           ///
        , gen(occ_major)
    label values occ_major occ_major_lbl
    la var occ_major "Occupation (1950 major group)"

    * ---- Collapse to 1950 Census major industry groups ----
    recode ind1950              ///
        (105/126 = 1)           ///
        (206/239 = 2)           ///
        (246     = 3)           ///
        (306/499 = 4)           ///
        (506/598 = 5)           ///
        (606/627 = 6)           ///
        (636/699 = 7)           ///
        (716/756 = 8)           ///
        (806/817 = 9)           ///
        (826/849 = 10)          ///
        (856/859 = 11)          ///
        (868/899 = 12)          ///
        (906/946 = 13)          ///
        (else    = .)           ///
        , gen(ind_major)
    label values ind_major ind_major_lbl
    la var ind_major "Industry (1950 major group)"

    * ---- One heatmap per nativity group ----
    foreach nat in 0 1 {

        loc natlbl = cond(`nat' == 0, "Domestic-born", "Foreign-born")

        * i.varname notation makes heatplot pick up value labels for the
        * tick labels (a plain "ind_major occ_major" call only shows the
        * underlying numeric codes, even with a matching ylabel/xlabel).
        heatplot i.ind_major i.occ_major [aw = perwt]      ///
            if foreign == `nat' & !missing(occ_major, ind_major), ///
            statistic(percent) fillin(0)                  ///
            colors(YlOrRd) levels(8)                      ///
            ylabel(, angle(0) labsize(vsmall))            ///
            xlabel(, angle(45) labsize(vsmall))           ///
            ytitle("") xtitle("")                         ///
            legend(size(vsmall) title("% of group", size(vsmall))) ///
            title("`yr' - `natlbl'", size(medium))         ///
            name(g`yr'_`nat', replace)

        graph export "${output}/graphs/Heatmap_OccInd_`yr'_`nat'.pdf", ///
            replace name(g`yr'_`nat')

        loc combined_graphs `combined_graphs' g`yr'_`nat'
    }
}

* ---- Combine into a single 2x2 grid: rows = year, cols = nativity ----
graph combine `combined_graphs', cols(2)                 ///
    title("Industry x Occupation, Wisconsin", size(medium)) ///
    name(g_occind_combined, replace)

graph export "${output}/graphs/Heatmap_OccInd_Combined.pdf", ///
    replace name(g_occind_combined)