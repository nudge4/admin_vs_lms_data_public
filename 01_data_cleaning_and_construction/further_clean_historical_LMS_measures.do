/* This script further cleans the historical LMS data by handling the missing values within the assignments and discussion forums measures */

use "~\Box Sync\Clickstream\data\full\LMS_data_historical.dta", clear

/*
replace session_cnt_halfterm = 0 if mi(session_cnt_halfterm)
replace cum_act_day_cnt_qrt2 = 0 if mi(cum_act_day_cnt_qrt2)
replace cum_act_day_cnt_qrt3 = 0 if mi(cum_act_day_cnt_qrt3)

replace assign_sub_cnt_am = assign_sub_cnt - assign_sub_cnt_day - assign_sub_cnt_pm if mi(assign_sub_cnt_am)
replace assign_sub_cnt_pm = assign_sub_cnt - assign_sub_cnt_day - assign_sub_cnt_am if mi(assign_sub_cnt_pm)
replace assign_sub_cnt_day = assign_sub_cnt - assign_sub_cnt_pm - assign_sub_cnt_am if mi(assign_sub_cnt_day)
gen flag = mi(assign_sub_cnt_am) + mi(assign_sub_cnt_pm) + mi(assign_sub_cnt_day)
gen new_flag = 0
replace new_flag = 1 if flag == 2 & !mi(assign_sub_cnt) & (assign_sub_cnt == assign_sub_cnt_am | assign_sub_cnt == assign_sub_cnt_pm | assign_sub_cnt == assign_sub_cnt_day)
replace assign_sub_cnt_day = 0 if mi(assign_sub_cnt_day) & new_flag == 1
replace assign_sub_cnt_pm = 0 if mi(assign_sub_cnt_pm) & new_flag == 1
replace assign_sub_cnt_am = 0 if mi(assign_sub_cnt_am) & new_flag == 1
drop flag new_flag
foreach v in day pm am {
	gen has_assign_sub_cnt_`v' = !mi(assign_sub_cnt_`v')
	replace assign_sub_cnt_`v' = 0 if mi(assign_sub_cnt_`v')
}
*/

replace on_time_assign_cnt = assign_sub_cnt - late_assign_cnt if !mi(assign_sub_cnt) & !mi(late_assign_cnt) & mi(on_time_assign_cnt)
assert on_time_assign_cnt >= 0
gen on_time_assign_share = on_time_assign_cnt / assign_sub_cnt // Derive the share of on time submissions from the raw data
gen has_on_time_assign_share = !mi(on_time_assign_share)
replace on_time_assign_share = 0 if mi(on_time_assign_share)
drop on_time_assign_cnt late_assign_cnt
gen has_assign_sub_cnt = !mi(assign_sub_cnt) // Indicator for missing values
replace assign_sub_cnt = 0 if mi(assign_sub_cnt)
/*
assert mi(avg_word_reply) if mi(disc_reply_cnt)
assert mi(avg_word_post) if mi(disc_post_cnt)
*/
replace disc_reply_cnt = 0 if mi(disc_reply_cnt)
replace disc_post_cnt = 0 if mi(disc_post_cnt)
replace disc_tot_messages = 0 if mi(disc_tot_messages)
assert disc_reply_cnt + disc_post_cnt == disc_tot_messages
/*
replace avg_word_post = 0 if mi(avg_word_post)
replace avg_word_reply = 0 if mi(avg_word_reply)
*/
replace avg_word_tot = 0 if mi(avg_word_tot)
replace avg_depth_post = 0 if mi(avg_depth_post)
drop disc_tot*

save "~\Box Sync\Clickstream\data\full\LMS_data_historical_updated.dta", replace
