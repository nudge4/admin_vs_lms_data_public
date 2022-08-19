/*
This script imputes the P+/P- grades assigned during the Spring 2020 term (when COVID outbreaks) following the percentage of A/B/C/D/F grades assigned in that term.
The imputed grades will be used when constructing predictors related course grades
*/

** Directory globals
global username="`c(username)'"
global root "/Users/${username}/Box Sync/GAA Transfer"
global data "/Users/${username}/Box Sync/VCCS restricted student data"
global intermediate_files_dir "${root}/data/intermediate_files/${username}"

zipuse "${data}/Build/Class/Class_2020_3_spe.dta.zip", clear
keep if grade == "P+" | grade == "P-"

set seed 72304783
gen r_num = runiform()
gen new_grade = "A" if grade == "P+"
replace new_grade = "D" if grade == "P-"
replace new_grade = "B" if r_num < 0.499 & grade == "P+"
replace new_grade = "C" if r_num < 0.181 & grade == "P+"
replace new_grade = "F" if r_num < 0.574 & grade == "P-"
drop r_num
save "~/Box Sync/Clickstream/data/y2020_3_spe_class_deid_new_grades.dta", replace
