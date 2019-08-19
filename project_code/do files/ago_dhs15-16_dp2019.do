********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Angola DHS 2015-16 [STATA do-file]. 
Available from OPHI website: http://ophi.org.uk/  

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
*** ANGOLA DHS 2015-16 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
*** Selecting variables from KR, BR, IR, & MR recode & merging with PR recode 
********************************************************************************
	
/*Angola DHS 2015-16: Anthropometric information was recorded for children 0-5 
in a subsample of 1/2 of sampled households (p.4). The men's questionnaires (not 
including anthropometric information) were given to the OTHER 50% of sampled 
households, meaning that we will not be using information from the men's 
questionnaire, since we will drop the households not included in the subsample 
with children's anthropometric data. Anthropometric information was not 
collected from women 15-49 and men 15-54 */


********************************************************************************
*** Step 1.1 KR - CHILDREN's RECODE (under 5)
********************************************************************************

use "$path_in/AOKR71FL.DTA", clear 


*** Generate individual unique key variable required for data merging
*** v001=cluster number; 
*** v002=household number; 
*** b16=child's line number in household
gen double ind_id = v001*1000000 + v002*100 + b16 
format ind_id %20.0g
label var ind_id "Individual ID"

drop if b5==0 
	//Children who are not alive are excluded 
	//Angola DHS 2015-16: 703 observations deleted

duplicates report ind_id
duplicates tag ind_id, gen(duplicates)
tab b16 if duplicates!=0 
tab hw13 if duplicates!=0
	/*For children not listed in the household, we create a false 
	household line. We will check at merging stage. However,these children do 
	not have info on nutrition */
bys ind_id: gen line = (_n)
replace ind_id = v001*1000000 + v002*100 + (line+90) if duplicate!=0 
	//We assume consecutive hh line starting at 90
duplicates report ind_id 
	//No duplicates at this stage

gen child_KR=1 if hw13!=7
	/*Generate identification variable for observations in KR recode. In the 
	context of Angola DHS 2015-16, we only want to identify the 50% household 
	where children under 5 were sampled for the anthropometric sample. */
	
	
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
gen str30 datalab = "children_nutri_ago" 
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
replace weight = . if hw2>=9990 
	//All missing values or out of range are replaced as "."
tab	hw13 hw2 if hw2>=9990 | hw2==., miss 
	//hw13: result of the measurement
desc weight 
summ weight


*** Variable: HEIGHT (CENTIMETERS)
codebook hw3, tab (9999)
gen	height = hw3/10 
	//We divide it by 10 in order to express it in centimeters
tab hw3 if hw3>9990, miss nol   
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
the calculated z-scores */
use "$path_out/children_nutri_ago_z_rc.dta", clear 


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
	/* Note: In the context of Angola DHS 2015-6, 183 children are replaced 
	as '.' because they have extreme z-scores which are biologically 
	implausible.*/
	
 
	//Retain relevant variables:
keep ind_id child_KR v001 v002 b16 v135 underweight* stunting* wasting* 
order ind_id child_KR v001 v002 b16 v135 underweight* stunting* wasting* 

sort ind_id
duplicates report ind_id


	//Erase files from folder:
erase "$path_out/children_nutri_ago_z_rc.xls"
erase "$path_out/children_nutri_ago_prev_rc.xls"
erase "$path_out/children_nutri_ago_z_rc.dta"


	//Save a temp file for merging with PR:
save "$path_out/AGO15-16_KR.dta", replace

/* Note: The Angola DHS 2015-16 report indicate that the height/age indicator is 
based on information from 93% eligible children, weight/height is based on 
94% of the eligible children, and the weight/age report is also based on 
94% of the eligible children. This suggest a missing value that ranges between 
6%-7%. As such there is high missing value in the final nutrition indicator */
	

********************************************************************************
*** Step 1.2  BR - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************
/*The purpose of step 1.2 is to identify children of any age who died in 
the last 5 years prior to the survey date.*/

use "$path_in/AOBR71FL.DTA", clear


	
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
	//1=child dead; 0=child alive
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
	//Angola DHS 2015-16: these figures are identical
	
		
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
save "$path_out/AGO15-16_BR.dta", replace	
	
	
********************************************************************************
*** Step 1.3  IR - WOMEN's RECODE  
*** (All eligible females 15-49 years in the household)
********************************************************************************

use "$path_in/AOIR71FL.DTA", clear


*** Generate individual unique key variable required for data merging
*** v001=cluster number;  
*** v002=household number; 
*** v003=respondent's line number
gen double ind_id = v001*1000000 + v002*100 + v003 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id
	//No duplicates	

gen women_IR=1 
	//Identification variable for observations in IR recode

	
	//Retain relevant variables:
keep ind_id women_IR v003 v005 v012 v201 v206 v207
order ind_id women_IR v003 v005 v012 v201 v206 v207 
sort ind_id
save "$path_out/AGO15-16_IR.dta", replace


********************************************************************************
*** Step 1.4  IR - WOMEN'S RECODE  
*** (Girls 15-19 years in the household)
********************************************************************************
/*Note: In the case of Angola DHS 2015-16, anthropometric data was NOT collected 
from adults.*/


********************************************************************************
*** Step 1.5  MR - MEN'S RECODE  
***(All eligible man: 15-54 years in the household) 
********************************************************************************

use "$path_in/AOMR71FL.DTA", clear 


*** Generate individual unique key variable required for data merging
	*** mv001=cluster number; 
	*** mv002=household number;
	*** mv003=respondent's line number
gen double ind_id = mv001*1000000 + mv002*100 + mv003 	
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id
	//No duplicates	

gen men_MR=1 	
	//Identification variable for observations in MR recode


	//Retain relevant variables:	
keep ind_id men_MR mv003 mv005 mv012 mv201 mv206 mv207
order ind_id men_MR mv003 mv005 mv012 mv201 mv206 mv207
sort ind_id
save "$path_out/AGO15-16_MR.dta", replace


********************************************************************************
*** Step 1.6  MR - MEN'S RECODE  
***(Boys 15-19 years in the household) 
********************************************************************************
	/*Note: In the case of Angola DHS 2015-16, anthropometric data was NOT 
	collected from adults.*/



********************************************************************************
*** Step 1.7  PR - HOUSEHOLD MEMBER'S RECODE 
********************************************************************************

use "$path_in/AOPR71FL.DTA", clear


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
merge 1:1 ind_id using "$path_out/AGO15-16_BR.dta"
drop _merge
erase "$path_out/AGO15-16_BR.dta"


*** Merging IR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/AGO15-16_IR.dta"
tab women_IR hv117, miss col
tab ha65 if hv117==1 & women_IR ==., miss 
	//Total number of eligible women not interviewed
tab ha65 ha13 if women_IR == . & hv117==1, miss   
drop _merge
erase "$path_out/AGO15-16_IR.dta"


*** Merging MR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/AGO15-16_MR.dta"
tab men_MR hv118, miss col
drop _merge
erase "$path_out/AGO15-16_MR.dta"


*** Merging KR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/AGO15-16_KR.dta"
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
erase "$path_out/AGO15-16_KR.dta"



sort ind_id


********************************************************************************
*** Step 1.9 KEEPING ONLY DE JURE HOUSEHOLD MEMBERS ***
********************************************************************************

//Permanent (de jure) household members 
clonevar resident = hv102 
codebook resident, tab (10) 
label var resident "Permanent (de jure) household member"

drop if resident!=1 
tab resident, miss
	/*Note: The Global MPI is based on de jure (permanent) household members 
	only. As such, non-usual residents will be excluded from the sample. 
	In the context of Angola DHS 2015-16, 1,026 individuals who were 
	non-usual residents were dropped from the sample. */


********************************************************************************
*** Step 1.10 SUBSAMPLE VARIABLE ***
********************************************************************************

/*In a significant number of country surveys, only half of the household or one 
third or two third of the household is assessed for anthropometric measures.  
In the context of Angola DHS 2015-16, in 50% of households that were not 
selected for interviews with men, all children under 5 years of age were weighed 
and measured to assess their nutritional status*/

clonevar subsample = hv042
label var subsample "Households selected as part of nutrition subsample" 
drop if subsample!=1 
tab subsample, miss	
	
	
********************************************************************************
*** Step 1.11 CONTROL VARIABLES
********************************************************************************

/* Households are identified as having 'no eligible' members if there are no 
applicable population, that is, children 0-5 years, adult women 15-49 years or 
adult men 15-54 years. These households will not have information on relevant 
indicators of health. As such, these households are considered as non-deprived 
in those relevant indicators.*/


*** No Eligible Women 15-49 years
*****************************************
gen	fem_eligible = (hv117==1)
bys	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
tab no_fem_eligible, miss


*** No Eligible Men 15-54 years
*****************************************
gen	male_eligible = (hv118==1)
bys	hh_id: egen hh_n_male_eligible = sum(male_eligible)  
	//Number of eligible men for interview in the hh
gen	no_male_eligible = (hh_n_male_eligible==0) 	
	//Takes value 1 if the household had no eligible males for an interview
lab var no_male_eligible "Household has no eligible man"
tab no_male_eligible, miss


*** No Eligible Children 0-5 years
*****************************************
gen	child_eligible = (hv120==1) 
bys	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible"
tab no_child_eligible, miss


*** No Eligible Women and Men 
***********************************************
	/*NOTE: In the DHS datasets, we use this variable as a control 
	variable for the child mortality indicator if mortality data was 
	collected from women and men. If child mortality was only colelcted 
	from women, the we use 'no_fem_eligible' as the eligibility criteria */
gen	no_adults_eligible = (no_fem_eligible==1 & no_male_eligible==1) 
	//Takes value 1 if the household had no eligible men & women for an interview
lab var no_adults_eligible "Household has no eligible women or men"
tab no_adults_eligible, miss 


*** No Eligible Children and Women  
***********************************************
	/*NOTE: In the DHS datasets, we use this variable as a control 
	variable for the nutrition indicator if nutrition data is 
	present for children and women. However this will not be used in Angola
	DHS 2015-16 because nutrition data was only collected from children*/
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
bys	hh_id: egen hh_n_hem_eligible = sum(hem_eligible) 	 
gen	no_hem_eligible = (hh_n_hem_eligible==0) 
	//Takes value 1 if the HH had no eligible females for hemoglobin test	 	
lab var no_hem_eligible "Household has no eligible individuals for hemoglobin measurements"
tab no_hem_eligible, miss

tab hv042 no_child_eligible, miss
	//All children measured are part of the subsample

	
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
codebook marital, tab (20)
recode marital (0=1)(1=2)
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
  	/*NOTE: The sample for the Angola DHS 2015-16 was designed to provide 
	estimates of key indicators for the country as a whole, for urban and rural 
	areas separately, and for each of the 18 provinces (p.2) */ 
lookfor region
codebook hv024, tab (100)
clonevar region = hv024	
lab var region "Region for subnational decomposition"
codebook region, tab (100)
lab define lab_region 1 "Cabinda" ///
					  2 "Zaire" ///
					  3 "Uíge" ///
					  4 "Luanda" ///
					  5 "Cuanza Norte" ///
					  6 "Cuanza Sul" ///
					  7 "Malanje" ///
					  8 "Lunda Norte" ///
					  9 "Benguela" ///
					  10 "Huambo" ///
					  11 "Bié" ///
					  12 "Moxico" ///
					  13 "Cuando Cubango" ///
					  14 "Namibe" ///
					  15 "Huíla" ///
					  16 "Cunene" ///
					  17 "Lunda Sul" ///
					  18 "Bengo" 				  
lab values region lab_region


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
 	//Final variable missing if household has info for < 2/3 of members 
lab var hh_years_edu6 "Household has at least one member with 6 years of edu"
tab hh_years_edu6, miss



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
	/*
	Note: In Angola, the official school entrance age to primary school is 
	6 years. So, age range is 6-14 (=6+8)
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
	/*Note: 
	Angola DHS 2015-16 has no anthropometric data for adult women & men. */

********************************************************************************
*** Step 2.3b Child Nutrition ***
********************************************************************************

*** Child Underweight Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(underweight)
gen	hh_no_underweight = (temp==0) 
	//Takes value 1 if no child in the hh is underweight 
replace hh_no_underweight = . if temp==.
replace hh_no_underweight = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1 
lab var hh_no_underweight "Household has no child underweight - 2 stdev"
drop temp


*** Child Stunting Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(stunting)
gen	hh_no_stunting = (temp==0) 
	//Takes value 1 if no child in the hh is stunted
replace hh_no_stunting = . if temp==.
replace hh_no_stunting = 1 if no_child_eligible==1 
lab var hh_no_stunting "Household has no child stunted - 2 stdev"
drop temp


*** Child Either Underweight or Stunted Indicator ***
************************************************************************

*** Standard MPI ***
gen hh_no_uw_st = 1 if hh_no_stunting==1 & hh_no_underweight==1
replace hh_no_uw_st = 0 if hh_no_stunting==0 | hh_no_underweight==0
	//Takes value 0 if child in the hh is stunted or underweight 
replace hh_no_uw_st = . if hh_no_stunting==. & hh_no_underweight==.
replace hh_no_uw_st = 1 if no_child_eligible==1
	//Households with no eligible children will receive a value of 1 
lab var hh_no_uw_st "Household has no child underweight or stunted"


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
replace hh_nutrition_uw_st = 0 if hh_no_uw_st==0
replace hh_nutrition_uw_st = . if hh_no_uw_st==.
replace hh_nutrition_uw_st = 1 if no_child_eligible==1   
 	/*We replace households that do not have the applicable population, that is, 
	children 0-5, as non-deprived in nutrition*/		
lab var hh_nutrition_uw_st "Household has no child underweight or stunted"



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
/*Members of the household are considered deprived if the household has no 
electricity */


*** Standard MPI ***
/*Members of the household are considered 
deprived if the household has no electricity */
***************************************************
clonevar electricity = hv206 
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


clonevar toilet = hv205  
codebook toilet, tab(30) 
codebook hv225, tab(30)  
clonevar shared_toilet = hv225 
	//0=no;1=yes;.=missing


*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************
	/* Note: In Angola, Table 2.3 of the DHS report (p.19) indicate that 'flush' 
	are improved toilet no matter where the flushed material goes to and 
	all others are non-improved toilets. As such, the category ‘flush to 
	open pit (ditch or river)’ is coded as improved in this estimation. */

gen	toilet_mdg = ((toilet<20) & shared_toilet!=1) 
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */
	
replace toilet_mdg = 0 if (toilet<20)  & shared_toilet==1   
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

clonevar water = hv201  
clonevar timetowater = hv204  
codebook water, tab(100)

clonevar ndwater = hv202  
	//Non-drinking water
	
tab hv202 if water==71 	
/*Because the quality of bottled water is not known, households using bottled 
water for drinking are classified as using an improved or unimproved source 
according to their water source for non-drinking activities such as cooking and 
hand washing. However, it is important to note that households using bottled 
water for drinking are classified as unimproved source if this is explicitly 
mentioned in the country report. */	

	/* Note: Table 2.1 of the DHS report (p.18) classifies 'public fountain' as 
	safe drinking water and is considered as such for the MPI. On the other 
	hand, Table 2.1 (p.18) classifies drinking water that is delivered using 
	'three-wheel-motorcycle' as deprived and the same is considered for the 
	MPI. */


*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************
gen	water_mdg = 1 if water==11 | water==12 | water==13 | water==14 | ///
					 water==31 | water==33 | water==41 | water==51 | water==71  
	/*Non deprived if water is "piped into dwelling", "piped to yard/plot", 
	  "public tap/standpipe", "tube well or borehole", "protected well", 
	  "protected spring", "rainwater", "bottled water" */
	
	
replace water_mdg = 0 if water==32 | water==42 | water==43 | ///
						 water==61 | water==62 | water==63 | water==96 
	/*Deprived if it is "unprotected well", "unprotected spring", "tanker truck"
	  "surface water (river/lake, etc)", "cart with small tank","other" */
	
	
replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=996 & timetowater!=998 & timetowater!=999 
	//Deprived if water is at more than 30 minutes' walk (roundtrip) 
	
replace water_mdg = . if water==. | water==99
replace water_mdg = 0 if water==71 & ///
						(ndwater==32 | ndwater==42 | ndwater==43 | /// 
						 ndwater==61 | ndwater==62 | ndwater==63 | ndwater==96)
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
clonevar floor = hv213 
codebook floor, tab(99)
gen	floor_imp = 1
replace floor_imp = 0 if floor==11 | floor==96  
	//Deprived if "mud/earth", "sand", "dung", "other" 	
replace floor_imp = . if floor==. | floor==99 	
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss		


/* Members of the household are considered deprived if the household has wall 
made of natural or rudimentary materials */
clonevar wall = hv214 
codebook wall, tab(99)	
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=26 | wall==96  
	/*Deprived if "no wall" "cane/palms/trunk" "mud/dirt" 
	"grass/reeds/thatch" "pole/bamboo with mud" "stone with mud" "plywood"
	"cardboard" "carton/plastic" "uncovered adobe" "canvas/tent" 
	"unburnt bricks" "reused wood" "other"*/
replace wall_imp = . if wall==. | wall==99 	
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	
	
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
clonevar roof = hv215
codebook roof, tab(99)		
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=23 | roof==96  
	/*Deprived if "no roof" "thatch/palm leaf" "mud/earth/lump of earth" 
	"sod/grass" "plastic/polythene sheeting" "rustic mat" "cardboard" 
	"canvas/tent" "wood planks/reused wood" "unburnt bricks" "other"*/	
replace roof_imp = . if roof==. | roof==99 	
lab var roof_imp "Household has roof that it is not of low quality materials"
tab roof roof_imp, miss


*** Standard MPI ***
/* Members of the household is deprived in housing if the roof, 
floor OR walls are constructed from low quality materials.*/
**************************************************************
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

lookfor cooking
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

	/*Note that in Angola DHS 2015-16, the category 'other' cooking fuel is not 
	identified as solid fuel. Hence this particular category is identified as 
	'non-deprived' */


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
clonevar computer = hv243e
clonevar animal_cart = hv243c



foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer animal_cart {
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Missing values replaced
	
	
	//Group telephone and mobiletelephone as a single variable 	
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
char _dta[cty] "Angola"
char _dta[ccty] "AGO"
char _dta[year] "2015-2016" 	
char _dta[survey] "DHS"
char _dta[ccnum] "024"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(filedate)'."	
save "$path_out/ago_dhs15-16.dta", replace 


/*Note on missing value for Angola DHS 2015-16

The nutrition indicator has very high missing value - close to 14%. 
Further check indicate that some 13% of the missing sample is from the province 
of Luanda. */
