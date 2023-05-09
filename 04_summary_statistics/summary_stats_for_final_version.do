

global user = c(username)
global box = "/Users/$user/Library/CloudStorage/Box-Box"
global project = "$box/Admin versus Clickstream"
global gitrepo "/Users/$user/BitHug/admin_vs_lms_data_public"

*** Reading in raw data
import delimited using "$project/first_term_sample.csv", clear
	gen sample = "first_term"
	tempfile first_term
	save `first_term', replace
	
import delimited using "$project/nonfirst_term_sample.csv", clear
	gen sample = "nonfirst_term"
	
append using `first_term'


************************************************
*** SUMMARY STATS OF ADMIN DATA ACROSS TERMS ***
************************************************

keep cum_gpa cum_cred_earn crnt_enr_intensity sample strm
duplicates drop

collapse (mean) cum_gpa cum_cred_earn crnt_enrl_intensity, by(sample strm)



*********************************************	
*** TRUE NEGATIVE RATES FOR SIMPLE MODELS ***
*********************************************

	*** Finding cumulative GPA at 22.2% percentile for non first-term sample
	preserve
		keep if is_validation==0 & sample == "nonfirst_term"
		order cum_gpa
		sort cum_gpa
		gen n = _n 
		sum n 
		gen total = r(N)
		gen perc = n / total
	restore

	*** Finding total time at 29.1 percent for first term sample
	preserve
		keep if is_validation==0 & sample == "nonfirst_term"
		order tot_click_cnt_qrt1
		sort tot_click_cnt_qrt1
		gen n = _n
		sum n 
		gen total = r(N)
		gen perc = n / total
		order perc tot_click_cnt_qrt1
	restore

	gen flag_gpa_nonfirstterm = cum_gpa <= 2.364 if ///
		is_validation==1 & sample=="nonfirst_term"
		
	gen flag_clicks_firstterm = tot_click_cnt_qrt1 <= -0.36678 if ///
		is_validation==1 & sample=="first_term"
		
	gen flag_clicks_nonfirstterm = tot_click_cnt_qrt1 <= -0.68264 if ///
		is_validation==1 & sample=="nonfirst_term"
				
		
	*** GPA model for returning students
		* Total true negative
		count if is_validation==1 & sample=="nonfirst_term" & ///
			inlist(actual_grade,"D","F","W")==1

		* Predicted negatives that are actually negative
		count if is_validation==1 & sample=="nonfirst_term" & ///
			inlist(actual_grade,"D","F","W")==1 & flag_gpa_nonfirstterm==1
			
		
	*** Total clicks for new students
		* Total true negative
		count if is_validation==1 & sample=="first_term" & ///
			inlist(actual_grade,"D","F","W")==1	
		
		* Predicted negatives that are actually negatiev
		count if is_validation==1 & sample=="first_term" & ///
			inlist(actual_grade,"D","F","W")==1 & flag_clicks_firstterm==1
			
	*** Total clicks for returning students
		* Total true negative
		count if is_validation==1 & sample=="nonfirst_term" & ///
			inlist(actual_grade,"D","F","W")==1

		* Predicted negatives that are actually negative
		count if is_validation==1 & sample=="nonfirst_term" & ///
			inlist(actual_grade,"D","F","W")==1 & flag_clicks_nonfirstterm==1	


*******************************************************************			
*** SUMMARY STATS OF LMS PREDICTORS ACROSS A VARIETY OF SAMPLES ***			
*******************************************************************
			
*** LMS predictors to generate extra summary stats
*** In the order they appear in the appendix table
*** Focusing on early-term target course
global lmspred "assign_sub_cnt has_assign_sub_cnt on_time_assign_share has_on_time_assign_share"
global lmspred "$lmspred avg_session_len irreg_session_len tot_click_cnt tot_time"
global lmspred "$lmspred avg_depth_post avg_word_tot disc_post_cnt disc_reply_cnt"

	* removing "qrt1_raw" and "qtr1_raw" suffix for ease
	rename *_qrt1_raw *
	rename *_qtr1_raw *
	rename has_on_time_assign_share_qtr1 has_on_time_assign_share
	
	* Filling in actual zeros 
	replace avg_session_len = 0 if avg_session_len==.
	replace tot_click_cnt = 0 if tot_click_cnt==.
	replace tot_time = 0 if tot_time==.
	replace avg_session_len = 0 if avg_session_len==.
	
	* Variables with Zero = missing
	replace avg_depth_post = . if avg_depth_post==0
	replace avg_word_tot = . if avg_word_tot==0 
	replace on_time_assign_share = . if has_on_time_assign_share==0
	replace assign_sub_cnt = . if has_assign_sub_cnt==0
	
	* Ordering variables in the way I want them in the summary stat table
	rename tot_time 				_01tot_time
	rename tot_click_cnt 			_02tot_click_cnt
	rename avg_session_len			_03avg_session_len
	rename irreg_session_len 		_04irreg_session_len
	rename assign_sub_cnt 			_05assign_sub_cnt
	rename has_assign_sub_cnt 		_06has_assign_sub_cnt
	rename on_time_assign_share 	_07on_time_assign_share
	rename has_on_time_assign_share _08has_on_time_assign_share
	rename disc_post_cnt 			_09disc_post_cnt
	rename disc_reply_cnt 			_10disc_reply_cnt
	rename avg_depth_post 			_11avg_depth_post
	rename avg_word_tot 			_12avg_word_tot

	
	global lmspred ""
	global lmspred "$lmspred _01tot_time _02tot_click_cnt _03avg_session_len"
	global lmspred "$lmspred _04irreg_session_len _05assign_sub_cnt _06has_assign_sub_cnt"
	global lmspred "$lmspred _07on_time_assign_share _08has_on_time_assign_share"	
	global lmspred "$lmspred _09disc_post_cnt _10disc_reply_cnt _11avg_depth_post"	
	global lmspred "$lmspred _12avg_word_tot"
	sum $lmspred
	
*** Creating summary stat tables for each sample of interest

	* First defining samples of interest
	gen full = 1 
	gen summer2019 = strm==2193
	gen fall2019 = strm==2194
	gen summer2020 = strm==2203
	gen fall2020 = strm==2204
	gen spring2021 = strm==2212
	gen eng111 = course=="ENG_111"
	gen eng112 = course=="ENG_112"
	gen bio101 = course=="BIO_101"
	gen mth154 = course=="MTH_154"
	gen mth161 = course=="MTH_161"
	global samples "full summer2019 fall2019 summer2020 fall2020 spring2021"
	global samples "$samples eng111 eng112 bio101 mth154 mth161"
	
	* Prepping data for collapsing for summary stat tables
	global meanvars ""
	global p50vars ""
	global sdvars ""
	foreach var of global lmspred {
	foreach stat in mean p50 sd {

		gen `var'_`stat' = `var'
		global `stat'vars "${`stat'vars} `var'_`stat'"
		
		}
		}
	* Collapsing data for each sample of interest
	local sample_num= 1 
	foreach sample of global samples {
		preserve
			keep if `sample' == 1
			gen n = 1
			collapse (mean) $meanvars (p50) $p50vars (sd) $sdvars (sum) n
			gen sample_num = `sample_num' 
			tempfile `sample'
			save ``sample'', replace
			local sample_num = `sample_num' + 1
		restore
		}
	
	* Compiling summary stats across samples
	clear 
	foreach sample of global samples {
		append using ``sample''
		}
	xpose, clear varname
	sort _varname
	
	drop if _varname=="_06has_assign_sub_cnt_p50" 
	drop if _varname=="_06has_assign_sub_cnt_sd"
	drop if _varname=="_08has_on_time_assign_share_p50" 
	drop if _varname=="_08has_on_time_assign_share_sd"
