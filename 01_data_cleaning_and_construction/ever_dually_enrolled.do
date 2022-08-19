/* This script identifies whether each student has ever been dually enrolled up to the target term. */

clear
forvalues y=2000/2020 {
	foreach v in 3_spe 4_sue 6_fae {
		if "`y'_`v'" != "2000_3_spe" {
			preserve
				zipuse "~\Box Sync\VCCS restricted student data\Build\Student\Student_`y'_`v'.dta.zip", clear
				keep vccsid strm dual_enrollment
				bys vccsid: egen dual_ind = max(dual_enrollment)
				drop dual_enrollment
				duplicates drop
				isid vccsid
				sort vccsid
				tempfile dual
				save "`dual'", replace
			restore
			append using "`dual'", force
		}
	}
}
preserve
	zipuse "~\Downloads\Student_2021_3_spe.dta.zip", clear
	keep vccsid strm dual_enrollment
	bys vccsid: egen dual_ind = max(dual_enrollment)
	drop dual_enrollment
	duplicates drop
	isid vccsid
	sort vccsid
	tempfile dual
	save "`dual'", replace	
restore
append using "`dual'", force
sort vccsid strm

preserve
	use "~\Box Sync\Clickstream\data\full\term_lvl_gpa_enrl_intensity.dta", clear
	keep vccsid strm
	duplicates drop
	tempfile all_id_strm
	save "`all_id_strm'", replace
restore
merge 1:1 vccsid strm using "`all_id_strm'", keep(2 3) nogen
replace dual_ind = 0 if mi(dual_ind)
sort vccsid strm


foreach t in 2193 2194 2203 2204 2212 {
	preserve
		keep if strm < `t'
		egen ever_dual = max(dual_ind), by(vccsid)
		gen target_term = `t'
		drop dual_ind strm
		duplicates drop
		tempfile ever_`t'
		save "`ever_`t''", replace
	restore
}
clear
foreach t in 2193 2194 2203 2204 2212 {
	append using "`ever_`t''", force
}
sort vccsid target_term
rename target_term strm
merge 1:1 vccsid strm using "~\\Box Sync\\Clickstream\\data\\full\\all_vccsid_strm.dta", keep(2 3) nogen
save "~\\Box Sync\\Clickstream\\data\\full\\ever_dually_enrolled.dta", replace
