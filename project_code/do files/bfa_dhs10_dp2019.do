********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Burkina Faso DHS 2010 
[STATA do-file]. Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/

********************************************************************************
	
clear all 
set more off
set maxvar 10000
set mem 500m


*** Working Folder Path ***
global path_in G:/My Drive/Work/GitHub/MPI/project_data/DHS MICS data files
global path_out G:/My Drive/Work/GitHub/MPI/project_data/MPI out
global path_ado G:/My Drive/Work/GitHub/MPI/project_data/ado

		
********************************************************************************
*** BURKINA FASO DHS 2010 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
*** Selecting variables from KR, BR, IR, & MR recode & merging with PR recode 
********************************************************************************

/*Burkina Faso DHS 2010: Anthropometric information were recorded for a 
subsample of 1/2 of households. Anthropometric data were collected for all 
eligible women and all children between 6 and 59 months in these households.
Anthropometric information was not collected from men 15-54 */


********************************************************************************
*** Step 1.1 KR - CHILDREN's RECODE (under 5)
********************************************************************************

use "$path_in/BFKR62FL.DTA", clear 


*** Generate individual unique key variable required for data merging
*** v001=cluster number; 
*** v002=household number; 
*** b16=child's line number in household
gen double ind_id = v001*1000000 + v002*100 + b16 
format ind_id %20.0g
label var  ind_id "Individual ID"

drop if b5==0 
	//Burkina Faso DHS 2010: 1328 observations deleted

duplicates report ind_id
duplicates tag ind_id, gen(duplicates)
tab b16 if duplicates!=0 
tab hw13 if duplicates!=0
	/*For children not listed in the household, we create a false 
	household line. We will check at merging stage. However,these children do 
	not have info on nutrition */
bysort ind_id: gen line = (_n)
replace ind_id = v001*1000000 + v002*100 + (line+90) if duplicate!=0 
	//We assume consecutive hh line starting at 90
duplicates report ind_id 
	//No duplicates 

gen child_KR=1 
	//Generate identification variable for observations in KR recode
	

*** Next, indicate to STATA where the igrowup_restricted.ado file is stored:
	***Source: http://www.who.int/childgrowth/software/en/
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
gen str30 datalab = "children_nutri_bfa" 
lab var datalab "Working file"


*** Next check the variables that WHO ado needs to calculate the z-scores:
*** sex, age, weight, height, measurement, oedema & child sampling weight


*** Variable: SEX ***
tab b4, miss 
	//"1" for male ;"2" for female
tab b4, nol 
clonevar gender = b4
desc gender
tab gender


*** Variable: AGE ***
tab hw1, miss 
codebook hw1 
	//Age is measured in months
clonevar age_months = hw1  
desc age_months
summ age_months
gen  str6 ageunit = "months" 
lab var ageunit "Months"
gen mdate = mdy(hw18, hw17, hw19)
gen bdate = mdy(b1, hw16, b2) if hw16 <= 31
	//Calculate birth date in days from date of interview
replace bdate = mdy(b1, 15, b2) if hw16 > 31 
	//If date of birth of child has been expressed as more than 31, we use 15
gen age = (mdate-bdate)/30.4375 
	//Calculate age in months with days expressed as decimals
	

*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook hw2, tab (9999)
gen	weight = hw2/10 
	//We divide it by 10 in order to express it in kilograms 
tab hw2 if hw2>9990, miss nol   
	//Missing values are 9994 to 9996
replace weight = . if hw2>=9990 
	//All missing values or out of range are replaced as "."
tab	hw13 hw2 if hw2>=9990 | hw2==., miss 
	//hw13: result of the measurement
desc weight 
summ weight


*** Variable: HEIGHT (CENTIMETERS) ***
codebook hw3, tab (9999)
gen	height = hw3/10 
	//We divide it by 10 in order to express it in centimeters
tab hw3 if hw3>9990, miss nol   
	//Missing values are 9994 to 9996
replace height = . if hw3>=9990 
	//All missing values or out of range are replaced as "."
tab	hw13 hw3   if hw3>=9990 | hw3==., miss
desc height 
summ height



*** Variable: MEASURED STANDING/LYING DOWN ***		
codebook hw15
gen measure = "l" if hw15==1 
	//Child measured lying down
replace measure = "h" if hw15==2 
	//Child measured standing up
replace measure = " " if hw15==9 | hw15==0 | hw15==. 
	//Replace with " " if unknown
desc measure
tab measure

	
*** Variable: OEDEMA ***
lookfor oedema
gen  oedema = "n"  
	//It assumes no-one has oedema
desc oedema
tab oedema	


*** Variable: INDIVIDUAL CHILD SAMPLING WEIGHT ***
gen  sw = v005/1000000 
	//For DHS sample weight has to be divided 1000000
desc sw
summ sw


/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age ageunit weight height ///
measure oedema sw



/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to create the child nutrition variables following WHO 
standards */
use "$path_out/children_nutri_bfa_z_rc.dta", clear 

		
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
keep ind_id child_KR v001 v002 b16 v135 underweight* stunting* wasting* 
order ind_id child_KR v001 v002 b16 v135 underweight* stunting* wasting* 
sort ind_id
save "$path_out/BFA10_KR.dta", replace


	//Erase files from folder:
erase "$path_out/children_nutri_bfa_z_rc.xls"
erase "$path_out/children_nutri_bfa_prev_rc.xls"
erase "$path_out/children_nutri_bfa_z_rc.dta"

	
********************************************************************************
*** Step 1.2  BR - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************
/*The purpose of step 1.2 is to identify children of any age who died in 
the last 5 years prior to the survey date.*/

use "$path_in/BFBR62FL.DTA", clear


*** Generate individual unique key variable required for data merging
*** v001=cluster number;  
*** v002=household number; 
*** v003=respondent's line number
gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g
label var ind_id "Individual ID"


desc b3 b7	
gen date_death = b3 + b7
	//Date of death = date of birth (b3) + age at death (b7)
gen mdead_survey = v008 - date_death
	//Months dead from survey = Date of interview (v008) - date of death
gen ydead_survey = mdead_survey/12
	//Years dead from survey


gen age_death = b7	
label var age_death "Age at death in months"
tab age_death, miss
	//Check whether the age is in months	
	
	
codebook b5, tab (10)	
gen child_died = 1 if b5==0
	//Redefine the coding and labels (1=child dead; 0=child alive)
replace child_died = 0 if b5==1
replace child_died = . if b5==.
label define lab_died 1 "child has died" 0 "child is alive"
label values child_died lab_died
tab b5 child_died, miss
	

	/*NOTE: For each woman, sum the number of children who died and compare to 
	the number of sons/daughters whom they reported have died */
bysort ind_id: egen tot_child_died = sum(child_died) 
egen tot_child_died_2 = rsum(v206 v207)
	//v206: sons who have died; v207: daughters who have died
compare tot_child_died tot_child_died_2
	//Burkina Faso DHS 2010: these figures are identical
	
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

gen women_BR = 1 
	//Identification variable for observations in BR recode

	
	//Retain relevant variables
keep ind_id women_BR childu18_died_per_wom_5y 
order ind_id women_BR childu18_died_per_wom_5y
sort ind_id
save "$path_out/BFA10_BR.dta", replace	

	
********************************************************************************
*** Step 1.3  IR - WOMEN's RECODE  
*** (All eligible females 15-49 years in the household)
********************************************************************************

use "$path_in/BFIR62FL.DTA", clear


*** Generate individual unique key variable required for data merging
*** v001=cluster number;  
*** v002=household number; 
*** v003=respondent's line number
gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id

gen women_IR=1 
	//Identification variable for observations in IR recode


keep ind_id women_IR v003 v005 v012 v201 v206 v207
order ind_id women_IR v003 v005 v012 v201 v206 v207
sort ind_id
save "$path_out/BFA10_IR.dta", replace



********************************************************************************
*** Step 1.4  IR - WOMEN'S RECODE  
*** (Girls 15-19 years in the household)
********************************************************************************

use "$path_in/BFIR62FL.DTA", clear


*** Generate individual unique key variable required for data merging
*** v001=cluster number;  
*** v002=household number; 
*** v003=respondent's line number
gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id	
	
	
***Variables required to calculate the z-scores to produce BMI-for-age:

*** Variable: SEX ***
gen gender=2 
	/*Assign all observations as "2" for female, as the IR file contains all 
	women, 15-49 years*/

	
*** Variable: AGE IN MONTHS ***
codebook v006, tab (10)
	//month of interview
codebook v007, tab (10)
	//year of interview	
codebook v009, tab (20)
	//month of birth
codebook v010, tab (100)
	//year of birth

gen imonth = mdy(v006, 1, v007)
	//month of interview (v006)
	//year of interview (v007)
gen bmonth = mdy(v009, 1, v010) 
	//month of birth (v009)
	//year of birth (v010)
gen age_month = (imonth-bmonth)/30.4375 
	//Calculate age in months 
lab var age_month "Age in months, individuals 15-19 years"	

	
*** Variable: AGE UNIT ***
gen str6 ageunit = "months" 
lab var ageunit "Months"

		
*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook v437, tab (1000)
gen weight = v437/10
	//We divide it by 10 in order to express it in kilograms
replace weight = . if v437>=9990 
	//All missing values or out of range are replaced as "."
summ weight


*** Variable: HEIGHT (CENTIMETERS)
codebook v438, tab (1000)
gen	height = v438/10 
	//We divide it by 10 in order to express it in centimeters
replace height = . if v438>=9990 
	//All missing values or out of range are replaced as "."
summ height


*** Variable: OEDEMA
gen oedema = "n"  
tab oedema	


*** Variable: SAMPLING WEIGHT ***
gen sw = v005/1000000 
	//For DHS sample weight has to be divided 1000000
summ sw	


*** Keep only relevant sample: teenagers 15 - 19 years ***		
count if v012>=15 & v012<=19
	//Total number of girls in the IR recode	
keep if v012>=15 & v012<=19	
	//Keep only girls between age 15-19 years to compute BMI-for-age		
		
		

*** Next, indicate to STATA where the igrowup_restricted.ado file is stored:
	***Source: https://www.who.int/growthref/tools/en/		
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
gen str30 datalab = "girl_nutri_bfa" 
lab var datalab "Working file"

	
/*We now run the command to calculate the z-scores with the adofile */
who2007 reflib datalib datalab gender age_month ageunit weight height oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to compute BMI-for-age*/
use "$path_out/girl_nutri_bfa_z.dta", clear 

		
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
	//Identification variable for observations in IR recode (only 15-19 years)	


	//Retain relevant variables:	
keep ind_id teen_IR age_month low_bmiage*
order ind_id teen_IR age_month low_bmiage*
sort ind_id
save "$path_out/BFA10_IR_girls.dta", replace


	//Erase files from folder:
erase "$path_out/girl_nutri_bfa_z.xls"
erase "$path_out/girl_nutri_bfa_prev.xls"
erase "$path_out/girl_nutri_bfa_z.dta"
 


********************************************************************************
*** Step 1.5  MR - MEN'S RECODE  
***(All eligible man: 15-59 years in the household) 
********************************************************************************

use "$path_in/BFMR62FL.DTA", clear 


*** Generate individual unique key variable required for data merging
	*** mv001=cluster number; 
	*** mv002=household number;
	*** mv003=respondent's line number
gen double ind_id = mv001*1000000 + mv002*100 + mv003 	
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id

gen men_MR=1 	
	//Identification variable for observations in MR recode

	
keep ind_id men_MR mv003 mv005 mv012 mv201 mv206 mv207
order ind_id men_MR mv003 mv005 mv012 mv201 mv206 mv207
sort ind_id
save "$path_out/BFA10_MR.dta", replace


********************************************************************************
*** Step 1.6  MR - MEN'S RECODE  
***(Boys 15-19 years in the household) 
********************************************************************************
	/*Note: In the case of Burkina Faso DHS 2010, anthropometric data was NOT 
	collected for men. */


********************************************************************************
*** Step 1.7  PR - HOUSEHOLD MEMBER'S RECODE 
********************************************************************************

use "$path_in/BFPR62FL.DTA", clear


*** Generate a household unique key variable at the household level using: 
	***hv001=cluster number 
	***hv002=household number
gen double hh_id = hv001*10000 + hv002 
format hh_id %20.0g
label var hh_id "Household ID"
codebook hh_id  


*** Generate individual unique key variable required for data merging using:
	*** hv001=cluster number; 
	*** hv002=household number; 
	*** hvidx=respondent's line number.
gen double ind_id = hv001*1000000 + hv002*100 + hvidx 
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id


sort hh_id ind_id
	
	
********************************************************************************
*** Step 1.8 DATA MERGING 
******************************************************************************** 
 
 
*** Merging BR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/BFA10_BR.dta"

drop _merge

erase "$path_out/BFA10_BR.dta"


*** Merging IR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/BFA10_IR.dta"

tab women_IR hv117, miss col
tab ha65 if hv117==1 & women_IR==., miss 
	//Total number of eligible women not interviewed
tab ha65 ha13 if women_IR== . & hv117==1, miss    

drop _merge

erase "$path_out/BFA10_IR.dta"


*** Merging IR Recode: 15-19 years girls 
*****************************************
merge 1:1 ind_id using "$path_out/BFA10_IR_girls.dta"

tab teen_IR hv117 if hv105>=15 & hv105<=19, miss col
tab ha65 if hv117==1 & teen_IR==. & (hv105>=15 & hv105<=19), miss 
	//Total number of eligible girls not interviewed
tab ha65 ha13 if hv117==1 & teen_IR==. & (hv105>=15 & hv105<=19), miss 
tab ha40 if ha65==1 & ha13==0 & hv117==1 & teen_IR==. & (hv105>=15 & hv105<=19), miss
	/*Note: In Burkina Faso DHS 2010, 15 girls 15-19 were identified as measured 
	and are present in the PR recode, but they were not present in the IR recode. 
	It should be noted that they have BMI information but not BMI-for-age.*/
drop _merge

erase "$path_out/BFA10_IR_girls.dta"


*** Merging MR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/BFA10_MR.dta"

tab men_MR hv118, miss col
tab hb65 if hv118==1 & men_MR ==. 
	//Total of eligible men not interviewed
tab hb13 hb65 if hv118==1 & men_MR==., miss 
	//No anthropometric data for men in Burkina Faso DHS 2010

drop _merge

erase "$path_out/BFA10_MR.dta"


*** Merging KR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/BFA10_KR.dta"
count if b16==0 & child_KR==1
	//The children without household line are unique to the KR recode
replace hh_id = v001*10000 + v002 if b16==0 & child_KR==1
	//Create hd_id for children without household line 
tab child_KR hv120 if hc60<30, miss col 
tab hc60 if hv120==1 & child_KR==. 
	/*If caretaker is not the mother/mother not in the household
	then the child is not in the KR recode */
tab hc13 hc60 if hv120==1 & child_KR==.  
sum hc5 if hc13==0 & hv120==1 & child_KR==.   
replace hv102 = v135 if b16==0 & child_KR==1 
tab child_KR underweight if b16==0 & child_KR==1, miss   
drop _merge
erase "$path_out/BFA10_KR.dta"


sort ind_id


********************************************************************************
*** Step 1.9 KEEPING ONLY DE JURE HOUSEHOLD MEMBERS ***
********************************************************************************

//Permanent (de jure) household members 
clonevar resident = hv102 
codebook resident, tab (10) 
label var resident "Permanent (de jure) household member"

tab resident, miss
drop if resident!=1 
	/*Note: The Global MPI is based on de jure (permanent) household members 
	only. As such, non-usual residents will be excluded from the sample. 
	In the context of Burkina Faso DHS 2010, 586 (0.71%) individuals who were 
	non-usual residents were dropped from the sample
	*/

	
********************************************************************************
*** Step 1.10 SUBSAMPLE VARIABLE ***
********************************************************************************

/*
In the context of Burkina Faso DHS 2010, height and weight measurements were
collected from children (0-5) and women (15-49) living in 1/2 of the sampled 
households. 
*/

clonevar subsample = hv042
label var subsample "Households selected as part of nutrition subsample" 
drop if subsample!=1 
tab subsample, miss	
	
	
********************************************************************************
*** Step 1.11 CONTROL VARIABLES
********************************************************************************

/* Households are identified as having 'no eligible' members if there are no 
applicable population, that is, children 0-5 years, adult women 15-49 years or 
men 15-54 / 15-59 years. These households will not have information on relevant 
indicators of health. As such, these households are considered as non-deprived 
in those relevant indicators. For further details see Alkire and Santos (2010)*/


*** No Eligible Women 15-49 years
*****************************************
gen	fem_eligible = (hv117==1)
bysort	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
tab no_fem_eligible, miss


*** No Eligible Men 15-54 / 15-54 years
*****************************************
gen	male_eligible = (hv118==1)
bysort	hh_id: egen hh_n_male_eligible = sum(male_eligible)  
	//Number of eligible men for interview in the hh
gen	no_male_eligible = (hh_n_male_eligible==0) 	
	//Takes value 1 if the household had no eligible males for an interview
	
lab var no_male_eligible "Household has no eligible man"
tab no_male_eligible, miss


*** No Eligible Children 0-5 years
*****************************************
gen	child_eligible = (hv120==1) 
bysort	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
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
	/*hv042 (household selected for hemoglobin) is essentially a variable that 
	indicates whether there is selection of a subsample for hemoglobin 
	data. For example, in some country data, only half of the household or one 
	third or two third of the households is assessed for hemoglobin data.*/
gen	hem_eligible =(hv042==1)
bysort	hh_id: egen hh_n_hem_eligible = sum(hem_eligible) 	 
gen	no_hem_eligible = (hh_n_hem_eligible==0) 
	//Takes value 1 if the HH had no eligible females for hemoglobin test	
lab var no_hem_eligible "Household has no eligible individuals for hemoglobin measurements"
tab no_hem_eligible, miss


drop fem_eligible hh_n_fem_eligible male_eligible hh_n_male_eligible ///
child_eligible hh_n_children_eligible hem_eligible hh_n_hem_eligible 


sort hh_id ind_id


********************************************************************************
*** Step 1.12 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
desc hv005
clonevar weight = hv005 
label var weight "Sample weight"


//Area: urban or rural	
desc hv025
codebook hv025, tab (5)		
clonevar area = hv025  
replace area=0 if area==2  
	//Redefine the coding and labels to 1/0
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"


//Sex of household member	
codebook hv104
clonevar sex = hv104 
label var sex "Sex of household member"


//Age of household member
codebook hv105, tab (100)
clonevar age = hv105  
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
clonevar marital = hv115 
codebook marital, tab (10)
recode marital (0=1)(1=2)(9=.)
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab hv115 marital, miss


//Total number of de jure hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
drop member


//Subnational region
	/*NOTE: The sample for the Burkina Faso DHS 2010 was designed to provide 
	estimates of key indicators for the country as a whole, for urban and rural 
	areas separately, and for each of the 13 districts (p.7).*/
lookfor region
codebook hv024, tab (100)	
clonevar region = hv024
lab var region "Region for subnational decomposition"
label define lab_reg ///
1 "Boucle de Mouhoun" ///
2 "Cascades" ///
3 "Centre" ///
4 "Centre-Est" ///
5 "Centre-Nord" ///
6 "Centre-Ouest" ///
7 "Centre-Sud" ///
8 "Est" ///
9 "Hauts-Bassins" ///
10 "Nord" ///
11 "Plateau Central" ///
12 "Sahel" ///
13 "Sud-Ouest"
label values region lab_reg


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

codebook hv108, tab(30)
clonevar  eduyears = hv108   
	//Total number of years of education
replace eduyears = . if eduyears>30
	//Recode any unreasonable years of highest education as missing value
replace eduyears = . if eduyears>=age & age>0
	/*The variable "eduyears" was replaced with a '.' if total years of 
	education was more than individual's age */
replace eduyears = 0 if age < 10 
	/*The variable "eduyears" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 10 years or older */

	
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
/*The entire household is considered deprived if no household member 
aged 10 years or older has completed SIX years of schooling.*/
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

codebook hv121, tab (10)
clonevar attendance = hv121 
recode attendance (2=1) 
codebook attendance, tab (10)	
replace attendance = 0 if (attendance==9 | attendance==.) & hv109==0 
	/*In some countries, they don't assess attendance for those with no 
	 educational attainment. These are replaced with a '0' */
replace attendance = . if  attendance==9 & hv109!=0
	//Replace missing values
	
	
*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
******************************************************************* 
gen	child_schoolage = (age>=6 & age<=14)
	/*Note: In Burkina Faso, the official school entrance age is 6 years.  
	  So, age range is 6-14 (=6+8) 
	  Source: "http://data.uis.unesco.org/?ReportId=163" */

	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the school age children */
count if child_schoolage==1 & attendance==.
	//Understand how many eligible school aged children are not attending school 
gen temp = 1 if child_schoolage==1 & attendance!=.
	/*Generate a variable that captures the number of eligible school aged 
	children who are attending school */
bysort hh_id: egen no_missing_atten = sum(temp)	
	//Total school age children with no missing information on school attendance 
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


********************************************************************************
*** Step 2.3a Adult Nutrition ***
********************************************************************************
//Note: Burkina Faso DHS 2010 has no anthropometric data for adult men 

lookfor body mass
codebook ha40 hb40 

foreach var in ha40 hb40 {
			 gen inf_`var' = 1 if `var'!=.
			 bys sex: tab age inf_`var' 
			 //Check if it is restricted to only an age group or full sample
			 drop inf_`var'
			 }
***

*** Standard MPI: BMI Indicator for Women 15-49 years ***
******************************************************************* 

gen	f_bmi = ha40/100
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
	
replace hh_no_low_bmi = 1 if no_fem_eligible==1
	/*Under this section, households that don't have eligible female population 
	is identified as non-deprived in nutrition. */	
	
drop low_bmi
lab var hh_no_low_bmi "Household has no adult with low BMI"

tab hh_no_low_bmi if subsample==1, miss
	/*Figures are exclusively based on information from eligible adult 
	women (15-49 years) */


*** Standard MPI: BMI Indicator for Men 15-54/15-59 years ***
******************************************************************* 

gen m_bmi = hb40/100
lab var m_bmi "Male's BMI"

gen m_low_bmi = (m_bmi<18.5)
replace m_low_bmi = . if m_bmi==. | m_bmi>=99.97 
lab var m_low_bmi "BMI of male < 18.5"
 
bysort hh_id: egen low_bmi = max(m_low_bmi) 

replace hh_no_low_bmi = 0 if low_bmi==1
	/*Under this section, households take a value of '0' if there's any male 
	with low bmi*/
	
replace hh_no_low_bmi = 1 if low_bmi==0 & hh_no_low_bmi==.
	/*Under this section, households take a value of '1' if no male has low BMI 
	& info is missing for women */
	
drop low_bmi
	
tab hh_no_low_bmi if subsample==1, miss
	/*Figures are based on information from eligible adult women and eligible
	men. For countries that do not have male recode or lack anthropometric data
	for men, then the figures are exclusively from women */


*** Standard MPI: BMI-for-age for individuals 15-19 years 
*** 				  and BMI for individuals 20-49 years ***
******************************************************************* 

gen low_bmi_byage = 0
lab var low_bmi_byage "Individuals with low BMI or BMI-for-age"

replace low_bmi_byage = 1 if f_low_bmi==1
	//Replace variable "low_bmi_byage = 1" if eligible women have low BMI

	
	/*Note: The following command will result in 0 changes when there is no BMI 
	information from men*/
	
replace low_bmi_byage = 1 if low_bmi_byage==0 & m_low_bmi==1 
	//Replace variable "low_bmi_byage = 1" if eligible men have low BMI
	
	
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
	
replace hh_no_low_bmiage = 1 if no_fem_eligible==1
	/*Households take a value of '1' if there is no eligible population.*/

	
drop low_bmi
lab var hh_no_low_bmiage "Household has no adult with low BMI or BMI-for-age"

tab hh_no_low_bmi if subsample==1, miss	
tab hh_no_low_bmiage if subsample==1, miss	

	/*NOTE that hh_no_low_bmi takes value 1 if: (a) no any eligible adult in the 
	household has (observed) low BMI or (b) there are no eligible adults in the 
	household. One has to check and adjust the dofile so all people who are 
	eligible and/or measured are included. It is particularly important to check 
	if male are measured and what age group among males and females. The 
	variable takes values 0 for those households that have at least one adult 
	with observed low BMI. The variable has a missing value only when there is 
	missing info on BMI for ALL eligible adults in the household */


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
	/* Households with no eligible children will receive a value of 1 */
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
*** Step 2.3c Household Nutrition Indicator ***
********************************************************************************


*** Standard MPI ***
/* Members of the household are considered deprived if the household has a 
child under 5 whose height-for-age or weight-for-age is under two standard 
deviation below the median, or has teenager with BMI-for-age that is under two 
standard deviation below the median, or has adults with BMI threshold that is 
below 18.5 kg/m2. Households that have no eligible adult AND no eligible 
children are considered non-deprived. The indicator takes a value of missing 
only if all eligible adults and eligible children have missing information 
in their respective nutrition variable. */
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
	
codebook v206 v207 mv206 mv207
	//v206 or mv206: number of sons who have died 
	//v207 or mv207: number of daughters who have died
	

	//Total child mortality reported by eligible women
egen temp_f = rowtotal(v206 v207), missing
replace temp_f = 0 if v201==0
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f
	
	//Total child mortality reported by eligible men	
egen temp_m = rowtotal(mv206 mv207), missing
replace temp_m = 0 if mv201==0
bysort	hh_id: egen child_mortality_m = sum(temp_m), missing
lab var child_mortality_m "Occurrence of child mortality reported by men"
tab child_mortality_m, miss
drop temp_m

egen child_mortality = rowmax(child_mortality_f child_mortality_m)
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
replace childu18_died_per_wom_5y = 0 if v201==0 
	/*Assign a value of "0" for:
	- all eligible women who never ever gave birth */
*replace childu18_died_per_wom_5y = 0 if hv115==0 & hv104==2 & hv105>=15 & hv105<=49
	/*This line replaces never-married women with 0 child death. If in your 
	country dataset, child mortality information was only collected from 
	ever-married women (check report), please activate this command line.*/		
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
clonevar electricity = hv206 
codebook electricity, tab (10)
replace electricity = . if electricity==9 
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

clonevar toilet = hv205  
codebook toilet, tab(30) 
codebook hv225, tab(30)  
clonevar shared_toilet = hv225 
	
	
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************
gen	toilet_mdg = ((toilet<23 | toilet==41) & shared_toilet!=1) 
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */
	
replace toilet_mdg = 0 if (toilet<23 | toilet==41)  & shared_toilet==1   
	/*Household is assigned a value of '0' if it uses improved sanitation 
	but shares toilet with other households  */	
	
replace toilet_mdg = 0 if toilet == 14 | toilet == 15
	/*Household is assigned a value of '0' if it uses non-improved sanitation: 
	"flush to somewhere else" and "flush don't know where"  */	

replace toilet_mdg = . if toilet==.  | toilet==99
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

clonevar water = hv201  
clonevar timetowater = hv204  
codebook water, tab(100)
	
clonevar ndwater = hv202  
	//No observation for non-drinking water for Burkina Faso DHS 2010
	

*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************
gen	water_mdg = 1 if water==11 | water==12 | water==13 | water==21 | ///
					 water==31 | water==41 | water==51 | water==71
	/*Non deprived if water is "piped into dwelling", "piped to yard/plot", 
	  "public tap/standpipe", "tube well or borehole", "protected well", 
	  "protected spring", "rainwater", "bottled water" */
	
replace water_mdg = 0 if water==32 | water==42 | water==43 | ///
						 water==61 | water==62 | water==96 
	/*Deprived if it is "unprotected well", "unprotected spring", "tanker truck"
	  "surface water (river/lake, etc)", "cart with small tank","other" */
	
replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=996 & timetowater!=998 & timetowater!=999 
	//Deprived if water is at more than 30 minutes' walk (roundtrip) 

replace water_mdg = . if water==. | water==99
lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water water_mdg, miss


********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
lookfor floor
clonevar floor = hv213 
codebook floor, tab(99)

gen	floor_imp = 1
replace floor_imp = 0 if floor<=12 | floor==96  
	//Deprived if "mud/earth", "sand", "dung", "other" 	
replace floor_imp = . if floor==. | floor==99 	
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss	


/* Members of the household are considered deprived if the household has wall 
made of natural or rudimentary materials */
lookfor wall
clonevar wall = hv214 
codebook wall, tab(99)	

gen	wall_imp = 1 
replace wall_imp = 0 if wall<=23 | wall==96  
	/*Deprived if "no wall" "cane/palms/trunk" "mud/dirt" 
	"grass/reeds/thatch" "pole/bamboo with mud" "stone with mud" "plywood"
	"cardboard" "carton/plastic" "uncovered adobe" "canvas/tent" 
	"unburnt bricks" "reused wood" "other"*/
replace wall_imp = . if wall==. | wall==99 	
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	
	
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
lookfor roof
clonevar roof = hv215
codebook roof, tab(99)	
	
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=23 | roof==96  
	/*Deprived if "no roof" "thatch/palm leaf" "mud/earth/lump of earth" 
	"sod/grass" "plastic/polythene sheeting" "rustic mat" "cardboard" 
	"canvas/tent" "unburnt bricks" "wood planks" "other"*/	
replace roof_imp = . if roof==. | roof==99 	
lab var roof_imp "Household has roof that it is not of low quality materials"
tab roof roof_imp, miss


*** Standard MPI ***
/* Members of the household is deprived in housing if the roof, 
floor OR walls are constructed from low quality materials.*/
**************************************************************
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

/*
Solid fuel are solid materials burned as fuels, which includes coal as well as 
solid biomass fuels (wood, animal dung, crop wastes and charcoal). 

Source: 
https://apps.who.int/iris/bitstream/handle/10665/141496/9789241548885_eng.pdf
*/

clonevar cookingfuel = hv226  
codebook cookingfuel, tab(99)


*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<95 
replace cooking_mdg = . if cookingfuel==. | cookingfuel==99
lab var cooking_mdg "Household has cooking fuel by MDG standards"
	/* Non deprived if: "electricity", "lpg", "natural gas", "biogas", 
						"kerosene" , "no food cooked in household", "other"
	   Deprived if: "coal/lignite", "charcoal", "wood", "straw/shrubs/grass" 
					"agricultural crop", "animal dung" */			 
tab cookingfuel cooking_mdg, miss	


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************
/*Assets that are included in the global MPI: Radio, TV, telephone, bicycle, 
motorbike, refrigerator, car, computer and animal cart */


clonevar television = hv208 
gen bw_television   = .
clonevar radio = hv207 
clonevar telephone =  hv221 
clonevar mobiletelephone = hv243a  
clonevar refrigerator = hv209 
clonevar car = hv212  
clonevar bicycle = hv210 
clonevar motorbike = hv211 
clonevar computer = sh110n
clonevar animal_cart = hv243c



foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer  animal_cart {
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Replace missing values
	


	//Skip these lines if mobile phone is missing
replace telephone=1 if telephone==0 & mobiletelephone==1
replace telephone=1 if telephone==. & mobiletelephone==1



*** Standard MPI ***
/* Members of the household are considered deprived in assets if the household 
does not own more than one of: radio, TV, telephone, bike, motorbike, 
refrigerator, computer or animal cart and does not own a car or truck.*/
*****************************************************************************
egen n_small_assets2 = rowtotal(television radio telephone refrigerator bicycle motorbike computer animal_cart), missing
lab var n_small_assets2 "Household Number of Small Assets Owned" 
  
  
gen hh_assets2 = (car==1 | n_small_assets2 > 1) 
replace hh_assets2 = . if car==. & n_small_assets2==.
lab var hh_assets2 "Household Asset Ownership: HH has car or more than 1 small assets incl computer & animal cart"


	
********************************************************************************
*** Step 2.11 Rename and keep variables for MPI calculation 
********************************************************************************

	//Retain DHS wealth index:
desc hv270 	
clonevar windex=hv270

desc hv271
clonevar windexf=hv271


	//Retain data on sampling design: 
desc hv022 hv021	
clonevar strata = hv022
clonevar psu = hv021

	//Retain year, month & date of interview:
desc hv007 hv006 hv008
clonevar year_interview = hv007 	
clonevar month_interview = hv006 
clonevar date_interview = hv008
	

 
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
char _dta[cty] "Burkina Faso"
char _dta[ccty] "BFA"
char _dta[year] "2010" 	
char _dta[survey] "DHS"
char _dta[ccnum] "854"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(filedate)'."	
save "$path_out/bfa_dhs10.dta", replace 

