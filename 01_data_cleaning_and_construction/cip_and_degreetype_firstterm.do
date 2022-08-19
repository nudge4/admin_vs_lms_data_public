/* This script generates the 2-digit CIP and degree level of each student x term, for all first-term observations.*/

forvalues y=2019/2020 {
	foreach v in "3_spe" "4_sue" "6_fae" {
		preserve
			zipuse "~\\Box Sync\\VCCS restricted student data\\Build\\Student\\Student_`y'_`v'.dta.zip", clear
			keep vccsid strm cip intended_degreetype total_credit_hrs
			duplicates drop
			gen degree_level = 4
			replace degree_level = 1 if intended_degreetype == "College Transfer"
			replace degree_level = 2 if intended_degreetype == "Occ/Tech"
			replace degree_level = 3 if intended_degreetype == "Certificate"
			gsort vccsid strm degree_level -total_credit_hrs
			bys vccsid strm: keep if _n == 1
			drop intended_degreetype total_credit_hrs
			replace cip = floor(cip)
			tempfile tmp
			save "`tmp'", replace
		restore
		append using "`tmp'", force
	}
}
drop if strm == 2192 | strm  == 2202
preserve
		zipuse "~\\Box Sync\\VCCS restricted student data\\Build\\Student\\Student_2021_3_spe.dta.zip", clear
		keep vccsid strm cip intended_degreetype total_credit_hrs
		duplicates drop
		gen degree_level = 4
		replace degree_level = 1 if intended_degreetype == "College Transfer"
		replace degree_level = 2 if intended_degreetype == "Occ/Tech"
		replace degree_level = 3 if intended_degreetype == "Certificate"
		gsort vccsid strm degree_level -total_credit_hrs
		bys vccsid strm: keep if _n == 1
		drop intended_degreetype total_credit_hrs
		replace cip = floor(cip)
		tempfile tmp
		save "`tmp'", replace
restore
append using "`tmp'", force
replace cip = 0 if cip == .
sort vccsid strm
merge 1:1 vccsid strm using "~\\Box Sync\\Clickstream\\data\\first\\all_vccsid_strm.dta", keep(2 3) nogen
bys cip: gen cip_counts = _N
replace cip = 99 if cip_counts < ceil(_N * 0.005)
sort vccsid strm
order vccsid strm
drop cip_counts
save "~\\Box Sync\\Clickstream\\data\\first\\cip_degree.dta", replace
