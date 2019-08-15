********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Morocco PAPFAM 2011 [STATA do-file]. 
Available from OPHI website: http://ophi.org.uk/  

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
*** MOROCCO PAPFAM 2011 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
********************************************************************************

/*Anthropometric measures (height and weight) available for children from 
0-6 years.*/


********************************************************************************
*** Step 1.1 CHILDREN's RECODE (under 5)
********************************************************************************
use "$path_in/mar11HR.dta", clear 


rename _all, lower	

	/*The HR dta file for Morocco PAPFAM 2011 includes all household members. 
	For the purpose of this section, keep only the child sample. Use variable 
	h108a to identify eligible children. NOTE: Sample size of children 0-5 years 
	reported in PAPFAM report is 8,407*/
	
tab agemonth, miss
	//Age in months
keep if agemonth>=0 & agemonth<=59
	/*NOTE: The data indicate a total of 8,407 children between 0-72 months old.
	However, the Global MPI's child nutrition indicators (malnutrition and 
	stunting) specify child under 5. In other words, the global focus is only on 
	children between 0-59 months. To be consistent with the Global MPI criteria, 
	we have computed BMI-for-age for children from 60-72 months old. This is 
	done in the next section, that is, Step 1.1b 
	
	The final sample count of children aged 0-59 months that is included 
	in the Global MPI estimation for Morocco PAPFAM 2011 is 7,053 children*/
		

*** Generate individual unique key variable required for data merging
*** cluster=cluster number; 
*** hhnum=household number; 
*** h101=line number of eligible child
gen double ind_id = cluster*1000000 + hhnum*100 + h101 
format ind_id %20.0g
label var  ind_id "Individual ID"

duplicates report ind_id
	//NOTE: No duplicate observations

gen child_CH=1 
	//Generate identification variable for observations in child recode

count if h102==1
	/*NOTE: In the context of Morocco PAPFAM 2011, all children aged 0-60 months 
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
gen str30 datalab = "children_nutri_mar" 
lab var datalab "Working file"


*** Next check the variables that WHO ado needs to calculate the z-scores:
*** sex, age, weight, height, measurement, oedema & child sampling weight


*** Variable: SEX ***
tab h103,miss
codebook h103,tab(30)	
	//"1" for male ;"2" for female
tab h103, nol
clonevar gender = h103
desc gender
tab gender


*** Variable: AGE ***
tab agemonth, miss 
clonevar age_months = agemonth	
gen  str6 ageunit = "months" 
lab var ageunit "Months"


*** Variable: BODY WEIGHT (KILOGRAMS) ***
tab h404, miss   
clonevar weight = h404	
replace weight = . if h404>=99.9 
tab	h407 h404 if h404>=99.9 | h404==., miss 
	//h407: Result of child measurement
desc weight 
summ weight


*** Variable: HEIGHT (CENTIMETERS) 
tab h405, miss
clonevar height = h405 
replace height = . if h405>=999.9 
	//All missing values or out of range are replaced as "."
tab	h407 h405 if h405>=999.9 | h405==., miss
desc height 
summ height


*** Variable: MEASURED STANDING/LYING DOWN ***
	//The PAPFAM survey provides a h variable that controls for this: h406	
codebook h406, tab (10)
gen measure = "l" if h406==1 
	//Child measured lying down
replace measure = "h" if h406==2 
	//Child measured standing up
replace measure = " " if h406==9 | h406==0 | h406==. 
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
igrowup_restricted reflib datalib datalab gender age_months ageunit weight ///
height measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores */
use "$path_out/children_nutri_mar_z_rc.dta", clear 

	
	
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
	/*Note: In the context of Morocco PAPFAM 2011, 558 children are replaced as 
	'.' because they have extreme z-scores which are biologically implausible */


 
	//Retain relevant variables:
keep ind_id child_CH underweight* stunting* wasting* 
order ind_id child_CH underweight* stunting* wasting* 
sort ind_id
save "$path_out/MAR11_CH.dta", replace


	//Erase files from folder:
erase "$path_out/children_nutri_mar_z_rc.xls"
erase "$path_out/children_nutri_mar_prev_rc.xls"
erase "$path_out/children_nutri_mar_z_rc.dta"


********************************************************************************
*** Step 1.1b CHILDREN's RECODE (5-6 years)
********************************************************************************

use "$path_in/mar11HR.dta", clear 


rename _all, lower	
	
tab agemonth, miss	
keep if agemonth >=60 & agemonth <=72		
	/*NOTE: The final sample count of children aged 60-72 months that is 
	included in the Global MPI estimation for Morocco PAPFAM 2011 is 1,354 
	children*/ 
	

*** Generate individual unique key variable required for data merging
*** cluster=cluster number; 
*** hhnum=household number; 
*** h101=line number of eligible child
gen double ind_id = cluster*1000000 + hhnum*100 + h101 
format ind_id %20.0g
label var  ind_id "Individual ID"

duplicates report ind_id
	//NOTE: No duplicate observations

gen child_CH=1 
	//Generate identification variable for observations in child recode

count if h102==1
	/*NOTE: In the context of Morocco PAPFAM 2011, all children aged 60-72 
	months are permenant residents of their HH */
	
	
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
gen str30 datalab = "children_nutri_mar" 
lab var datalab "Working file"


*** Next check the variables that WHO ado needs to calculate the z-scores:
*** sex, age, weight, height, measurement, oedema & child sampling weight


*** Variable: SEX ***
tab h103,miss
codebook h103,tab(30)	
	//"1" for male ;"2" for female
tab h103, nol
clonevar gender = h103
desc gender
tab gender


*** Variable: AGE ***
tab agemonth, miss 
	//Child's age is measured in months
clonevar age_months = agemonth	
gen  str6 ageunit = "months" 
lab var ageunit "Months"


*** Variable: BODY WEIGHT (KILOGRAMS) ***
tab h404, miss   
clonevar weight = h404	
replace weight = . if h404>=99.9 
tab	h407 h404 if h404>=99.9 | h404==., miss 
	//h407: Result of child measurement
desc weight 
summ weight


*** Variable: HEIGHT (CENTIMETERS) 
tab h405, miss
clonevar height = h405 
replace height = . if h405>=999.9 
	//All missing values or out of range are replaced as "."
tab	h407 h405 if h405>=999.9 | h405==., miss
desc height 
summ height

	
	
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
who2007 reflib datalib datalab gender age_months ageunit weight ///
height oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to compute BMI-for-age*/
use "$path_out/children_nutri_mar_z.dta", clear 

		
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
keep ind_id child_CH age_months low_bmiage*
order ind_id child_CH age_months low_bmiage*
sort ind_id
save "$path_out/MAR11_CH_6Y.dta", replace


	//Erase files from folder:
erase "$path_out/children_nutri_mar_z.xls"
erase "$path_out/children_nutri_mar_prev.xls"
erase "$path_out/children_nutri_mar_z.dta"



********************************************************************************
*** Step 1.2  BR - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************

	/* Note: There is no birth history data file for Morocco PAPFAM 2011. Hence 
	this section has been deactivated */	
	

********************************************************************************
*** Step 1.3  IR - WOMEN's RECODE  
*** (All eligible females 15-49 years in the household)
********************************************************************************

use "$path_in/MAR11WOM.dta", clear 


rename _all, lower	


*** Generate individual unique key variable required for data merging
*** cluster=cluster number;  
*** hhnum=household number; 
*** ln=respondent's line number
gen double ind_id = cluster*1000000 + hhnum*100 + ln 
format ind_id %20.0g
label var ind_id "Individual ID"


duplicates report ind_id


gen women_WM=1 
	//Identification variable for observations in IR recode


	//Retain relevant variables:		
keep ind_id women_WM wmweight qresult q201 q206 q207a q207b q208 ///
q122 q123 q104 q105 q106 q106a q107
order ind_id women_WM wmweight qresult q201 q206 q207a q207b q208 ///
q122 q123 q104 q105 q106 q106a q107
sort  ind_id
save "$path_out/MAR11_WM.dta", replace	


********************************************************************************
*** Step 1.4 HH - Household's recode ***
********************************************************************************

use "$path_in/mar11HH.dta", clear 


rename _all, lower


*** Generate individual unique key variable required for data merging
*** cluster=cluster number;  
*** hhnum=household number; 
gen	double hh_id = cluster*100 + hhnum 
format	hh_id %20.0g
lab var hh_id "Household ID"


save "$path_out/MAR11_HH.dta", replace


********************************************************************************
*** Step 1.5 HR - Household Member's recode ****
********************************************************************************

use "$path_in/mar11HR.dta", clear 


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
	***	hln=respondent's line number.
gen double ind_id = cluster*1000000 + hhnum*100 + h101 
format ind_id %20.0g
label var ind_id "Individual ID"


********************************************************************************
*** Step 1.6 DATA MERGING 
******************************************************************************** 
 


*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$path_out/MAR11_WM.dta"
tab qresult women_WM, miss col
bys hh_id: egen temp=sum(women_WM)
tab qhwomen temp, miss  
tab qhchild temp, miss 
count if temp==0 & qhchild >=1 
	// Total number of eligible children
	//NOTE: There is 494 women not eligible but with child measures 
drop temp _merge

erase "$path_out/MAR11_WM.dta"


*** Merging HH Recode 
*****************************************
merge m:1 hh_id using "$path_out/MAR11_HH.dta"
tab qhresult  if _m==2
drop  if _merge==2
	//Drop households that were not interviewed 
drop _merge
erase "$path_out/MAR11_HH.dta"


*** Merging CH Recode 
*****************************************
merge 1:1 ind_id using "$path_out/MAR11_CH.dta"	
drop _merge
erase "$path_out/MAR11_CH.dta"


*** Merging CH 5-6 years Recode 
*****************************************
merge 1:1 ind_id using "$path_out/MAR11_CH_6Y.dta"
drop _merge
erase "$path_out/MAR11_CH_6Y.dta"


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
	However, in Morocco PAPFAM 2011, all householders are permanent members.
	*/

	
********************************************************************************
*** Step 1.8 SUBSAMPLE VARIABLE ***
********************************************************************************

/*
In the context of Morocco PAPFAM 2014, height and weight measurements were
collected from all children (0-5). As such there is no presence of 
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
tab no_fem_eligible qhchild, miss 
	/* NOTE: There is 494 individuals living in households without eligible 
	women but have child who was eligible for anthropometric measures.*/
lab var no_fem_eligible "Household has no eligible women"


*** No Eligible Men 
*****************************************
	//NOTE: Morocco PAPFAM 2011 have no male recode file 
gen no_male_eligible = . 
lab var no_male_eligible "Household has no eligible man"
tab no_male_eligible, miss

	
*** No Eligible Children 0-5 years
*****************************************
gen child_eligible = 0
replace	child_eligible = 1 if qhchild>=1 & (agemonth>=0 & agemonth<=59) 
bysort	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
tab no_child_eligible,miss	

lab var no_child_eligible "Household has no children eligible"	


*** No Eligible Children 5-6 years 
*****************************************
gen child_eligible_6y = 0
replace	child_eligible_6y = 1 if qhchild>=1 & (agemonth>=60 & agemonth<=72) 
bysort	hh_id: egen hh_n_children_eligible_6y = sum(child_eligible_6y)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible_6y = (hh_n_children_eligible_6y==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
tab no_child_eligible_6y, miss	

lab var no_child_eligible_6y "Household has no children 5-6 years eligible"	



*** No Eligible Women and Men 
***********************************************
	/*Morocco PAPFAM 2011 enumerated men, as household members but did not 
	collect child mortality information from men. As such this 
	variable is generated as an empty variable*/
gen	no_adults_eligible = .
lab var no_adults_eligible "Household has no eligible women or men"
tab no_adults_eligible, miss 

	
*** No Eligible Children and Women  
***********************************************
	/*NOTE: In the DHS datasets, we use this variable as a control 
	variable for the nutrition indicator if nutrition data is 
	present for children and women. However, in this dataset, nutrition 
	data only covers children. So we generate an empty variable */
gen	no_child_fem_eligible = .
lab var no_child_fem_eligible "Household has no children or women eligible"
tab no_child_fem_eligible, miss 


*** No Eligible Women, Men or Children 
***********************************************
	/*NOTE: In the DHS datasets, we use this variable as a control 
	variable for the nutrition indicator if nutrition data is 
	present for children, women and men. There is no data for men. So 
	we generate this variable as an empty variable. */
gen no_eligibles = .
lab var no_eligibles "Household has no eligible women, men, or children"
tab no_eligibles, miss

 	
*** No Eligible Subsample 
*****************************************
	//Note that PAPFAM surveys do not collect hemoglobin data from householders
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
codebook qhmili, tab (5)		
clonevar area = qhmili 
replace area=0 if area==2  
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"


//Sex of household member
codebook h103 
clonevar sex = h103 
label var sex "Sex of household member"


//Age of household member
codebook h109age, tab (100)  
clonevar age = h109age  
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
codebook qhregion , tab (99)
decode qhregion, gen(temp)
replace temp =  proper(temp)
encode temp, gen(region)
lab var region "Region for subnational decomposition"
codebook region, tab (100)
tab  region, miss 
drop temp
label define lab_reg ///
1 "Chaouia Ourdigha" ///
2 "Doukkala-Abda" ///
3 "Gharb-Chrarda-Béni Hssen" ///
4 "Fès-Boulemane" ///
5 "Grand Casablanca" ///
6 "Marrakech-Tensift-El Haouz" ///
7 "Meknès-Tafilalet" ///
8 "Rabat-Salé-Zemmour-Zaer" ///
9 "Oriental" ///
10 "Sahara" ///
11 "Souss-Massa-Draa" ///
12 "Tadla-Azilal" ///
13 "Tanger-Tetouan" ///
14 "Taza-Al Hoceima-Taounate"
label values region lab_reg

	
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
	
tab h110, miss 
tab age h110 if h109a==1, miss

rename edulevel edulevel_ori
gen	edulevel = h110 
	//Highest educational level attended
replace edulevel = . if h110==. | h110==9  
	//These are missing values
bysort h109a: tab h110, miss
tab h110 h112, miss
replace edulevel = 0 if h109a == 3  
//Never attended school, in fact, we could control for h112 read and write
label define lab_edulevel 1 "None" 2 "Primary"  3 "Brevet" 4 "Preparatory" ///
						  5"Technical Certificate" 6 "University" 7 "Other" 
label values edulevel lab_edulevel
label var  edulevel "Highest educational level attended"

gen	eduhighyear = 0 
	//Highest grade of education completed
replace eduhighyear = 0 if edulevel <= 1
replace eduhighyear = 6 if edulevel == 2
replace eduhighyear = 6+3 if edulevel == 3
replace eduhighyear = 6+3+3 if edulevel == 4
replace eduhighyear = 13 if (edulevel == 5 | edulevel == 6)

replace eduhighyear = .  if edulevel==. | edulevel == 7  
	//These are considered missing values
replace eduhighyear = 0  if h109a == 3 
	//Never attended school

lab var eduhighyear "Highest year of education completed"

** Cleaning inconsistencies
replace eduhighyear = 0 if age < 10 

gen eduhighyear2 = eduhighyear
tab eduhighyear*, miss
replace eduhighyear = q106 if women_WM==1 & q105==1 & q106<87   
	//Primary level attended
ta eduhighyear*, miss
replace eduhighyear = q106+6 if women_WM==1 & q105==2 & q106<87 
	//Preparatory level attended
ta eduhighyear*, miss
replace eduhighyear = q106+9 if women_WM==1 & q105==3  & q106<87  
	//Median level 
ta eduhighyear*, miss
replace eduhighyear = q106+12 if women_WM==1 & q105==4   & q106<88 
	//University
replace eduhighyear = 12 if women_WM==1 & q105==4   & q106>=88  
	//University
ta eduhighyear*,miss
replace eduhighyear = 0 if women_WM==1 & (q105==5)   
	//Alphabetisation
ta eduhighyear*,miss
replace eduhighyear = 0  if women_WM==1 & q104==3   
	//Never attended school
tab eduhighyear*,miss
tab q104 h109a, miss
tab q105 edulevel, miss
** Now we create the years of schooling
gen	eduyears = eduhighyear
replace eduyears = . if eduyears>30
replace eduyears = . if edulevel==. 

** Checking for further inconsistencies
replace eduyears = . if age<=eduyears & age>0
replace eduyears = 0 if age<10     
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

codebook h109a, tab (10)
clonevar attendance = h109a 
recode attendance (2 3=0) 
	//2='attended in the past'; 3='never attended'


*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
******************************************************************* 
gen	child_schoolage = (age>=6 & age<=14)
	/*
	Note: In Morocco, the official school entrance age is 6 years.  
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
/* Morocco PAPFAM 2011 collected nutrition data from children under 6. In this 
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


*** Standard MPI: Child Either Stunted or Underweight Indicator ***
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
/* Morocco PAPFAM 2011 collected nutrition data from children under 6. In this 
section, the construction of the nutrition indicator will be for children 
between 5 - 6 years. Households with no eligible children will receive a value 
of 1 */


bysort hh_id: egen temp = max(low_bmiage)
gen	hh_no_low_bmiage = (temp==0) 
	//Takes value 1 if no child in the hh has low BMI-for-age 
replace hh_no_low_bmiage = . if temp==.
replace hh_no_low_bmiage  = 1 if no_child_eligible_6y==1 
	//Households with no eligible children will receive a value of 1 
lab var hh_no_low_bmiage "Household has no child low BMI-for-age"
drop temp


********************************************************************************
*** Step 2.3c Household Nutrition Indicator ***
********************************************************************************

tab qhresult if child_CH==1
	//qhresult: Results of measurement


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
/*In the context of Morocco PAPFAM 2014, information on child mortality was 
collected only from women */

codebook q206 q207a q207b
	// q206: Had children who died 
	// q207a: number of sons who have died 
	// q207b: number of daughters who have died 
	
egen temp_f = rowtotal(q207a q207b), missing
	//Total child mortality reported by eligible women
	
replace temp_f = 0 if (q201==1 & q206!=1) | (q201==2 & q206!=1)
replace temp_f = 0 if q201==. & q206==. & marital==1 & temp_f==. 
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
/*Deprived if any children under 18 died in the household in the 
last 5 years from the survey year */
************************************************************************
	/*In the case of Morocco, there is no birth history data. This means, there 
	is no information on the date of death of children who have died. As such
	we are not able to construct the indicator on child mortality under 18 that 
	occurred in the last 5 years. Instead, we identify individuals as 
	deprived if any children died in the household */
	
gen	hh_mortality = (child_mortality==0)
	/*Household is replaced with a value of "1" if there is no incidence of 
	child mortality*/
replace hh_mortality = . if child_mortality==.
replace hh_mortality = 1 if no_fem_eligible==1 
	//Household is replaced with a value of "1" if there is no eligible women
	
lab var hh_mortality "Household had no child mortality"
tab hh_mortality, miss


gen hh_mortality_u18_5y = .
lab var hh_mortality_u18_5y "Household had no under 18 child mortality in the last 5 years"


********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************
/*Members of the household are considered deprived if the household has no 
electricity 

Note: Morocco PAPFAM 2011 has no direct question on whether household has 
electricity or not. As the best alternative, the electricity indicator for 
Morocco PAPFAM 2011 was drawn from the h317 variable: Main type of lighting. 
The categoreis are: Electricity; Kerosene; Gas; Oil/Candles; Other; No lighting. 
As such, the category 'Electricity' is recoded as 'Yes electricity' and all 
other categories are recoded as 'No electricity' */


*** Standard MPI ***
****************************************
codebook h317, tab (10)
	//h317 - Main type of lighting	
gen electricity = h317 
recode electricity (2/8=0)
replace electricity = . if h317==.
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


clonevar toilet = h314  
codebook toilet, tab (30)
codebook h315, tab(10)  
	//Note: replace public toilet as 'shared'
recode h315(2=0)(9=.),gen(shared_toilet)  
replace shared_toilet=1 if h314==5 & h314==.
tab h314 shared_toilet, miss



*** Standard MPI ***
****************************************
/*
NOTE: 
The toilet categories for Morocco PAPFAM 2011 are different from the 
standardised version found in DHS and MICS. The categories are: 

1 toilet connected to the sewer
2 Toilet with sifon plugged in the goux
3 Toilet connected to the ground
4 Toilet connected to a pit septic
5 Public toilet
6 In nature
7 Other
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
clonevar water = h308  
codebook water, tab (30)
clonevar timetowater = h310   
codebook timetowater, tab (999)	
gen ndwater = . 
	//No data on the use of water for non-drinking activities

/*NOTE: 
The sources of drinking water categories for Morocco PAPFAM 2011 are different 
from the standardised version found in DHS and MICS. The categories are: 
		
	 1 public network							improved
	 2 public tap (Fountain)					improved 
	 3 Well equipped with a pump				improved 
	 4 Well, not equipped with a pump			none improved 
	 5 Source monitored							improved 
	 6 Source not monitored						none improved 
	 7 River / stream							none improved 
	 8 Lake										none improved 		
	 9 Water from the plains					improved 		
	 10 Vehicle equipped with a tank water 		none improved 		
	 11 Mineral water of glass or plastic		improved 		
	 96 Other									none improved 		
*/
 
 
*** Standard MPI ***
****************************************
gen	water_mdg = 1 if (water>=1 & water <=3)| water==5 | water==9 | water==11 
	
replace water_mdg = 0 if water== 4 | water==6 | water==7 | water==8 | ///
						 water==10 | water==96 

replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=998 
	//Deprived if water is at more than 30 minutes' walk (roundtrip) 
		
replace water_mdg = . if water==. | water==99

lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water water_mdg, miss



********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
clonevar floor = h303
codebook floor, tab(99)
gen	floor_imp = 1
replace floor_imp = 0 if floor==1 | floor==6   
replace floor_imp = . if floor==. 		
lab var floor_imp "Household has floor that it is not earth/sand/dung"
replace floor_imp = 0 if floor==. & h301!=. 	
	/*Specific to Morocco PAPFAM 2011: Deprived if type of dwelling is 
	traditional, booth, tent, temporary shelter or other */
tab floor floor_imp, miss


/* Members of the household are considered deprived if the household has wall 
made of natural or rudimentary materials 
Morocco PAPFAM 2011 has no data on wall*/
gen wall = . 
gen	wall_imp = .
lab var wall_imp "Household has wall that it is not of low quality materials"

	

/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials 

1 concrete 				deprived	
2 Tin					deprived
3 Wood					deprived
4 Cane					none deprived
6 Other					none deprived
8 There is no ceiling	none deprived
*/ 	
clonevar roof = h306
codebook roof, tab(99)		
gen	roof_imp = 1 
replace roof_imp = 0 if roof>=4 
replace roof_imp = . if roof==. 
lab var roof_imp "Household has roof that it is not of low quality materials"
replace roof_imp = 0 if roof==. & h301!=. 	
	/*Specific to Morocco PAPFAM 2011: Deprived if type of dwelling is 
	traditional, booth, tent, temporary shelter or other */
tab roof roof_imp, miss



*** Standard MPI ***
/*Household is deprived in housing if the roof, floor 
OR walls uses low quality materials.*/
****************************************
gen housing_1 = 1
replace housing_1 = 0 if floor_imp==0 | roof_imp==0
replace housing_1 = . if floor_imp==. & roof_imp==.
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

clonevar cookingfuel = h319  
codebook cookingfuel, tab(99)


*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>=4 & cookingfuel<6  
replace cooking_mdg = . if cookingfuel==. 
lab var cooking_mdg "Household has cooking fuel by MDG standards"
	//Deprived if: coal; wood; other  
tab cookingfuel cooking_mdg, miss


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************
/*Assets that are included in the global MPI: Radio, TV, telephone, bicycle, 
motorbike, refrigerator, car, computer and animal cart */


clonevar television = h324b 
gen bw_television   = .
clonevar radio = h324a 
clonevar telephone =  h324j
clonevar mobiletelephone = h324k 
clonevar refrigerator = h324e
clonevar car = h328b  
gen bicycle = .
	//Morocco PAPFAM 2011 has no data on ownership of bicycle
gen motorbike = h328a
clonevar computer = h324n  
gen animal_cart = .	
	//No observation for animal cart

	
foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer animal_cart {
replace `var' = 0 if `var'==2 
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Missing values replaced
	
	

	//Group telephone and mobiletelephone as a single variable
replace telephone=1 if telephone==0 & mobiletelephone==1
replace telephone=1 if telephone==. & mobiletelephone==1



*** Standard MPI ***
/* Members of the household are considered deprived in assets if the household 
does not own more than one of: radio, TV, telephone, bike, motorbike, 
refrigerator, computer or animal_cart and does not own a car or truck.*/
****************************************
egen n_small_assets2 = rowtotal(television radio telephone refrigerator bicycle motorbike computer animal_cart), missing
lab var n_small_assets2 "Household Number of Small Assets Owned" 
  
  
gen hh_assets2 = (car==1 | n_small_assets2 > 1) 
replace hh_assets2 = . if car==. & n_small_assets2==.
lab var hh_assets2 "Household Asset Ownership: HH has car or more than 1 small assets incl computer & animal cart"


********************************************************************************
*** Step 2.11 Rename and keep variables for MPI calculation 
********************************************************************************

	//Retain data on sampling design: 
clonevar strata = region  
clonevar psu = cluster


	//Retain year, month & date of interview:
clonevar year_interview = qhinty 	
clonevar month_interview = qhintm 
clonevar date_interview = xqhintc 


*** Rename key global MPI indicators for estimation ***
	/* Note: In the case of Morocco PAPFAM 2011, there is no birth history file. 
	We are not able to identify whether child mortality occured in the last 5 
	years preceeding the survey date. As such, for the estimation, we use the 
	indicator 'hh_mortality' that represent all child mortality that was ever 
	reported. */
recode hh_mortality			(0=1)(1=0) , gen(d_cm)
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
char _dta[cty] "Morocco"
char _dta[ccty] "MAR"
char _dta[year] "2011" 	
char _dta[survey] "PAPFAM"
char _dta[ccnum] "504"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(filedate)'."	
save "$path_out/mar_papfam11.dta", replace 
