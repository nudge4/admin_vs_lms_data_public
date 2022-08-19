/* This script merges the early-term LMS predictors with the early-term concurrent LMS predictors */

use "~\Box Sync\Clickstream\data\full\LMS_data_standardized.dta", clear
duplicates drop
merge 1:1 vccsid strm college course section using "~\Box Sync\Clickstream\data\full\LMS_data_standardized_concurrent.dta"
gen has_concurrent_qtr1 = _merge == 3
drop _merge
/*
foreach v in avg_click_cnt_per_session_qrt1 avg_session_len_qrt1 avg_time_per_day_qrt1 cum_act_day_cnt_qrt1 irreg_session_gap_qrt1 irreg_session_len_qrt1 longest_inact_qrt1 tot_click_cnt_qrt1 tot_time_qrt1 {
	replace `v'c = `v'c - `v'
}
foreach v in assign_sub_cnt_am_qtr1 assign_sub_cnt_day_qtr1 assign_sub_cnt_pm_qtr1 on_time_assign_share_qtr1 {
	replace has_`v'c = (has_`v'c == 1 & has_`v' == 1)
}
foreach v in assign_sub_cnt_am_qtr1 assign_sub_cnt_day_qtr1 assign_sub_cnt_pm_qtr1 on_time_assign_share_qtr1 {
	replace `v'c = `v'c - `v' if has_`v'c == 1
	replace `v'c = 0 if has_`v'c == 0
}
foreach v in avg_click_cnt_per_session_qrt1 avg_session_len_qrt1 avg_time_per_day_qrt1 cum_act_day_cnt_qrt1 irreg_session_gap_qrt1 irreg_session_len_qrt1 longest_inact_qrt1 tot_click_cnt_qrt1 tot_time_qrt1 {
	replace `v'c = 0 if `v'c == .
}
*/
foreach v in avg_session_len_qrt1 irreg_session_len_qrt1 tot_click_cnt_qrt1 tot_time_qrt1 {
	replace `v'c = `v'c - `v'
}
foreach v in assign_sub_cnt_qtr1 on_time_assign_share_qtr1 {
	replace has_`v'c = (has_`v'c == 1 & has_`v' == 1)
}
foreach v in assign_sub_cnt_qtr1 on_time_assign_share_qtr1 {
	replace `v'c = `v'c - `v' if has_`v'c == 1
	replace `v'c = 0 if has_`v'c == 0
}
foreach v in avg_session_len_qrt1 irreg_session_len_qrt1 tot_click_cnt_qrt1 tot_time_qrt1 {
	replace `v'c = 0 if `v'c == .
}
order vccsid strm college course section
sort vccsid strm college course section
isid vccsid strm college course section
save "C:\Users\ys8mz\Box Sync\Clickstream\data\full\LMS_data_standardized.dta", replace
