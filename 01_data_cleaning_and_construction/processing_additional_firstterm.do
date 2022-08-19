*Name: processing_additional_firstterm.do
*Author: Yifeng Song
*Purpose: Additional processing for the VCCS Class files, so that the demographic and non-course-specific predictors can be constructed for first-term observations.
* Those pre-constructed predictors will be retrieved in subsequent steps when building the clean training and validation sets for course performance prediction models.


*****************************************************************************************
** First deal with the missing grades issue (Same as the first part in "preprocessing.do"
*****************************************************************************************
** There are courses with multiple sessions within the same student x college x term: if one session has a non-missing grade but the rest of the sessions have missing grades,
** then we can fill in those missing grades with the grade of the non-missing session of the course
use "~\\Box Sync\\Clickstream\\data\\Merged_Class.dta", clear
merge m:1 vccsid using "~\Box Sync\Clickstream\data\first\all_vccsid.dta", keep(3) nogen
drop if strm >= 2202


preserve
	zipuse "~\Box Sync\VCCS restricted student data\Build\Class\Class_2020_3_spe.dta.zip", clear
	merge m:1 vccsid using "~\Box Sync\Clickstream\data\first\all_vccsid.dta", keep(3) nogen
	tempfile sp
	save "`sp'", replace
restore
append using "`sp'", force
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


** Modify the P+/P- grades in the Spring 2020 term
preserve
	keep if inlist(grade, "P+", "P-")
	keep vccsid strm college subject course_num section grade
	merge 1:1 vccsid strm college subject course_num section grade using "~\Box Sync\Clickstream\data\full\y2020_3_spe_class_deid_new_grades.dta", keep(1 3) nogen
	gen flag = mi(new_grade)
	tab flag
	set seed 982347
	gen r_num = runiform() if new_grade == ""
	tab r_num
	replace new_grade = "A" if grade == "P+" & flag == 1
	replace new_grade = "D" if grade == "P-" & flag == 1
	replace new_grade = "B" if r_num < 0.499 & grade == "P+" & flag == 1
	replace new_grade = "C" if r_num < 0.181 & grade == "P+" & flag == 1
	replace new_grade = "F" if r_num < 0.574 & grade == "P-" & flag == 1
	assert !mi(new_grade)
	drop r_num grade flag
	rename new_grade grade
	tempfile p_plus
	save "`p_plus'"
restore
keep if !inlist(grade, "P+", "P-")
append using "`p_plus'", force
sort vccsid collnum strm subject course_num section
replace grade = "W" if grade == "WC"


replace course_num = substr(course_num, 2, .) if regexm(course_num,"^[0-9][0-9][0-9][0-9]L$")
replace course_num = substr(course_num, 1, 3) if regexm(course_num,"^[0-9][0-9][0-9]L$")
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
** There are courses with multiple sessions within the same student x term: if one session has a non-missing grade but the rest of the sessions have missing grades,
** then we can fill in those missing grades with the grade of the non-missing session of the course
sort vccsid strm subject course_num
gen tmp = 1 if grade == ""
egen flag = max(tmp), by(vccsid strm subject course_num)
egen num_of_grades_tmp = nvals(grade), by(vccsid strm subject course_num)
egen num_of_grades = max(num_of_grades_tmp), by(vccsid strm subject course_num)
drop num_of_grades_tmp
bys vccsid strm subject course_num: gen num_of_obs = _N
egen new_grade = mode(grade) if flag == 1 & num_of_grades == 1, by(vccsid strm subject course_num)
replace grade = new_grade if tmp == 1 & new_grade != ""
drop new_grade tmp flag num_of_obs num_of_grades


****************************************************************************************************************************************************************
** Next find out the term GPA and term enrollment intensity by term for each historical VCCS student (the trendline predictors will be constructed using Python)
****************************************************************************************************************************************************************
gen adj_credit = credit
replace adj_credit = credit/3 if inlist(grade, "W") // adj_credit is used for calculating term_enrl_intesity
replace adj_credit = credit/2 if inlist(grade, "X", "XY", "XN", "R") // we assume enrollment intensity of audited courses as well as the courses marked as "re-enroll" is only worth 1/2 of the credits
gen effective_credit_2 = credit // effective_credits_2 is used for estimating the running term gpa
replace effective_credit_2 = 0 if !inlist(grade, "A", "B", "C", "D", "F")
gen numeric_grade = 0
replace numeric_grade = 4 if grade == "A"
replace numeric_grade = 3 if grade == "B"
replace numeric_grade = 2 if grade == "C"
replace numeric_grade = 1 if grade == "D"
gen grade_point_2 = numeric_grade*effective_credit_2
sort vccsid strm subject course_num
bys vccsid strm: egen term_credits_attempted = sum(adj_credit)
bys vccsid strm: egen sum_grade_point_2 = sum(grade_point_2)
bys vccsid strm: egen sum_effective_credit_2 = sum(effective_credit_2)
gen term_gpa = sum_grade_point_2/sum_effective_credit_2
keep vccsid strm term_credits_attempted term_gpa
duplicates drop
sort vccsid strm
isid vccsid strm
bys vccsid: gen term_num = _n
replace term_credits_attempted = 1.5*term_credits_attempted if mod(strm, 10) == 3 // adjust the enrollment intensity for Summer to get a more coherent estimation of trendline of enrollment intensity predictors
sort vccsid strm
* Enrollment Intensity of the term in which we'd like to predict course grades
gen crnt_enrl_intensity = term_credits_attempted



* Merge the different intermediate files
drop term_num term_gpa term_credits_attempted
order vccsid strm crnt_enrl_intensity
sort vccsid strm
merge 1:1 vccsid strm using "~\\Box Sync\\Clickstream\\data\\first\\all_vccsid_strm.dta", keep(2 3) nogen
sort vccsid strm
save "~\\Box Sync\\Clickstream\\data\\first\\twelve_additional_predictors.dta", replace // In fact there're a total of 18 predictors stored in this file
