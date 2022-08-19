/* This script creates certain course-specific predictors for first-term observations*/

use "~\Box Sync\Clickstream\data\first\all_vccsid.dta", clear
merge 1:m vccsid using "~\\Box Sync\\Clickstream\\data\\Merged_Class.dta", keep(3) nogen
drop if strm >= 2202


preserve
	zipuse "~\Box Sync\VCCS restricted student data\Build\Class\Class_2020_4_sue.dta.zip", clear
	merge m:1 vccsid using "~\Box Sync\Clickstream\data\first\all_vccsid.dta", keep(3) nogen
	tempfile su
	save "`su'", replace
restore
append using "`su'", force
preserve
	zipuse "~\Box Sync\VCCS restricted student data\Build\Class\Class_2020_6_fae.dta.zip", clear
	merge m:1 vccsid using "~\Box Sync\Clickstream\data\first\all_vccsid.dta", keep(3) nogen
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
	merge m:1 vccsid using "~\Box Sync\Clickstream\data\first\all_vccsid.dta", keep(3) nogen
	tempfile sp
	save "`sp'", replace
restore
append using "`sp'", force


replace course_num = substr(course_num, 2, .) if regexm(course_num,"^[0-9][0-9][0-9][0-9]L$")
replace course_num = substr(course_num, 1, 3) if regexm(course_num,"^[0-9][0-9][0-9]L$")
** There are courses with multiple sessions within the same student x college x term: if one session has a non-missing grade but the rest of the sessions have missing grades,
** then we can fill in those missing grades with the grade of the non-missing session of the course
sort vccsid college strm subject course_num
gen tmp = 1 if grade == ""
egen flag = max(tmp), by(vccsid college strm subject course_num) // flag indicates the course has missing grades
egen num_of_grades_tmp = nvals(grade), by(vccsid college strm subject course_num) 
egen num_of_grades = max(num_of_grades_tmp), by(vccsid college strm subject course_num) // if there's a unique non-missing grade for the course
drop num_of_grades_tmp
bys vccsid college strm subject course_num: gen num_of_obs = _N
egen new_grade = mode(grade) if flag == 1 & num_of_grades == 1, by(vccsid college strm subject course_num)
replace grade = new_grade if tmp == 1 & new_grade != "" // fill in the missing values under this category
drop new_grade tmp flag num_of_grades
drop if credit == 0 & num_of_obs == 1 & mi(grade)
drop num_of_obs
drop if credit == 0
gen college_lvl = regexm(course_num, "^[1-9][0-9][0-9]$")
drop if college_lvl == 0


keep vccsid college strm subject course_num section day_eve_code
duplicates drop
sort vccsid college strm subject course_num section day_eve_code
bys vccsid college strm subject course_num section: keep if _n == _N
isid vccsid college strm subject course_num section
sort vccsid college strm subject course_num section
/*
bys vccsid strm subject course_num: gen new_section_tmp = section if _n == 1
bys vccsid strm subject course_num: egen new_section = mode(new_section_tmp)
keep if section == new_section
isid vccsid strm subject course_num
drop new_*
*/
bys strm college subject course_num section: gen section_size = _N
gen eve_ind = day_eve_code == "E"
gen online_ind = day_eve_code == "O"
drop day_eve_code
gen lvl2_ind = substr(course_num, 1, 1) == "2"
gen course = subject + "_" + course_num
drop subject course_num
sort strm college course section vccsid
merge 1:1 strm college course section vccsid using "~\Box Sync\Clickstream\data\first\LMS_data_new.dta", keep(2 3) nogen
drop grade-avg_depth_post_qtr1
sort strm college course section vccsid
tabmiss
replace eve_ind = 0 if eve_ind == .
replace online_ind = 0 if online_ind == .
replace lvl2_ind = 0 if lvl2_ind == .
save "~\\Box Sync\\Clickstream\\data\\first\\part1_new.dta", replace
