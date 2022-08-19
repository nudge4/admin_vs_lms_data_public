/* This script identifies all VCCS courses that are graded using A/B/C/D/F scale, which are potential samples to be included in predictive modeling */ 

zipuse "~\Box Sync\VCCS restricted student data\Build\Class\Class_2019_6_fae.dta.zip", clear
preserve
	zipuse "~\Box Sync\VCCS restricted student data\Build\Class\Class_2019_4_sue.dta.zip", clear
	tempfile su
	save "`su'", replace
restore
append using "`su'", force
preserve
	zipuse "~\Box Sync\VCCS restricted student data\Build\Class\Class_2020_4_sue.dta.zip", clear
	tempfile su
	save "`su'", replace
restore
append using "`su'", force
preserve
	zipuse "~\Box Sync\VCCS restricted student data\Build\Class\Class_2020_6_fae.dta.zip", clear
	tempfile fa
	save "`fa'", replace
restore
append using "`fa'", force
preserve
	local str_var acadplan class_end class_start course_num curr grade_date home_campus instmod ps_session
	** Load the first Class file
	import delimited "~/Downloads/y2021_3_spe_class_deid.csv", clear
	foreach v in `str_var' {
		tostring `v', replace
		replace `v' = "" if `v' == "."
	}
	tempfile sp
	save "`sp'", replace
restore
append using "`sp'", force
keep vccsid strm college subject course_num section credit grade
duplicates drop
drop if credit == 0
drop if inlist(grade, "", "I", "P", "P+", "R", "S", "U", "X", "XY")
replace grade = "W" if grade == "WC"
gen course = subject + "_" + course_num
sort strm college course section vccsid
order strm college course section vccsid
drop course_num subject
sort strm college course section vccsid grade
bys strm college course section vccsid grade: egen new_credit = sum(credit)
drop credit
duplicates drop
rename new_credit credit
collapse (first) grade (sum) credit, by(strm college course section vccsid)
isid strm college course section vccsid
save "~\Desktop\2019_2021_vccs_courses.dta", replace
