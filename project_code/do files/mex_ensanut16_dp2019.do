********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Mexico ENSANUT 2016 [STATA do-file]. 
Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************


clear all 
set more off
set maxvar 10000
set mem 500m


*** Working Folder Path ***
global path_in "T:/GMPI 2.0/rdta/Mexico ENSANUT 2016"	  
global path_out "G:/GMPI 2.0/cdta"
global path_ado "T:/GMPI 2.0/ado"


********************************************************************************
*** MEXICO ENSANUT 2016 ***
********************************************************************************

/* México ENSANUT 2016: 
There are 4 database that we use to compute the Global MPI: 
- HOGAR     : "hogar_integrantes_procesada" and "hogar_socioeconomicoprocesada"
- NUTRITION : "Edo_Nut_AdultoS" and "Edo_Nut_Men_Adol"

There are 2 data files that we use to compute indicators related to nutrition:
https://ensanut.insp.mx/ensanut2016/descarga_bases.php
"Edo_Nut_Adultos" (Adults' nutritional information); and 
"Edo_Nut_Men_Adol" (Teenagers' and under 5 nutritional information)


Anthropometric information is available for individuals aged 0-99 years.*/ 


********************************************************************************
*** Step 1.1 NUTRITION DATA
********************************************************************************

use "$path_in/ponde_antropo_2_procesada_09112016.DTA", clear 


*** Household unique id
clonevar hh_id = folio 
lab var  hh_id "Household ID"


*** Individual unique id
ren int ind_id 
label var  ind_id "Individual ID"


duplicates report hh_id ind_id


*** Variable: SEX ***
lookfor sexo 
rename sexo sex  
tab sex, miss 
	//"1" for male ;"2" for female
tab  sex, nol 
clonevar gender = sex
desc gender
tab gender


*** Variable: AGE ***
lookfor edad
codebook edad, tab (999)
 	//edad = age in years  
codebook edadmeses, tab (9999)
	//edadmeses = age in months
clonevar age_month = edadmeses  
desc age_month
summ age_month
gen  str6 ageunit = "months" 
lab var ageunit "Months"
lab var age_month "Age in months"

	
	
*** Variable: BODY WEIGHT (KILOGRAMS) ***
lookfor peso
codebook peso, tab (9999) 
	//peso = first measure (in kg)
codebook peso2, tab (9999)
	//peso2 = second measure(in kg)
compare peso peso2 
	/*There is mismatch between the variable peso and peso2 which essentially 
	measures the same thing. As the general data management practise, we utilise 
	the second variable (peso2) that was constructed by the data managers. 
	Presumably the variable peso2 was generated to correct for issues observed 
	in the peso variable. */
clonevar  weight = peso2

lookfor rpeso 
tab rpeso, miss
	//rpeso = result of weight measurement
label define lab_weight 1 "without problem" 2 "physical problem" ///
						3 "didn't cope"     4 "refused" 
label values rpeso lab_weight
tab	rpeso weight if weight>=9990 | weight==., miss 
	//43 missing values for weight explained 
desc weight 
summ weight 
	//16,285 obs 

	
*** Variable: HEIGHT (CENTIMETERS)
lookfor talla
codebook talla, tab (9999) 
	//talla = first measure (in cm)
codebook talla2, tab (9999) 	
	//talla2 = second measure (in cm)
compare talla talla2 
	/*There is mismatch between the variable talla and talla2 which essentially 
	measures the same thing. As the general data management practise, we utilise 
	the second variable (peso2) that was constructed by the data managers. 
	Presumably the variable peso2 was generated to correct for issues observed 
	in the peso variable. */
clonevar  height = talla2 
		
lookfor rtalla 
tab rtalla, miss
	//rtalla = result of height measurement
label define lab_height 1 "without problem" 2 "physical problem" 3"didn't cope" 4 "refused" 
label values rtalla lab_height
tab	rtalla height if height>=9990 | height==., miss 
	//74 missing values for height explained 
desc height 
summ height 
	//16,254 obs 

	
*** Variable: MEASURED STANDING/LYING DOWN ***	
	/*Note: MEXICO ENSANUT 2016 has no information on whether the individual was 
	measured standing up or lying down. As such an empty variable is generated*/
gen str1 measure = " "
	
	
*** Variable: OEDEMA ***
	/*Note:MEXICO ENSANUT 2016 has no information on oedema. So it is assumed 
	that no-one has oedema*/
lookfor oedema
gen  oedema = "n"  
desc oedema
tab oedema	


*** Variable: INDIVIDUAL SAMPLING WEIGHT ***	
lookfor ponde 
	//"ponde_f" = final weight 
clonevar sw = ponde_f 
desc sw
summ sw 


	/*Save file in order to use the .dta file to compute nutrition indicators 
	individually for children under 5, teenagers, and adults */
save "$path_out/nutri_temp.dta", replace


********************************************************************************
*** Step 1.1a Nutrition indicators for children under 5
********************************************************************************

clear

use "$path_out/nutri_temp.dta"

sort ind_id

gen child_KR=1 if age_month<=59 
	//The focus in this section is on children under 5 years 

keep if child_KR==1 
	//Retain  observations of those children aged 59 months & younger 
	
tab age_month, miss
	//2,027 children 59 months and younger 

/* 
For this part of the do-file we use the WHO Anthro and macros. This is to 
calculate the z-scores of children under 5. 
Source of ado file: http://www.who.int/childgrowth/software/en/
*/	
	
*** Indicate to STATA where the igrowup_restricted.ado file is stored:
adopath + "$path_ado/igrowup_stata"

*** We will now create three nutritional variables for children under 5: 
	*** weight-for-age (underweight),  
	*** weight-for-height (wasting) 
	*** height-for-age (stunting)

/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Child Growth Standards are stored. */	
gen str100 reflib = "$path_ado/igrowup_stata"
lab var reflib "Directory of reference tables"


/* We use datalib to specify the working directory where the input STATA 
dataset containing the anthropometric measurement is stored. */
gen str100 datalib = "$path_out" 
lab var datalib "Directory for datafiles"


/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file*/
gen str30 datalab = "children_nutri_mex" 
lab var datalab "Working file"



//We now run the command to calculate the z-scores with the adofile 
igrowup_restricted reflib datalib datalab gender age_month ageunit weight ///
height measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to create the child nutrition variables following WHO 
standards */
use "$path_out/children_nutri_mex_z_rc.dta", clear 



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
	/*Note: In Mexico ENSANUT 2016, 13 children were replaced as missing because
	they have extreme z-scores which are biologically implausible. */
 
 
	//Retain relevant variables:
keep hh_id ind_id child_KR underweight* stunting* wasting* 
order hh_id ind_id child_KR underweight* stunting* wasting* 
sort hh_id ind_id
duplicates report hh_id ind_id
	//No duplicates at this stage
save "$path_out/MEX16_KR.dta", replace	

	
	//Erase files from folder:
erase "$path_out/children_nutri_mex_z_rc.xls"
erase "$path_out/children_nutri_mex_prev_rc.xls"
erase "$path_out/children_nutri_mex_z_rc.dta"

	
********************************************************************************
*** Step 1.1b BMI-for-age for individuals above 5 years & under 20 years 
********************************************************************************

clear 

use "$path_out/nutri_temp.dta", clear


count if age_month> 59 & age_month < 240
keep if age_month> 59 & age_month < 240
	//Keep only relevant sample: individuals above 5 years and under 20 years 
count	
	//5,837 individuals above 5 years and under 20 years

	
/* 
For this part of the do-file we use the WHO AnthroPlus software. This is to 
calculate the z-scores for young individuals above 5 years & under 20 years. 
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
gen str30 datalab = "teen_nutri_mex" 
lab var datalab "Working file"
	
	
//We now run the command to calculate the z-scores with the adofile 
who2007 reflib datalib datalab gender age_month ageunit weight height oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to compute BMI-for-age*/
use "$path_out/teen_nutri_mex_z.dta", clear 

		
gen	z_bmi = _zbfa
replace z_bmi = . if _fbfa==1 
lab var z_bmi "z-score bmi-for-age WHO"


*** Standard MPI indicator ***
gen	low_bmiage = (z_bmi < -2.0) 
	/*Takes value 1 if BMI-for-age is under 2 stdev below the median & 0 
	otherwise */
replace low_bmiage = . if z_bmi==.
lab var low_bmiage "Teenage low bmi 2sd - WHO"


 	//Identification variable for children above 5 years and under 20 years 
gen teen_IR=1 


sort hh_id ind_id
duplicates report hh_id ind_id
	//No duplicates at this stage

	
	//Retain relevant variables:	
keep hh_id ind_id teen_IR age_month low_bmiage*
order hh_id ind_id teen_IR age_month low_bmiage*
 
 
 
	/*Append the nutrition information of children above 5 years with 
	children under 5 */	
append using "$path_out/MEX16_KR.dta"
	
	
	//Save a temp file for merging later:
save "$path_out/MEX16_children.dta", replace


	//Erase files from folder:
erase "$path_out/teen_nutri_mex_z.xls"
erase "$path_out/teen_nutri_mex_prev.xls"
erase "$path_out/teen_nutri_mex_z.dta"	
erase "$path_out/MEX16_KR.dta"
 
 
 
********************************************************************************
*** Step 1.1c BMI for all individuals in the dataset
********************************************************************************

clear 

use "$path_out/nutri_temp.dta", clear

count if age_month>=180
	//9,964 individuals who are 15 years and older
count if age_month>=240	
	//8,464 individuals who are 20 years and older


*** Variable: ADULT BMI ***
	/*In this section we compute BMI for all individuals up to the age of 70 
	years but we will later apply this measure for individuals who are 20 - 70 years*/
gen bmi=(weight)/((height/100)^2)
lab var bmi "BMI"


gen low_bmi = (bmi<18.5)
replace low_bmi=. if bmi==.
replace low_bmi = . if age_month>840 & age_month<.
	/*Replace individuals who are older than 70 years with '.' even if they had 
	provided nutrition information since the global MPI does not take into 
	account of nutrition information of those above 70 years. */ 
lab var low_bmi "BMI <18.5"
lab define lab_low_bmi 1 "bmi<18.5" 0 "bmi>=18.5"
lab values low_bmi lab_low_bmi
tab low_bmi, miss


gen low_bmi_u = (bmi<17)
replace low_bmi_u = . if bmi==. 
replace low_bmi_u = . if age_month>840 & age_month<.
lab var low_bmi_u "BMI <17"
lab define lab_low_bmi_u 1 "bmi<17" 0 "bmi>=17"
lab values low_bmi_u lab_low_bmi_u
tab low_bmi_u, miss


sort hh_id ind_id
duplicates report hh_id ind_id
	//No duplicates at this stage


	/*Merge nutrition information from individuals under 20 years.
	7,864 individuals merged, this matches the number of individuals under 20 
	years in the data */
merge 1:1 hh_id ind_id using "$path_out/MEX16_children.dta"

drop _merge

rename weight weight_kg
rename height height_cm
rename sex sex_nutri

	//Erase files from folder:	
erase "$path_out/MEX16_children.dta"
erase "$path_out/nutri_temp.dta"


	//Save a temp file for merging later:
save "$path_out/MEX16_NUTRI.dta", replace


********************************************************************************
*** Step 1.2  HOUSEHOLD RECODE
********************************************************************************

use "$path_in/hogar_socioeconomicoprocesada.dta", clear

clonevar hh_id = folio 
lab var  hh_id "Household ID"

ren int ind_id
label var  ind_id "Individual ID"

sort hh_id ind_id
duplicates report hh_id ind_id
	//No duplicates at this stage

save "$path_out/MEX16_HR.dta", replace  


********************************************************************************
*** Step 1.3 HOUSEHOLD MEMBER'S RECODE
********************************************************************************

use "$path_in/hogar_integrantes_procesada.dta", clear


clonevar hh_id = folio 
lab var  hh_id "Household ID"

ren int ind_id 
label var  ind_id "Individual ID"


sort hh_id ind_id
duplicates report hh_id ind_id
	//No duplicates at this stage


********************************************************************************
*** 1.4 DATA MERGING
********************************************************************************


*** Merging household recode 
***************************************************

merge m:1 hh_id using "$path_out/MEX16_HR.dta" 
	//29,795 observations matched (100%)
drop _merge
erase "$path_out/MEX16_HR.dta"

*** Merging nutrition data
***************************************************

merge 1:1 hh_id ind_id using "$path_out/MEX16_NUTRI.dta" 
	//16, 326 observations matched except for 2 observations which is dropped
drop if _merge==2	
drop _merge
erase "$path_out/MEX16_NUTRI.dta"




********************************************************************************
*** 1.5 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
desc ponde_f ponde_h ponde_i
	/*ponde_f=final weight; 
	  ponde_i=individual sample weight; 
	  ponde_h=household sample weight */
clonevar weight = ponde_h 
label var weight "Sample weight"


//Area: urban or rural	
	/*Note: There are two variables in the ENSANUT dataset that could be used to
	construct the rural-urban variable: 'area' variable and 'rural' variable. 
	Following the advice from users of ENSANUT, we have used the rural variable 
	to construct the rural-urban information for the global MPI */
rename area area_ori	
codebook rural, tab (5)
gen area = 1 if rural==2
replace area = 0 if rural==1
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"
tab area rural, miss


//Sex of household member	
codebook sexo
clonevar sex = sexo
label var sex "Sex of household member"


//Age of household member
codebook edad, tab (999)
clonevar age = edad  
replace age = . if age>=900
label var age "Age of household member"


//Age group 
recode age (0/4 = 1 "0-4")(5/9 = 2 "5-9")(10/14 = 3 "10-14") ///
		   (15/17 = 4 "15-17")(18/59 = 5 "18-59")(60/max=6 "60+"), gen(agec7)
lab var agec7 "age groups (7 groups)"	
	   
recode age (0/9 = 1 "0-9") (10/17 = 2 "10-17")(18/59 = 3 "18-59") ///
		   (60/max=4 "60+"), gen(agec4)
lab var agec4 "age groups (4 groups)"



//Marital status of household member
lookfor h219
codebook h219 
gen marital = 1 if h219 == 1 | h219 == 6
replace marital = 2 if h219 == 5
replace marital = 3 if h219 == 4
replace marital = 4 if h219 == 3
replace marital = 5 if h219 == 2
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab h219 marital, miss


//Total number of de jure hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
drop member


//Subnational region
	/*NOTE: The sample for the Mexico ENSANUT 2016 was designed to provide 
	estimates for north, south, centre and df (p.15, country report). */
tab region, miss	
lab var region "Region for subnational decomposition"
label define lab_reg ///
1  "Norte" ///
2  "Centro" ///
3  "Mexico City" ///
4  "Sur"
label values region lab_reg

********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

/*Mexico ENSANUT 2016 does not provide the number of years of education so we 
need to construct that variable from the edulevel and eduhighyear variables.

Official entrance age to primary education in Mexico is 6 years old. 
Duration in primary: 6 years
Duration in lower secondary: 3 years
Duration in upper secondary: 3 years 

Source: "http://data.uis.unesco.org/?ReportId=163"*/ 
	
	
codebook h218a, tab(20) 
	//h218a = Highest educational level completed
codebook h218b, tab(20) 
	//h218b = Highest year of education completed at highest edulevel

tab h218a h218b, miss


** Creating educational level variable
gen	       edulevel = . 
replace    edulevel = 0 if h218a==0 | h218a==1
replace    edulevel = 1 if h218a==2
replace    edulevel = 2 if h218a==3
replace    edulevel = 3 if h218a==4
replace    edulevel = 3 if h218a==5
replace    edulevel = 2 if h218a==6
replace    edulevel = 3 if h218a==7
replace    edulevel = 4 if h218a==8
replace    edulevel = 4 if h218a==9
replace    edulevel = 4 if h218a==10
replace    edulevel = 4 if h218a==11
replace    edulevel = 4 if h218a==12
replace    edulevel = . if h218a==. 
label define lab_edulevel 0 "No education/Preeschool" 1 "Primary" ///
						  2 "Secondary" 3 "Higher" 4 "University"
lab values edulevel lab_edulevel
lab var edulevel "Highest educational level"
tab edulevel h218a, miss


gen	eduhighyear = h218b 
lab var eduhighyear "Highest year of education completed"
tab	eduhighyear h218b, missing


	/*ENSANUT does not provide the number of years of education so we need to 
construct that variable from the edulevel and eduhighyear variables */
tab h218a h218b, miss
tab edulevel eduhighyear, miss


*** Cleaning inconsistencies 
replace eduhighyear = 0 if age<10 
	/*The variable "eduhighyear" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 10 years or older */ 
replace eduhighyear = 0 if edulevel<1 


*** Creating the years of education variable **
	//We give missing values if edulevel is missing and zero if no edulevel attained 
gen	eduyears = . 
replace eduyears = 0 if edulevel==0 
replace eduyears = . if edulevel==. 
replace eduyears = 0 if age<=4 


	//Primary equal to the eduhighyear var 
replace eduyears = eduhighyear if edulevel==1

	/*Lower secondary - in Mexico completion of primary education is 6 years, 
	so + 6 for lower secondary level */
replace eduyears = eduhighyear + 6 if edulevel==2

	/*Upper secondary - we add 9 years (6 primary + 3 lower secondary) to the 
	year reported in upper secondary */
replace eduyears = eduhighyear + 9 if edulevel==3 

	/*University - we add 12 years (6 primary + 3 lower secondary + 3 upper 
	secondary) to the year reported in university */
replace eduyears = eduhighyear + 12 if edulevel==4 
replace eduyears = . if eduyears>30
replace eduyears = . if edulevel==. 
lab var eduyears "Total number of years of education accomplished"


*** Checking for further inconsistencies 
replace eduyears = . if age<=eduyears & age>0 
	/*There are cases in which the years of schooling are greater than the 
	age of the individual. This is clearly a mistake in the data. Please check 
	whether this is the case and correct when necessary */
replace eduyears = 0 if age< 10 
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

codebook h217, tab (10)
	//Do you currently attend school?
tab age h217, miss

gen	attendance = .
replace attendance = 0 if h217==2 
	//not currently attending
replace attendance = 1 if h217==1 
	//currently attending
replace attendance = 0 if age<5 | age>24 
	//Replace attendance with '0' for individuals who are not of school age 
label define lab_attendance 1 "currently attending" 0 "not currently attending"
label values attendance lab_attendance
lab var attendance "Currently attending school"
tab attendance, miss 

	
*** Standard MPI ***
******************************************************************* 
/*The entire household is considered deprived if any school-aged child is not 
attending school up to class 8. */

gen	child_schoolage = (age>=6 & age<=14)
	/*
	Note: In Mexico, the official school entrance age is 6 years  
	So, age range is 6-14 (=6+8). 
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
	/*Note: Mexico ENSANUT 2016: Anthropometric information were recorded for 
	individuals 0-99 years. This departs from the usual DHS surveys that tend to 
	collect anthropometric data only from adults between the age group of 15-49 
	or 15-59 years. For the purpose of the global MPI, we have used nutrition 
	data when the data is available for all individuals but up to the age of 70 
	years. Hence, in the case of Mexico, we make use of the anthropometric data 
	for children under 5 years, young individuals older than 5 years and under 
	20 years, and finally adult women and men aged 20-70 years. */ 
	
count if age_month!=.
	//16,326 individuals aged 0-99 years

count if age_month<=840
	//15,481 individuals aged 0-70 years

		
***As a first step, construct the eligibility criteria	
*** No Eligible Women, Men or Children for Nutrition
******************************************************	
gen nutri_eligible = age_month<=840
bysort	hh_id: egen n_nutri_eligible = sum(nutri_eligible) 	
gen	no_nutri_eligible = (n_nutri_eligible==0) 	
lab var no_nutri_eligible "Household has no eligible women, men, or children"
tab no_nutri_eligible, miss	

drop nutri_eligible n_nutri_eligible	
	

********************************************************************************
*** Step 2.3a Adult Nutrition ***
********************************************************************************


*** Standard MPI: BMI Indicator for Adults 20-70 years ***
******************************************************************* 
tab low_bmi if age_month>=240 & age_month<=840, miss
	//7,617 adults 20-70 years with BMI indicator (40 missing cases). 

gen low_bmi_20 = low_bmi if age_month>=240 & age_month<=840
	/*In the context of Mexico, we focus on BMI measure for individuals aged 
	20-70 years because BMI-for-age is applied for individuals above 5 
	years and under 20 years */
bysort hh_id: egen temp = max(low_bmi_20)
tab temp, miss 

gen hh_no_low_bmi = (temp==0) 
	/*Under this section, households take a value of '1' if no adults in the 
	household has low bmi */

replace hh_no_low_bmi = . if temp==.
	/*Under this section, households take a value of '.' if there is no 
	information from adults*/
drop temp

lab var hh_no_low_bmi "Household has no adult with low BMI"

tab hh_no_low_bmi, miss
	//Figures are based on information from adults aged 20-70 years.

	
********************************************************************************
*** Step 2.3b Nutrition for Individuals 6-19 ***
********************************************************************************


*** Standard MPI: BMI-for-age for those above 5 years and under 20 years ***
******************************************************************* 	

count if age_month>59 & age_month<240
count if age_month>59 & age_month<240 & teen_IR==1
	//5,837 individuals who are above 5 years and under 20 years
	
tab low_bmiage if age_month>59 & age_month<240, miss	
tab low_bmiage if teen_IR==1, miss	

bysort hh_id: egen temp = max(low_bmiage)  
tab temp, miss
gen	hh_no_low_bmiage = (temp==0) 
	/*Takes value 1 if no individuals above 5 years and under 20 years in the 
	household has low bmi-for-age*/
replace hh_no_low_bmiage = . if temp==.
drop temp

lab var hh_no_low_bmiage "Household has no adult with low BMI-for-age"
tab hh_no_low_bmiage, miss
	/*Figures are based on information from individuals above 5 years and under 
	20 years. */

	
********************************************************************************
*** Step 2.3c Child Nutrition ***
********************************************************************************


***As a first step, construct the eligibility criteria for children
*** No Eligible Children for Nutrition
***********************************************	
gen child_eligible = age_month<=59
bysort	hh_id: egen n_child_eligible = sum(child_eligible) 	
gen	no_child_eligible = (n_child_eligible==0) 	
lab var no_child_eligible "Household has no eligible children <59"
tab no_child_eligible, miss	

drop child_eligible n_child_eligible	
	
	
*** Standard MPI: Child Underweight Indicator ***
************************************************************************

tab underweight if child_KR==1, miss	

bysort hh_id: egen temp = max(underweight)
tab temp, miss
gen	hh_no_underweight = (temp==0) 
	//Takes a value of '1' if no child in the household is underweight 
replace hh_no_underweight = . if temp==.
replace hh_no_underweight = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
drop temp
lab var hh_no_underweight "Household has no child underweight - 2 stdev"
tab hh_no_underweight, miss


*** Standard MPI: Child Stunting Indicator ***
************************************************************************

tab stunting if child_KR==1, miss

bysort hh_id: egen temp = max(stunting)
tab temp, miss
gen	hh_no_stunting = (temp==0) 
	//Takes a value of '1' if no child in the household is stunted
replace hh_no_stunting = . if temp==.
replace hh_no_stunting = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
drop temp
lab var hh_no_stunting "Household has no child stunted - 2 stdev"
tab hh_no_stunting, miss


*** Standard MPI: Child Either Stunted or Underweight Indicator ***
************************************************************************

gen uw_st = 1 if stunting==1 | underweight==1
replace uw_st = 0 if stunting==0 & underweight==0
replace uw_st = . if stunting==. & underweight==.

tab uw_st if child_KR==1, miss


bysort hh_id: egen temp = max(uw_st)
tab temp, miss
gen	hh_no_uw_st = (temp==0) 
	/*Takes a value of '1' if no child in the household is underweight or 
	stunted */
replace hh_no_uw_st = . if temp==.
replace hh_no_uw_st = 1 if no_child_eligible==1
	//Households with no eligible children will receive a value of 1
drop temp
lab var hh_no_uw_st "Household has no child underweight or stunted"
tab hh_no_uw_st, miss



********************************************************************************
*** Step 2.3d Household Nutrition Indicator ***
********************************************************************************


*** Standard MPI ***

/* The indicator takes value 1 if there is no low BMI-for-age among teenagers, 
no low BMI among adults or no children under 5 stunted or underweight. The 
indicator takes value missing "." only if all eligible adults and eligible 
children have missing information in their respective nutrition variable. */
************************************************************************

gen	hh_nutrition_uw_st = 1
replace hh_nutrition_uw_st = 0 if hh_no_low_bmi==0 | hh_no_low_bmiage==0 | hh_no_uw_st==0
replace hh_nutrition_uw_st = . if hh_no_low_bmi==. & hh_no_low_bmiage==. & hh_no_uw_st==.	
replace hh_nutrition_uw_st = 1 if no_nutri_eligible==1
 	/*We replace households that do not have the applicable population, that is, 
	women and men up to 70 years and children under 5, as non-deprived in 
	nutrition*/	
lab var hh_nutrition_uw_st "Household has no child underweight/stunted or adult deprived by BMI/BMI-for-age"
lab value hh_nutrition_uw_st lab_nutri 


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************
    /*NOTE: Mexico ENSANUT 2016 has no data on child mortality. As such the
    indicators under this section is assigned with missing value */


gen child_mortality = .
lab var child_mortality "Total child mortality within household"

	
gen hh_mortality_u18_5y = .
lab var hh_mortality_u18_5y "Household had no under 18 child mortality in the last 5 years"

	

********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************
/*Members of the household are considered deprived if the household has no 
electricity */


*** Standard MPI ***
****************************************

lookfor h507 
	//h507 = is there electricity in this household? 
clonevar  electricity = h507
codebook electricity, tab (10) 
	//1 = yes, 2 = no 
recode electricity (2=0)
lab define lab_yes_no 0 "no" 1 "yes"
lab values electricity lab_yes_no
label var electricity "Electricity"


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



	/*Note: In Mexico ENSANUT 2016, toilet is recoded based on three variables: 
	if there is toilet, latrine or similar (h510), if it flushes (h512) and to 
	where it flushes (h513). We assume it is latrine when it does not flush or 
	has no drainage, otherwise it is assumed as toilet */
	
codebook h510 h512 h513 
	/*
	"h510" = does the hh has toilet, latrine or black hole? 
	"h512" = does the toilet: 
	  1 = direct flush with water, 
	  2 = doesn't flush (water is thrown inside), 
	  3 = doesn't flush(water can't be thrown inside)
	  0 = those who don't have toilet; 
	"h513" = the household has sewer system or drain connected to: 
	  1 = public pipe, 
	  2 = septic tank, 
	  3 = pipe going to a canyon or rift, 
	  4 = pipe that goes to river/lake/sea, 
	  5 = doesn't have drainage 
	  */

gen toilet= . 
replace    toilet = 11 if h510==1 & h513==1
replace    toilet = 12 if h510==1 & h513==2
replace    toilet = 14 if h510==1 & (h513==3 | h513==4)
replace    toilet = 23 if h510==1 & (h512==3 | h513==5)
replace    toilet = 61 if h510==2 
label define toilet 11 "flush toilet to piped sewer"  ///
					12 "flush to septic tank"  ///
					14 "flush to somewhere else"  ///
					23 "pit latrine without slab/open pit" ///
					61 "no facility/bush/field"
lab values toilet toilet
tab toilet, miss 
tab toilet h512, miss
tab toilet h513, miss
lab var toilet "Type of toilet"


lookfor h511 
	//"h511" = is this toilet shared with another household? 
codebook h511 
gen shared_toilet = h511
recode shared_toilet (0=.) (2=0) 
lab define shared_toilet 0 "No" 1 "Yes"
lab values shared_toilet shared_toilet
tab shared_toilet, miss
lab var shared_toilet "Household has access to shared toilet"



*** Standard MPI ***
****************************************
	/*Note: In Mexico, there is no particular information in the country report 
	on the type of improved or non-improved toilet. As such we follow the SDG 
	guideline. */
codebook toilet, tab(20)
codebook shared_toilet

gen	toilet_mdg = (toilet<23 & shared_toilet!=1) 
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */
	
replace toilet_mdg = 0 if toilet<23  & shared_toilet==1 
	/*Household is assigned a value of '0' if it uses improved sanitation 
	but shares toilet with other households  */	
	
replace toilet_mdg = 0 if toilet == 14
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

	/*NOTE: Mexico ENSANUT 2016 does not have information on the the time it 
	takes to collect drinking water, if it is outside of the household premise. */
codebook h508, tab (99)
	/*h508 = type of water availability
	1=piped into dwelling, 
	2=piped out of the dwelling but inside the ground (to yard/plot), 
	3=public tap/standpipe, 
	4=piped water from another dwelling, 
	5= tanker truck, 
	6=surface water (river/dam/lake/pond/stream/canal/irrigation channel, etc)*/
	
gen water=.
replace water = 11 if h508==1
replace water = 12 if h508==2
replace water = 13 if h508==3
replace water = 96 if h508==4
replace water = 61 if h508==5
replace water = 81 if h508==6
label define water 11 "piped into dwelling" ///
				   12 "piped to yard/plot" ///
				   13 "public tap/standpipe" ///
				   61 "tanker truck" ///
				   81 "surface water (river/dam/lake/pond/stream)" /// 
				   96 "other"
lab values water water
lab var water "Type of water"

gen timetowater=.
gen ndwater = .
	//Non-drinking water: no observations


*** Standard MPI ***
****************************************
codebook water, tab(99)

gen	water_mdg = 1 if water==11 | water==12 | water==13 
	/*Non deprived if water is "piped into dwelling", "piped to yard/plot", 
	  "public tap/standpipe", "tube well or borehole", "protected well", 
	  "protected spring", "rainwater", 71"bottled water" */
	
replace water_mdg = 0 if water==61 | water==81 | water==96 
	/*Deprived if it is "unprotected well", "unprotected spring", "tanker truck"
	  "surface water (river/lake, etc)", "cart with small tank","other" */

replace water_mdg = . if water==. | water==99
lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water water_mdg, miss



********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
 
codebook h503, tab(10) 
	//h503 = which is the main material of the floor of this dwelling?
gen floor = . 
replace  floor = 11 if h503 == 1
replace  floor = 34 if h503 == 2
replace  floor = 33 if h503 == 3
replace  floor = .  if h503 == 9
label define floor 11 "earth/sand" ///
				   33 "ceramic tiles/mosaic/marble/granite" /// 
				   34 "cement" 
label values floor floor
lab var floor "Material of floor"

codebook floor, tab(10)
gen	floor_imp = 1
replace floor_imp = 0 if floor==11 | floor==96  
replace floor_imp = . if floor== . | floor==99 
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss


/* Members of the household are considered deprived if the household has walls 
made of natural or rudimentary materials */

codebook h501, tab(10) 
	//h501 = which is the main material of the walls os this dwelling?
gen wall = . 
replace wall = 26 if h501 == 1
replace wall = 23 if h501 == 2 | h501==3
replace wall = 21 if h501 == 4 
replace wall = 13 if h501 == 5 | h501==7
replace wall = 30 if h501 == 6
replace wall = 31 if h501 == 8
label define wall 13 "mud" ///
				  21 "palm/bamboo" ///
				  23 "sheets" ///
				  26 "waste material" ///
				  30 "wood" ///
				  31 "cement" 
label values wall wall
lab var wall "Material of walls"
codebook wall, tab(10)
gen	wall_imp = 1 
replace wall_imp = 0 if wall<=26  
replace wall_imp = . if wall==. | wall==99 
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	


/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */

codebook h502, tab(10)
	//h502 = which is the main material of the roof in this dwelling?
gen roof = . 
replace roof = 96 if h502 == 1 
replace roof = 24 if h502 == 2 
replace roof = 33 if h502 == 3
replace roof = 34 if h502 == 4 | h502 == 7 
replace roof = 12 if h502 == 5
replace roof = 23 if h502 == 6 
replace roof = 31 if h502 == 8 | h502 == 9 
label define roof 12 "thatch/palm leaf" ///  
				  23 "wood" ///
				  24 "cardboard" /// 
				  31 "tiles (mud, ceramic, concrete)" ///
				  33 "metalic sheets" ///
				  34 "asbesto sheets" /// 
				  96 "other (waste material)"
label values roof roof
lab var roof "Material of roof"
codebook roof, tab(10)
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=24 | roof==96  
replace roof_imp = . if roof==. 
lab var roof_imp "Household has roof that it is not of low quality materials"
tab roof roof_imp, miss


/*
Note: The roof material 'Terrado con viguería' is considered by the CONEVAL 
as 'improved material'. 
Source: http://blogconeval.gob.mx/wordpress/index.php/2013/07/23/carencia_por_calidad_y_espacios_en_la_vivienda/
*/


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
	
codebook h514, tab(10) 
	//combustible = type of fuel used for cooking in the household
gen cookingfuel  = .
replace  cookingfuel = 2  if h514==1 
replace  cookingfuel = 3  if h514==2 
replace  cookingfuel = 8  if h514==3 
replace  cookingfuel = 7  if h514==4 
replace  cookingfuel = 1  if h514==5 
replace  cookingfuel = 96 if h514==6 
label define cookingfuel 1 "electricity" ///
						 2 "lpg" ///
						 3 "natural gas" ///
						 7 "charcoal" ///
						 8 "wood" ///
						 96 "other"
label values cookingfuel cookingfuel 
lab var cookingfuel "Type of cookingfuel"
	
codebook cookingfuel, tab(10)


*** Standard MPI ***
****************************************

gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>=7 & cookingfuel<=8 
replace cooking_mdg = . if cookingfuel==. |cookingfuel==99
lab var cooking_mdg "Househod has cooking fuel according to MDG standards"
/*
Deprived if: 6 "coal/lignite", 7 "charcoal", 8 "wood", 9 "straw/shrubs/grass" 
	         10 "agricultural crop", 11 "animal dung"
*/			 
tab cookingfuel cooking_mdg, miss	



********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************
/*Assets that are included in the global MPI: Radio, TV, telephone, bicycle, 
motorbike, refrigerator, car, computer and animal cart */


	//Television (includes analogic TV and digital TV)
tab h60106, miss
gen	television = h60106
replace television = 0 if h60106==2
replace television = . if h60106==9
replace television = 1 if h60107==1
label var television "The household has at least one TV (analogic or digital)"
gen bw_television   = .


	//Radio 
tab h60108, miss
gen	radio = h60108
replace radio = 0 if h60108==2
replace radio = . if h60108==9
replace radio = 1 if h60109==1
label var radio "The household has at least one radio (normal or radio recorder)"


	//Telephone 
tab h60120, miss
gen	telephone = h60120
replace telephone = 0 if h60120==2
replace telephone = . if h60120==9
label var telephone "The household has a telephone"


	//Mobilephone 
tab h60124, miss
gen	mobiletelephone = h60124
replace mobiletelephone = 0 if h60124==2
replace mobiletelephone = . if h60124==9
label var mobiletelephone "The household has a mobilephone"


	//Refrigerator
tab h60112, miss
gen	refrigerator = h60112
replace refrigerator = 0 if h60112==2
replace refrigerator = . if h60112==9
label var refrigerator "The household has at least one refrigerator"


	//Car (includes car and van)
tab h60102, miss
tab h60103, miss
	//h60103 = do you or any other person in this household have a van? 
gen	car = h60102
replace car = 0 if h60102==2
replace car = . if h60102==9
replace car = 1 if h60103==1 
	//replace car = 1 if the household has a van 
label var car "The household has at least one car (or van)"


	//Bicycle: no data
gen	bicycle = .
label var bicycle "The household has at least one bicycle"


	//Motorbike
tab h60104, miss
gen	motorbike = h60104
replace motorbike = 0 if h60104==2
replace motorbike = . if h60104==9
label var motorbike "The household has at least one motorbike"


	//Computer
tab h60117, miss
gen	computer = h60117
replace computer = 0 if h60117==2
replace computer = . if h60117==9
label var computer "The household has at least one computer"



	//Animal cart: no data
gen	animal_cart = .



label define assets 1 "Yes" 0 "No"
label values television       assets
label values radio	          assets
label values telephone        assets
label values mobiletelephone  assets
label values refrigerator     assets
label values car	          assets
label values bicycle	      assets
label values motorbike	      assets
label values computer	      assets
label values animal_cart      assets



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
	

	//Retain data on sampling design: 
lookfor estrato upm	 
desc est_var code_upm	
clonevar strata = est_var
clonevar psu = code_upm

	//Retain year, month & date of interview:
lookfor tiempo_gen  
desc tiempo_gen
gen year_interview = .
gen month_interview = . 
gen date_interview = .


	//Generate presence of subsample
gen subsample = .		


	//Destring hh_id ind_id psu
desc hh_id ind_id psu strata
encode hh_id, gen (hh_id2)
encode psu, gen (psu2)
drop hh_id psu
rename hh_id2 hh_id
rename psu2 psu



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
char _dta[cty] "Mexico"
char _dta[ccty] "MEX"
char _dta[year] "2016" 	
char _dta[survey] "ENSANUT"
char _dta[ccnum] "484"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(filedate)'."	
save "$path_out/mex_ensanut16.dta", replace 
