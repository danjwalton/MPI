********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Nicaragua DHS 2011-2012
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
*** NICARAGUA DHS 2011-2012 ***
********************************************************************************

********************************************************************************
*** Step 1: Data preparation 
*** Selecting variables from KR, BR, IR, & MR recode & merging with PR recode 
********************************************************************************


/*Nicaragua DHS 2011-2012: Anthropometric information was recorded for all 
women aged 15-49, and children (p.2-5). Anthropometric information was not 
collected from adult men.*/


********************************************************************************
*** Step 1.1 KR - CHILDREN's RECODE (under 5)
********************************************************************************

use "$path_in/endesa2011_historia_de_nacimiento.dta", clear

rename _all, lower	


*** Generate individual unique key variable required for data merging
*** v001=cluster number; hhclust conglomerado endesa
*** v002=household number; hhnumbv número de vivienda
*** b16=child's line number in household ; qw221 número de línea
gen double ind_id = hhclust*10000000 + hhnumbv*1000 + hvnumint*100 + qw221
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id


drop if qw225==2
	//Children who are not alive are excluded. 
	//Nicaragua DHS 2011: 1545 observations 

duplicates report ind_id 
	//No duplicates
	

gen child_KR=1 
	//Generate identification variable for observations in KR recode
	

/* 
For this part of the do-file we use the WHO Anthro and macros. This is to 
calculate the z-scores of children under 5. 
Source of ado file: http://www.who.int/childgrowth/software/en/
*/	
	
*** Next, indicate to STATA where the igrowup_restricted.ado file is stored:
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
gen str30 datalab = "children_nutri_nic" 
lab var datalab "Working file"


*** Next check the variables that WHO ado needs to calculate the z-scores:
*** sex, age, weight, height, measurement, oedema & child sampling weight


*** Variable: SEX ***
tab qw223, miss
tab qw223, nol 
clonevar gender = qw223
desc gender
tab gender

*** Variable: AGE ***
tab qw227, miss
tab edad_hijo, miss
tab agemos, miss
codebook agemos
clonevar age_months = agemos 
desc age_months
summ age_months
gen  str6 ageunit = "months" 
lab var ageunit "Months"


gen mdate = mdy(qintm, qintd, qinty)
gen bdate = mdy(qw224m, qw224d, qw224a) if qw224d <= 31
replace bdate = mdy(qw224m, 15, qw224a) if qw224d > 31 
gen age = (mdate-bdate)/30.4375 
replace qw1005=1 if qw1005==. & qw1006==1 & agemos<60 
keep if qw1005==1 

	
*** Variable: BODY WEIGHT (KILOGRAMS) ***
tab qw1009, miss
codebook qw1009, tab (9999)
gen weight = qw1009 if qw1009<90
tab qw1009 if qw1009>9990, miss nol   
replace weight = . if qw1009>=9990 
replace weight=. if qw1006>1 
tab qw1009 qw1006 if qw1006>1, miss 
desc weight 
summ weight


*** Variable: HEIGHT (CENTIMETERS)
tab qw1007, miss
codebook qw1007, tab (9999)
gen height = qw1007 if qw1007<900
tab qw1007 if qw1007>9990, miss nol    
replace height=. if qw1006>1 
replace height = . if qw1007>=9990
tab qw1007 qw1006 if qw1006>1, miss
desc height 
summ height

*** Variable: MEASURED STANDING/LYING DOWN
codebook qw1008
gen measure = "l" if qw1008==1 
replace measure = "h" if qw1008==2 
replace measure = " " if qw1008==0 | qw1008==9 | qw1008==.
desc measure
tab measure

	
*** Variable: OEDEMA ***
gen str1 oedema = "n"  
	//It assumes no-one has oedema
desc oedema
tab oedema	


*** Variable: INDIVIDUAL CHILD SAMPLING WEIGHT ***
gen sw = pesonino
desc sw
summ sw


/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age ageunit weight height ///
measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to create the child nutrition variables following WHO 
standards */
use "$path_out/children_nutri_nic_z_rc.dta", clear 


	
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
	/* Note: in the context of Nicaragua MICS 2011-12, 55 children were replaced 
	as '.' because they have extreme z-scores that are biologically 
	implausible.*/

 
	//Retain relevant variables:
keep ind_id child_KR hhclust hhnumbv qw221 underweight* stunting* wasting* 
order ind_id child_KR hhclust hhnumbv qw221 underweight* stunting* wasting* 
sort ind_id
save "$path_out/NIC11-12_KR.dta", replace


	//Erase files from folder:
erase "$path_out/children_nutri_nic_z_rc.xls"
erase "$path_out/children_nutri_nic_prev_rc.xls"
erase "$path_out/children_nutri_nic_z_rc.dta"


********************************************************************************
*** Step 1.2  BR - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************
/*The purpose of step 1.2 is to identify children of any age who died in 
the last 5 years prior to the survey date.*/

use "$path_in/endesa2011_historia_de_nacimiento.dta", clear

rename _all, lower	

		
*** Generate individual unique key variable required for data merging
*** v001=cluster number; hhclust conglomerado endesa
*** v002=household number; hhnumbv número de vivienda 
*** v003=respondent's line number 
gen double ind_id = hhclust*10000000 + hhnumbv*1000 + hvnumint*100 + cp
format ind_id %20.0g
label var ind_id "Individual ID"


desc qw224d qw224m qw224a
gen dnac = qw224d 
gen mnac = qw224m
gen anac = qw224a
replace anac=. if anac>9000
replace mnac=. if mnac>90
replace dnac=. if dnac>90
count if anac!=. & mnac==. 
gen b3 = ym( anac , mnac ) 
format b3 % tm

gen mfall = qw228m 
gen afall = qw228a
replace mfall=. if mfall>=98
replace afall=. if afall>=9998
gen date_death=ym(afall, mfall)
format date_death % tm


gen v008 = ym(qinty, qintm)
format v008 %tm
gen mdead_survey=v008-date_death
gen ydead_survey = mdead_survey/12

gen age_death = date_death - b3
label var age_death "Age at death in months"
tab age_death, miss
	//Check whether the age is in months

codebook qw225, tab (10)
gen b5=0 if qw225==2
replace b5=1 if qw225==1
gen child_died = 1 if b5==0
replace child_died = 0 if b5==1
replace child_died = . if b5==.
label define lab_died 1 "child has died" 0 "child is alive"
label values child_died lab_died
tab b5 child_died, miss


bysort ind_id: egen tot_child_died = sum(child_died) 
		
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
keep ind_id women_BR childu18_died_per_wom_5y cp qw1006 tot_child_died
order ind_id women_BR childu18_died_per_wom_5y cp qw1006 tot_child_died
sort ind_id
save "$path_out/NIC11-12_BR.dta", replace	
	
	
********************************************************************************
*** Step 1.3  IR - WOMEN's RECODE  
*** (All eligible females 15-49 years in the household)
********************************************************************************

use "$path_in/endesa2011_entrevista_individual_de_mujeres_en_edad_fertil.dta", clear
	
	
*** Generate individual unique key variable required for data merging
*** v001=cluster number;  
*** v002=household number; 
*** v003=respondent's line number
gen double ind_id = hhclust*10000000 + hhnumbv*1000 + hvnumint*100 + cp
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id

duplicates report ind_id

gen women_IR=1 
	//Identification variable for observations in IR recode



tab qw209v, miss
tab qw209m, miss
tab qw209v qw209m, miss
	/*For Nicaragua DHS 2011-2012, individuals who reported child mortality
	responded to the variables qw209v and qw209m. Individuals who did not 
	experience any child mortality (14,056) are identified with a value of '.' 
	across both variables.*/
	
egen tot_child_died_2 = rsum(qw209v qw209m)
	//qw209m: sons who have died; qw209v: daughters who have died

	//Retain relevant variables:

keep ind_id women_IR cp imc estacony pesomef qw1011 qw1013 qw102 qw217d qw700 ///
qw208 qw209v qw209m tot_child_died_2 
order ind_id women_IR cp imc estacony pesomef qw1011 qw1013 qw102 qw217d qw700 ///
qw208 qw209v qw209m tot_child_died_2 
sort ind_id
save "$path_out/NIC11-12_IR.dta", replace


********************************************************************************
*** Step 1.4  IR - WOMEN'S RECODE  
*** (Girls 15-19 years in the household)
********************************************************************************

use "$path_in/endesa2011_entrevista_individual_de_mujeres_en_edad_fertil.dta", clear

		
*** Generate individual unique key variable required for data merging
*** v001=cluster number;  
*** v002=household number; 
*** v003=respondent's line number
gen double ind_id = hhclust*10000000 + hhnumbv*1000 + hvnumint*100 + cp
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id

duplicates report ind_id	
	
***Variables required to calculate the z-scores to produce BMI-for-age:

*** Variable: SEX ***
gen gender=2 
	/*Assign all observations as "2" for female, as the IR file contains all 
	women, 15-49 years*/
	
*** Variable: AGE IN MONTHS ***
codebook qintm, tab (10)
	//month of interview
codebook qinty, tab (10)
	//year of interview	
codebook qw103m, tab (100)
	//month of birth
codebook qw103a, tab (100)
	//year of birth

gen age_years=qw102
gen age_month=age_years*12
lab var age_month "Age in months, individuals 15-19 years"	

	
*** Variable: AGE UNIT ***
gen str6 ageunit = "months" 
lab var ageunit "Months"
		
*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook qw1013, tab (1000)
gen weight = qw1013
summ weight

*** Variable: HEIGHT (CENTIMETERS)
codebook qw1012, tab (1000)
gen	height = qw1012 
summ height

*** Variable: OEDEMA
gen oedema = "n"  
tab oedema	

*** Variable: Sampling weight ***
gen sw = pesomef 
summ sw	
	
	
count if qw102>=15 & qw102<=19
	//Total number of girls in the IR recode: 2,771  
keep if qw102>=15 & qw102<=19	
	//Keep only girls between age 15-19 years to compute BMI-for-age
	
		
/* 
For this part of the do-file we use the WHO AnthroPlus software. This is to 
calculate the z-scores for young individuals aged 15-19 years. 
Source of ado file: https://www.who.int/growthref/tools/en/
*/

*** Next, indicate to STATA where the igrowup_restricted.ado file is stored:	
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
gen str30 datalab = "girl_nutri_nic" 
lab var datalab "Working file"
	

/*We now run the command to calculate the z-scores with the adofile */
who2007 reflib datalib datalab gender age_month ageunit weight height oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to compute BMI-for-age*/
use "$path_out/girl_nutri_nic_z.dta", clear 

		
gen	z_bmi = _zbfa
replace z_bmi = . if _fbfa==1 
lab var z_bmi "z-score bmi-for-age WHO"


*** Standard MPI indicator ***
	/*Takes value 1 if BMI-for-age is under 2 stdev below the median & 0 
	otherwise */
	
gen	low_bmiage = (z_bmi < -2.0) 
replace low_bmiage = . if z_bmi==.
lab var low_bmiage "Teenage low bmi 2sd - WHO"


gen teen_IR=1 
	//Identification variable for observations in IR recode (only 15-19 years)	


	//Retain relevant variables:
keep ind_id teen_IR age_month low_bmiage* imc
order ind_id teen_IR age_month low_bmiage* imc
sort ind_id
save "$path_out/NIC11-12_IR_girls.dta", replace


	//Erase files from folder:
erase "$path_out/girl_nutri_nic_z.xls"
erase "$path_out/girl_nutri_nic_prev.xls"
erase "$path_out/girl_nutri_nic_z.dta"

	
********************************************************************************
*** Step 1.5  MR - MEN'S RECODE  
***(All eligible man: 15-59 years in the household) 
********************************************************************************


use "$path_in/endesa2011_entrevista_individual_de_hombres_en_edad_fertil.dta", clear


*** Generate individual unique key variable required for data merging
	*** mv001=cluster number; 
	*** mv002=household number;
	*** mv003=respondent's line number
gen double ind_id = hhclust*10000000 + hhnumbv*1000 + hvnumint*100 + cp	
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id

duplicates report ind_id

gen men_MR=1 	
	//Identification variable for observations in MR recode



	//Retain relevant variables:
keep ind_id men_MR cp pesohef m102 m203t m205t m206 m207t m207m m207v
order ind_id men_MR cp pesohef m102 m203t m205t m206 m207t m207m m207v
sort ind_id
save "$path_out/NIC11-12_MR.dta", replace


********************************************************************************
*** Step 1.6  MR - MEN'S RECODE  
***(Boys 15-19 years in the household) 
********************************************************************************
/*Note: In the case of Nicaragua DHS 2011-2012, anthropometric data was NOT 
collected for men, hence this section has been deactivated.*/


********************************************************************************
*** Step 1.7A  HH - HOUSEHOLD INFORMATION RECODE 
********************************************************************************
/* For Nicaragua DHS 2011-12 living standard indicators such as electricity, 
housing material, and others are extracted from this file. */ 


use "$path_in/endesa2011_datos_de_la_vivienda_y_el_hogar.dta", clear


*** Generate a household unique key variable at the household level using: 
	***hv001=cluster number 
	***hv002=household number
gen double hh_id = hhclust*10000000 + hhnumbv*1000 + hvnumint*100
format hh_id %20.0g
label var hh_id "Household ID"
codebook hh_id 


duplicates report hh_id
sort hh_id


	//Save a temp file for merging with PR:
save "$path_out/NIC11-12_HH.dta", replace


********************************************************************************
*** Step 1.7B  PR - HOUSEHOLD MEMBER'S RECODE 
********************************************************************************

use "$path_in/endesa2011_miembros_del_hogar.dta", clear

	
*** Generate a household unique key variable at the household level using: 
	***hv001=cluster number 
	***hv002=household number
gen double hh_id = hhclust*10000000 + hhnumbv*1000 + hvnumint*100
format hh_id %20.0g
label var hh_id "Household ID"
codebook hh_id  


*** Generate individual unique key variable required for data merging using:
	*** hv001=cluster number; 
	*** hv002=household number; 
	*** hvidx=respondent's line number.
gen double ind_id = hhclust*10000000 + hhnumbv*1000 + hvnumint*100 + cp
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id
duplicates report ind_id


sort hh_id ind_id



********************************************************************************
*** Step 1.8 DATA MERGING 
******************************************************************************** 

*** Merging HH Information Recode 
**************************************************
merge m:1 hh_id using "$path_out/NIC11-12_HH.dta"

drop _merge

erase "$path_out/NIC11-12_HH.dta"


*** Merging BR Recode 
**************************************************
merge 1:1 ind_id using "$path_out/NIC11-12_BR.dta"

drop _merge

erase "$path_out/NIC11-12_BR.dta"


*** Merging IR Recode 
**************************************************
merge 1:1 ind_id using "$path_out/NIC11-12_IR.dta"

tab qw1011 women_IR , miss col
count if imc!=. & women_IR==1 
	//Total number of eligible women not interviewed 5.9% (901) in this case

drop _merge

erase "$path_out/NIC11-12_IR.dta"


*** Merging IR Recode: 15-19 years girls 
**************************************************
merge 1:1 ind_id using "$path_out/NIC11-12_IR_girls.dta"

tab teen_IR qw1011 if qw102>=15 & qw102<=19, miss col
tab qw1011 if teen_IR==. & (qw102>=15 & qw102<=19), miss 
tab imc if qw1011==1 & teen_IR==. & (qw102>=15 & qw102<=19), miss
drop _merge

erase "$path_out/NIC11-12_IR_girls.dta"


*** Merging MR Recode 
**************************************************
//Anthropometric data  is not available for men in Nicaragua DHS 2011-2012

merge 1:1 ind_id using "$path_out/NIC11-12_MR.dta"
	
drop _merge

erase "$path_out/NIC11-12_MR.dta"


*** Merging KR Recode 
**************************************************
merge 1:1 ind_id using "$path_out/NIC11-12_KR.dta"

drop _merge

erase "$path_out/NIC11-12_KR.dta"


sort ind_id


********************************************************************************
*** Step 1.9 KEEPING ONLY DE JURE HOUSEHOLD MEMBERS ***
********************************************************************************
	//No variable to identify between non-residents and residents.
	
gen residents = .	
label var resident "Permanent (de jure) household member"


********************************************************************************
*** Step 1.10 SUBSAMPLE VARIABLE ***
********************************************************************************

/*In the context of Nicaragua DHS 2011-2012, there is no selection of subsample 
for anthropometric measures. Hence the variable is generated as an empty 
variable.*/

gen subsample=.
label var subsample "Households selected as part of nutrition subsample" 
tab subsample, miss


********************************************************************************
*** Step 1.11 CONTROL VARIABLES
********************************************************************************

/* Households are identified as having 'no eligible' members if there are no 
applicable population, that is, children 0-5 years, adult women 15-49 years or 
men 15-59 years. These households will not have information on relevant 
indicators of health. As such, these households are considered as non-deprived 
in those relevant indicators.*/


*** No Eligible Women 15-49 years
*****************************************
gen fem_eligible = (qhs3p05==2 & qhs3p03>=15 & qhs3p03<=49)
bysort hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
tab no_fem_eligible, miss


*** No Eligible Men 15-59 years
*****************************************
gen male_eligible = men_MR
bysort hh_id: egen hh_n_male_eligible = sum(male_eligible)  
	//Number of eligible men for interview in the household
gen no_male_eligible =  (hh_n_male_eligible==0)
lab var no_male_eligible "Household has no eligible man"
tab no_male_eligible, miss


*** No Eligible Children 0-5 years
*****************************************
gen	child_eligible = (child_KR==1) 
bysort	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible"
tab no_child_eligible, miss


*** No Eligible Women and Men 
***********************************************
	/*NOTE: In the DHS datasets, we use this variable as a control 
	variable for the child mortality indicator if mortality data was 
	collected from women and men. If child mortality was only collected 
	from women, the we use 'no_fem_eligible' as the eligibility criteria */
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
	present for children, women and men. Since nutrition information was not
	collected for men, this variable is created as empty variable */
gen no_eligibles = .
lab var no_eligibles "Household has no eligible women, men, or children"
tab no_eligibles, miss


*** No Eligible Subsample 
*****************************************
	/*Households selected for hemoglobin is essentially a variable that 
	indicates whether there is selection of a subsample for anthropometric 
	data. Since there is no subsample selection in the Nicaragua 
	dataset, this variable is generated as an empty variable */	 	
gen no_hem_eligible = . 	
lab var no_hem_eligible "Household has no eligible individuals for hemoglobin measurements"
tab no_hem_eligible, miss


drop fem_eligible hh_n_fem_eligible male_eligible hh_n_male_eligible ///
child_eligible hh_n_children_eligible 


sort hh_id ind_id

	
	
********************************************************************************
*** Step 1.12 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
desc pesohogar
clonevar weight = pesohogar 
label var weight "Sample weight"


//Area: urban or rural	
desc area
codebook area, tab(5)
rename area area_ori
	//we will rename and maintain the original variable
clonevar area = area_ori			
replace area=0 if area_ori==2  
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"
tab area area_ori, miss


//Sex of household member
codebook qhs3p05
clonevar sex = qhs3p05 
label var sex "Sex of household member"


//Age of household member
codebook qhs3p03, tab (9999)
clonevar age = qhs3p03  
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
tab qw700 estacony, miss
clonevar marital = estacony 
codebook marital, tab (10)
recode marital (6=1)(1=2)(3=4)(5=3)
label define lab_mar 1"never married" 2"currently married" ///
					 3"widowed" 4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab estacony marital, miss


//Total number of de jure hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
drop member


//Subnational region
	/*NOTE: The sample for Nicaragua DHS 2011-2012 was designed to provide 
	estimates of key indicators for the country as a whole, for urban and rural 
	areas separately, and for each of the 15 districts and 2 autonomus regions 
	of the caribbean (p.2). So we use the "hhdepar" variable that contains 
	17 districts.*/   
codebook hhdepar, tab (99)
rename region region_ori
decode hhdepar, gen(temp)
replace temp =  proper(temp)
encode temp, gen(region)
lab var region "Region for subnational decomposition"
tab hhdepar region, miss 
codebook region, tab (99)
drop temp


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************

********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************


codebook qhs3p16n, tab(30)
	//highest level of school passed
codebook qhs3p16g, tab(30)
	//highest grade passed
codebook totgrado, tab(30)
	//years of graduation of the population of 6 years and older

gen eduyears=totgrado if totgrado>=0

	/*In the context of the Nicaragua, there is no evidence in the survey 
	report that indicates whether the category adult education is formal or non-
	formal. The literature indicate that in most cases, adult education is 
	an informal form of learning. See a comprehensive review provided in: 
	http://unesdoc.unesco.org/images/0024/002470/247039e.pdf
	Following thid, for the purpose of the global MPI, adult education in
	Nicaragua is identified as non-formal education. As such, the category is 
	assigned as 0 years of schooling.*/
replace eduyears = 0 if qhs3p16n==3


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
******************************************************************* 
/*The entire household is considered deprived if no household member aged 
10 years or older has completed SIX years of schooling. */

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

codebook qhs3p15, tab (10)
clonevar attendance = qhs3p15 
recode attendance (2=0) (9=.)
label define lab_att 0"not attending" 1"attending" 
label values attendance lab_att	
codebook attendance, tab (10)

replace attendance = 0 if (attendance==9 | attendance==.) & qhs3p16n==0 
replace attendance = . if  attendance==9 & qhs3p16n!=0
	//9, 99 and 8, 98 are missing or non-applicable
	

*** Standard MPI ***
******************************************************************* 
/*The entire household is considered deprived if any school-aged child is not 
attending school up to class 8. */ 

gen	child_schoolage = (age>=6 & age<=14)
	/*
	Note: In Nicaragua, the official primary school entrance age is 6 years. 
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


********************************************************************************
*** Step 2.3a Adult Nutrition ***
********************************************************************************
	//Note: Nicaragua DHS 2011-2012 has no anthropometric data for men  

codebook imc
gen ha40 = imc
gen hb40 = .

foreach var in ha40 hb40 {
			 gen inf_`var' = 1 if `var'!=.
			 bysort sex: tab age inf_`var' 
			 drop inf_`var'
			 }
***

*** Standard MPI: BMI Indicator for Women 15-49 years ***
******************************************************************* 

gen	f_bmi = ha40	
lab var f_bmi "Women's BMI"

gen	f_low_bmi = (f_bmi<18.5)
replace f_low_bmi = . if f_bmi==. 
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

tab hh_no_low_bmi, miss
	/*Figures are exclusively based on information from eligible adult 
	women (15-49 years) */

	
	
*** Standard MPI: BMI-for-age for individuals 15-19 years 
*** 				  and BMI for individuals 20-49 years ***
******************************************************************* 

gen low_bmi_byage = 0

replace low_bmi_byage = 1 if f_low_bmi==1
	//Replace variable "low_bmi_byage = 1" if eligible women have low BMI

	

	/*Note: The following command replaces BMI with BMI-for-age for those 
	between the age group of 15-19 by their age in months where information is 
	available */
	/*Note: In the case of Nicaragua DHS 2011-12, this information is exclusively 
	from teenage girls since there is no male recode */ 
	
replace low_bmi_byage = 1 if low_bmiage==1 & age_month!=.
	//Replace variable "low_bmi_byage = 1" if eligible teenagers have low BMI
replace low_bmi_byage = 0 if low_bmiage==0 & age_month!=.
	/*Replace variable "low_bmi_byage = 0" if teenagers are identified as 
	having low BMI but normal BMI-for-age */ 	

	
	/*Note: The following control variable is applied when there is BMI 
	information for women and BMI-for-age for teenagers. */	
replace low_bmi_byage = . if f_low_bmi==. & low_bmiage==.
	
bysort	hh_id: egen low_bmi = max(low_bmi_byage)

gen	hh_no_low_bmiage = (low_bmi==0)
	/*Households take a value of '1' if all eligible adults and teenagers in the 
	household has normal bmi or bmi-for-age */
	
replace hh_no_low_bmiage = . if low_bmi==.
	/*Households take a value of '.' if there is no information from eligible 
	individuals in the household */
	
replace hh_no_low_bmiage = 1 if no_fem_eligible==1
	/*Households take a value of '1' if there is no eligible population.
	Note: In the case of Nicaragua DHS 2011-12, anthropometric data was collected 
	only from women, so we use the no_fem_eligible criteria */
		
drop low_bmi
lab var hh_no_low_bmiage "Household has no adult with low BMI or BMI-for-age"

tab hh_no_low_bmi, miss	
tab hh_no_low_bmiage, miss	

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
*** Step 2.3c Household Nutrition Indicator ***
********************************************************************************


*** Standard MPI ***
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
	//Replace households as non-deprived if there is no eligible population	
lab var hh_nutrition_uw_st "Household has no child underweight/stunted or adult deprived by BMI/BMI-for-age"



********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************

codebook qw208 qw209v qw209m m207t m207m m207v m206
 
 
	//Total child mortality reported by eligible women
egen temp_f = rowtotal(qw209m qw209v), missing
replace temp_f = 0 if qw208==2
replace temp_f = 0 if qw208==. & tot_child_died_2<.
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f

	
	//Total child mortality reported by eligible men
egen temp_m = rowtotal(m207m m207v), missing
replace temp_m = 0 if m206==2
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
replace childu18_died_per_wom_5y = 0 if qw208==2 
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

/*Members of the household are considered deprived if the household has no 
electricity */


*** Standard MPI ***
****************************************
/*Note: In Nicaragua, there is no direct question on whether the household 
has electricity. As such, we have used a closely related question, which is
what is the main source of lighting for this house. The answers for this 
question are: electric grid, power plant or generator, solar panel, car battery,
kerosene, candle, other or do not have light. For the purpose of the global MPI,
and in line with the objective of this indicator, we identify households as 
having electricity if the lighting is powered by electric grid or power plant
or generator. All other categories, including solar panel is identified as 
deprived. */

codebook qhs1p06, tab (10)
gen electricity = 1 if qhs1p06==1 | qhs1p06==2 
replace electricity = 0 if  qhs1p06==3 | qhs1p06==4 | qhs1p06==5 | ///
						    qhs1p06==6 | qhs1p06==7 | qhs1p06==8 | qhs1p06==96							
replace electricity = . if electricity==99 
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

clonevar toilet = qhs1p09
codebook toilet, tab(30) 
replace toilet = . if qhs1p09==99
gen shared_toilet = .
	//Note: Nicaragua DHS 2011-2012 has no information on shared toilet

	
*** Standard MPI ***
****************************************
	/*Note: In Nicaragua, households that flush to a septic tank/well have been 
	identfied as non-deprived. This decision follows country level information 
	that specifies that these tanks/wells are well covered and it is usually 
	pumped out by private sewage companies. */

gen	toilet_mdg = toilet==1 | toilet==2 | toilet == 3 
	//Household is assigned a value of '1' if it uses improved sanitation
	
replace toilet_mdg = 0 if toilet == 4 | toilet == 5 
	//Household is assigned a value of '0' if it uses non-improved sanitation

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


clonevar water = qhs1p07  
clonevar timetowater = qhs1p08mn  
codebook water, tab(100)
	
gen ndwater=. 
	//No data on non-drinking water.
	

*** Standard MPI ***
****************************************

	/*Note: In the cotext of Nicaragua DHS 2011-12, we identify drinking water 
	from public and private well(POZO), spring (MANANTIAL) and from another 
	house/neighbour/company (VECINO/EMPRESA) as non-improved because there is 
	no information on the quality of the water from these sources. */
	
gen	water_mdg = 1 if water==11 | water==12 | water==13 | water==14 | water==51
	/*Non deprived if water is "piped into dwelling", "piped to yard/plot", 
	 "public tap/standpipe", "tube well or borehole", "protected well", 
	 "protected spring", "rainwater", "bottled water" */
	
replace water_mdg = 0 if water==21 | water==22 | water==31 | water==32 | ///
						 water==33 | water==41 | water==61 | water==96 
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
clonevar floor =qhs1p04 
codebook floor, tab(99)
gen	floor_imp = 1
replace floor_imp = 0 if floor==5 | floor==96  
replace floor_imp = . if floor==. | floor==99 
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss	


/* Members of the household are considered deprived if the household has walls 
made of natural or rudimentary materials */
clonevar wall = qhs1p02
codebook wall, tab(99)	
gen	wall_imp = 1 
replace wall_imp = 0 if wall==13 | wall==14 | wall==15 | wall==96  
replace wall_imp = . if wall== . | wall==99 
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
		
	
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
clonevar roof = qhs1p03
codebook roof, tab(99)		
gen	roof_imp = 1 
replace roof_imp = 0 if roof==5 | roof==6 | roof==96  
replace roof_imp = . if roof==. | roof==99 
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


/*Household is deprived in housing if it uses low quality materials in 
at least two out of three components: roof, floor AND/OR walls */
gen housing_2 = 1
replace housing_2 = 0 if (floor_imp==0 & wall_imp==0 & roof_imp==1) | ///
						 (floor_imp==0 & wall_imp==1 & roof_imp==0) | ///
						 (floor_imp==1 & wall_imp==0 & roof_imp==0) | ///
						 (floor_imp==0 & wall_imp==0 & roof_imp==0)
replace housing_2 = . if floor_imp==. & wall_imp==. & roof_imp==.
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

clonevar cookingfuel = qhs1p13 
codebook cookingfuel, tab(99)


*** Standard MPI ***
****************************************
gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel==2 | cookingfuel==3 						    
replace cooking_mdg = . if cookingfuel==. | cookingfuel==99
lab var cooking_mdg "Household has cooking fuel according to MDG standards"			 
tab cookingfuel cooking_mdg, miss

	/*Note that in Nicaragua DHS 2011-12, there is no evidence in the literature 
	to indicate that the category 'other' cooking fuel relates to solid fuel. 
	Hence this particular category is identified as 'non-deprived' */	


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************
/* Members of the household are considered deprived if the household does not 
own more than one of: radio, TV, telephone, bike, motorbike or refrigerator and 
does not own a car or truck. */

	//Check that for standard assets in living standards: "no"==0 and yes=="1"
codebook qhs2p01d qhs2p01a qhs2p01p qhs2p01q qhs2p01f qhs2p02a qhs2p02c qhs2p02b


clonevar television = qhs2p01d  
replace television = 0 if television == 2
gen bw_television   = .

gen	radio = .
replace radio = 1 if qhs2p01a==1 | qhs2p01b==1 | qhs2p01c==1
replace radio = 0 if qhs2p01a==2 & qhs2p01b==2 & qhs2p01c==2

clonevar telephone =  qhs2p01p 
replace telephone = 0 if telephone == 2

clonevar mobiletelephone = qhs2p01q  
replace mobiletelephone = 0 if mobiletelephone == 2

clonevar refrigerator = qhs2p01f 
replace refrigerator = 0 if refrigerator == 2

clonevar car = qhs2p02a  
replace car = 0 if car == 2
	
clonevar bicycle = qhs2p02c 
replace bicycle = 0 if bicycle == 2

clonevar motorbike = qhs2p02b 
replace motorbike = 0 if motorbike == 2

clonevar computer = qhs2p01m
replace computer = 0 if computer == 2


	//Nicaragua DHS 2011-12 has no data on land, livestock or animal cart
gen animal_cart = .


foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer animal_cart {
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Missing values replaced
	
	
	//Combine information on telephone and mobiletelephone
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

	//Retain DHS wealth index:
gen windex  = .
gen windexf = .


	//Retain data on sampling design:
gen psu = hhclust
egen strata = group(hhdepar area)	
	


	//Retain year, month & date of interview:
desc hhinty hhintm hhintd
clonevar year_interview = hhinty	
clonevar month_interview = hhintm 
clonevar date_interview = hhintd


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
char _dta[cty] "Nicaragua"
char _dta[ccty] "NIC"
char _dta[year] "2011-2012" 	
char _dta[survey] "DHS"
char _dta[ccnum] "558"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(filedate)'."	
save "$path_out/nic_dhs11-12.dta", replace 

