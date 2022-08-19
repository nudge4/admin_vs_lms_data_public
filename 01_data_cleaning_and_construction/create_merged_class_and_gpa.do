*Name: create_merged_class_and_gpa.do
*Author: Yifeng Song
*Purpose: Merge all of the VCCS Class and GPA files, so that the relevant term-level course-taking and GPA data could be easily retrieved in subsequent steps of building predictive models.


** Directory globals
global username="`c(username)'"
global data "/Users/${username}/Box Sync/VCCS restricted student data/Raw"
global intermediate_files_dir "/Users/${username}/Box Sync/Clickstream/data"


*************************************
** First create the merged Class file
*************************************
local str_var acadplan class_end class_start course_num curr grade_date home_campus instmod ps_session
** Load the first Class file
import delimited "${data}/Class/y2000_4_sue_class_deid.csv", clear
foreach v in `str_var' {
	tostring `v', replace
	replace `v' = "" if `v' == "."
}
** Load the rest of Class files one by one, and append it to the running merged file
local files : dir "${data}/Class" files "*.csv"
foreach file in `files' {
	if "`file'" != "y2000_4_sue_class_deid.csv" {
		di "`file'"
		preserve
			import delimited using "${data}/Class/`file'", clear
			tostring dl_code, replace
			replace dl_code = "" if dl_code == "."
			foreach v in `str_var' {
				tostring `v', replace
				replace `v' = "" if `v' == "."
			}
			tempfile class_file
			save "`class_file'", replace
		restore
		append using "`class_file'", force
	}
}
sort vccsid collnum strm subject course_num section
** Additional Cleaning for the grade variable
replace grade = "D" if grade == "(D)"
replace grade = "F" if grade == "(F)"
replace grade = "" if grade == "("
egen college_new = mode(college), by(collnum)
replace college = college_new if college == ""
drop college_new
save "${intermediate_files_dir}/Merged_Class.dta", replace



*************************************
** Next create the merged GPA file
*************************************
** Load the first GPA file
import delimited "${data}/GPA/gpa2003_deid.csv", clear
isid vccsid collnum strm
sort vccsid collnum strm
** Load the rest of GPA files one by one, and append it to the running merged file
local files : dir "${data}/GPA/" files "*.csv"
foreach file in `files' {
	if "`file'" != "gpa2003_deid.csv" {
		di "`file'"
		preserve
			import delimited using "${data}/GPA/`file'", clear
			isid vccsid collnum strm
			sort vccsid collnum strm
			tempfile gpa_file
			save "`gpa_file'", replace
		restore
		append using "`gpa_file'", force
	}
}
isid vccsid collnum str
sort vccsid collnum str
** Further Data Cleaning: If a student attempted zero credits in one term, the term gpa should be missing. If the student has attempted zero cumulative credits up to a term, the cumulative gpa of that term should be missing.
assert cur_gpa == 0 if unt_taken_prgrss == 0
assert cum_gpa == 0 if tot_taken_prgrss == 0
replace cur_gpa = . if unt_taken_prgrss == 0
replace cum_gpa = . if tot_taken_prgrss == 0
replace cum_gpa = 4 if cum_gpa <= 10 & cum_gpa > 4
replace cum_gpa = cum_gpa/10 if cum_gpa > 10
assert cum_gpa >= 0 & cum_gpa <=4 if cum_gpa != .
save "${intermediate_files_dir}/Merged_GPA.dta", replace
