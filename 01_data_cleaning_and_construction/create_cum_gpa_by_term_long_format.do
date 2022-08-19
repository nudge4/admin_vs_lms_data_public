/* This script creates the student x term cumulative GPA values and then convert the data into the long format, which will be used to construct term-specific predictors. */

use "~\\Box Sync\\Clickstream\\data\\full\\agg_cum_gpa_by_term.dta", clear // This file is created by the Python script "cum_gpa_by_term.ipynb"

merge 1:1 vccsid using "~\Box Sync\Clickstream\data\full\all_vccsid.dta", keep(2 3) nogen
merge 1:1 vccsid using "~\Box Sync\Clickstream\data\full\agg_cum_gpa_2212.dta", keep(1 3) nogen
sort vccsid
reshape long term_@, i(vccsid) j(cum_gpa)
rename cum_gpa term
rename term_ cum_gpa
gen tmp = 0
replace tmp = 1 if cum_gpa != .
egen flag = sum(tmp), by(vccsid)
drop if flag == 0
drop tmp flag

sort vccsid term
bys vccsid: gen new_cum_gpa = cum_gpa[_n-1] if _n > 1
drop cum_gpa
rename term strm
rename new_cum_gpa cum_gpa


isid vccsid strm
sort vccsid strm
save "~\\Box Sync\\Clickstream\\data\\full\\agg_cum_gpa_by_term_long_format.dta", replace
