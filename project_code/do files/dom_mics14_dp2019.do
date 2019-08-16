********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Dominican Republic MICS 2014 
[STATA do-file]. Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off
set maxvar 10000
set mem 500m


*** Working Folder Path ***
global path_in G:/My Drive/Work/GitHub/MPI//project_data/DHS MICS data files/Dominican_Republic_MICS5_Datasets
global path_out G:/My Drive/Work/GitHub/MPI//project_data/MPI out
global path_ado G:/My Drive/Work/GitHub/MPI//project_data/ado


********************************************************************************
*** Dominican Republic MICS 2014 ***
********************************************************************************

********************************************************************************
*** Step 1: Data preparation 
*** Selecting main variables from CH, WM, HH & MN recode & merging with HL recode 
********************************************************************************

	//Dominican Republic MICS 2014: There is no anthropometrics 

********************************************************************************
*** Step 1.1 CH - CHILDREN's RECODE (under 5)
********************************************************************************	
	/*Note: Anthropometric data was not collected for children under 5*/


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
save "$path_out/DOM14_BH.dta", replace	



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
	//Women in the sample: 15-49 years
tab cm1 cm8, miss  
	/*Women who has never ever given birth will not have information on 
	child mortality. In the DR there are 9 who have never given birth but report 
	having had a child that later died. This inconsistency will be adjusted 
	later in the dofile */
	

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
save "$path_out/DOM14_WM.dta", replace



********************************************************************************
*** Step 1.4  MN - MEN'S RECODE 
***(All eligible man: 15-54 / 15-59 years in the household) 
********************************************************************************

/* Note: There is no male data file for Dominican Republic MICS 2014. Hence this 
section has been deactivated */


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
codebook hh_id


save "$path_out/DOM14_HH.dta", replace



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
codebook hh_id

*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** hl1=respondent's line number.
gen double ind_id = hh1*100000 + hh2*100 + hl1 
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id


sort ind_id


	
********************************************************************************
*** Step 1.7 DATA MERGING 
******************************************************************************** 
 
*** Merging BR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/DOM14_BH.dta"
drop _merge
erase "$path_out/dom14_BH.dta" 
  
  
*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$path_out/DOM14_WM.dta"
tab hl7, miss 
gen temp = (hl7>0) 
tab women_WM temp, miss col
tab wm7 if temp==1 & women_WM==., miss  
	//Total of eligible women not interviewed 
drop temp
drop _merge
erase "$path_out/dom14_WM.dta"


*** Merging HH Recode 
*****************************************
merge m:1 hh_id using "$path_out/DOM14_HH.dta"
tab hh9 if _m==2
drop  if _merge==2
	//Drop households that were not interviewed 
drop _merge
erase "$path_out/dom14_HH.dta"



********************************************************************************
*** Step 1.8 CONTROL VARIABLES
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
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
tab no_fem_eligible, miss


*** No Eligible Men 15-59 years
*****************************************
	/*Since there is no male data file, this variable is generated as an empty 
	variable */
gen no_male_eligible = . 
lab var no_male_eligible "Household has no eligible man"
tab no_male_eligible, miss


	
*** No Eligible Children 0-5 years
***************************************** 
	/*Since there is no anthropometrics data for children under 5, this variable 
	is generated as an empty variable */ 
gen	no_child_eligible = .
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
	data is only collected from children. Since there is no anthropometrics data 
	for children under 5, this variable is generated as an empty variable.*/ 
gen	no_child_fem_eligible = .
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


drop fem_eligible hh_n_fem_eligible 


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
replace sex=. if sex==9
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
drop member


//Subnational region 
codebook hh7, tab (100)
decode hh7, gen(temp)
replace temp =  proper(temp)
encode temp, gen(region)
lab var region "Region for subnational decomposition"
tab hh7 region, miss 
drop temp


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************

********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************


/* The admission age to compulsory education in Dominican Republic is 6 years. 
Preschool education takes place from age 3 and lasts 3 years. Primary education 
takes place from age 6-14 (grades 1-8) and it lasts 8 years. Secondary education 
takes place from age 14-18(grades 9-12) and it lasts 4 years. 
Compulsory education lasts 15 years. (page 184 of report) */

tab ed4b ed4a, miss
tab age ed6a if ed5==1, miss
	/*In the case of Dominican Republic MICS 2014, there are some inconsistencies such 
	as individuals showing too much schooling given their age. This issue will be 
	addressed in the subsequent set of commands, that is, cleaning the
	inconsistencies*/

clonevar edulevel = ed4a 
	//Highest educational level attended
replace edulevel = . if ed4a==. | ed4a==8 | ed4a==9   
	//ed4a=8/98/99 are missing values 
replace edulevel = 0 if ed3==2 
	//Those who never attended school are replaced as '0'
label var edulevel "Highest educational level attended"


clonevar eduhighyear = ed4b 
	//Highest grade of education completed
replace eduhighyear = . if ed4b==. | ed4b==98 | ed4b==99 
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
gen eduyears = eduhighyear
replace eduyears = 0 if edulevel<=1 & eduhighyear==.   
	/*Assuming 0 year if they only attend preschool or primary but the last year 
	is unknown*/
replace eduyears = eduhighyear + 8 if (edulevel==2) 
	/*Secondary (lower and higher) after 8 years of primary*/
replace eduyears = eduhighyear + 12 if (edulevel==3)   
	/*University education assumed to start after 12 years of general 
	education */
replace eduyears = 0 if edulevel==0 & eduyears==. 
replace eduyears = . if edulevel==. & eduhighyear==. 
	//Replaced as missing value when level of education is missing

	
*** Checking for further inconsistencies 
replace eduyears = . if age<=eduyears & age>0 
	/*There are cases in which the years of schooling are greater than the 
	age of the individual. This is clearly a mistake in the data. Please check 
	whether this is the case and correct when necessary */
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
	/*Total number of household members who are 10 years and older */
replace no_missing_edu = no_missing_edu/hhs
replace no_missing_edu = (no_missing_edu>=2/3)
	/*Identify whether there is information on years of education for at 
	least 2/3 of the household members aged 10 years and older */
tab no_missing_edu, miss
	//Values for 0 are less than 1%
label var no_missing_edu "No missing edu for at least 2/3 of the HH members aged 10 years & older"	
drop temp temp2 hhs


*** New Standard MPI ***
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
	
replace attendance = 0 if age<5 | age>24 
	/*Replace attendance with '0' for individuals who are not of school age */
	
tab attendance, miss
label define lab_attend 1 "currently attending" 0 "not currently attending"
label values attendance lab_attend
label var attendance "Attended school during current school year"



*** Standard MPI ***
/*The entire household is considered deprived if any school-aged child is not 
attending school up to class 8. */ 
******************************************************************* 
gen child_schoolage = (age>=6 & age<=14)
	/*Note: In Dominican Republic, the official school entrance age is 6 years  
	 So, age range is 6-14 (=6+8). 
	Source: "http://data.uis.unesco.org/?ReportId=163"
	Go to Education>Education>System>Official Entrance Age to Compulsory 
	Education. Look at the starting age and add 8. */
	

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

	/*Dominican Republic MICS 2014 has no information on nutrition.*/

gen	hh_nutrition_uw_st = .
lab var hh_nutrition_uw_st "Household has no child underweight/stunted or adult deprived by BMI/BMI-for-age"


	
********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************
	//Dominican Republic MICS 2014: No information on child mortality from men 


codebook cm9a cm9b
	//cm9a: number of sons who have died 
	//cm9b: number of daughters who have died

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
	
	
	/* In the case of Dominican Republic, this variable takes missing value 
	because the survey did not collect information on child mortality from men*/	
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
	//missing values replaced	
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
recode shared_toilet (2=0)
recode shared_toilet (9=.)
tab ws9 shared_toilet, miss nol
	//0=no;1=yes;.=missing
		
		
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************
/* The country report for Dominican Republic indicate that the categoy 'flush do 
not where' as improved saniation facility (p.120). As such, for the purpose of 
the global MPI we follow the report. */

gen toilet_mdg = (toilet==11 | toilet==12 | toilet==13 | toilet==15 | ///
				  toilet==21 | toilet==22) & shared_toilet!=1 
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */

replace toilet_mdg = 0 if (toilet==14 | toilet==41 | toilet==42 | ///
					       toilet==95 | toilet==96) & shared_toilet==1 
	/*Household is assigned a value of '0' if it uses improved sanitation 
	but shares toilet with other households  */
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

clonevar water = ws1  
clonevar timetowater = ws4  
codebook water, tab(100)
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
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************

gen water_mdg = 1 if water==11 | water==12 | water==13 | water==14 | ///
					 water==21 | water==31 | water==41 | water==51 | ///
					 water==91 
	/*Non deprived if water is "piped into dwelling", "piped to yard/plot", 
	 "public tap/standpipe", "tube well or borehole", "protected well", 
	 "protected spring", "rainwater", "bottled water" */
replace water_mdg = 0 if water==32 | water==42 | water==61 | water==62 | ///
						 water==71 | water==81 | water==96 
	/*Deprived if it is "unprotected well", "unprotected spring", "tanker truck"
	"surface water (river/lake, etc)", "cart with small tank","other" */
replace water_mdg = 0 if water_mdg==1 & timetowater>=30 & timetowater!=. & ///
						 timetowater!=998 & timetowater!=999 
	//Deprived if water is at more than 30 minutes' walk (roundtrip) 
replace water_mdg = . if water==. | water==99
replace water_mdg = 0 if water==91 & (ndwater==32 | ndwater==42 | ///
						 ndwater==61 | ndwater==62 | ndwater==71 | ///
						 ndwater==81 | ndwater==96) 
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
gen floor_imp = 1
replace floor_imp = 0 if floor==11 | floor==96  
replace floor_imp = . if floor==. | floor==99 
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss	

	
/* Members of the household are considered deprived if the household has wall 
made of natural or rudimentary materials 

For Dominican Republic MICS 2014 yagua, tejamanil, madera rústica are considered 
part of rudimentary walls and classified as deprived (p.352)*/
clonevar wall = hc5
codebook wall, tab(99)
gen wall_imp = 1 
replace wall_imp = 0 if wall<=26 | wall==96
replace wall_imp = . if wall==. | wall==99 
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss
	
	
	
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials 

For Dominican Republic MICS 2014 metal o lata is NOT considered part of 
rudimentary walls and so it is classified as not deprived (p.351). */
clonevar roof = hc4
codebook roof, tab(99)	
gen roof_imp = 1 
replace roof_imp = 0 if roof==12 | roof==96
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

clonevar cookingfuel = hc6  
codebook cookingfuel, tab(99)


*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>5 & cookingfuel<95 
replace cooking_mdg = . if cookingfuel==. | cookingfuel==99
lab var cooking_mdg "Household has cooking fuel according to MDG standards"
	/* Deprived if: "coal/lignite", "charcoal", "wood", "straw/shrubs/grass" 
					"agricultural crop", "animal dung" */		 
tab cookingfuel cooking_mdg, miss	


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************
/*Assets that are included in the global MPI: Radio, TV, telephone, bicycle, 
motorbike, refrigerator, car, computer and animal cart */

	
clonevar television = hc8c
gen bw_television = .
clonevar radio = hc8b 
clonevar telephone = hc8d
clonevar mobiletelephone = hc9b 
clonevar refrigerator = hc8e

clonevar car = hc9f 
replace car = 1 if hc9j==1
	//hc9j (jeep) 
replace car = 1 if hc9k==1
	//hc9k (truck)

	
clonevar bicycle = hc9c
clonevar motorbike = hc9d


clonevar computer = hc8n
replace computer = 1 if tic1==1
	//tic1(personal computer)
replace computer = 1 if hc9h==1
	//hc9h (laptop) 
replace computer = 1 if hc9i==1
	//hc9i (tablet)

clonevar animal_cart = hc9e



foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer animal_cart  {
replace `var' = 0 if `var'==2 
	//0=no; 1=yes
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//9 , 99 and 8, 98 are missing
	


	//Combine information on telephone and mobilephone 
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

	//Retain data on sampling design: 
desc psu stratum
clonevar strata = stratum	

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
char _dta[cty] "Dominican Republic"
char _dta[ccty] "DOM"
char _dta[year] "2014" 	
char _dta[survey] "MICS"
char _dta[ccnum] "214"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(filedate)'."	
save "$path_out/dom_mics14.dta", replace 
