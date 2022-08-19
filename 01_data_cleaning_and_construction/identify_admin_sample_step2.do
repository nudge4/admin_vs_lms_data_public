/* This script continues identify_admin_sample_step1.do by merging in additional information
to identify the student x term x college x course x section observations to be included in
the study sample for non-first-term observations*/

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
			merge m:1 vccsid using "~\Box Sync\Clickstream\data\full\all_vccsid.dta", keep(3) nogen
			gen source = `i'
		}
		else {
			preserve
				zipuse "~\\Box Sync\\VCCS restricted student data\\Build\\Student\\`file'", clear
				keep vccsid strm age gender new_race
				merge m:1 vccsid using "~\Box Sync\Clickstream\data\full\all_vccsid.dta", keep(3) nogen
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
preserve
	zipuse "~\Downloads\Student_2021_3_spe.dta.zip", clear
	keep vccsid strm age gender new_race
	merge m:1 vccsid using "~\Box Sync\Clickstream\data\full\all_vccsid.dta", keep(3) nogen
	gen source = `i'
	tempfile stu_temp_`i'
	save "`stu_temp_`i''", replace
restore
append using "`stu_temp_`i''", force

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


drop male white hisp afam asian other
merge 1:m vccsid using "~\Box Sync\Clickstream\data\full\temp_0.dta", keep(2 3) nogen
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


preserve
	keep vccsid strm age cum_gpa cum_cred_earn
	duplicates drop
	sort vccsid strm
	isid vccsid strm
	merge 1:1 vccsid strm using "~\\Box Sync\\Clickstream\\data\\full\\all_vccsid_strm.dta", keep(3) nogen
	sort vccsid strm
	save "~\\Box Sync\\Clickstream\\data\\full\\age_gpa_earn.dta", replace
restore

drop if credit == 0
save "~\\Box Sync\\Clickstream\\data\\full\\temp_1.dta", replace // save the intermediate file for training sample


/*
keep vccsid
duplicates drop
merge 1:m vccsid using "C:\Users\ys8mz\Box Sync\Clickstream\data\all_vccsid_strm.dta", keep(3) nogen
sort vccsid strm
save "C:\Users\ys8mz\Box Sync\Clickstream\data\all_vccsid_strm.dta", replace
keep vccsid
duplicates drop
sort vccsid
save "C:\Users\ys8mz\Box Sync\Clickstream\data\all_vccsid.dta", replace
*/


use "~\Box Sync\Clickstream\data\full\all_vccsid_strm.dta", clear
merge 1:m vccsid strm using "~\Box Sync\Clickstream\data\full\LMS_data.dta", keep(1 3) nogen
sort strm college course section vccsid
save "~\Box Sync\Clickstream\data\full\LMS_data_new.dta", replace
