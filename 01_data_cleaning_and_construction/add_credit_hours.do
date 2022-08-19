/* This script appends the credit hour value of each course section to the standardized LMS data */

forvalues y=2019/2020 {
	foreach v in "3_spe" "4_sue" "6_fae" {
		preserve
			zipuse "C:\\Users\\ys8mz\\Box Sync\\VCCS restricted student data\\Build\\Course\\Course_`y'_`v'.dta.zip", clear
			keep college strm subject course_num section credit
			duplicates drop
			gen course = subject + "_" + course_num
			drop subject course_num
			tempfile tmp
			save "`tmp'", replace
		restore
		append using "`tmp'", force
	}
}
preserve
		zipuse "C:\\Users\\ys8mz\\Downloads\\Course_2021_3_spe.dta.zip", clear
		keep college strm subject course_num section credit
		duplicates drop
		gen course = subject + "_" + course_num
		drop subject course_num
		tempfile tmp
		save "`tmp'", replace
restore
append using "`tmp'", force
collapse (sum) credit, by(college strm course section)
isid college strm course section


merge 1:m college strm course section using "~\Box Sync\Clickstream\data\full\LMS_data_standardized.dta", keep(2 3) nogen
replace credit = 3 if credit == .

preserve
	keep vccsid strm college course section
	duplicates drop
	sort vccsid strm college course section
	bys vccsid strm: drop if _N == 1
	keep vccsid strm
	duplicates drop
	tempfile tmp
	save "`tmp'", replace
restore
merge m:1 vccsid strm using "`tmp'", keep(3) nogen

* drop avg_depth_post_qtr1 avg_word_post_qtr1 avg_word_reply_qtr1 disc_post_cnt_qtr1 disc_reply_cnt_qtr1 grade
drop avg_depth_post_qtr1 avg_word_tot_qtr1 disc_post_cnt_qtr1 disc_reply_cnt_qtr1 grade
order vccsid
sort vccsid strm college course section
duplicates drop
isid vccsid strm college course section
save "~\Box Sync\Clickstream\data\full\LMS_data_standardized_with_credit.dta", replace
