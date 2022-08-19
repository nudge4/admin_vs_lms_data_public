/* This script further cleans the current LMS data by handling the missing values within the assignments and discussion forums measures */

use "~\Box Sync\Clickstream\data\full\LMS_data.dta", clear

/*
replace assign_sub_cnt_am_qtr1 = assign_sub_cnt_qtr1 - assign_sub_cnt_day_qtr1 - assign_sub_cnt_pm_qtr1 if mi(assign_sub_cnt_am_qtr1)
replace assign_sub_cnt_pm_qtr1 = assign_sub_cnt_qtr1 - assign_sub_cnt_day_qtr1 - assign_sub_cnt_am_qtr1 if mi(assign_sub_cnt_pm_qtr1)
replace assign_sub_cnt_day_qtr1 = assign_sub_cnt_qtr1 - assign_sub_cnt_pm_qtr1 - assign_sub_cnt_am_qtr1 if mi(assign_sub_cnt_day_qtr1)
gen flag = mi(assign_sub_cnt_am_qtr1) + mi(assign_sub_cnt_pm_qtr1) + mi(assign_sub_cnt_day_qtr1)
gen new_flag = 0
replace new_flag = 1 if flag == 2 & !mi(assign_sub_cnt_qtr1) & (assign_sub_cnt_qtr1 == assign_sub_cnt_am_qtr1 | assign_sub_cnt_qtr1 == assign_sub_cnt_pm_qtr1 | assign_sub_cnt_qtr1 == assign_sub_cnt_day_qtr1)
replace assign_sub_cnt_day_qtr1 = 0 if mi(assign_sub_cnt_day_qtr1) & new_flag == 1
replace assign_sub_cnt_pm_qtr1 = 0 if mi(assign_sub_cnt_pm_qtr1) & new_flag == 1
replace assign_sub_cnt_am_qtr1 = 0 if mi(assign_sub_cnt_am_qtr1) & new_flag == 1
drop flag new_flag
foreach v in day pm am {
	gen has_assign_sub_cnt_`v'_qtr1 = !mi(assign_sub_cnt_`v'_qtr1)
	replace assign_sub_cnt_`v'_qtr1 = 0 if mi(assign_sub_cnt_`v'_qtr1)
}
*/

replace on_time_assign_cnt_qtr1 = assign_sub_cnt_qtr1 - late_assign_cnt_qtr1 if !mi(assign_sub_cnt_qtr1) & !mi(late_assign_cnt_qtr1) & mi(on_time_assign_cnt_qtr1)
assert on_time_assign_cnt_qtr1 >= 0
gen on_time_assign_share_qtr1 = on_time_assign_cnt_qtr1 / assign_sub_cnt_qtr1 // Derive the share of on time submissions from the raw data
gen has_assign_qtr1 = !mi(on_time_assign_share_qtr1)
replace on_time_assign_share_qtr1 = 0 if mi(on_time_assign_share_qtr1)
drop on_time_assign_cnt_qtr1 late_assign_cnt_qtr1
gen has_assign_sub_cnt_qtr1 = !mi(assign_sub_cnt_qtr1) // Indicator for missing values
replace assign_sub_cnt_qtr1 = 0 if mi(assign_sub_cnt_qtr1)

/*
assert mi(avg_word_reply_qtr1) if mi(disc_reply_cnt_qtr1)
assert mi(avg_word_post_qtr1) if mi(disc_post_cnt_qtr1)
*/
replace disc_reply_cnt_qtr1 = 0 if mi(disc_reply_cnt_qtr1)
replace disc_post_cnt_qtr1 = 0 if mi(disc_post_cnt_qtr1)
replace disc_tot_messages_qtr1 = 0 if mi(disc_tot_messages_qtr1)
assert disc_reply_cnt_qtr1 + disc_post_cnt_qtr1 == disc_tot_messages_qtr1
/*
replace avg_word_post_qtr1 = 0 if mi(avg_word_post_qtr1)
replace avg_word_reply_qtr1 = 0 if mi(avg_word_reply_qtr1)
*/
replace avg_word_tot_qtr1 = 0 if mi(avg_word_tot_qtr1)
replace avg_depth_post_qtr1 = 0 if mi(avg_depth_post_qtr1)
drop disc_tot*

save "~\Box Sync\Clickstream\data\full\LMS_data_updated.dta", replace
