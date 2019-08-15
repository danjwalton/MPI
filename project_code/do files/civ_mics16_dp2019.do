********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Cote d'Ivoire MICS 2016 
[STATA do-file]. Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off
set maxvar 10000
set mem 500m



*** Working Folder Path ***
global path_in G:/My Drive/Work/GitHub/MPI//project_data/DHS MICS data files
global path_out G:/My Drive/Work/GitHub/MPI//project_data/MPI out
global path_ado G:/My Drive/Work/GitHub/MPI//project_data/ado


********************************************************************************
*** COTE D'IVOIRE MICS 2016 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
*** Selecting main variables from CH, WM, HH & MN recode & merging with HL recode 
********************************************************************************

	/* Note: Cote D'Ivoire MICS 2016: Five sets of questionnaires were used in 
	the survey: a Household Questionnaire, a Questionnaire for Individual Women 
	administered to all women age 15-49 years living in the households, a 
	Questionnaire for Individual Men administered to men age 15-49 years living 
	in the households, a Questionnaire for Children Under five administered to 
	mothers (or caretakers) of children under 5 years of age living in the 
	households, and a Questionnaire testing the Water Quality administered to 
	all households (p. 5).
	
	Anthropometric data was collected for all childen under 5 years, and women 
	15-49. 
	
	In addition, page 231 provides further details on the survey design:
	
	- only half of the households were selected for men interviews 
	  (all men 15-49 in these hh were interviewed)
	- in half of the households, all women 15-49 were measured for 
	  (not necessarily the same 50% as those for men questionnaire) */

	  
********************************************************************************
*** Step 1.1 CH - CHILDREN's RECODE (under 5)
********************************************************************************	

use "$path_in/ch.dta", clear 

rename _all, lower	


*** Generate individual unique key variable required for data merging
*** hh1=cluster number; 
*** hh2=household number; 
*** ln=child's line number in household
gen double ind_id = hh1*100000 + hh2*100 + ln 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id 
	//9259 obs, no duplicates
	
gen child_CH=1 
	//Generate identification variable for observations in CH recode

	
*** Next, indicate to STATA where the igrowup_restricted.ado file is stored:
	***Source of ado file: http://www.who.int/childgrowth/software/en/
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
gen str30 datalab = "children_nutri_civ" 
lab var datalab "Working file"


*** Next check the variables that WHO ado needs to calculate the z-scores:
*** sex, age, weight, height, measurement, oedema & child sampling weight


*** Variable: SEX ***
tab hl4, miss 
	//"1" for male ;"2" for female
tab hl4, nol 
clonevar gender = hl4
desc gender
tab gender


*** Variable: AGE ***
codebook ag2 cage, tab (30)
tab cage, miss 
codebook cage 
clonevar age_months = cage
desc age_months
replace age_months = . if cage==9999 
replace age_months = . if cage < 0  
summ age_months
gen str6 ageunit = "months"
lab var ageunit "Months"


*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook an3, tab (10000)
clonevar weight = an3	
replace weight = . if an3>=99 
tab	an2 an3 if an3>=99 | an3==., miss 
	//an2: result of the measurement
tab uf9 if an2==. & an3==.	
desc weight 
summ weight	


*** Variable: HEIGHT (CENTIMETERS)
codebook an4, tab (10000)
clonevar height = an4
replace height = . if an4>=999 
tab	an2 an4 if an4>=999 | an4==., miss
desc height 
summ height


	
*** Variable: MEASURED STANDING/LYING DOWN	
codebook an4a
gen measure = "l" if an4a==1 
	//Child measured lying down
replace measure = "h" if an4a==2 
	//Child measured standing up
replace measure = " " if an4a==9 | an4a==0 | an4a==. 
	//Replace with " " if unknown
desc measure
tab measure
		
	
*** Variable: OEDEMA ***
lookfor oedema
gen str1 oedema = "n"  
	//It assumes no-one has oedema
desc oedema
tab oedema	


*** Variable: INDIVIDUAL CHILD SAMPLING WEIGHT ***
gen sw = chweight
desc sw
summ sw	

	
	
/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age_months ageunit weight ///
height measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores */
use "$path_out/children_nutri_civ_z_rc.dta", clear 


	
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



	//Retain relevant variables:
keep ind_id child_CH ln underweight* stunting* wasting*  
order ind_id child_CH ln underweight* stunting* wasting*
sort ind_id
save "$path_out/CIV16_CH.dta", replace


	//Erase files from folder:
erase "$path_out/children_nutri_civ_z_rc.xls"
erase "$path_out/children_nutri_civ_prev_rc.xls"
erase "$path_out/children_nutri_civ_z_rc.dta"

	
********************************************************************************
*** Step 1.2  BR - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************
/*The purpose of step 1.2 is to identify children of any age who died in 
the last 5 years prior to the survey date.*/

use "$path_in/bh.dta", clear


rename _all, lower	


*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** ln=women's line number.
gen double ind_id = hh1*100000 + hh2*100 + ln
format ind_id %20.0g
label var ind_id "Individual ID"

		
desc bh4c bh9c	
gen date_death = bh4c + bh9c	
	//Date of death = date of birth (bh4c) + age at death (bh9c)	
gen mdead_survey = wdoi-date_death	
	//Months dead from survey = Date of interview (wdoi) - date of death	
replace mdead_survey = . if (bh9c==0 | bh9c==.) & bh5==1	
	/*Replace children who are alive as '.' to distinguish them from children 
	who died at 0 months */ 
gen ydead_survey = mdead_survey/12
	//Years dead from survey
	

gen age_death = bh9c if bh5==2
label var age_death "Age at death in months"	
tab age_death, miss
	//Check whether the age is in months	
	
	
codebook bh5, tab (10)	
gen child_died = 1 if bh5==2
replace child_died = 0 if bh5==1
replace child_died = . if bh5==.
label define lab_died 0"child is alive" 1"child has died"
label values child_died lab_died
tab bh5 child_died, miss
	
	
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
	/*All children who are alive or who died longer than 5 years from the 
	interview date are replaced as '0'*/
	
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


gen women_BH = 1 
	//Identification variable for observations in BH recode

	
	//Retain relevant variables
keep ind_id women_BH childu18_died_per_wom_5y 
order ind_id women_BH childu18_died_per_wom_5y
sort ind_id
save "$path_out/CIV16_BH.dta", replace	



********************************************************************************
*** Step 1.3  WM - WOMEN's RECODE  
*** (All eligible females 15-49 years in the household)
********************************************************************************
use "$path_in/wm.dta", clear 
	
rename _all, lower	

	
*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
*** ln=respondent's line number
gen double ind_id = hh1*100000 + hh2*100 + ln
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id 
	//12463 obs, no duplicates

gen women_WM =1 
	//Identification variable for observations in WM recode

	
tab wb2, miss 
	//683 women 15-49 years in the sample have missing observations for age
	
tab cm1 cm8, miss
	/*Women who has never ever given birth will not have information on 
	child mortality. However in the case of CIV MICS 2016, 25 cases of women 
	having never given birth but had a child who died. This will be fixed 
	later in the dofile */
	

lookfor marital mariage	matrimoniale
codebook mstatus ma6, tab (10)
tab mstatus ma6, miss 
gen marital = 1 if mstatus == 3 & ma6==.
	//1: Never married
replace marital = 2 if mstatus == 1 & ma6==.
	//2: Currently married
replace marital = 3 if mstatus == 2 & ma6==1
	//3: Widowed	
replace marital = 4 if mstatus == 2 & ma6==2
	//4: Divorced	
replace marital = 5 if mstatus == 2 & ma6==3
	//5: Separated/not living together	
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab marital, miss
tab ma6 marital, miss
tab mstatus marital, miss
rename marital marital_wom	
	
	
	//Retain relevant variables:	
keep wm7 cm1 cm8 cm9a cm9b wan2 wan3 wan4 ind_id women_WM *_wom
order wm7 cm1 cm8 cm9a cm9b wan2 wan3 wan4 ind_id women_WM *_wom
sort ind_id
save "$path_out/CIV16_WM.dta", replace


********************************************************************************
*** Step 1.4  IR - WOMEN'S RECODE  
*** (Girls 15-19 years in the household)
********************************************************************************

use "$path_in/wm.dta", clear
	
	
rename _all, lower	

		
*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
*** ln=respondent's line number
gen double ind_id = hh1*100000 + hh2*100 + ln
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id	
	
	
***Variables required to calculate the z-scores to produce BMI-for-age:

*** Variable: SEX ***
gen gender=2 
	//Assign all observations as "2" for all women, 15-49 years

	
*** Variable: AGE IN MONTHS ***
codebook wm6m, tab (20)
	//month of interview

codebook wm6y, tab (10)
	//year of interview	

codebook wb1m, tab (20)
replace wb1m = . if wb1m==2
	//month of birth

codebook wb1y, tab (100)
replace wb1y = . if wb1y==9998
	//year of birth

gen imonth = mdy(wm6m, 1, wm6y)
	//month of interview (wm6m)
	//year of interview (wm6y)
gen bmonth = mdy(wb1m, 1, wb1y) 
	//month of birth (wb1m)
	//year of birth (wb1y)

gen age_month = (imonth-bmonth)/30.4375 
	//Calculate age in months 
lab var age_month "Age in months, individuals 15-19 years"	

	
*** Variable: AGE UNIT ***
gen str6 ageunit = "months" 
lab var ageunit "Months"

		
*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook wan3, tab (1000)
clonevar weight = wan3
summ weight


*** Variable: HEIGHT (CENTIMETERS)
codebook wan4, tab (1000)
clonevar height = wan4
replace height = . if wan4>=999 
	/*All missing values or out of range are replaced as "."
	 There are two observations with above 190 cm of height. This is a 16-years-
	 old and a 22-years-old girl. The 22 years old will be dropped below as 
	 we are computing 15-19. We keep the 16 years old. This would not change the 
	 results and it could be a real value */
summ height


*** Variable: OEDEMA
gen oedema = "n"  
tab oedema	


*** Variable: SAMPLING WEIGHT ***
gen sw = wmweight 
summ sw	


*** Keep only relevant sample: teenagers 15 - 19 years ***		
count if wb2>=15 & wb2<=19
	//Total number of girls 15-19 years: 2,260	
keep if wb2>=15 & wb2<=19	
	//Keep only girls between age 15-19 years to compute BMI-for-age		
		
		
*** Next, indicate to STATA where the igrowup_restricted.ado file is stored:
	***Source of ado file: https://www.who.int/growthref/tools/en/		
adopath + "$path_ado/who2007_stata"


/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Growth reference are stored. Note that we use strX to specify 
the length of the path in string. */		
gen str100 reflib = "$path_ado/who2007_stata"
lab var reflib "Directory of reference tables"


/* We use datalib to specify the working directory where the input STATA data
set containing the anthropometric measurement is stored. */
gen str100 datalib = "$path_out" 
lab var datalib "Directory for datafiles"


/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file*/
gen str30 datalab = "girl_nutri_civ" 
lab var datalab "Working file"
	

/*We now run the command to calculate the z-scores with the adofile */
who2007 reflib datalib datalab gender age_month ageunit weight height oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to compute BMI-for-age*/
use "$path_out/girl_nutri_civ_z.dta", clear 

		
gen	z_bmi = _zbfa
replace z_bmi = . if _fbfa==1 
lab var z_bmi "z-score bmi-for-age WHO"


*** Standard MPI indicator ***
gen	low_bmiage = (z_bmi < -2.0) 
	/*Takes value 1 if BMI-for-age is under 2 stdev below the median & 0 
	otherwise */
replace low_bmiage = . if z_bmi==.
lab var low_bmiage "Teenage low bmi 2sd - WHO"


gen teen_IR=1 
	//Identification variable for observations 15-19 years


	//Retain relevant variables:	
keep ind_id teen_IR age_month low_bmiage*
order ind_id teen_IR age_month low_bmiage*
sort ind_id
save "$path_out/CIV16_WM_girls.dta", replace


	//Erase files from folder:
erase "$path_out/girl_nutri_civ_z.xls"
erase "$path_out/girl_nutri_civ_prev.xls"
erase "$path_out/girl_nutri_civ_z.dta"


********************************************************************************
*** Step 1.5  MN - MEN'S RECODE 
***(All eligible man: 15-49 years in the household) 
********************************************************************************

use "$path_in/mn.dta", clear 

rename _all, lower

	
*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
*** ln=respondent's line number
gen double ind_id = hh1*100000 + hh2*100 + ln
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id 

gen men_MN=1 	
	//Identification variable for observations in MR recode


lookfor marital mariage matrimoniale	
codebook mmstatus mma6, tab (10)
tab mmstatus mma6, miss 
gen marital = 1 if mmstatus == 3 & mma6==.
	//1: Never married
replace marital = 2 if mmstatus == 1 & mma6==.
	//2: Currently married
replace marital = 3 if mmstatus == 2 & mma6==1
	//3: Widowed	
replace marital = 4 if mmstatus == 2 & mma6==2
	//4: Divorced	
replace marital = 5 if mmstatus == 2 & mma6==3
	//5: Separated/not living together	
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
					 4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab marital, miss
tab mma6 marital, miss
tab mmstatus marital, miss
rename marital marital_men


	//Retain relevant variables:	   
keep mceb mcsurv mcdead ind_id men_MN *_men 
order mceb mcsurv mcdead ind_id men_MN *_men 
sort ind_id
save "$path_out/CIV16_MN.dta", replace



********************************************************************************
*** Step 1.6 HH - HOUSEHOLD RECODE 
***(All households interviewed) 
********************************************************************************

use "$path_in/hh.dta", clear 
	
rename _all, lower	


*** Generate individual unique key variable required for data merging
*** hh1=cluster number;  
*** hh2=household number; 
gen	double hh_id = hh1*100 + hh2 
format	hh_id %20.0g
lab var hh_id "Household ID"

save "$path_out/CIV16_HH.dta", replace



********************************************************************************
*** Step 1.7 HL - HOUSEHOLD MEMBER  
********************************************************************************

use "$path_in/hl.dta", clear 

rename _all, lower


*** Generate a household unique key variable at the household level using: 
	***hh1=cluster number 
	***hh2=household number
gen double hh_id = hh1*100 + hh2 
format hh_id %20.0g
label var hh_id "Household ID"


*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** hl1=respondent's line number.
gen double ind_id = hh1*100000 + hh2*100 + hl1 
format ind_id %20.0g
label var ind_id "Individual ID"

	
sort ind_id
	
********************************************************************************
*** Step 1.8 DATA MERGING 
******************************************************************************** 
 
 
*** Merging BR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/CIV16_BH.dta"
drop _merge
erase "$path_out/CIV16_BH.dta" 
 
 
*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$path_out/CIV16_WM.dta"
tab hl7, miss 
gen temp = (hl7>0) 
tab women_WM temp, miss col
tab wm7 if temp==1 & women_WM==., miss  
	//Total of eligible women not interviewed 
drop temp _merge
erase "$path_out/CIV16_WM.dta"



*** Merging WM Recode: 15-19 years girls 
*****************************************
merge 1:1 ind_id using "$path_out/CIV16_WM_girls.dta"
drop _merge
erase "$path_out/CIV16_WM_girls.dta"



*** Merging HH Recode 
*****************************************
merge m:1 hh_id using "$path_out/CIV16_HH.dta"
tab hh9 if _m==2
drop  if _merge==2
	//Drop households that were not interviewed 
drop _merge
erase "$path_out/CIV16_HH.dta"



*** Merging MN Recode 
*****************************************
merge 1:1 ind_id using "$path_out/CIV16_MN.dta"
drop _merge
erase "$path_out/CIV16_MN.dta"



*** Merging CH Recode 
*****************************************
merge 1:1 ind_id using "$path_out/CIV16_CH.dta"
count if ln==0 
	//The children without household line are unique to the CH recode 
replace hh_id = hh1*100 + hh2 if ln==0 
	//Creates hd_id for children without household line
drop _merge
erase "$path_out/CIV16_CH.dta"

sort ind_id



********************************************************************************
*** Step 1.9 CONTROL VARIABLES
********************************************************************************

/* Households are identified as having 'no eligible' members if there are no 
applicable population, that is, children 0-5 years, adult women 15-49 years or 
men 15-54 / 15-59 years. These households will not have information on relevant 
indicators of health. As such, these households are considered as non-deprived 
in those relevant indicators.*/


*** No Eligible Women 15-49 years
*****************************************
gen	fem_eligible = (hl7>0) if hl7!=.
bys	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
tab no_fem_eligible, miss



*** No Eligible Men 15-49 years
*****************************************
gen	male_eligible = (hl7a>0) if hl7a!=.
bys	hh_id: egen hh_n_male_eligible = sum(male_eligible)  
	//Number of eligible men for interview in the hh
gen	no_male_eligible = (hh_n_male_eligible==0) 	
	//Takes value 1 if the household had no eligible males for an interview
lab var no_male_eligible "Household has no eligible man"
tab no_male_eligible, miss


	
*** No Eligible Children 0-5 years
***************************************** 
gen	child_eligible = (hl7b>0 | child_CH==1) 
bys	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible"	
tab no_child_eligible, miss
	
	
	
*** No Eligible Women and Men 
***********************************************
gen	no_adults_eligible = (no_fem_eligible==1 & no_male_eligible==1) 
	//Takes value 1 if the household had no eligible men & women for an interview
lab var no_adults_eligible "Household has no eligible women or men"
tab no_adults_eligible, miss 


		
*** No Eligible Children and Women  
***********************************************
	/*NOTE: In this datasets, we use this variable as a control 
	variable for the nutrition indicator since nutrition data is 
	present for children and women 15-49 (all women in half of the hh).
	As a first step we created a new variable to identify eligible women for 
	anthropometrics. */ 
gen	fem_eligible_nutr = (women_WM==1 & wan2>=1 & wan2<=6) 
bys	hh_id: egen hh_n_fem_eligible_nutr = sum(fem_eligible_nutr) 	
	//Number of eligible women for anthropometrics in the hh
gen	no_fem_eligible_nutr = (hh_n_fem_eligible_nutr==0) 									
	//Takes value 1 if the household had no eligible females for anthropometrics
lab var no_fem_eligible_nutr "Household has no eligible women for anthropometrics"
tab no_fem_eligible_nutr, miss

gen	no_child_fem_eligible = (no_child_eligible==1 & no_fem_eligible_nutr==1)
lab var no_child_fem_eligible "Household has no children or women eligible for anthropometrics"
tab no_child_fem_eligible, miss 



*** No Eligible Women, Men or Children 
***********************************************
	/*NOTE: In the DHS datasets, we use this variable as a control 
	variable for the nutrition indicator if nutrition data is 
	present for children, women and men. However, in MICS, we do NOT 
	use this as a control variable. This is because nutrition 
	data is only collected from children. However, we continue to 
	generate this variable in this do-file so as to be consistent*/
gen no_eligibles = .
lab var no_eligibles "Household has no eligible women, men, or children"
tab no_eligibles, miss


*** No Eligible Subsample 
*****************************************
	/*Note that the MICS surveys do not collect hemoglobin data. 
	As such, this variable takes missing value. However, we continue 
	to generate this variable in this do-file so as to be consistent*/	 	
gen	no_hem_eligible = .
lab var no_hem_eligible "Household has no eligible individuals for hemoglobin measurements"


drop fem_eligible hh_n_fem_eligible fem_eligible_nutr hh_n_fem_eligible_nutr ///
	 male_eligible hh_n_male_eligible child_eligible hh_n_children_eligible 


sort hh_id



********************************************************************************
*** Step 1.10 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
clonevar weight = hhweight 
label var weight "Sample weight"


//Type of place of residency: urban or rural		
desc hh6	
clonevar urban = hh6  
replace urban=0 if urban==2  
label define lab_urban 1 "urban" 0 "rural"
label values urban lab_urban
label var urban "Urban area"


//Area: urban or rural		
desc hh6	
clonevar area = hh6  
replace area=0 if area==2  
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"


//Sex of household member
codebook hl4
clonevar sex = hl4 
label var sex "Sex of household member"


//Age of household member
codebook hl6, tab (999)
clonevar age = hl6  
replace age = . if age>=98
label var age "Age of household member"


//Age group 
recode age (0/4 = 1 "0-4")(5/9 = 2 "5-9")(10/14 = 3 "10-14") ///
		   (15/17 = 4 "15-17")(18/59 = 5 "18-59")(60/max=6 "60+"), gen(agec7)
lab var agec7 "age groups (7 groups)"	
	   
recode age (0/9 = 1 "0-9") (10/17 = 2 "10-17")(18/59 = 3 "18-59") ///
		   (60/max=4 "60+"), gen(agec4)
lab var agec4 "age groups (4 groups)"


//Total number of de jure hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
compare hhsize hh11
drop member


//Subnational region
	/*Note: The sample for the Côte d'Ivoire MICS 2016 was designed to provide 
	  estimates for a large number of indicators on the situation of children 
	  and women at the national level, urban and rural areas, and for each of 
	  the eleven areas: Center, Center-East, Center-North, Center-West, North, 
	  North-East, North-West, West, South, South-West and City of Abidjan. */
codebook hh7, tab (99)
clonevar region = hh7
lab var region "Region for subnational decomposition"
tab hh7 region, miss 
label define lab_reg ///
1 "Centre" ///
2 "Centre-Est" ///
3 "Centre-Nord" ///
4 "Centre-Ouest" ///
5 "Nord" ///
6 "Nord-Est" ///
7 "Nord-Ouest" ///
8 "Ouest" ///
9 "Sud (ex. Ville d'Abidjan)" ///
10 "Sud-Ouest" ///
11 "Ville d'Abidjan"
label values region lab_reg
						 
						 
********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

	/*Note: The education model in Cote D'Ivoire consists of 13 years of basic 
	education with 6 years of compulsory primary, 4 years of compulsory lower 
	secondary, and 3 years of upper secondary. The admission age to compulsory 
	education is 6 years. Preschool education takes place from age 3. Primary 
	education takes place from age 6-11 (grades 1-6). Lower secondary education 
	takes place from age 12-15 (grades 7-10). Upper secondary education takes 
	place from age 16-18 (grades 11-13).

References: 
http://uis.unesco.org/country/CI
https://www.epdc.org/sites/default/files/documents/EPDC%20NEP_Cote%20d%20Ivoire.pdf
*/

tab ed4b ed4a, miss
tab age ed6a if ed5==1, miss


clonevar edulevel = ed4a 
	//Highest educational level attended
replace edulevel = . if ed4a==. | ed4a==8 | ed4a==9  
	//ed4a=8/98/99 are missing values 
replace edulevel = 0 if ed3==2 
	//Those who never attended school are replaced as '0'
label var edulevel "Highest educational level attended"


clonevar eduhighyear = ed4b 
	//Highest grade of education completed
replace eduhighyear = . if ed4b==. | ed4b==97 | ed4b==98 | ed4b==99 
	//ed4b=97/98/99 are missing values
replace eduhighyear = 0 if ed3==2 
	//Those who never attended school are replaced as '0'
lab var eduhighyear "Highest year of education completed"


*** Cleaning inconsistencies 
replace eduhighyear = 0 if age<10 
	/*The variable "eduhighyear" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 10 years or older */ 
replace eduhighyear = 0 if edulevel<1


*** Now we create the years of schooling
tab eduhighyear edulevel, miss
gen	eduyears = eduhighyear
replace eduyears = 0 if edulevel<2 & eduhighyear==.   
	/*Assuming 0 year if they only attend preschool or primary but the last year 
	is unknown*/
replace eduyears = eduhighyear + 6 if (edulevel==2)
	/* Secondary school assumed to start after 6 years of primary education */
replace eduyears = eduhighyear + 13 if (edulevel==3)   
	/*Higher education assumed to start after 13 years of general 
	education (6 years of primary + 7 years of secondary) */
replace eduyears = 0 if edulevel==0 & eduyears==. 
replace eduyears = . if edulevel==. & eduhighyear==. 
	//Replaced as missing value when level of education is missing


*** Checking for further inconsistencies 
replace eduyears = . if age<=eduyears & age>0 
	/*There are cases in which the years of schooling are greater than the 
	age of the individual. This is clearly a mistake in the data.*/
replace eduyears = 0 if age<10 
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
	/*Total number of household members who are 10 years and older */
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

codebook ed5, tab (10)
gen	attendance = .
replace attendance = 1 if ed5==1 
	//Replace attendance with '1' if currently attending school
replace attendance = 0 if ed5==2 
	//Replace attendance with '0' if currently not attending school
replace attendance = 0 if ed3==2
	//Replace attendance with '0' if never ever attended school	
tab age ed5, miss	
	//Check individuals who are not of school age
	
tab ed5 if age>=5 & age<=24, miss	
replace attendance = 0 if age<5 | age>24 
	//Replace attendance with '0' for individuals who are not of school age 		
label define lab_attend 1 "currently attending" 0 "not currently attending"
label values attendance lab_attend
label var attendance "Attended school during current school year"
tab attendance, miss
	
	
*** Standard MPI ***
/*The entire household is considered deprived if any school-aged child is not 
attending school up to class 8. */ 
******************************************************************* 

gen	child_schoolage = (age>=6 & age<=14)
	/*Note: In Cote d'Ivoire, the official school entrance age is 6 years. 
	        So, age range is 6-14 (=6+8). 
			Source: http://data.uis.unesco.org/?ReportId=163 */

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the school age children */
count if child_schoolage==1 & attendance==.
	//Understand how many eligible school aged children are not attending school 	
gen temp = 1 if child_schoolage==1 & attendance!=.
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
	
	
bysort	hh_id: egen hh_children_schoolage = sum(child_schoolage)
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

	/*Note: In Cote d'Ivoire MICS 2016, nutrition data is available for all 
	women living in half of the households in the sample, as well as for all 
	children under 5. There is  no anthropometric data for men. */
	
********************************************************************************
*** Step 2.3a Adult Nutrition ***
********************************************************************************

codebook wan3 wan4, tab(1000)
	//wan3 weight (in kg); wan4 height (in cm)


*** Standard MPI: BMI Indicator for Women 15-49 years ***
******************************************************************* 

gen	f_bmi = wan3/((wan4/100)^2)
	//Low BMI of women 15-49 years	
lab var f_bmi "Women's BMI"

gen	f_low_bmi = (f_bmi<18.5)
replace f_low_bmi = . if f_bmi==. | f_bmi>=99.97
lab var f_low_bmi "BMI of women < 18.5"

bysort hh_id: egen low_bmi = max(f_low_bmi)

gen	hh_no_low_bmi = (low_bmi==0)
	/*Under this section, households take a value of '1' if no women in the 
	household has low bmi */
	
replace hh_no_low_bmi = . if low_bmi==.
	/*Under this section, households take a value of '.' if there is no 
	information from eligible women*/
	
replace hh_no_low_bmi = 1 if no_fem_eligible_nutr==1
	/*Under this section, households that don't have eligible female population 
	is identified as non-deprived in nutrition. */	
	
drop low_bmi
lab var hh_no_low_bmi "Household has no adult with low BMI"

tab hh_no_low_bmi, miss
	/*Figures are exclusively based on information from eligible adult 
	women (15-49 years) */


*** Standard MPI: BMI-for-age for individuals 15-19 years 
*** and BMI for individuals 20-49 years ***
******************************************************************* 

gen low_bmi_byage = 0
lab var low_bmi_byage "Individuals with low BMI or BMI-for-age"

replace low_bmi_byage = 1 if f_low_bmi==1
	//Replace variable "low_bmi_byage = 1" if eligible women have low BMI

	
	/*Note: The following command replaces BMI with BMI-for-age for those 
	between the age group of 15-19 by their age in months where information is 
	available */
	
replace low_bmi_byage = 1 if low_bmiage==1 & age_month!=.
	//Replace variable "low_bmi_byage = 1" if eligible teenagers have low BMI
replace low_bmi_byage = 0 if low_bmiage==0 & age_month!=.
	/*Replace variable "low_bmi_byage = 0" if teenagers are identified as 
	having low BMI but normal BMI-for-age */ 	

	
	/*Note: The following control variable is applied when there is BMI 
	information for women and BMI-for-age for teenagers. */
replace low_bmi_byage = . if f_low_bmi==. & low_bmiage==.

bysort hh_id: egen low_bmi = max(low_bmi_byage)

gen	hh_no_low_bmiage = (low_bmi==0)
	/*Households take a value of '1' if all eligible adults and teenagers in the 
	household has normal bmi or bmi-for-age */
	
replace hh_no_low_bmiage = . if low_bmi==.
	/*Households take a value of '.' if there is no information from eligible 
	individuals in the household */
	
replace hh_no_low_bmiage = 1 if no_fem_eligible_nutr==1
	//Households take a value of '1' if there is no eligible population. 

drop low_bmi
lab var hh_no_low_bmiage "Household has no adult with low BMI or BMI-for-age"

tab hh_no_low_bmi, miss	
tab hh_no_low_bmiage, miss	

	/*NOTE that hh_no_low_bmi takes value 1 if: (a) no any eligible adult in the 
	household has (observed) low BMI or (b) there are no eligible adults in the 
	household. The variable takes values 0 for those households that have at 
	least one adult with observed low BMI. The variable has a missing value 
	only when there is missing info on BMI for ALL eligible adults in the 
	household */


 
********************************************************************************
*** Step 2.3b Child Nutrition ***
********************************************************************************


*** Standard MPI: Child Underweight Indicator ***
************************************************************************

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

bysort	hh_id: egen temp = max(stunting)
gen	hh_no_stunting = (temp==0) 
	//Takes value 1 if no child in the hh is stunted
replace hh_no_stunting = . if temp==.
replace hh_no_stunting = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
lab var hh_no_stunting "Household has no child stunted - 2 stdev"
drop temp


*** Standard MPI: Child Either Stunted or Underweight Indicator ***
************************************************************************

gen uw_st = 1 if stunting==1 | underweight==1
replace uw_st = 0 if stunting==0 & underweight==0
replace uw_st = . if stunting==. & underweight==.

bysort	hh_id: egen temp = max(uw_st)
gen	hh_no_uw_st = (temp==0) 
	//Takes value 1 if no child in the hh is underweight or stunted
replace hh_no_uw_st = . if temp==.
replace hh_no_uw_st = 1 if no_child_eligible==1
	//Households with no eligible children will receive a value of 1 
lab var hh_no_uw_st "Household has no child underweight or stunted"
drop temp


********************************************************************************
*** Step 2.3c Household Nutrition Indicator ***
********************************************************************************


*** Nutrition ***
/* The indicator takes value 1 if there is no low BMI-for-age among teenagers, 
no low BMI among adults or no children under 5 underweight or stunted. It also 
takes value 1 for the households that have no eligible adult AND no eligible 
children. The indicator takes a value of missing "." only if all eligible adults 
and eligible children have missing information in their respective nutrition 
variable. */
************************************************************************

gen	hh_nutrition_uw_st = 1
replace hh_nutrition_uw_st = 0 if hh_no_low_bmiage==0 | hh_no_uw_st==0
replace hh_nutrition_uw_st = . if hh_no_low_bmiage==. & hh_no_uw_st==.
replace hh_nutrition_uw_st = 1 if no_child_fem_eligible==1   
 	/*We replace households that do not have the applicable population, that is, 
	women 15-49 & children 0-5, as non-deprived in nutrition*/
lab var hh_nutrition_uw_st "Household has no child underweight/stunted or adult deprived by BMI/BMI-for-age"


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************

	//NOTE: Cote d'Ivoire MICS 2016: No information on child mortality from men 	
codebook cm9a cm9b
	  
egen temp_f = rowtotal(cm9a cm9b), missing
	//Total child mortality reported by eligible women
replace temp_f = 0 if cm1==1 & cm8==2 | cm1==2 
	/*Assign a value of "0" for:
	- all eligible women who have ever gave birth but reported no child death 
	- all eligible women who never ever gave birth */
replace temp_f = 0 if no_fem_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f
	

	/* In the case of Cote D'Ivoire, this variable takes missing value because 
	the survey did not collect information on child mortality from men */	
gen child_mortality_m = .
lab var child_mortality_m "Occurrence of child mortality reported by men"
tab child_mortality_m, miss


egen child_mortality = rowmax(child_mortality_f)
lab var child_mortality "Total child mortality within household reported by women & men"
tab child_mortality, miss

	
*** Standard MPI *** 
/* The standard MPI indicator takes a value of "0" if women in the household 
reported mortality among children under 18 in the last 5 years from the survey 
year. The indicator takes a value of "1" if eligible women within the household 
reported (i) no child mortality or (ii) if any child died longer than 5 years 
from the survey year or (iii) if any child 18 years and older died in the last 
5 years. Households were replaced with a value of "1" if eligible 
men within the household reported no child mortality in the absence of 
information from women. The indicator takes a missing value if there was 
missing information on reported death from eligible individuals. */
************************************************************************

tab childu18_died_per_wom_5y, miss
	/* The 'childu18_died_per_wom_5y' variable was constructed in Step 1.2 using 
	information from individual women who ever gave birth in the BH file. The 
	missing values represent eligible woman who have never ever given birth and 
	so are not present in the BR file. But these 'missing women' may be living 
	in households where there are other women with child mortality information 
	from the BH file. So at this stage, it is important that we aggregate the 
	information that was obtained from the BH file at the household level. This
	ensures that women who were not present in the BH file is assigned with a 
	value, following the information provided by other women in the household.*/		
replace childu18_died_per_wom_5y = 0 if cm1==2 															   
	/*Assign a value of "0" for:
	- all eligible women who never ever gave birth */
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
/*Members of the household are considered deprived if the household has no 
electricity */
****************************************
clonevar electricity = hc8a 
codebook electricity, tab (10)
replace electricity = 0 if electricity==2 
	//0=no; 1=yes 
replace electricity = . if electricity==9 
label var electricity "Household has electricity"


********************************************************************************
*** Step 2.6 Sanitation ***
********************************************************************************
/*In cases of mismatch between the SDG guideline and country report, 
we followed the country report.*/

lookfor toilet
clonevar toilet = ws8  
codebook toilet, tab(99) 

codebook ws9, tab(30)  
clonevar shared_toilet = ws9 
recode shared_toilet (2=0) (9=.)
tab ws9 shared_toilet, miss nol
	//0=no;1=yes;.=missing
	

	
*** Standard MPI ***
****************************************
	/*Note: The country report for Cote d'Ivoire indicate that the categoy 
	'flush do not where' as improved saniation facility (p.79). As such, for 
	the purpose of the global MPI we follow the report.  Furthermore, the 
	report considers the category open defecation as neither improve nor 
	non-improved. We follow the standard set in the MDGs, where this is clearly 
	a deprived standard. */

gen	toilet_mdg = (toilet<23 | toilet==31) & shared_toilet!=1
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */
	
replace toilet_mdg = 0 if toilet==14 

replace toilet_mdg = 0 if (toilet<23 | toilet==31) & shared_toilet==1 
 	/*Household is assigned a value of '0' if it uses improved sanitation 
	but shares toilet with other households */	
	
replace toilet_mdg = . if toilet==.  | toilet==99
	//Household is assigned a value of '.' if it has missing information 

lab var toilet_mdg "Household has improved sanitation with MDG Standards"
tab toilet toilet_mdg, miss


********************************************************************************
*** Step 2.7 Drinking Water  ***
********************************************************************************
/*In cases of mismatch between the SDG guideline and country report, 
we followed the country report.*/

clonevar water = ws1  
clonevar timetowater = ws4  
codebook water, tab(99)
	
clonevar ndwater = ws2  
	//Non-drinking water	
tab ws2 if water==91 	
/*Because the quality of bottled water is not known, households using bottled 
water for drinking are classified as using an improved or unimproved source 
according to their water source for non-drinking activities such as cooking and 
hand washing. However, it is important to note that households using bottled 
water for drinking are classified as unimproved source if this is explicitly 
mentioned in the country report. */	


*** Standard MPI ***
****************************************

gen	water_mdg = 1 if water==11 | water==12 | water==13 | water==14 | ///
					 water==31 | water==41 | water==51 | water==91 | ///
					 water==21 
	/*Non deprived if water is "piped into dwelling", "piped to yard/plot", 
	 "public tap/standpipe", "tube well or borehole", "protected well", 
	 "protected spring", "rainwater", "bottled water" */
	
replace water_mdg = 0 if water==32 | water==42 | water==71 | ///
						 water==81 | water==92 | water==96 | water==61
	/*Deprived if it is "unprotected well", "unprotected spring", "tanker truck"
	"surface water (river/lake, etc)", "cart with small tank", "other" */
	
replace water_mdg = 0 if water_mdg==1 & timetowater>=30 & timetowater!=. & ///
						 timetowater!=998 & timetowater!=999
	//Deprived if water is at more than 30 minutes' walk (roundtrip) 

replace water_mdg = . if water==. | water==99
replace water_mdg = 0 if water==91 & ///
						(ndwater==32 | ndwater==42 | ndwater==71 | ///
						 ndwater==81 | ndwater==96 | ndwater==61 | ndwater==92) 
	/*Households using bottled water for drinking are classified as using an 
	improved or unimproved source according to their water source for 
	non-drinking activities	*/

lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water water_mdg, miss


********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
clonevar floor = hc3
codebook floor, tab(99)
gen	floor_imp = 1
replace floor_imp = 0 if floor==11 | floor==12 | floor==96 	
replace floor_imp = . if floor==.	
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss	



/* Members of the household are considered deprived if the household has wall 
made of natural or rudimentary materials */
lookfor wall
clonevar wall = hc5
codebook wall, tab(99)
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=26 | wall==96 
replace wall_imp = . if wall==. 
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	

	
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
lookfor roof
clonevar roof = hc4
codebook roof, tab(99)	
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=24 | roof==96	
replace roof_imp = . if roof==. 
lab var roof_imp "Household has roof that it is not of low quality materials"
tab roof roof_imp, miss


*** Standard MPI ***
****************************************
/*Household is deprived in housing if the roof, floor OR walls uses 
low quality materials.*/
gen housing_1 = 1
replace housing_1 = 0 if floor_imp==0 | wall_imp==0 | roof_imp==0
replace housing_1 = . if floor_imp==. & wall_imp==. & roof_imp==.
lab var housing_1 "Household has roof, floor & walls that it is not low quality material"
tab housing_1, miss


********************************************************************************
*** Step 2.9 Cooking Fuel ***
********************************************************************************

clonevar cookingfuel = hc6  
codebook cookingfuel, tab(99)

*** Standard MPI ***
****************************************

gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<95 
replace cooking_mdg = . if cookingfuel==. | cookingfuel==99
lab var cooking_mdg "Household has cooking fuel according to MDG standards"
/*Deprived if: 6 "coal/lignite", 7 "charcoal", 8 "wood", 9 "straw/shrubs/grass" 
	         10 "agricultural crop", 11 "animal dung" */			 
tab cookingfuel cooking_mdg, miss	


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************

/* Members of the household are considered deprived if the household does not 
own more than one of: radio, TV, telephone, bike, motorbike or refrigerator and 
does not own a car or truck. */


clonevar television = hc8c
gen bw_television   = .
clonevar radio = hc8b 

clonevar telephone =  hc8d
clonevar mobiletelephone = hc9b 
replace mobiletelephone = 1 if hc9n==1
	//hc9n = smartphone

clonevar refrigerator = hc8e
clonevar car = hc9f  	
clonevar bicycle = hc9c
clonevar motorbike = hc9d

clonevar computer = hc9l
replace computer = 1 if hc9m==1
	//hc9m = tablet

clonevar animal_cart = hc9e


foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer animal_cart  {
replace `var' = 0 if `var'==2 
	//0=no; 1=yes
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//9 , 99 and 8, 98 are missing
	

	//Combine telephone and mobilephone 
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
	
	/*Retain data on sampling design:
	According to the MICS survey methodology, each of the 11 regions is 
	subdivided into two strata (urban stratum and rural stratum). Only the 
	city of Abidjan has a stratum (urban stratum). Thus, 21 strata were formed.
	Some 25 households were clustered in each strata, leading to a total of 512 
	clusters being formed. */	
gen psu = hh1
rename stratum strata


	//Retain year, month & date of interview:
desc hh5y hh5m hh5d 
clonevar year_interview = hh5y 	
clonevar month_interview = hh5m 
clonevar date_interview = hh5d 
 
 
	//Generate presence of subsample
gen subsample = .
 
		

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
char _dta[cty] "Côte d'Ivoire"
char _dta[ccty] "CIV"
char _dta[year] "2016" 	
char _dta[survey] "MICS"
char _dta[ccnum] "384"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(filedate)'."	
save "$path_out/civ_mics16.dta", replace 

