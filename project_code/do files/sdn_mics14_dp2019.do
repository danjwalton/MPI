********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Sudan MICS 2014
[STATA do-file]. Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off
set maxvar 10000
set mem 500m


*** Working Folder Path ***
global path_in G:/My Drive/Work/GitHub/MPI//project_data/DHS MICS data files/Sudan_MICS5_Datasets
global path_out G:/My Drive/Work/GitHub/MPI//project_data/MPI out
global path_ado G:/My Drive/Work/GitHub/MPI//project_data/ado



********************************************************************************
*** Sudan MICS 2014 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
*** Selecting main variables from CH, WM, HH & MN recode & merging with HL recode 
********************************************************************************
	
/*Sudan MICS 2014: Four sets of questionnaires were used in the survey (p6): 
1) a household questionnaire which was used to collect basic demographic 
information on all de jure household members (usual residents), and the
dwelling; 2) a questionnaire for individual women administered in each 
household to all women age 15-49 years; 3) a questionnaire for individual 
men administered in every second household to all men age 15-54 years; and 
4) an under-5 questionnaire, administered to mothers (or caretakers)for all 
children under 5 living in the household. P8 indicate that anthropometric data
was collected only for childen under 5 years. */


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
	//No duplicates 

gen child_CH=1 
	//Generate identification variable for observations in CH recode

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
gen str30 datalab = "children_nutri_sdn" 
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
tab caged, miss
	//Age measured in days:  2,335 missing observations
tab cage, miss
	//Age measured in months: 670 missing observations

	/*Note that the variable age measured in days have much higher missing 
	values, while age measured in months have lower missing observations. 
	As such, we use the variable age that is measured in months.*/	
clonevar age_months = cage
desc age_months
summ age_months
gen str6 ageunit = "months" 
lab var ageunit "Months"

	
*** Variable: BODY WEIGHT (KILOGRAMS) ***
	/*Note: In the Sudan MICS 2014 dataset, some 1,827 (12%) of the 
	children under 5 had missing weight data.*/
codebook an3, tab (9999)
clonevar weight = an3	
replace weight = . if an3>=99    
tab	an2 an3 if an3>=99 | an3==., miss 
	//an2: result of the measurement
tab uf9 if an2==. & an3==.	
desc weight 
summ weight	


*** Variable: HEIGHT (CENTIMETERS)
	/*Note: In the Sudan MICS 2014 dataset, some 2,033 (14%) of the 
	children under 5 had missing height data.*/
codebook an4, tab (9999)
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
	//odema present: an5
replace an5=. if an5==9
tostring an5, generate(oedema)  
desc oedema
tab oedema, miss	


*** Variable: INDIVIDUAL CHILD SAMPLING WEIGHT ***
gen sw = chweight
desc sw
summ sw	
	
	
/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age_months ageunit weight ///
height measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores */
use "$path_out/children_nutri_sdn_z_rc.dta", clear 

	
	
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
	/* Note: in the context of Sudan MICS 2014, 328 children were replaced as'.'
	because they have extreme z-scores that are biologically implausible. */
 

	//Retain relevant variables:
keep ind_id child_CH ln underweight* stunting* wasting*  
order ind_id child_CH ln underweight* stunting* wasting*
sort ind_id
save "$path_out/SDN14_CH.dta", replace


	//Erase files from folder:
erase "$path_out/children_nutri_sdn_z_rc.xls"
erase "$path_out/children_nutri_sdn_prev_rc.xls"
erase "$path_out/children_nutri_sdn_z_rc.dta"


	/*Note: Up to some 14% of children under 5 have either missing info on 
	height or weight. The country report confirmed the high missing 
	anthropometric information (p.299-300).*/


********************************************************************************
*** Step 1.2  BH - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************
/*The purpose of step 1.2 is to identify children of any age who died in 
the last 5 years prior to the survey date.*/

use "$path_in/bh.dta", clear


rename _all, lower	

	
*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** wm4=women's line number.   
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
save "$path_out/SDN14_BH.dta", replace	



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


gen women_WM =1 
	//Identification variable for observations in WM recode

	
tab wb2, miss
	// women in the sample: 15-49 years
	
tab cm1 cm8, miss  
	/*Women who has never ever given birth will not have information on 
	child mortality
	
	In Sudan MICS 2014, never married women do not have information about births 
	or mortality. */



lookfor marital	
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
keep wm7 cm1 cm8 cm9a cm9b ind_id women_WM *_wom 
order wm7 cm1 cm8 cm9a cm9b ind_id women_WM *_wom
sort ind_id
save "$path_out/SDN14_WM.dta", replace


********************************************************************************
*** Step 1.4  MN - MEN'S RECODE 
***(All eligible man in the household) 
********************************************************************************
/* Note: There is no male data file for Sudan MICS 2014. Hence this section has 
been deactivated */


********************************************************************************
*** Step 1.5 HH - HOUSEHOLD RECODE 
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


save "$path_out/SDN14_HH.dta", replace


********************************************************************************
*** Step 1.6 HL - HOUSEHOLD MEMBER  
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
*** Step 1.7 DATA MERGING 
******************************************************************************** 
 
 
*** Merging BR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/SDN14_BH.dta"
drop _merge
erase "$path_out/SDN14_BH.dta" 
 
 
*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$path_out/SDN14_WM.dta"
tab hl7, miss 
gen temp = (hl7>0) 
tab women_WM temp, miss col
tab wm7 if temp==1 & women_WM==., miss  
	//Total of eligible women not interviewed 
drop temp
drop _merge
erase "$path_out/SDN14_WM.dta"


*** Merging HH Recode 
*****************************************
merge m:1 hh_id using "$path_out/SDN14_HH.dta", force
tab hh9 if _m==2
drop  if _merge==2
	//Drop households that were not interviewed 
drop _merge
erase "$path_out/SDN14_HH.dta"


*** Merging MN Recode 
*****************************************
	//There is no male data file for Sudan MICS 2014

gen marital_men = .
label var marital_men "Marital status of household member"


*** Merging CH Recode 
*****************************************
merge 1:1 ind_id using "$path_out/SDN14_CH.dta"
drop _merge
erase "$path_out/SDN14_CH.dta"
sort ind_id


********************************************************************************
*** Step 1.8 CONTROL VARIABLES
********************************************************************************

/* Households are identified as having 'no eligible' members if there are no 
applicable population, that is, children 0-5 years, adult women 15-49 years or 
men years. These households will not have information on relevant 
indicators of health. As such, these households are considered as non-deprived 
in those relevant indicators.*/


*** No Eligible Women 15-49 years
*****************************************
gen	fem_eligible = (hl7>0) if hl7!=.
bys	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
tab no_fem_eligible, miss


*** No Eligible Men 15-54 / 15-54 years
*****************************************
	/*Since there is no male data file, this variable is generated as an empty 
	variable */
gen no_male_eligible = . 
lab var no_male_eligible "Household has no eligible man"
tab no_male_eligible, miss

	
*** No Eligible Children 0-5 years
*****************************************
gen child_eligible = (hl7b>0 | child_CH==1) 
bys hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible"	
tab no_child_eligible, miss
	
	
*** No Eligible Women and Men 
***********************************************
	/*Since there is no male data file, this variable is generated as an empty 
	variable */
gen	no_adults_eligible = .
lab var no_adults_eligible "Household has no eligible women or men"
tab no_adults_eligible, miss 

		
*** No Eligible Children and Women  
***********************************************
	/*NOTE: In the DHS datasets, we use this variable as a control 
	variable for the nutrition indicator if nutrition data is 
	present for children and women. However, in MICS, we do NOT 
	use this as a control variable. This is because nutrition 
	data is only collected from children. However, we continue to 
	generate this variable in this do-file so as to be consistent*/ 
gen	no_child_fem_eligible = (no_child_eligible==1 & no_fem_eligible==1)
lab var no_child_fem_eligible "Household has no children or women eligible"
tab no_child_fem_eligible, miss 


*** No Eligible Women, Men or Children 
***********************************************
	/*NOTE: In the DHS datasets, we use this variable as a control 
	variable for the nutrition indicator if nutrition data is 
	present for children, women and men. However, in MICS, we do NOT 
	use this as a control variable. This is because nutrition 
	data is only collected from children. However, we continue to 
	generate this variable in this do-file so as to be consistent
	Since there is no male data file, this variable is generated as an empty 
	variable */
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


drop fem_eligible hh_n_fem_eligible child_eligible hh_n_children_eligible 


sort hh_id



********************************************************************************
*** Step 1.9 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
clonevar weight = hhweight 
label var weight "Sample weight"



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
recode sex (9=.)
label var sex "Sex of household member"


//Age of household member
codebook hl6, tab (100)
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


//Total number of hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
compare hhsize hh11
drop member


//Subnational region 
	/*Note: The sample for Sudan MICS 2014 was designed to provide estimates 
	for a large number of indicators that describe the situation of children and 
	women at the national level, in urban and rural areas, and in the 18 States 
	of Sudan. */
codebook hh7, tab (99)
decode hh7, gen(temp)
replace temp =  proper(temp)
encode temp, gen(region)
lab var region "Region for subnational decomposition"
tab hh7 region, miss 
drop temp
label define lab_reg ///
1 "Blue Nile" ///
2 "Central Darfur" ///
3 "East Darfur" ///
4 "Al Qadarif" ///
5 "Al Jazirah" ///
6 "Kassala" ///
7 "Khartoum" ///
8 "North Darfur" ///
9 "North Kurdufan" ///
10 "Northern" ///
11 "Red Sea" ///
12 "River Nile" ///
13 "Sinnar" ///
14 "South Darfur" ///
15 "South Kurdufan" ///
16 "West Darfur" ///
17 "West Kurdufan" ///
18 "White Nile"
label values region lab_reg


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************


/* Sudan education model:
11 years of basic education: 
6 years of compulsory primary, 
2 years of compulsory secondary, and 
3 years of upper secondary. 

The admission age to compulsory education is 6 years.
Primary education takes place from age 6-12 (grades 1-6). 
Lower secondary education takes place from age 12-14 (grades 7-8). 
Upper secondary education takes place from age 14-17 (grades 9-11).

Reference: http://data.uis.unesco.org/ */


tab ed4b ed4a, miss
tab age ed6a if ed5==1, miss

/*
In Sudan, children enter primary school at age 6 and enter secondary school at 
age 14. There are 8 grades in primary school and 3 grades in secondary school. 
In primary school, grades are referred to as year 1 basic to year 8 basic. 
For secondary school, grades are referred to as grade 1 to grade 3. The school 
year typically runs from June of one year to March of the following year (p.176 
of the country report).
*/
	
clonevar edulevel = ed4a 
	//Highest educational level attended
replace edulevel = . if ed4a==. | ed4a==98 | ed4a==99  
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
replace eduhighyear = 0 if edulevel<2 
	/* Note: In the context of Sudan, khalwa (koranic) school is considered 
	as non-formal education hence replaced as 0 years education */
	

*** Now we create the years of schooling
tab eduhighyear edulevel, miss
gen eduyears = eduhighyear
replace eduyears = 0 if edulevel<=4 & eduhighyear==.   
	/* Note: In the context of Sudan, elementary, primary and assas levels are 
	recognised as primary education, while khalwa (koranic) school is considered 
	as non-formal education */ 
replace eduyears = eduhighyear + 8 if (edulevel>=5 & edulevel<=10)
	/*Higher secondary comes after 8 years of education, that is , 6 years of 
	primary + 2 years of lower secondary. */
replace eduyears = eduhighyear + 11 if (edulevel==11 | edulevel==12)
	/*University education comes after 11 years, that is, 6 years of primary + 
	2 years of lower secondary + 3 years of higher secondary */
replace eduyears = 0 if edulevel==0 & eduyears==. 
replace eduyears = . if edulevel==. & eduhighyear==.
	//Replaced as missing value when level of education is missing
 

*** Checking for further inconsistencies 
replace eduyears = . if age<=eduyears & age>0 
	/*There are cases in which the years of schooling are greater than the 
	age of the individual. This is a mistake in the data.*/
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
	
replace attendance = 0 if age<5 | age>24 
	/*Replace attendance with '0' for individuals who are not of school age */
		
tab attendance, miss
label define lab_attend 1 "currently attending" 0 "not currently attending"
label values attendance lab_attend
label var attendance "Attended school during current school year"


*** Standard MPI ***
******************************************************************* 
/*The entire household is considered deprived if any school-aged child is not 
attending school up to class 8. */ 


gen child_schoolage = (age>=6 & age<=14)
	/*
	In Sudan, the official primary school entrance age is 6 years. The 
	country report confirms this - see page 176. So, age range is 6-14 (=6+8).
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

********************************************************************************
*** Step 2.3a Child Nutrition ***
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
*** Step 2.3b Household Nutrition Indicator ***
********************************************************************************


*** Standard MPI ***
/* The indicator takes value 1 if there is no children under 5 underweight or 
stunted. It also takes value 1 for the households that have no eligible children. 
The indicator takes value missing "." only if all eligible children have missing 
information in their respective nutrition variable. */
************************************************************************

gen	hh_nutrition_uw_st = 1
replace hh_nutrition_uw_st = 0 if hh_no_uw_st==0
replace hh_nutrition_uw_st = . if hh_no_uw_st==.
replace hh_nutrition_uw_st = 1 if no_child_eligible==1   
 	/*We replace households that do not have the applicable population, that is, 
	children 0-5, as non-deprived in nutrition*/		
lab var hh_nutrition_uw_st "Household has no child underweight or stunted"



********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************

codebook cm9a cm9b
	  
egen temp_f = rowtotal(cm9a cm9b), missing
	//Total child mortality reported by eligible women
replace temp_f = 0 if cm1==1 & cm8==2 | cm1==2
replace temp_f = 0 if cm1==. & cm8==. & marital_wom==1 & temp_f==. 
	/*Assign a value of "0" for:
	- all eligible women who have ever gave birth but reported no child death 
	- all eligible women who never ever gave birth 
	- all elegible but never married women were not asked birth history 
	questions and hence we assume there is no child mortality among this group*/	
replace temp_f = 0 if no_fem_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f
	

	/* In the case of Sudan, this variable takes missing value because the 
	survey did not collect information on child mortality from men */	
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
replace childu18_died_per_wom_5y = 0 if cm1==1 & cm8==2 | cm1==2 
replace childu18_died_per_wom_5y = 0 if cm1==. & cm8==. & marital_wom==1 & childu18_died_per_wom_5y==. 														   
	/*Assign a value of "0" for:
	- all eligible women who never ever gave birth 
	- all elegible but never married women were not asked birth history 
	questions and hence we assume there is no child mortality among this group
	*/	
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
clonevar electricity = hc8a 
codebook electricity, tab (10)
replace electricity = 0 if electricity==2 
	//0=no; 1=yes 
replace electricity = . if electricity==9 
	//Missing value replaced	
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

clonevar toilet = ws8  
codebook toilet, tab(30) 
codebook ws9, tab(30)  	
clonevar shared_toilet = ws9 
recode shared_toilet (2=0) (9=.)
tab ws9 shared_toilet, miss nol
	//0=no;1=yes;.=missing
	
	
*** Standard MPI ***
****************************************
	/*Note: Following the MDG definition, the categories 'flush to somewhere 
	else' and 'flush to unknown place/not sure/do not know where' are considered 
	as non-improved sanitation facility. However, in Sudan, both these 
	categories are identified as improved sanitation facilities in the country 
	report (p.115)*/

gen toilet_mdg = 1 if (toilet==11 | toilet==12 | toilet==13 | toilet==14 | ///
					   toilet==15 | toilet==21 | toilet==22 | toilet==31) ///
					   & shared_toilet!=1
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */

replace toilet_mdg = 0 if toilet==23 | toilet==41 | ///
						  toilet==95 | toilet==96
						  
replace toilet_mdg = 0 if shared_toilet==1
	/*Household is assigned a value of '0' if it uses improved sanitation 
	but shares toilet with other households  */
		
replace toilet_mdg = . if toilet==. | toilet==99
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
					 water==15 | water==31 | water==41 | water==91 					 
	/*Non deprived if water is "piped into dwelling", "piped to yard/plot", 
	 "public tap/standpipe", "tube well or borehole", "protected well", 
	 "protected spring", "rainwater", "bottled water" */
	
	
replace water_mdg = 0 if water==32 | water==42 | water==52 | water==53 | ///
						 water==61 | water==62 | water==63 | water==96 
	/*Deprived if it is "unprotected well", "unprotected spring", "tanker truck"
	"surface water (river/lake, etc)", "cart with small tank","other" */

	
replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=998 & timetowater!=999 
	//Deprived if water is at more than 30 minutes' walk (roundtrip) 
	
replace water_mdg = . if water==. | water==99
replace water_mdg = 0 if water==91 & ///
						(ndwater==32 | ndwater==42 | ndwater==52 | ///
						 ndwater==53 | ndwater==61 | ndwater==62 | ///
						 ndwater==63 | ndwater==96) 
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
replace floor_imp = 0 if floor<=12 | floor == 96 
replace floor_imp = . if floor==99 
replace floor_imp = . if floor == .
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss	


/* Members of the household are considered deprived if the household has wall 
made of natural or rudimentary materials */
clonevar wall = hc5
codebook wall, tab(99)
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=26| wall==96 
replace wall_imp = . if wall==99 	
replace wall_imp = . if wall == .
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	

	
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
clonevar roof = hc4
codebook roof, tab(99)		
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=25|  roof==96 
replace roof_imp = . if roof==99 	
replace roof_imp = . if roof== . 
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

/*
Solid fuel are solid materials burned as fuels, which includes coal as well as 
solid biomass fuels (wood, animal dung, crop wastes and charcoal). 

Source: 
https://apps.who.int/iris/bitstream/handle/10665/141496/9789241548885_eng.pdf
*/

clonevar cookingfuel = hc6  
codebook cookingfuel, tab(99)


*** Standard MPI ***
****************************************

gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<95 & cookingfuel!=12
replace cooking_mdg = . if cookingfuel==. |cookingfuel==99
lab var cooking_mdg "Household has cooking fuel according to MDG standards"
/*
Deprived if: 6 "coal/lignite", 7 "charcoal", 8 "wood", 9 "straw/shrubs/grass" 
	         10 "agricultural crop", 11 "animal dung"
*/			 
tab cookingfuel cooking_mdg, miss	



********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************
/* Members of the household are considered deprived if the household does not 
own more than one of: radio, TV, telephone, bike, motorbike or refrigerator and 
does not own a car or truck. */

codebook hc8b hc8c hc8d hc8e hc8g hc8h hc8i hc9b hc9c hc9d hc9e ///
		 hc9f hc9g hc9i hc9j hc9k


clonevar television = hc8c 
replace television = 1 if hc8g==1 
	//hc8g = flat TV Screen	
gen bw_television = .	

clonevar radio = hc8b 
clonevar telephone =  hc8d

clonevar mobiletelephone = hc9b 
replace mobiletelephone =1 if hc9i==1
	//hc9i = smartphone

clonevar refrigerator = hc8e
clonevar car = hc9f	
clonevar bicycle = hc9c
clonevar motorbike = hc9d

clonevar computer = hc8i 
replace computer=1 if hc9j==1
	//hc9j = laptop/tablet
replace computer=. if computer==6	

clonevar animal_cart = hc9e



foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer animal_cart  {
replace `var' = 0 if `var'==2 
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Missing values replaced
	
	

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
desc psu strata


	//Retain year, month & date of interview:
desc hh5y hh5m hh5d 
clonevar year_interview = hh5y 	
clonevar month_interview = hh5m 
clonevar date_interview = hh5d 


	//Generate presence of subsample
gen subsample = .
 

	/*Final check to see the total number of missing values  for each variable. 
	Variables should not have at this stage high proportion of missing (unless 
	the information was not collected for the country). If larger than 3%, 
	please check whether it is genuinely missing information.*/
mdesc psu strata area age ///
hh_years_edu6 hh_child_atten hh_no_uw_st hh_nutrition_uw_st ///
hh_mortality_u18_5y electricity toilet_mdg water_mdg housing_1 ///
cooking_mdg hh_assets2 television radio telephone refrigerator bicycle ///
motorbike car computer animal_cart  
 
	/*Note: Up to some 14% of children under 5 have either missing info on 
	height or weight. The country report confirmed the high missing anthropometric 
	information (see page 299-300 of the country report). As a result, this 
	affect the size of missing observations for the final nutrition indicator. 
	Some 7 percent of the individuals live in households where there is missing 
	nutrition data. */ 
		

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
char _dta[cty] "Sudan"
char _dta[ccty] "SDN"
char _dta[year] "2014" 	
char _dta[survey] "MICS"
char _dta[ccnum] "729"
char _dta[type] "micro"

	
*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(filedate)'."	
save "$path_out/sdn_mics14.dta", replace 
