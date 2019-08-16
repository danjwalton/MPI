********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Libya PAPFAM 2014 [STATA do-file]. 
Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

	
clear all 
set more off
set maxvar 10000
set mem 500m


*** Working Folder Path ***
global path_in "T:/GMPI 2.0/rdta/Libya PAPFAM 2014" 
global path_out "G:/GMPI 2.0/cdta"
global path_ado "T:/GMPI 2.0/ado"


********************************************************************************
*** LIBYA PAPFAM 2014 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
*** Selecting variables from KR, BR, IR, & MR recode & merging with PR recode 
********************************************************************************
/*The questionnaire instructs the enumerator to collect data on all children 
under 6. It does not collect any anthropometrics on adults. The report indicate 
that anthropometric data was successfully collected for 82% of children sampled. 
The majority of those not measured for height and weight were under 6 months 
old. */


********************************************************************************
*** Step 1.1 KR - CHILDREN's RECODE (under 5)
********************************************************************************
use "$path_in/HR.dta", clear 

rename _all, lower	
	
	/*The HR dta file for Libya PAPFAM 2014 includes all household members. For 
	the purpose of this section, keep only the child sample. Use variable h108a 
	to identify eligible children. NOTE: Sample size of children 0-5 years 
	reported in PAPFAM report is 15,941 */
	
desc h108a	
tab h108a, miss	
keep if h108a!=.
count
	/*NOTE: The data indicate a total of 15,941 children aged 0-5 years. 
	In terms of age in months, these children are between 0-72 months old.
	However, the Global MPI's child nutrition indicators (malnutrition and 
	stunting) specify child under 5. In other words, the global focus is only on 
	children between 0-59 months. To be consistent with the Global MPI criteria, 
	we have computed BMI-for-age for children from 60-72 months old. This is 
	done in the next section, that is, Step 1.1b */
desc h105a
	//Age of member in years
desc age_months
	//Age in months
tab age_months h105a, miss
	/*Children who were between the age of 5 years 1 month and up to 
	5 years 11 months were identified as 5 years old */
keep if age_months>=0 & age_months<=59		
	/*NOTE: The final sample count of children aged 0-59 months that is included 
	in the Global MPI estimation for Libya PAPFAM 2014 is 13,486 children*/ 
	

*** Generate individual unique key variable required for data merging
*** cluster=cluster number; 
*** hhnum=household number; 
*** h108=line number of eligible child
gen double ind_id = cluster*1000000 + hhnum*100 + hln 
format ind_id %20.0g
label var  ind_id "Individual ID"

duplicates report ind_id
	//NOTE: No duplicate observations

gen child_CH=1 
	//Generate identification variable for observations in child recode

count if h102==1
	/*NOTE: In the context of Libya PAPFAM 2014, all children aged 0-59 months 
	are permenant residents of their HH*/
	
	 
/* 
For this part of the do-file we use the WHO Anthro and macros. This is to 
calculate the z-scores of children under 5. 
Source of ado file: http://www.who.int/childgrowth/software/en/
*/	
	
*** Indicate to STATA where the igrowup_restricted.ado file is stored:
adopath + "$path_ado/igrowup_stata"

*** We will now proceed to create three nutritional variables: 
	*** weight-for-age (underweight),  
	*** weight-for-height (wasting) 
	*** height-for-age (stunting)
	
/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Child Growth Standards are stored. Note that we use 
strX to specify the length of the path in string. If the path is long, 
you may specify str55 or more, so it will run. */	
gen str100 reflib = "$path_ado/igrowup_stata"
lab var reflib "Directory of reference tables"


/* We use datalib to specify the working directory where the input STATA 
dataset containing the anthropometric measurement is stored. */
gen str100 datalib = "$path_out" 
lab var datalib "Directory for datafiles"


/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file (datalab_z_r_rc and datalab_prev_rc)*/
gen str30 datalab = "children_nutri_lby" 
lab var datalab "Working file"


*** Next check the variables that WHO ado needs to calculate the z-scores:
*** sex, age, weight, height, measurement, oedema & child sampling weight


*** Variable: SEX ***
lookfor sex
tab h103,miss
codebook h103,tab(30)	
	//"1" for male ;"2" for female
tab h103, nol
clonevar gender = h103
desc gender
tab gender


*** Variable: AGE ***
tab age_months, miss 
clonevar age = age_months
gen  str6 ageunit = "months" 
lab var ageunit "Months"


*** Variable: BODY WEIGHT (KILOGRAMS) ***
tab h904, miss   
clonevar weight = h904	
replace weight = . if h904>=99.9 
	//All missing values or out of range are replaced as "."
tab	h907 h904 if h904>=99.9 | h904==., miss 
	//h907: Result of child measurement
desc weight 
summ weight


*** Variable: HEIGHT (CENTIMETERS) 
tab h905, miss
clonevar height = h905 
replace height = . if h905>=999.9 
	//All missing values or out of range are replaced as "."
tab	h907 h905 if h905>=999.9 | h905==., miss
desc height 
summ height


*** Variable: MEASURED STANDING/LYING DOWN ***
	/*The PAPFAM survey provides a variable that controls for this: h906*/		
codebook h906, tab (10)
gen measure = "l" if h906==1 
	//Child measured lying down
replace measure = "h" if h906==2 
	//Child measured standing up
replace measure = " " if h906==9 | h906==0 | h906==. 
	//Replace with " " if unknown
desc measure
tab measure
	
	
*** Variable: OEDEMA ***
lookfor oedema
gen  oedema = "n"  
	//It assumes no-one has oedema
desc oedema
tab  oedema	


*** Variable: SAMPLING WEIGHT ***
gen  sw = hhweight
	//For household sample weight
desc sw
summ sw


/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age ageunit weight height ///
measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to create the child nutrition variables following WHO 
standards */
use "$path_out/children_nutri_lby_z_rc.dta", clear 

	
*** Standard MPI indicator ***
	//Takes value 1 if the child is under 2 stdev below the median & 0 otherwise	

gen	underweight = (_zwei < -2.0) 
replace underweight = . if _zwei == . | _fwei==1
lab var underweight  "Child is undernourished (weight-for-age) 2sd - WHO"
tab underweight, miss


gen stunting = (_zlen < -2.0)
replace stunting = . if _zlen == . | _flen==1
lab var stunting "Child is stunted (length/height-for-age) 2sd - WHO"
tab stunting, miss


gen wasting = (_zwfl < - 2.0)
replace wasting = . if _zwfl == . | _fwfl == 1
lab var wasting  "Child is wasted (weight-for-length/height) 2sd - WHO"
tab wasting, miss

count if _fwei==1 | _flen==1
	/*Note: In the context of Libya PAPFAM 2014, 959 children are replaced as 
	'.' because they have extreme z-scores which are biologically implausible */
 
	//Retain relevant variables:
keep ind_id child_CH cluster hhnum h108a underweight* stunting* wasting* 
order ind_id child_CH cluster hhnum h108a underweight* stunting* wasting* 
sort ind_id
save "$path_out/lby14_CH.dta", replace


	//Erase files from folder:
erase "$path_out/children_nutri_lby_z_rc.xls"
erase "$path_out/children_nutri_lby_prev_rc.xls"
erase "$path_out/children_nutri_lby_z_rc.dta"


********************************************************************************
*** Step 1.1b KR - CHILDREN's RECODE (5-6 years)
********************************************************************************
use "$path_in/HR.dta", clear 

rename _all, lower	
	
	/*The HR dta file for Libya PAPFAM 2014 includes all household members. For 
	the purpose of this section, keep only the child sample. Use variable h108a 
	to identify eligible children. */
	
desc h108a	
tab h108a, miss	
keep if h108a!=.
count
	//NOTE: We compute BMI-for-age for children from 60-72 months old.
keep if age_months>=60 & age_months<=72		
	/*NOTE: The final sample count of children aged 60-72 months that is 
	included in the Global MPI estimation for Libya PAPFAM 2014 is 2,454 
	children*/ 
	

*** Generate individual unique key variable required for data merging
*** cluster=cluster number; 
*** hhnum=household number; 
*** h108=line number of eligible child
gen double ind_id = cluster*1000000 + hhnum*100 + hln 
format ind_id %20.0g
label var  ind_id "Individual ID"

duplicates report ind_id
	//NOTE: No duplicate observations

gen child_CH=1 
	//Generate identification variable for observations in child recode

count if h102==1
	/*NOTE: In the context of Libya PAPFAM 2014, all children aged 60-72 months 
	are permenant residents of their HH*/
	
	
/* 
For this part of the do-file we use the WHO AnthroPlus software. This is to 
calculate the z-scores for children aged 60-72 months.
Source of ado file: https://www.who.int/growthref/tools/en/
*/
	
*** Indicate to STATA where the igrowup_restricted.ado file is stored:
adopath + "$path_ado/who2007_stata"


/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Growth reference are stored. Note that we use strX to specity 
the length of the path in string. */		
gen str100 reflib = "$path_ado/who2007_stata"
lab var reflib "Directory of reference tables"


/* We use datalib to specify the working directory where the input STATA data
set containing the anthropometric measurement is stored. */
gen str100 datalib = "$path_out" 
lab var datalib "Directory for datafiles"


/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file*/
gen str30 datalab = "children_nutri_lby" 
lab var datalab "Working file"


*** Next check the variables that WHO ado needs to calculate the z-scores:
*** sex, age, weight, height, measurement, oedema & child sampling weight


*** Variable: SEX ***
lookfor sex
tab h103,miss
codebook h103,tab(30)	
	//"1" for male ;"2" for female
tab h103, nol
clonevar gender = h103
desc gender
tab gender


*** Variable: AGE ***
tab age_months, miss 
	//Age is measured in months
clonevar age = age_months	
gen  str6 ageunit = "months" 
lab var ageunit "Months"


*** Variable: BODY WEIGHT (KILOGRAMS) ***
tab h904, miss   
clonevar weight = h904	
replace weight = . if h904>=99.9 
	//All missing values or out of range are replaced as "."
tab	h907 h904 if h904>=99.9 | h904==., miss 
	//h907: Result of child measurement
desc weight 
summ weight


*** Variable: HEIGHT (CENTIMETERS) 
tab h905, miss
clonevar height = h905 
replace height = . if h905>=999.9 
	//All missing values or out of range are replaced as "."
tab	h907 h905 if h905>=999.9 | h905==., miss
desc height 
summ height


*** Variable: MEASURED STANDING/LYING DOWN ***		
codebook h906, tab (10)
gen measure = "l" if h906==1 
	//Child measured lying down
replace measure = "h" if h906==2 
	//Child measured standing up
replace measure = " " if h906==9 | h906==0 | h906==. 
	//Replace with " " if unknown
desc measure
tab measure
	
	
*** Variable: Oedema ***
lookfor oedema
gen  oedema = "n"  
	//It assumes no-one has oedema
desc oedema
tab  oedema	


*** Variable: Sampling weight ***
gen  sw = hhweight
	//For household sample weight
desc sw
summ sw


/*We now run the command to calculate the z-scores with the adofile */
who2007 reflib datalib datalab gender age_month ageunit weight height oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to compute BMI-for-age*/
use "$path_out/children_nutri_lby_z.dta", clear 

		
gen	z_bmi = _zbfa
replace z_bmi = . if _fbfa==1 
lab var z_bmi "z-score bmi-for-age WHO"


*** Standard MPI indicator ***
gen	low_bmiage = (z_bmi < -2.0) 
	/*Takes value 1 if BMI-for-age is under 2 stdev below the median & 0 
	otherwise */
replace low_bmiage = . if z_bmi==.
lab var low_bmiage "Teenage low bmi 2sd - WHO"


	//Retain relevant variables:	
keep ind_id child_CH age_month low_bmiage*
order ind_id child_CH age_month low_bmiage*
sort ind_id
save "$path_out/lby14_CH_6Y.dta", replace

	//Erase files from folder:
erase "$path_out/children_nutri_lby_z.xls"
erase "$path_out/children_nutri_lby_prev.xls"
erase "$path_out/children_nutri_lby_z.dta"


********************************************************************************
*** Step 1.2  BR - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************
/*The purpose of step 1.2 is to identify children of any age who died in 
the last 5 years prior to the survey date.*/


use "$path_in/BH.dta", clear

rename _all, lower	

		
*** Generate individual unique key variable required for data merging
*** cluster=cluster number;  
*** hhnum=household number; 
*** wln=respondent's line number
gen double ind_id = cluster*1000000 + hhnum*100 + wln 
format ind_id %20.0g
label var ind_id "Individual ID"


lookfor interview
	/*NOTE: In the context of Libya PAPFAM 2014 There are two dates of 
	interview: 
	xhintc - Date of interview (CMC) 
	xwintc - Woman Date of Interview (CMC) 
	For accuracy purpose, we go with the Woman Date of Interview (CMC).
	*/
desc xw215c xw220c xhintc xwintc

compare xhintc xwintc
   
gen date_death = xw215c + xw220c
	//Date of death = date of birth (xw215c) + age at death (xw220c)
gen mdead_survey = xwintc - date_death
	//Months dead from survey = Date of interview (xwintc) - date of death
gen ydead_survey = mdead_survey/12
	//Years dead from survey
sum ydead_survey
	//There is one case with negative "years dead"
drop if ydead_survey<0	
	

gen age_death = xw220c if w216==2
label var age_death "Age at death in months"	
tab age_death, miss
	//Check whether the age is in months	
		
codebook w216, tab (10)	
gen child_died = 1 if w216==2
	//Redefine the coding and labels (1=child dead; 0=child alive)
replace child_died = 0 if w216==1
replace child_died = . if w216==.
label define lab_died 1 "child has died" 0 "child is alive"
label values child_died lab_died
tab w216 child_died, miss
	
		
bysort ind_id: egen tot_child_died = sum(child_died) 
	//For each woman, sum the number of children who died
		
	
	//Identify child under 18 mortality in the last 5 years
gen child18_died = child_died 
replace child18_died=0 if age_death>=216 & age_death<.
label values child18_died lab_died
tab child18_died, miss	
	
bysort ind_id: egen tot_child18_died_5y=sum(child18_died) if ydead_survey<=5
	/*Total number of children under 18 who died in the past 5 years 
	prior to the interview date */	
	
replace tot_child18_died_5y=0 if tot_child18_died_5y==. & tot_child_died>=0 & tot_child_died<.
	/*All children who are alive or children under 18 who died longer than 
	5 years from the interview date are replaced as '0'*/
	
replace tot_child18_died_5y=. if child18_died==1 & ydead_survey==.
	//Replace as '.' if there is no information on when the child died  

tab tot_child_died tot_child18_died_5y, miss

bysort ind_id: egen childu18_died_per_wom_5y = max(tot_child18_died_5y)
lab var childu18_died_per_wom_5y "Total child under 18 death for each women in the last 5 years (birth recode)"
	

	//Keep one observation per women
bysort ind_id: gen id=1 if _n==1
keep if id==1
drop id
duplicates report ind_id 

gen women_BR = 1 
	//Identification variable for observations in BR recode

	
	//Retain relevant variables
keep ind_id women_BR childu18_died_per_wom_5y 
order ind_id women_BR childu18_died_per_wom_5y
sort ind_id
save "$path_out/LBY14_BR.dta", replace	



********************************************************************************
*** Step 1.3  IR - WOMEN's RECODE  
*** (All eligible females 15-49 years in the household)
********************************************************************************
use "$path_in/WOM.dta", clear 

rename _all, lower	


*** Generate individual unique key variable required for data merging
*** cluster=cluster number;  
*** hhnum=household number; 
*** wln=respondent's line number
gen double ind_id = cluster*1000000 + hhnum*100 + wln 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id

gen women_WM=1 
	//Identification variable for observations in IR recode

tab w124 w206, miss   
	//Check whether all ever married women are present in the sample

			
	//Retain relevant variables:	
keep ind_id women_WM wmweight wresult w201 w206 w207a w207b 
order ind_id women_WM wmweight wresult w201 w206 w207a w207b 
sort  ind_id
save "$path_out/LBY14_WM.dta", replace	



********************************************************************************
*** Step 1.4 HH - Household's recode ***
********************************************************************************

use "$path_in/HH.dta", clear 

rename _all, lower


*** Generate individual unique key variable required for data merging
*** cluster=cluster number;  
*** hhnum=household number; 
gen	double hh_id = cluster*100 + hhnum 
format	hh_id %20.0g
lab var hh_id "Household ID"


save "$path_out/LBY14_HH.dta", replace


********************************************************************************
*** Step 1.5 HR - Household Member's recode ****
********************************************************************************

use "$path_in/HR.dta", clear 
	
rename _all, lower


*** Generate a household unique key variable at the household level using: 
	***cluster=cluster number 
	***hhnum=household number
gen double hh_id = cluster*100 + hhnum 
format hh_id %20.0g
label var hh_id "Household ID"


*** Generate individual unique key variable required for data merging using:
	*** cluster=cluster number; 
	*** hhnum=household number; 
	*** hln=respondent's line number.
gen double ind_id = cluster*1000000 + hhnum*100 + hln 
format ind_id %20.0g
label var ind_id "Individual ID"

	

********************************************************************************
*** Step 1.6 DATA MERGING 
******************************************************************************** 
 
 
*** Merging BR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/LBY14_BR.dta"
drop _merge
erase "$path_out/LBY14_BR.dta"


*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$path_out/LBY14_WM.dta"
tab wresult women_WM, miss col
bys hh_id: egen temp=sum(women_WM)
tab h101w temp, miss  
tab h101c temp, miss 
count if temp==0 & h101c >=1
	//NOTE: There is 1,326 women not eligible but with child measures 
drop temp _merge
erase "$path_out/LBY14_WM.dta"


*** Merging HH Recode 
*****************************************
merge m:1 hh_id using "$path_out/LBY14_HH.dta"
tab hresult if _m==2
drop  if _merge==2
	//Drop households that were not interviewed 
drop _merge
erase "$path_out/LBY14_HH.dta"


*** Merging CH Under 5 Recode 
*****************************************
merge 1:1 ind_id using "$path_out/LBY14_CH.dta"	
drop _merge
erase "$path_out/LBY14_CH.dta"
sort ind_id


*** Merging CH 5-6 years Recode 
*****************************************
merge 1:1 ind_id using "$path_out/LBY14_CH_6Y.dta"	
drop _merge
erase "$path_out/LBY14_CH_6Y.dta"
sort ind_id


********************************************************************************
*** Step 1.7 KEEPING ONLY DE JURE HOUSEHOLD MEMBERS ***
********************************************************************************

//Permanent (de jure) household members 
clonevar resident = h102 
codebook resident, tab (10) 
label var resident "Permanent (de jure) household member"

drop if resident!=1 
tab resident, miss
	/*Note: The Global MPI is based on de jure (permanent) household members 
	only. As such, non-usual residents will be excluded from the sample. 
	Note: However, in Libya PAPFAM 2014, all householders are permanent members.
	*/

********************************************************************************
*** Step 1.8 SUBSAMPLE VARIABLE ***
********************************************************************************

/*  
In the context of Libya PAPFAM 2014, height and weight measurements were
collected from all children (0-72 months). As such there is no presence of 
subsample. 
*/

gen subsample = .
label var subsample "Households selected as part of nutrition subsample" 
tab subsample, miss
	
	
********************************************************************************
*** Step 1.9 CONTROL VARIABLES
********************************************************************************

/* Households are identified as having 'no eligible' members if there are no 
applicable population, that is, children 0-5 years, adult women 15-49 years or 
men 15-59 years. These households will not have information on relevant 
indicators of health. As such, these households are considered as non-deprived 
in those relevant indicators.*/


*** No Eligible Women 
*****************************************
gen	fem_eligible = (women_WM==1) 
bys	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
tab no_fem_eligible, miss	
tab no_fem_eligible h101c, miss 
	/* NOTE: There is 1,326 individuals living in households without eligible 
	women but have child who was eligible for anthropometric measures. */
lab var no_fem_eligible "Household has no eligible women"


*** No Eligible Men 
*****************************************
	//NOTE: Libya PAPFAM 2014 have no male recode file 
gen no_male_eligible = . 
lab var no_male_eligible "Household has no eligible man"
tab no_male_eligible, miss

	
*** No Eligible Children Under 5  
*****************************************
gen child_eligible = 0
replace	child_eligible = 1 if h101c>=1 & (age_months>=0 & age_months<=59) 
bys	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
tab no_child_eligible,miss	

lab var no_child_eligible "Household has no children under 5 eligible"	


*** No Eligible Children 5-6 years 
*****************************************
gen child_eligible_6y = 0
replace	child_eligible_6y = 1 if h101c>=1 & (age_months>=60 & age_months<=72) 
bys	hh_id: egen hh_n_children_eligible_6y = sum(child_eligible_6y)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible_6y = (hh_n_children_eligible_6y==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
tab no_child_eligible_6y, miss	

lab var no_child_eligible_6y "Household has no children 5-6 years eligible"	



*** No Eligible Women and Men 
***********************************************
gen	no_adults_eligible = (no_fem_eligible==1 & no_male_eligible==1) 
lab var no_adults_eligible "Household has no eligible women or men"
tab no_adults_eligible, miss 
	/*Libya PAPFAM 2014 enumerated men, as household members but did not collect 
	child mortality information from men */

*** No Eligible Children and Women  
***********************************************
	/*NOTE: In the DHS datasets, we use this variable as a control 
	variable for the nutrition indicator if nutrition data is 
	present for children and women.*/
gen	no_child_fem_eligible = (no_child_eligible==1 & no_fem_eligible==1)
lab var no_child_fem_eligible "Household has no children or women eligible"
tab no_child_fem_eligible, miss 


*** No Eligible Women, Men or Children 
***********************************************
	/*NOTE: In the DHS datasets, we use this variable as a control 
	variable for the nutrition indicator if nutrition data is 
	present for children, women and men. */
gen no_eligibles = (no_fem_eligible==1 & no_male_eligible==1 & no_child_eligible==1)
lab var no_eligibles "Household has no eligible women, men, or children"
tab no_eligibles, miss

 	
*** No Eligible Subsample 
*****************************************
//Note that PAPFAM surveys do not collect hemoglobin data from women
gen no_hem_eligible = . 	
lab var no_hem_eligible "Household has no eligible individuals for hemoglobin measurements"
tab no_hem_eligible, miss	
	

drop fem_eligible hh_n_fem_eligible child_eligible hh_n_children_eligible 


sort hh_id ind_id


********************************************************************************
*** Step 1.10 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************


//Sample weight
clonevar weight = hhweight
label var weight "Sample weight"


//Area: urban or rural	
codebook area , tab (5)	 
replace area=0 if area==2  
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"



//Sex of household member
	//Ensure coding is "1" Male, "2" Female
codebook h103 
clonevar sex = h103 
label var sex "Sex of household member"


//Age of household member
codebook h105a, tab (100)
clonevar age = h105a  
replace age = . if age>=98
label var age "Age of household member"


//Age group 
recode age (0/4 = 1 "0-4")(5/9 = 2 "5-9")(10/14 = 3 "10-14") ///
		   (15/17 = 4 "15-17")(18/59 = 5 "18-59")(60/max=6 "60+"), gen(agec7)
lab var agec7 "age groups (7 groups)"	
	   
recode age (0/9 = 1 "0-9") (10/17 = 2 "10-17")(18/59 = 3 "18-59") ///
		   (60/max=4 "60+"), gen(agec4)
lab var agec4 "age groups (4 groups)"



//Marital status of household member
desc h106
clonevar marital = h106
codebook marital, tab (10)
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab h106 marital, miss


//Total number of de jure hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
drop member


//Subnational region
	/*NOTE: Libya PAPFAM 2014 was designed to provide estimates of key 
	indicators for the country as a whole, and for urban and rural of each of 
	the 21 districts sampled.*/ 	
lookfor region
codebook district, tab (99)
clonevar region = district
lab var region "Region for subnational decomposition"
codebook region, tab (100)

	

********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

	/*PAPFAM does not provide the number of years of education so we need to 
	construct that variable from the edulevel and eduhighyear variables */ 
codebook h110a , tab (99) 
	/*School attendance: 
	Currently attending; Attended in the past; Never attended; DK/Missing */	
codebook h110ba , tab (99) 
	/*Highest level reached: 
	KG;Basic;Secondary;Higher institute;University+;DK/Missing */	
tab h110ba h110a, miss
tab age if h110a==.
	/*Missing value in school attendance variable is because the data was not 
	collected from children aged 0-5 years. */

	
*** Creating educational level variable ***
clonevar edulevel = h110ba 
	//Highest educational level attended
replace edulevel = . if h110ba==8 | h110ba==9 | h110ba==.   
	//Check for the categories related to missing values
replace edulevel = 0 if h110a==3 
	//Assign edulevel=0 for individuals who never ever attended school
replace edulevel = 0 if age < 10
	/*The variable "edulevel" was replaced with a '0' given that the criteria for 
	the years of schooling indicator is household member aged 10 years or older */	
label define lab_edulevel 0 "None" 1 "Primary" 2 "Secondary"  3 "Higher" 4"University" 
label values edulevel lab_edulevel	
label var edulevel "Highest educational level attended"


*** Creating educational grade variable ***
tab h110bb h110ba,m
	//Check the relationship between highest grade and level
clonevar eduhighyear = h110bb 
	//Highest grade finished successfully
replace eduhighyear = .  if h110bb==. | h110bb==98 
	//Check for the categories related to missing values
replace eduhighyear = 0  if h110a==3 
	//Assign eduhighyear=0 for individuals who never ever attended school	
replace eduhighyear = 10  if h110bb==88 & edulevel==4
	//Assign eduhighyear=10 for individuals who have postgraduate degree
replace eduhighyear = 0 if age < 10
	/*The variable "eduhighyear" was replaced with a '0' given that the criteria for 
	the years of schooling indicator is household member aged 10 years or older */
replace eduhighyear = 0 if edulevel<1
	//Cleaning inconsistencies 
replace eduhighyear=. if (eduhighyear!=. & edulevel==.) & (eduhighyear!=0 & edulevel==.)
	//Cleaning further inconsistencies 	
replace eduhighyear=. if edulevel==. 	
	//Cleaning further inconsistencies 
lab var eduhighyear "Highest year of education completed"

tab eduhighyear edulevel,miss

	
*** Finally: creating the years of schooling variable ***
gen	eduyears = eduhighyear
/*NOTE: Children in Libya attend primary school between the ages of 6 and 15, 
that is for 9 years. Hence replacements are necessary because eduhighyear does 
not consider consecutive years after edulevel>=1 */
replace eduyears = 0 if edulevel<1   
replace eduyears = 9+eduhighyear if edulevel==2
replace eduyears = 13+eduhighyear if edulevel==3
	/*These  higher institutions  offer programmes in many vocational 
	specialities for a  period  of  three  years  after  obtaining  the 
	secondary   school   certificate. So one may assume that this category 
	should be +13 following secondary completion */
replace eduyears = 13+eduhighyear if edulevel==4 
	/*The bachelor degree (university, category 4) requires four years of study 
	in most programmes after obtaining the secondary school certificate. So one 
	may assume that this category should be +13 as well following secondary 
	completion */
replace eduyears = . if edulevel==. & eduhighyear==. 
	
replace eduyears = . if age<=eduyears & age>0
	/*There are cases in which the years of schooling are greater than the 
	age of the individual, which is clearly a mistake in the data. There might 
	also be individuals that show too much schooling given their age 
	e.g. a 7 year-old with 5 years of schooling). 
	Please check whether this is the case and correct when necessary */
replace eduyears = 0 if age< 10  
	/*The variable "eduyears" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 10 years or older */
lab var eduyears "Total number of years of education accomplished"



	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the household members aged 10 years 
	and older */	
gen temp = 1 if eduyears!=. & age>=10 & age!=.
bysort	hh_id: egen no_missing_edu = sum(temp)
	/*Total household members who are 10 years and older with no missing 
	years of education */
gen temp2 = 1 if age>=10 & age!=.
bysort hh_id: egen hhs = sum(temp2)
	//Total number of household members who are 10 years and older 
replace no_missing_edu = no_missing_edu/hhs
replace no_missing_edu = (no_missing_edu>=2/3)
	/*Identify whether there is information on years of education for at 
	least 2/3 of the household members aged 10 years and older */
tab no_missing_edu, miss
label var no_missing_edu "No missing edu for at least 2/3 of the HH members aged 10 years & older"		
drop temp temp2 hhs


*** Standard MPI ***
/*The entire household is considered deprived if no household member aged 
10 years or older has completed SIX years of schooling. */
******************************************************************* 
gen	 years_edu6 = (eduyears>=6)
	/* The years of schooling indicator takes a value of "1" if at least someone 
	in the hh has reported 6 years of education or more */
replace years_edu6 = . if eduyears==.
bysort hh_id: egen hh_years_edu6_1 = max(years_edu6)
gen	hh_years_edu6 = (hh_years_edu6_1==1)
replace hh_years_edu6 = . if hh_years_edu6_1==.
replace hh_years_edu6 = . if hh_years_edu6==0 & no_missing_edu==0 
lab var hh_years_edu6 "Household has at least one member with 6 years of edu"


********************************************************************************
*** Step 2.2 Child School Attendance ***
********************************************************************************

/* Note that the school attendance variable used for Libya PAPFAM 2014 is: 
hv110a (School attendance). The information was collected from all individuals 
aged 6 years and older */

codebook h110a, tab (10)
clonevar attendance = h110a 
	//1=attending, 0=not attending
recode attendance (2=0) (3=0) 
	//2='attended in the past'; 3='never attended'
replace attendance = . if  attendance==9 
	//9, 99 and 8, 98 are missing or non-applicable


*** Standard MPI ***
/*The entire household is considered deprived if any school-aged child is not 
attending school up to class 8. */ 
******************************************************************* 	
gen	child_schoolage = (age>=6 & age<=14)
	/*
	Note: In Libya, the official school entrance age is 6 years.  
	So, age range is 6-14 (=6+8)  
	Source: "http://data.uis.unesco.org/?ReportId=163"
	Go to Education>Education>System>Official entrance age to primary education. 
	Look at the starting age and add 8. 
	*/

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the school age children */
count if child_schoolage==1 & attendance==.
	//Understand how many eligible school aged children are not attending school 
gen temp = 1 if child_schoolage==1 & attendance!=.
	/*Generate a variable that captures the number of eligible school aged 
	children who are attending school */
bysort hh_id: egen no_missing_atten = sum(temp)	
	/*Total school age children with no missing information on school 
	attendance */
gen temp2 = 1 if child_schoolage==1	
bysort hh_id: egen hhs = sum(temp2)
	//Total number of household members who are of school age
replace no_missing_atten = no_missing_atten/hhs 
replace no_missing_atten = (no_missing_atten>=2/3)
	/*Identify whether there is missing information on school attendance for 
	more than 2/3 of the school age children */			
tab no_missing_atten, miss
label var no_missing_atten "No missing school attendance for at least 2/3 of the school aged children"		
drop temp temp2 hhs
	
	
bysort hh_id: egen hh_children_schoolage = sum(child_schoolage)
replace hh_children_schoolage = (hh_children_schoolage>0) 
	//Control variable: 
	//It takes value 1 if the household has children in school age
lab var hh_children_schoolage "Household has children in school age"


gen	child_not_atten = (attendance==0) if child_schoolage==1
replace child_not_atten = . if attendance==. & child_schoolage==1
bysort	hh_id: egen any_child_not_atten = max(child_not_atten)
gen	hh_child_atten = (any_child_not_atten==0) 
replace hh_child_atten = . if any_child_not_atten==.
replace hh_child_atten = 1 if hh_children_schoolage==0
replace hh_child_atten = . if hh_child_atten==1 & no_missing_atten==0 
	/*If the household has been intially identified as non-deprived, but has 
	missing school attendance for at least 2/3 of the school aged children, then 
	we replace this household with a value of '.' because there is insufficient 
	information to conclusively conclude that the household is not deprived */
lab var hh_child_atten "Household has all school age children up to class 8 in school"
tab hh_child_atten, miss

/*Note: The indicator takes value 1 if ALL children in school age are attending 
school and 0 if there is at least one child not attending. Households with no 
children receive a value of 1 as non-deprived. The indicator has a missing value 
only when there are all missing values on children attendance in households that 
have children in school age. */




********************************************************************************
*** Step 2.3 Nutrition ***
********************************************************************************
/*Please note that the PAPFAM datasets do not collect nutrition data from adults. 
In the context of countries with PAPFAM datasets, the entire household is 
considered deprived if any child under 5 for whom there is nutritional 
information is malnourished or children 5-6 years have low BMI-for-age in the 
household.*/
 

********************************************************************************
*** Step 2.3a Child (under 5) Nutrition ***
********************************************************************************


*** Standard MPI: Child Underweight Indicator ***
************************************************************************
/* Libya PAPFAM 2014 collected nutrition data from children under 6. In this 
section, the construction of the nutrition indicator will be on children under 
5. Households with no eligible children will receive a value of 1 */


bysort hh_id: egen temp = max(underweight)
gen	hh_no_underweight = (temp==0) 
	//Takes value 1 if no child in the hh is underweight 
replace hh_no_underweight = . if temp==.
replace hh_no_underweight = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1 
lab var hh_no_underweight "Household has no child underweight - 2 stdev"
drop temp


*** Standard MPI: Child Stunting Indicator ***
************************************************************************

bysort hh_id: egen temp = max(stunting)
gen	hh_no_stunting = (temp==0) 
	//Takes value 1 if no child in the hh is stunted
replace hh_no_stunting = . if temp==.
replace hh_no_stunting = 1 if no_child_eligible==1 
lab var hh_no_stunting "Household has no child stunted - 2 stdev"
drop temp


*** New Standard MPI: Child Either Stunted or Underweight Indicator ***
************************************************************************

gen uw_st = 1 if stunting==1 | underweight==1
replace uw_st = 0 if stunting==0 & underweight==0
replace uw_st = . if stunting==. & underweight==.

bysort hh_id: egen temp = max(uw_st)
gen	hh_no_uw_st = (temp==0) 
	//Takes value 1 if no child in the hh is underweight or stunted
replace hh_no_uw_st = . if temp==.
replace hh_no_uw_st = 1 if no_child_eligible==1
	//Households with no eligible children will receive a value of 1 
lab var hh_no_uw_st "Household has no child underweight or stunted"
drop temp


********************************************************************************
*** Step 2.3b Child 5-6 years Nutrition ***
********************************************************************************

*** Standard MPI: Child BMI-for-age Indicator ***
************************************************************************
/* Libya PAPFAM 2014 collected nutrition data from children under 6. In this 
section, the construction of the nutrition indicator will be for children 
between 5 - 6 years. Households with no eligible children will receive a value 
of 1 */


bysort hh_id: egen temp = max(low_bmiage)
gen	hh_no_low_bmiage = (temp==0) 
	//Takes value 1 if no child in the hh has low BMI-for-age 
replace hh_no_low_bmiage = . if temp==.
replace hh_no_low_bmiage  = 1 if no_child_eligible_6y==1 
	/* Households with no eligible children will receive a value of 1 */
lab var hh_no_low_bmiage "Household has no child low BMI-for-age"
drop temp


********************************************************************************
*** Step 2.3c Household Nutrition Indicator ***
********************************************************************************
	/* In the context of Libya PAPFAM 2014, the final nutrition indicator had 
	around 10 percent missing value. The report indicate that the high missing 
	value was because eligible children were not present for measurement. */

tab h907 if child_CH==1
	//h907: Results of child measurement


*** Standard MPI ***
/* The indicator takes value 1 if there is no children under 5 underweight or 
stunted. It also takes value 1 for the households that have no eligible children. 
The indicator takes value missing "." only if all eligible children have missing 
information in their respective nutrition variable. */
************************************************************************

gen	hh_nutrition_uw_st = 1
replace hh_nutrition_uw_st = 0 if hh_no_uw_st==0 | hh_no_low_bmiage==0 
replace hh_nutrition_uw_st = . if hh_no_uw_st==. & hh_no_low_bmiage==.
replace hh_nutrition_uw_st = 1 if no_child_eligible==1 & no_child_eligible_6y==1
 	/*We replace households that do not have the applicable population, as 
	non-deprived in nutrition*/	
lab var hh_nutrition_uw_st "Household has no child underweight or stunted"


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************
/*In the context of Libya PAPFAM 2014, information on child mortality was 
collected only from women */

codebook w206 w207a w207b
	// w206: Had children who died 
	// w207a: number of sons who have died 
	// w207b: number of daughters who have died 
	
egen temp_f = rowtotal(w207a w207b), missing
	//Total child mortality reported by eligible women
	
replace temp_f = 0 if (w201==1 & w206!=1) | (w201==2 & w206!=1)
replace temp_f = 0 if w201==. & w206==. & marital==1 & temp_f==. 
	/*Assign a value of "0" for:
	- all eligible women who ever had a life birth but reported no child death 
	- all eligible women who never had a life birth and reported no death 
	(presumably this group are women who never ever gave birth)  
    - all elegible but never married women were not asked birth history 
	questions and hence we assume there is no child mortality among this group*/
		
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f

egen child_mortality = rowmax(child_mortality_f)
lab var child_mortality "Total child mortality within household reported by women & men"
tab child_mortality, miss


*** Standard MPI *** 
/* Members of the household are considered deprived if women in the household 
reported mortality among children under 18 in the last 5 years from the survey 
year. Members of the household is considered non-deprived if eligible women 
within the household reported (i) no child mortality or (ii) if any child died 
longer than 5 years from the survey year or (iii) if any child 18 years and 
older died in the last 5 years. In adddition, members of the household were 
identified as non-deprived if eligible men within the household reported no 
child mortality in the absence of information from women. Households that have 
no eligible women or adult are considered non-deprived. The indicator takes 
a missing value if there was missing information on reported death from 
eligible individuals. */
************************************************************************

tab childu18_died_per_wom_5y, miss
	/* The 'childu18_died_per_wom_5y' variable was constructed in Step 1.2 using 
	information from individual women who ever gave birth in the BR file. The 
	missing values represent eligible woman who have never ever given birth and 
	so are not present in the BR file. But these 'missing women' may be living 
	in households where there are other women with child mortality information 
	from the BR file. So at this stage, it is important that we aggregate the 
	information that was obtained from the BR file at the household level. This
	ensures that women who were not present in the BR file is assigned with a 
	value, following the information provided by other women in the household.*/	
replace childu18_died_per_wom_5y = 0 if (w201==1 & w206!=1) | (w201==2 & w206!=1)
replace childu18_died_per_wom_5y = 0 if w201==. & w206==. & marital==1 & childu18_died_per_wom_5y==. 
	/*Assign a value of "0" for:
	- all eligible women who ever had a life birth but reported no child death 
	- all eligible women who never had a life birth and reported no death 
	(presumably this group are women who never ever gave birth)  
    - all elegible but never married women were not asked birth history 
	questions and hence we assume there is no child mortality among this group*/
replace childu18_died_per_wom_5y = 0 if no_fem_eligible==1 
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */	
	
bysort hh_id: egen childu18_mortality_5y = sum(childu18_died_per_wom_5y), missing
replace childu18_mortality_5y = 0 if childu18_mortality_5y==. & child_mortality==0
	/*Replace all households as 0 death if women has missing value and men 
	reported no death in those households */
label var childu18_mortality_5y "Under 18 child mortality within household past 5 years reported by women"
tab childu18_mortality_5y, miss		
	
gen hh_mortality_u18_5y = (childu18_mortality_5y==0)
replace hh_mortality_u18_5y = . if childu18_mortality_5y==.
lab var hh_mortality_u18_5y "Household had no under 18 child mortality in the last 5 years"
tab hh_mortality_u18_5y, miss 



********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************



*** Standard MPI ***
/*Members of the household are considered 
deprived if the household has no electricity */
***************************************************

/*Note: Libya PAPFAM 2014 has no direct question on whether household has 
electricity or not. As the best alternative, the electricity indicator for Libya 
PAPFAM 2014 was drawn from the h617 variable: Main type of lighting. 
The categoreis are: Electricity; Kerosene; Gas; Oil/Candles; Other; No lighting. 
As such, the category 'Electricity' is recoded as 'Yes electricity' and all 
other categories are recoded as 'No electricity' */

lookfor electricity
lookfor lighting
codebook h617, tab (10)
	//h617 - Main type of lighting
clonevar electricity = h617 
recode electricity (2/8=0)
replace electricity = . if electricity==9 
	//Please check that missing values remain missing
codebook electricity, tab (10)
label var electricity "Household has electricity"



********************************************************************************
*** Step 2.6 Sanitation ***
********************************************************************************
/*
Improved sanitation facilities include flush or pour flush toilets to sewer 
systems, septic tanks or pit latrines, ventilated improved pit latrines, pit 
latrines with a slab, and composting toilets. These facilities are only 
considered improved if it is private, that is, it is not shared with other 
households.
Source: https://unstats.un.org/sdgs/metadata/files/Metadata-06-02-01.pdf

Note: In cases of mismatch between the country report and the internationally 
agreed guideline, we followed the report.
*/

lookfor toilet
clonevar toilet = h614  
codebook toilet, tab (30)

codebook h615, tab(10)  
	//0=no;1=yes;.=missing
	//Note: replace public toilet as 'shared'
recode h615(2=0)(9=.),gen(shared_toilet)  
replace shared_toilet=1 if h614==5 & h615==.
tab h615 shared_toilet, miss



*** Standard MPI ***
****************************************
/*
NOTE: 
The toilet categories for Libya PAPFAM 2014 are different from the 
standardised version found in DHS and MICS. The categories are: 
1  FT connected
2  FT not connected
3  Toilet connected
4  Toilet connected to closed pit
5  Public toilet
6  Open air
96 Other

Following the country report, the categories of public toilet, open air & other 
are coded as non-improved sanitation. 
*/

gen	toilet_mdg = toilet<=4 & shared_toilet!=1
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */

replace toilet_mdg = 0 if toilet<=4  & shared_toilet==1 
	/*Household is assigned a value of '0' if it uses improved sanitation 
	but shares toilet with other households  */

replace toilet_mdg = . if toilet==.  
	//Household is assigned a value of '.' if it has missing information 
	
lab var toilet_mdg "Household has improved sanitation with MDG Standards"
tab toilet toilet_mdg, miss


********************************************************************************
*** Step 2.7 Drinking Water  ***
********************************************************************************

/*
Improved drinking water sources include the following: piped water into 
dwelling, yard or plot; public taps or standpipes; boreholes or tubewells; 
protected dug wells; protected springs; packaged water; delivered water and 
rainwater which is located on premises or is less than a 30-minute walk from 
home roundtrip. 
Source: https://unstats.un.org/sdgs/metadata/files/Metadata-06-01-01.pdf

Note: In cases of mismatch between the country report and the internationally 
agreed guideline, we followed the report.
*/

lookfor water
clonevar water = h608  
codebook water, tab (30)
	
clonevar timetowater = h610   
codebook timetowater, tab (9999)	

	/*Because the quality of bottled water is not known, households using bottled 
	water for drinking are classified as using an improved or unimproved source 
	according to their water source for non-drinking activities such as cooking and 
	hand washing. However, it is important to note that households using bottled 
	water for drinking are classified as unimproved source if this is explicitly 
	mentioned in the country report. */		
gen ndwater = . 

	/*NOTE: 
	-Libya PAPFAM 2014 do not have a variable on the use of water for 
	non-drinking activities. So no observation for ndwater variable.
	
	-The Libya PAPFAM 2014 report indicate that public tab, piped supply, 
	protected and supervised wells including rain water are improved source 
	of drinking water. 
	
	-The Libya PAPFAM 2014 report considers bottled water as non-improved source 
	of drinking water.
	*/
	
	
*** Standard MPI ***
****************************************

gen	water_mdg = 1 if water==1 | water==2 | water==3 | water==4 | ///
					 water==5 | water==8 
	/*Non deprived if water is "piped supply","public tap", "artesian well", 
	"regular well", "protected spring", "rainwater",  */

	
replace water_mdg = 0 if water==6  | water==7 | water==9 | ///
						 water==10 | water==96 
	/*Deprived if water is "unprotected well", "unprotected spring", "lake/pool",
	"tanker truck","bottled water", "other" */	
	

replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=996 & timetowater!=998 & timetowater!=999 
	//Deprived if water is at more than 30 minutes' walk (roundtrip) 
		
replace water_mdg = . if water==. | water==99
lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water water_mdg, miss



********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/*
NOTE: 
The Libya PAPFAM 2014 show that some 4000+ individuals have missing data 
for floor. This is because, the data was not collected from households if their 
type of dwelling is hut, tent, temporary shelter or other. Given the precarious  
conditions of these dwellings, the flooring  of these dwellings were re-coded as 
non-improved rather than treating it as 'missing'. 
*/
clonevar floor = h603
codebook floor, tab (10) 
codebook h601, tab (99)
gen	floor_imp = 1
replace floor_imp = 0 if floor==1 | floor==6   
	//Deprived if "mud/earth", "sand", "dung", "other" 	
replace floor_imp = . if floor==. | floor==9
replace floor_imp = 0 if floor==. & h601 >=5 	
	/*Specific to Libya PAPFAM 2014: Deprived if type of dwelling is hut, tent, 
	temporary shelter or other */		
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss



/* Members of the household are considered deprived if the household has wall 
made of natural or rudimentary materials */
gen wall = . 
	//Libya PAPFAM 2014 has no data on wall	
gen	wall_imp = .
lab var wall_imp "Household has wall that it is not of low quality materials"

	
	
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
gen roof = .
	//Libya PAPFAM 2014 has no data on roof	
gen	roof_imp = .	
lab var roof_imp "Household has roof that it is not of low quality materials"



*** Standard MPI ***
****************************************
/*Household is deprived in housing if the roof, floor OR walls uses 
low quality materials. Since Libya PAPFAM 2014 do not have information
on walls and roof, we replace the MPI indicator on housing with information on 
floor. */
gen housing_1 = floor_imp
lab var housing_1 "Household has roof, floor & walls that it is not low quality material"
tab housing_1, miss


/*Household is deprived in housing if it uses low quality materials in 
at least two out of three components: roof, floor AND/OR walls. Since Libya 
PAPFAM 2014 do not have information on walls and roof, we replace the MPI 
indicator on housing with information on floor.*/
gen housing_2 = floor_imp
lab var housing_2 "Household has one of three aspects(either roof,floor/walls) that it is not low quality material"
tab housing_2, miss



********************************************************************************
*** Step 2.9 Cooking Fuel ***
********************************************************************************

/*
Solid fuel are solid materials burned as fuels, which includes coal as well as 
solid biomass fuels (wood, animal dung, crop wastes and charcoal). 

Source: 
https://apps.who.int/iris/bitstream/handle/10665/141496/9789241548885_eng.pdf
*/
clonevar cookingfuel = h619  
codebook cookingfuel, tab(10)


*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>=4 & cookingfuel<6  
replace cooking_mdg = . if cookingfuel==. | cookingfuel==99
lab var cooking_mdg "Household has cooking fuel by MDG standards"
	/* Non deprived if: gas from cylendre; gas; kaz/ kerosene; other
	       Deprived if: coal; wood; */		 
tab cookingfuel cooking_mdg, miss


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************
/*Assets that are included in the global MPI: Radio, TV, telephone, bicycle, 
motorbike, refrigerator, car, computer and animal cart */

/*It is useful to state onset that Libya PAPFAM 2014 has no data for motorbike, 
animal cart, motorboat and the specific type and number of livestock*/


	//Check that for standard assets in living standards: "no"==0 and yes=="1"
codebook h625_2 h625_1 h625_10 h625_11 h625_5 h629_2 h629_1 h625_14 h628 h629_12

clonevar television = h625_2 
gen bw_television   = .
clonevar radio = h625_1
clonevar telephone =  h625_10
clonevar mobiletelephone = h625_11 
clonevar refrigerator = h625_5
clonevar car = h629_2  
clonevar bicycle = h629_1
gen motorbike = .
	//NOTE: Libya PAPFAM 2014 has no data on ownership of motorcycle
clonevar computer = h625_14  

	
gen animal_cart = .	
	//Libya PAPFAM 2014 has no observation for animal cart


foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer animal_cart {
replace `var' = 0 if `var'==2 //Please ensure that 0=no; 1=yes
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//9 , 99 and 8, 98 are missing
	
	
	//Group telephone and mobiletelephone as a single variable 	
replace telephone=1 if telephone==0 & mobiletelephone==1
replace telephone=1 if telephone==. & mobiletelephone==1


*** Standard MPI ***
****************************************
/* Members of the household are considered deprived in assets if the household 
does not own more than one of: radio, TV, telephone, bike, motorbike, 
refrigerator, computer or animal_cart and does not own a car or truck.*/

egen n_small_assets2 = rowtotal(television radio telephone refrigerator bicycle motorbike computer animal_cart), missing
lab var n_small_assets2 "Household Number of Small Assets Owned" 
  
  
gen hh_assets2 = (car==1 | n_small_assets2 > 1) 
replace hh_assets2 = . if car==. & n_small_assets2==.
lab var hh_assets2 "Household Asset Ownership: HH has car or more than 1 small assets incl computer & animal cart"



********************************************************************************
*** Step 2.11 Rename and keep variables for MPI calculation 
********************************************************************************

	//Retain data on sampling design: 
clonevar strata = district 
clonevar psu = cluster


	//Retain year, month & date of interview:
clonevar year_interview = hinty 	
clonevar month_interview = hintm 
clonevar date_interview = xhintc 


		
*** Rename key global MPI indicators for estimation ***
recode hh_mortality_u18_5y  (0=1)(1=0) , gen(d_cm)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ)
recode electricity 			(0=1)(1=0) , gen(d_elct)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani)
recode housing_1 			(0=1)(1=0) , gen(d_hsg)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst)
 

*** Generate coutry and survey details for estimation ***
char _dta[cty] "Libya"
char _dta[ccty] "LBY"
char _dta[year] "2014" 	
char _dta[survey] "PAPFAM"
char _dta[ccnum] "434"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(filedate)'."	
save "$path_out/lby_papfam14.dta", replace 
