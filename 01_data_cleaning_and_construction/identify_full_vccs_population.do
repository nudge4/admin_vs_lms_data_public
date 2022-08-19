/* This script extracts the key admin measures of all student x term x college x course x section in the VCCS population*/

use "~\\Box Sync\\Clickstream\\data\\full\\LMS_data.dta", clear
keep vccsid
duplicates drop
merge 1:m vccsid using "~\\Box Sync\\Clickstream\\data\\Merged_Class.dta", keep(3) nogen
drop if strm >= 2202


preserve
	zipuse "~\Box Sync\VCCS restricted student data\Build\Class\Class_2020_3_spe.dta.zip", clear
	tempfile sp
	save "`sp'", replace
restore
append using "`sp'", force
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


sort vccsid strm subject course_num section section
egen first_strm = min(strm), by(vccsid)
gen first_ind = (first_strm == strm)


preserve
	keep vccsid strm
	duplicates drop
	merge 1:1 vccsid strm using "~\\Box Sync\\Clickstream\\data\\full\\dual.dta", keep(1 3) nogen
	drop if dual_ind == 1
	drop dual_ind
	sort vccsid strm
	drop strm
	duplicates drop
	sort vccsid
	tempfile vccsid_new
	save "`vccsid_new'", replace	
restore
merge m:1 vccsid using "`vccsid_new'", keep(3) nogen


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

** There are courses with multiple sessions within the same student x term (could be across multiple colleges): if one session has a non-missing grade but the rest of the sessions have missing grades,
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




***************************************************************************************
** Next find out the cumulative (college-level) credits each student has earned in VCCS
***************************************************************************************
gen college_lvl = regexm(course_num, "^[1-9][0-9][0-9]$")
gen online_ind = inlist(instmod, "CV", "ER", "WW", "HY")
gen passd = 1
replace passd = 0 if inlist(grade,"F","I","R","U","W","X","XN","XY") // Recognize all non-passing grades
gen earned_credit = 0
gen earned_credit_online = 0
gen att_credit = 0
replace earned_credit = credit if passd == 1 & college_lvl == 1
replace earned_credit_online = credit if passd == 1 & college_lvl == 1 & online_ind == 1
replace att_credit = credit if college_lvl == 1
sort vccsid strm subject course_num
bys vccsid strm: egen term_cred_earn = sum(earned_credit)
bys vccsid strm: egen term_cred_earn_online = sum(earned_credit_online)
bys vccsid strm: egen term_cred_att = sum(att_credit)
sort vccsid strm subject course_num
assert term_cred_earn <= term_cred_att
preserve // For each student x term, find out the running cumulative earned credits at the beginning of the term
	keep vccsid strm term_cred_earn term_cred_earn_online term_cred_att
	duplicates drop
	sort vccsid strm
	bys vccsid: gen prev_term_cred_earn = term_cred_earn[_n-1] if _n > 1
	bys vccsid: gen prev_term_cred_earn_online = term_cred_earn_online[_n-1] if _n > 1
	replace prev_term_cred_earn = 0 if prev_term_cred_earn == . // cum_cred_earn is calculated based on the number of credits students are expected to earn (attempted credits) in the "current term" (term in which course recommendation will be implemented)
	replace prev_term_cred_earn_online = 0 if prev_term_cred_earn_online == .
	bys vccsid: gen cum_cred_earn_old = sum(prev_term_cred_earn) // cum_cred_earn_old is calculated based on the number of credits students actually earned in the "current term" (term in which course recommendation will be implemented)
	bys vccsid: gen cum_cred_earn_online = sum(prev_term_cred_earn_online)
	bys vccsid: gen cum_cred_earn = 0 if _n == 1
	bys vccsid: replace cum_cred_earn = cum_cred_earn_old - term_cred_earn[_n-1] + term_cred_att[_n-1] if _n > 1 // The only difference in terms of number of credits between cum_cred_earn_old and cum_cred_earn is the credits in the most recent term
	assert cum_cred_earn >= cum_cred_earn_old
	drop prev_term_cred_earn term_cred_earn term_cred_att
	sort vccsid strm cum_cred_earn
	tempfile cum_credits
	save "`cum_credits'", replace
restore
merge m:1 vccsid strm using "`cum_credits'", keep(1 3) nogen
drop college_lvl passd earned_credit term_cred_earn term_cred_att term_cred_earn_online online_ind
sort vccsid strm subject course_num


************************************************************************************************************************************************************************
** Next aggregate multiple observations of courses (credits, course grades) so that there's a single observation of course grade per stuid x term x subject x course_num
************************************************************************************************************************************************************************
gen simplified_grade = grade
replace simplified_grade = "UNKNOWN" if inlist(grade, "", "*", "K", "N", "Z", "XN")
replace simplified_grade = "UNKNOWN" if inlist(grade, "R", "I", "X", "XY")
gen adj_credit = credit
replace adj_credit = credit/3 if inlist(grade, "W") // adj_credit is used for calculating term enrl_intesity: to simplify the calculation, we assume enrollment intensity of courses with grade "W" is only worth 1/3 of the credits
replace adj_credit = credit/2 if inlist(grade, "X", "XY", "XN", "R") // we assume enrollment intensity of audited courses as well as the courses marked as "re-enroll" is only worth 1/2 of the credits
gen effective_credit = credit // effective_credit is used for estimating the new course grades if there're multiple observations per stuid x term x subject x course_num
replace effective_credit = 0 if simplified_grade == "UNKNOWN" | simplified_grade == "W"
gen effective_credit_2 = credit // effective_credits_2 is used for estimating the cumulative gpa
replace effective_credit_2 = 0 if (!regexm(course_num, "^[0-9][0-9][0-9]$") & !regex(course_num, "^[0-9][0-9][0-9]L$") & !regex(course_num, "^[0-9][0-9][0-9][0-9]L$")) | !inlist(grade, "A", "B", "C", "D", "F") // estimating college-level cum GPA only include non-developmental courses whose grades are A/B/C/D/F
gen numeric_grade = 0
replace numeric_grade = 4 if inlist(grade, "A", "S", "P") // assume the courses with grades "S"/"P" is worth 4 grade points just as "A" courses
replace numeric_grade = 3 if grade == "B"
replace numeric_grade = 2 if grade == "C"
replace numeric_grade = 1 if grade == "D"
gen grade_point = numeric_grade*effective_credit
gen grade_point_2 = numeric_grade*effective_credit_2
sort vccsid strm subject course_num
bys vccsid strm subject course_num: egen sum_effective_credit = sum(effective_credit)
bys vccsid strm subject course_num: egen sum_grade_point = sum(grade_point)
bys vccsid strm subject course_num: egen sum_effective_credit_2 = sum(effective_credit_2)
bys vccsid strm subject course_num: egen sum_grade_point_2 = sum(grade_point_2)
gen est_grade = sum_grade_point/sum_effective_credit // If there are multiple observations per stuid x term x subject x course_num, we need to calculate a single course grade for it
gen new_credit = credit
replace new_credit = 0 if inlist(grade, "W", "X", "XN", "XY")
bys vccsid strm subject course_num: egen sum_credit = sum(new_credit)


************************************
** Further Cleanup and Aggregration
************************************
** Clean up the case where all observations per stuid x term x subject x course_num contain all "W" grades
gen tmp = 0
replace tmp = 1 if grade == "W"
egen withdrawn_1 = sum(tmp), by(vccsid strm subject course_num)
bys vccsid strm subject course_num: gen withdrawn_2 = _N
gen withdrawn_ind = (withdrawn_1 == withdrawn_2)
bys vccsid strm subject course_num: egen sum_adj_credit = sum(adj_credit)
** Clean up the case where for the same stuid x term x subject x course_num, there are multiple observations from different colleges (choose the college in which the course has higher credit and grade).
** So that there're a unique college corresponding to each stuid x term x subject x course_num
set seed 1234
gen r_num = runiform() // Use random number generator to break ties
gsort vccsid strm subject course_num -credit -numeric_grade r_num
bys vccsid strm subject course_num: gen college_tmp = college if _n == 1
bys vccsid strm subject course_num: egen college_new = mode(college_tmp)

*** Keep useful variables, drop duplicates so that the table is unique per student x term x course
keep vccsid strm subject course_num college_new sum_adj_credit est_grade withdrawn_ind sum_credit sum_effective_credit* sum_grade_point* cum_cred_earn cum_cred_earn_old cum_cred_earn_online first_ind
duplicates drop
isid vccsid strm subject course_num
sort vccsid strm subject course_num
rename college_new college
bys vccsid strm: egen term_credits_attempted = sum(sum_adj_credit) // total (adjusted) credits attempted by student x term
* drop if withdrawn_ind == 1
* drop if sum_adj_credit == 0
foreach v in effective_credit grade_point effective_credit_2 grade_point_2 {
	rename sum_`v' `v'
}
sort vccsid strm subject course_num
duplicates tag vccsid strm subject course_num, gen(dups)
rename sum_adj_credit adj_credit
rename sum_credit credit
** Merge the remaining stuid x term x subject x course_num pairs that still have multiple observations
bys vccsid strm subject course_num: egen sum_adj_credit = sum(adj_credit)
bys vccsid strm subject course_num: egen sum_effective_credit = sum(effective_credit)
bys vccsid strm subject course_num: egen sum_grade_point = sum(grade_point)
bys vccsid strm subject course_num: egen sum_effective_credit_2 = sum(effective_credit_2)
bys vccsid strm subject course_num: egen sum_grade_point_2 = sum(grade_point_2)
gen new_est_grade = sum_grade_point/sum_effective_credit if dups >= 1
replace est_grade = new_est_grade if dups >= 1
drop dups sum_effective_credit sum_grade_point new_est_grade effective_credit* grade_point* withdrawn_ind adj_credit
duplicates drop
isid vccsid strm subject course_num
sort vccsid strm subject course_num
drop cum_cred_earn
rename cum_cred_earn_old cum_cred_earn
gen online_share = cum_cred_earn_online/cum_cred_earn
* keep if inlist(strm, 2193, 2194, 2203, 2204, 2212)
save "~\Box Sync\Clickstream\data\full\updated\temp_0_population.dta", replace


keep vccsid
duplicates drop
sort vccsid
save "~\Box Sync\Clickstream\data\full\updated\all_vccsid_population.dta", replace



**************************************************************************************
** Merge and process the Student files to retrieve demographic information of students
**************************************************************************************
local files: dir "~\Box Sync\VCCS restricted student data\Build\Student" files "*.dta.zip"
local i = 0
foreach file in `files' {
	if "`file'" != "student_all_records.dta.zip" {
		if `i' == 0 {
			zipuse "~\\Box Sync\\VCCS restricted student data\\Build\\Student\\`file'", clear
			keep vccsid strm age gender new_race
			merge m:1 vccsid using "~\Box Sync\Clickstream\data\full\all_vccsid_population.dta", keep(3) nogen
			gen source = `i'
		}
		else {
			preserve
				zipuse "~\\Box Sync\\VCCS restricted student data\\Build\\Student\\`file'", clear
				keep vccsid strm age gender new_race
				merge m:1 vccsid using "~\Box Sync\Clickstream\data\full\all_vccsid_population.dta", keep(3) nogen
				gen source = `i'
				tempfile stu_temp_`i'
				save "`stu_temp_`i''", replace
			restore
			append using "`stu_temp_`i''", force
		}
		di "`file'"
		local i = `++i'
	}
}

replace strm = 2003 if strm == .
gsort vccsid -source // relying on Student files during the more recent terms to determine the demographic information if there're discrepancies
egen max_source = max(source), by(vccsid)
keep if source == max_source
duplicates drop
drop source max_source

egen gender_new = mode(gender), by(vccsid)
gen male = (gender_new == "M")
drop gender gender_new
gen new_race_copy = new_race
replace new_race_copy = . if inlist(new_race_copy, 0, 7)
egen new_race_new = mode(new_race_copy), by(vccsid)
gen tmp = 0
replace tmp = 1 if new_race_copy == .
egen flag = min(tmp), by(vccsid)
replace new_race_new = 8 if flag == 0 & new_race_new == .
gen white = (new_race_new == 1)
gen afam = (new_race_new == 2)
gen hisp = (new_race_new == 3)
gen asian = (new_race_new == 4)
gen other = inlist(new_race_new,5,6,8)
drop new_race new_race_copy new_race_new tmp flag
duplicates drop
sort vccsid age
bys vccsid: keep if _n == 1
isid vccsid
sort vccsid
rename strm age_strm


merge 1:m vccsid using "~\Box Sync\Clickstream\data\full\temp_0_population.dta", keep(2 3) nogen
gen age_new = age + floor((strm-age_strm)/10)
drop age age_strm
rename age_new age



sort vccsid strm subject course_num
rename sum_effective_credit_2 effective_credit_2
rename sum_grade_point_2 grade_point_2
order vccsid strm term_credits_attempted subject course_num est_grade
gen course = subject + "_" + course_num
gen dev_ind = 1 // Identify all developmental courses
replace dev_ind = 0 if regexm(course_num, "^[0-9][0-9][0-9]$") | regexm(course_num, "^9[0-9]$") // Sometimes 9X courses are non-developmental: we don't know for sure
drop subject course_num
replace term_credits_attempted = 1.5*term_credits_attempted if mod(strm, 10) == 3 // Based on the statistics of the entire Class data of the historical cohorts, on average summer enrollment intensity is roughly 2/3 of fall/spring. So we make this adjustment in order that the summer enrollment intensity is comparable with the fall/spring enrollment intensity values
order vccsid-term_credits_attempted course
merge m:1 vccsid strm using "~\\Box Sync\\Clickstream\\data\\full\\agg_cum_gpa_by_term_long_format.dta", keep(1 3) nogen // This file is created by "create_cum_gpa_by_term_long_format.do"
sort vccsid strm course
isid vccsid strm course
preserve // If the VCCS GPA files don't contain the cumulative GPA data for a student x term, we manually calculate the prior cumulative GPA for it using the course-level information in VCCS Class files
	egen first_strm = min(strm), by(vccsid)
	gen flag = 1 if strm > first_strm & mi(cum_gpa)
	keep vccsid strm effective_credit_2 grade_point_2 flag
	bys vccsid strm: egen sum_effective_credit_2 = sum(effective_credit_2)
	bys vccsid strm: egen sum_grade_point_2 = sum(grade_point_2)
	keep vccsid strm sum_* flag
	duplicates drop
	isid vccsid strm
	sort vccsid strm
	bys vccsid: gen running_effective_credit_2 = sum(sum_effective_credit_2)
	bys vccsid: gen running_grade_point_2 = sum(sum_grade_point_2)
	gen crnt_cum_gpa = running_grade_point_2/running_effective_credit_2 // the cumulative GPA value up to the end of each term, calculated based on VCCS Class files
	keep vccsid strm flag crnt_cum_gpa
	reshape wide flag crnt_cum_gpa, i(vccsid) j(strm)
	reshape long flag@ crnt_cum_gpa@, i(vccsid) j(strm)
	sort vccsid strm
	bys vccsid: replace crnt_cum_gpa = crnt_cum_gpa[_n-1] if _n > 1 & crnt_cum_gpa == . // if the cum_gpa value is missing for a certain term, inherit from the most recen term in which cum_gpa isn't missing
	bys vccsid: gen prev_cum_gpa = crnt_cum_gpa[_n-1] if _n > 1 // Aligned with course recommendation implementation times
	keep vccsid strm flag prev_cum_gpa
	replace prev_cum_gpa = . if flag == .
	tempfile prev_gpa
	save "`prev_gpa'", replace
restore
merge m:1 vccsid strm using "`prev_gpa'", keep(3) nogen
isid vccsid strm course
sort vccsid strm course
replace cum_gpa = prev_cum_gpa if flag == 1
drop flag prev_cum_gpa sum_adj_credit effective_credit_2 grade_point_2
order vccsid-term_credits_attempted cum_gpa


keep if inlist(strm, 2193, 2194, 2203, 2204, 2212)
keep if length(course) == 7
save "~\\Box Sync\\Clickstream\\data\\full\\temp_1_population.dta", replace // save the intermediate file for training sample


use "~\Box Sync\Clickstream\data\full\all_vccsid_population.dta", clear
merge 1:m vccsid using "~\\Box Sync\\Clickstream\\data\\Merged_Class.dta", keep(3) nogen
drop if strm >= 2202


preserve
	zipuse "~\Box Sync\VCCS restricted student data\Build\Class\Class_2020_4_sue.dta.zip", clear
	merge m:1 vccsid using "~\Box Sync\Clickstream\data\full\all_vccsid_population.dta", keep(3) nogen
	tempfile su
	save "`su'", replace
restore
append using "`su'", force
preserve
	zipuse "~\Box Sync\VCCS restricted student data\Build\Class\Class_2020_6_fae.dta.zip", clear
	merge m:1 vccsid using "~\Box Sync\Clickstream\data\full\all_vccsid_population.dta", keep(3) nogen
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
	merge m:1 vccsid using "~\Box Sync\Clickstream\data\full\all_vccsid_population.dta", keep(3) nogen
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
* drop if credit == 0
gen college_lvl = regexm(course_num, "^[1-9][0-9][0-9]$")
drop if college_lvl == 0


keep vccsid college strm subject course_num section day_eve_code
duplicates drop
sort vccsid college strm subject course_num section day_eve_code
bys vccsid college strm subject course_num section: keep if _n == _N
isid vccsid college strm subject course_num section
sort vccsid college strm subject course_num section
gen course = subject + "_" + course_num
keep vccsid college strm course section
duplicates drop
merge m:1 vccsid college strm course using "~\Box Sync\Clickstream\data\full\updated\temp_1_population.dta", keep(2 3) nogen
* drop if credit == 0
drop if mi(section)
keep vccsid college strm course section male white afam hisp asian other age first_ind cum_cred_earn online_share cum_gpa
save "~\Box Sync\Clickstream\data\full\population.dta", replace
merge 1:1 vccsid college strm course section using "~\Box Sync\Clickstream\data\full\LMS_data_final.dta", keep(3) nogen

preserve
	keep vccsid race
	duplicates drop
	tab race, mi
restore
