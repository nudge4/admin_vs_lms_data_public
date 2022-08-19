/* This script identifies all VCCS instructors who have taught the courses included in the study sample of all non-first-term observations */

clear
preserve
	zipuse "~\Box Sync\VCCS restricted student data\Build\Course\Course_2019_4_sue.dta.zip", clear
	tempfile su
	save "`su'", replace
restore
append using "`su'", force
preserve
	zipuse "~\Box Sync\VCCS restricted student data\Build\Course\Course_2019_6_fae.dta.zip", clear
	tempfile fa
	save "`fa'", replace
restore
append using "`fa'", force
preserve
	zipuse "~\ys8mz\Box Sync\VCCS restricted student data\Build\Course\Course_2020_4_sue.dta.zip", clear
	tempfile su
	save "`su'", replace
restore
append using "`su'", force
preserve
	zipuse "~\Box Sync\VCCS restricted student data\Build\Course\Course_2020_6_fae.dta.zip", clear
	tempfile fa
	save "`fa'", replace
restore
append using "`fa'", force
preserve
	zipuse "~\Downloads\Course_2021_3_spe.dta.zip", clear
	tempfile sp
	save "`sp'", replace
restore
append using "`sp'", force
sort strm college subject course_num section faculty_code
bys strm college subject course_num section: keep if _n == 1
isid strm college subject course_num section
keep strm college subject course_num section faculty_code vccsid_instructor
gen full_time = faculty_code == 1
drop faculty_code
sort strm college subject course_num section
gen course = subject + "_" + course_num
drop subject course_num


merge 1:m strm college course section using "~\Box Sync\Clickstream\data\full\LMS_data_new.dta", keep(2 3) nogen
sort strm college course section vccsid
replace full_time = 0 if full_time == .
preserve
	drop vccsid_instructor
	drop vccsid-tot_time_qrt1
	duplicates drop
	save "~\Box Sync\Clickstream\data\full\full_time.dta", replace
restore
keep vccsid_instructor strm college course section
rename strm teaching_strm
duplicates drop
drop if mi(vccsid_instructor)
sort vccsid_instructor teaching_strm course course section
save "~\Box Sync\Clickstream\data\full\instructors.dta", replace
keep vccsid_instructor college
duplicates drop
save "~\Box Sync\Clickstream\data\full\instructor_list.dta", replace
