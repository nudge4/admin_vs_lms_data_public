/*
This script identifies the dual enrollment status at the student x term level within 2019 Spring - 2021 Spring
*/

clear
forvalues y=2019/2020 {
	foreach v in 4_sue 6_fae {
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
save "~\\Box Sync\\Clickstream\\data\\full\\dual.dta", replace
