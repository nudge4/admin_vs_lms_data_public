/* This script cleans up the cumulative GPA data in the most recent term, which doesn't show up in the merged historical GPA file */

** Load the GPA file of the most recent term
import delimited "~\Downloads\gpa2212_deid.csv", clear
isid vccsid collnum strm
sort vccsid collnum strm
** Further Data Cleaning: If a student attempted zero credits in one term, the term gpa should be missing. If the student has attempted zero cumulative credits up to a term, the cumulative gpa of that term should be missing.
assert cur_gpa == 0 if unt_taken_prgrss == 0
assert cum_gpa == 0 if tot_taken_prgrss == 0
replace cur_gpa = . if unt_taken_prgrss == 0
replace cum_gpa = . if tot_taken_prgrss == 0
replace cum_gpa = 4 if cum_gpa <= 10 & cum_gpa > 4
replace cum_gpa = cum_gpa/10 if cum_gpa > 10
assert cum_gpa >= 0 & cum_gpa <= 4 if cum_gpa != .
save "~\Downloads\gpa2212_deid.dta", replace
