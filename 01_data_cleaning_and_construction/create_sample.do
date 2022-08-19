/* This script creates the data set that contains the information of all prior courses taken, which will
be used to construct predictors related to prior courses later on */

**************************************
** Add in all other predictors created
**************************************
use "~\\Box Sync\\Clickstream\\data\\full\\updated\\temp_1.dta", clear
sort vccsid strm course
order vccsid strm course


*********************************************
* Create single table for the training sample
*********************************************
gen post_fa2009 = (strm >= 2094 & strm <= 2204)
replace post_fa2009 = . if strm == 2212
sort vccsid strm course
** Course-specific mean grades based on pre or post Fall 2009
egen mean_est_grade_tmp_1 = mean(est_grade) if post_fa2009 == 1, by(course)
egen mean_est_grade_1 = max(mean_est_grade_tmp_1), by(course)
egen mean_est_grade_tmp_0 = mean(est_grade) if post_fa2009 == 0, by(course)
egen mean_est_grade_0 = max(mean_est_grade_tmp_0), by(course)
** Universal mean grades (will be used in case course-specific mean grades are not available)
egen overall_mean_est_grade_tmp_1 = mean(est_grade) if post_fa2009 == 1
egen overall_mean_est_grade_1 = max(overall_mean_est_grade_tmp_1)
egen overall_mean_est_grade_tmp_0 = mean(est_grade) if post_fa2009 == 0
egen overall_mean_est_grade_0 = max(overall_mean_est_grade_tmp_0)
drop mean_est_grade_tmp* overall_mean_est_grade_tmp*

preserve
	keep course mean_* overall_*
	duplicates drop
	sort course
	save "~\\Box Sync\\Clickstream\\data\\full\\mean_course_grades.dta", replace // save all course-specific mean courses, which will be useful for dealing with missing grades course-specific training sample
restore

sort vccsid strm course
gen mi_grade = 0 // Courses with missing grades won't be used as target variables in the training/validation sample for building grade prediction models; However, when it comes to predicting course grades using the prior course-taking history, we'll use the imputed course grades to calculate the "clustered" predictors corresponding to each subject x level
replace mi_grade = 1 if est_grade == .
replace est_grade = mean_est_grade_1 if est_grade == . & (post_fa2009 == 1 | mi(post_fa2009)) // If the course was taken after Fall 2009 and the course grade is missing, impute the missing grade using the course-specifc mean grade of this course taken after Fall 2009
replace est_grade = mean_est_grade_0 if est_grade == . & post_fa2009 == 0 // If the course was taken prior to Fall 2009 and the course grade is missing, impute the missing grade using the course-specifc mean grade of this course taken prior to Fall 2009
replace est_grade = overall_mean_est_grade_1 if est_grade == . & (post_fa2009 == 1 | post_fa2009 == .) // Using the mean grade of all post Fall 2009 courses to impute the missing grade if the course-specific mean grade is unavailable and the course was taken after Fall 2009
replace est_grade = overall_mean_est_grade_0 if est_grade == . & post_fa2009 == 0 // Using the mean grade of all pre Fall 2009 courses to impute the missing grade if the course-specific mean grade is unavailable and the course was taken prior to Fall 2009
drop post_fa2009
drop mean_* overall* mi_grade dev_ind college term_credits_attempted cum_gpa age cum_cred_earn
sort vccsid strm course
isid vccsid strm course
keep if strm < 2212
save "~\\Box Sync\\Clickstream\\data\\full\\prior_courses.dta", replace
