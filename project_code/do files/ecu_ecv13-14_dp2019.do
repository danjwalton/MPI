********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Ecuador ECV 2013-14 [STATA do-file]. 
Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off
set maxvar 10000
set mem 500m

*** Working Folder Path ***
global path_in "T:/GMPI 2.0/rdta/Ecuador ECV 2013-14" 
global path_out "G:/GMPI 2.0/cdta"
global path_ado "T:/GMPI 2.0/ado"


********************************************************************************
*** Ecuador ECV 2013-14 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
*** Selecting variables from KR, BR, IR, & MR recode & merging with PR recode 
********************************************************************************
	
	/*Ecuador ECV 2013-14: Anthropometric information were recorded for 
	all individuals aged 0-98 years. For the purpose of the global MPI, we have 
	used nutrition data when the data is available for all individuals but up 
	to the age of 70 years. */


********************************************************************************
*** Step 1.1 Underweight, Stunting & Wasting for Children Under 5 
********************************************************************************

use "$path_in/ecv6r_personas.dta", clear 


*** Generate individual unique key variable required for data merging
tostring persona, replace
forvalues i=1(1)9 {
replace persona="0`i'" if persona=="`i'"
}
gen ind_id = identif_hog+persona  
label var  ind_id "Individual ID"


duplicates report ind_id
	//No duplicates

	
*** Keep only childen under 5 years	
gen age_months = pd03b if edad==0
replace age_months = pd03b+12 if edad==1
replace age_months = pd03b+24 if edad==2
replace age_months = pd03b+36 if edad==3
replace age_months = pd03b+48 if edad==4
tab age_months, miss


count if age_months < 60
	//Count children under 5 years: 11,473 children
keep if age_months < 60
	//Keep only children under 5 years

gen child = 1 
	//Generate identification variable for individuals under 5


	
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
gen str30 datalab = "children_nutri_ecu" 
lab var datalab "Working file"


*** Next check the variables that WHO ado needs to calculate the z-scores:
*** sex, age, weight, height, measurement, oedema & child sampling weight


*** Variable: SEX ***
tab sexo, miss 
gen gender = sexo
desc gender
tab gender


*** Variable: AGE ***
sum age_months
gen str6 ageunit = "months" 
label var ageunit "Months"	


*** Variable: BODY WEIGHT (KILOGRAMS) ***
gen weight = (ps82 + ps82a)/2 if ps82b==. 
replace weight = (ps82 + ps82a + ps82b)/3 if ps82b<.
desc weight 
summ weight


*** Variable: HEIGHT (CENTIMETERS) ***
gen height = (ps83 + ps83a)/2 if ps83b==. & edad<2 
replace height = (ps83 + ps83a + ps83b)/3 if ps83b<. & edad<2
replace height = (ps84 + ps84a)/2 if ps84b==. & edad>=2
replace height = (ps84 + ps84a + ps84b)/3 if ps84b<. & edad>=2
ta height, miss
codebook height
desc height 
replace height=. if ps84<0
summ height


*** Variable: MEASURED STANDING/LYING DOWN ***
gen measure = "l" if ps83<. 
replace measure = "h" if ps84<. 
desc measure
tab measure


*** Variable: OEDEMA ***
gen oedema=" "


*** Variable: INDIVIDUAL CHILD SAMPLING WEIGHT ***
gen sw = fexp
desc sw
summ sw



/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age_months ageunit ///
weight height measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores */
use "$path_out/children_nutri_ecu_z_rc.dta", clear 


gen z_scorewa = _zwei
replace z_scorewa = . if _fwei==1 
lab var z_scorewa "z-score weight-for-age WHO"


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
	/* Note: in the context of Ecuador ECV 2013-14, 44 children were replaced 
	as '.' because they have extreme z-scores that are biologically implausible.*/


	//Retain relevant variables:
keep ind_id child age_months under* stunting* wasting* 
order ind_id child age_months under* stunting* wasting* 

sort ind_id

duplicates report ind_id

	//Erase files from folder:
erase "$path_out/children_nutri_ecu_z_rc.xls"
erase "$path_out/children_nutri_ecu_prev_rc.xls"
erase "$path_out/children_nutri_ecu_z_rc.dta"	


	//Save a temp file for merging later:
save "$path_out/ECU13-14_child.dta", replace
	
	
********************************************************************************
*** Step 1.2  BMI-for-age for youth above 5 years & under 20 years 
********************************************************************************

use "$path_in/ecv6r_personas.dta", clear


*** Generate individual unique id variable required for data merging:
tostring persona, replace
forvalues i=1(1)9 {
replace persona="0`i'" if persona=="`i'"
}
gen ind_id = identif_hog+persona  
label var  ind_id "Individual ID"


duplicates report ind_id	
	//No duplicates	

	
*** Generate age in months for all individuals:	
/*We generate the variable on age in months for individuals under 5 and above 5 
separately. This is because, different variables are used to construct these age 
groups. In addition, the variables used to construct age in months for children 
under 5 is accurate and we would like to maintain that information, while 
merging it with age in months from all individuals above 5 years.*/

	//First for children under 5
gen age_months = pd03b if edad==0
replace age_months = pd03b+12 if edad==1
replace age_months = pd03b+24 if edad==2
replace age_months = pd03b+36 if edad==3
replace age_months = pd03b+48 if edad==4
tab age_months, miss
	

	//Second for all individuals above 5	
foreach var in ps80b ps80c {
replace `var'=. if `var'<0
}
gen am     = (ps81c-ps80c)*12
replace am = am+(ps81b-ps80b) if ps81b>=ps80b
replace am = (am-12)+(ps81b-1)+(13-ps80b) if ps81b<ps80b 
replace am = edad*12 if ps79==1 & ps80b==. 
	//We do not know the month of the birth but we impute the age in months 


	//Merge information from individuals under 5 and above 5	
count if age_months ==. & am!=.	
replace age_months = am if age_months==.
label var age_months "Age in months for all members"
tab age_months, miss	
	
	
count if age_months > 59 & age_months < 240
keep  if age_months > 59 & age_months < 240 
	/*Relevant sample: individuals above 5 years and under 20 years 	
	  34,766 individuals above 5 years and under 20 years */

	
***Variables required to calculate the z-scores to produce BMI-for-age:


*** Variable: SEX ***
tab sexo, miss 
clonevar sex = sexo


*** Variable: AGE IN MONTHS ***	
sum age_months
gen str6 ageunit="months"				
lab var ageunit "months"


*** Variable: BODY WEIGHT (KILOGRAMS) ***
gen weight      = (ps82+ps82a+ps82b)/3 if ps82b<.
replace weight  = (ps82+ps82a)/2 if ps82b==.
sum weight 

*** Variable: HEIGHT (CENTIMETERS)
gen height      = (ps84+ps84a+ps84b)/3 if ps84b<. 
replace height  = (ps84+ps84a)/2 if ps84b==.
replace height  = . if ps84<0 | ps84a<0 | ps84b<0
sum height


*** Variable: OEDEMA
gen oedema = "n"  
tab oedema


*** Variable: SAMPLING WEIGHT ***
gen sw = fexp
desc sw
summ sw


sort ind_id


*** BMI-for-age for adolescents 15-19 years***	
*** Next, indicate to STATA where the igrowup_restricted.ado file is stored:
	***Source of ado file: https://www.who.int/growthref/tools/en/		
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
gen str30 datalab = "youth_nutri_ecu" 
lab var datalab "Working file"



/*We now run the command to calculate the z-scores with the adofile */
who2007 reflib datalib datalab sex age_month ageunit weight height oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to compute BMI-for-age*/
use "$path_out/youth_nutri_ecu_z.dta", clear 

		
gen	z_bmi = _zbfa
replace z_bmi = . if _fbfa==1 
lab var z_bmi "z-score bmi-for-age WHO"


*** Standard MPI indicator ***
gen	low_bmiage = (z_bmi < -2.0) 
	/*Takes value 1 if BMI-for-age is under 2 stdev below the median & 0 
	otherwise */
replace low_bmiage = . if z_bmi==.
lab var low_bmiage "Teenage low bmi 2sd - WHO"

	
gen youth = 1 
	//Identification variable for individuals 5-19 years	


	//Retain relevant variables:	
keep ind_id age_months youth low_bmiage*
order ind_id age_months youth low_bmiage*
 
sort ind_id



	/*Append the nutrition information of children above 5 years with 
	children under 5 */	
append using "$path_out/ECU13-14_child.dta"


	//Check appended information
tab age_months, miss
tab stunting if age_months < 60, miss 
tab low_bmiage if age_months > 59 & age_months < 240, miss 

	
	//Save a temp file for merging later:
save "$path_out/ECU13-14_children.dta", replace


	//Erase files from folder:
erase "$path_out/youth_nutri_ecu_z.xls"
erase "$path_out/youth_nutri_ecu_prev.xls"
erase "$path_out/youth_nutri_ecu_z.dta"
erase "$path_out/ECU13-14_child.dta"



********************************************************************************
*** Step 1.3 BMI for all individuals 
********************************************************************************


use "$path_in/ecv6r_personas.dta", clear


*** Generate individual unique id variable required for data merging:
tostring persona, replace
forvalues i=1(1)9 {
replace persona="0`i'" if persona=="`i'"
}
gen ind_id = identif_hog+persona  
label var  ind_id "Individual ID"


duplicates report ind_id	
	//No duplicates	



*** Variable: HEIGHT (CENTIMETERS) ***
gen rtalla = (ps84+ps84a+ps84b)/3 if ps84b<. 
replace rtalla = (ps84+ps84a)/2 if ps84b==. 
replace rtalla = . if ps84<0 | ps84a<0 | ps84b<0


*** Variable: BODY WEIGHT (KILOGRAMS) ***
gen rpeso = (ps82+ps82a+ps82b)/3 if ps82b<. 
replace rpeso = (ps82+ps82a)/2 if ps82b==. 
  
  
*** Variable: BMI MEASURE *** 
gen bmi = rpeso/((rtalla/100)^2)
tab edad if bmi!=., miss
lab var bmi "BMI"


gen low_bmi = (bmi<18.5)
replace low_bmi=. if bmi==.
lab var low_bmi "BMI <18.5"
lab define lab_low_bmi 1 "bmi<18.5" 0 "bmi>=18.5"
lab values low_bmi lab_low_bmi
tab low_bmi, miss


	//Retain relevant variables:	
keep ind_id bmi low_bmi*
order ind_id bmi low_bmi*
 
sort ind_id


	//Merge nutrition information from individuals under 20 years
merge 1:1 ind_id using "$path_out/ECU13-14_children.dta"

drop _merge

	
	/*Save a temp file that contains nutrition information for all age group 
	for merging later */	
save "$path_out/ECU13-14_nutri.dta", replace


********************************************************************************
*** Step 1.4  HOUSEHOLD LEVEL INFORMATION
********************************************************************************

*** Household's assets database
***********************************

use "$path_in/ecv6r_equipamiento.dta", clear
keep  identif_hog eq00 eqbien  eq01
keep if eq00== 4 | eq00== 9 | eq00==10 | eq00==11 | eq00==19 | eq00==25 | ///
		eq00==26 | eq00==28 | eq00==29 | eq00==30 | eq00==33 | eq00==34 | ///
		eq00==35 

replace eqbien = "eqpsonido"     if eq00==11
replace eqbien = "telfijo"       if eq00==19
replace eqbien = "grabadora"     if eq00==25
replace eqbien = "TV_bn"         if eq00==28
replace eqbien = "TV_plas_lcd"   if eq00==29
replace eqbien = "TV_color"      if eq00==30
replace eqbien = "carro"         if eq00==33
replace eqbien = "moto"          if eq00==34
replace eqbien = "bicicleta"     if eq00==4
replace eqbien = "refrigeradora" if eq00==26
replace eqbien = "laptop"  	     if eq00==9
replace eqbien = "computer"  	 if eq00==10
replace eqbien = "terrenos"  	 if eq00==35
drop eq00
rename eq01 _
reshape wide _, i(identif_hog) j(eqbien) string
sort identif_hog


*** Dwelling database 
***********************************
merge 1:1 identif_hog using "$path_in/ecv6r_vivienda.dta"
sort identif_hog
drop _merge

save "$path_out/ECU13-14_hh1.dta", replace

 
use "$path_in/ecv6r_agro1.dta", clear
rename _all, lower
sort identif_hog

save "$path_out/ECU13-14_hh2.dta", replace


use "$path_in/ecv6r_agro_parte_e_v_f_g.dta", clear
rename _all, lower	
clonevar truck = ff0602
replace truck = 0 if ff0602==2

keep identif_hog region area_5000 regional ciudad zona sector ///
	 vivienda hogar ff01 ff0602 truck

sort identif_hog

save "$path_out/ECU13-14_hh3.dta", replace


********************************************************************************
*** Step 1.5  HOUSEHOLD MEMBER'S INFORMATION 
********************************************************************************

use "$path_in/ecv6r_personas.dta", clear


*** Generate a household unique key variable at the household level using: 
tostring persona, replace
forvalues i=1(1)9 {
replace persona="0`i'" if persona=="`i'"
}
gen ind_id = identif_hog+persona  
label var  ind_id "Individual ID"

gen hh_id = identif_hog
label var hh_id "Household ID"


sort hh_id ind_id



********************************************************************************
*** 1.6 DATA MERGING
********************************************************************************



*** Merging Nutrition Data
*************************************************
merge 1:1 ind_id using "$path_out/ECU13-14_nutri.dta"
drop _merge
erase "$path_out/ECU13-14_nutri.dta"
sort identif_hog


*** Merging Household Data  
*****************************************

merge m:1 identif_hog using "$path_out/ECU13-14_hh1.dta"
drop _merge
erase "$path_out/ECU13-14_hh1.dta"

sort identif_hog
merge m:1 identif_hog using "$path_out/ECU13-14_hh2.dta"
drop _merge
erase "$path_out/ECU13-14_hh2.dta"

sort identif_hog
merge m:1 identif_hog using "$path_out/ECU13-14_hh3.dta"
drop _merge
erase "$path_out/ECU13-14_hh3.dta"


sort ind_id


********************************************************************************
*** 1.7 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
desc fexp
clonevar weight = fexp


//Area: urban or rural	
codebook area_5000, tab (5)		
clonevar area = area_5000  
replace area=0 if area==2  
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"
tab area area_5000, miss


//Sex of household member	
codebook sexo, tab (5)
clonevar sex = sexo  


//Age of household member
codebook edad, tab (999)
clonevar age = edad  


//Age group 
recode age (0/4 = 1 "0-4")(5/9 = 2 "5-9")(10/14 = 3 "10-14") ///
		   (15/17 = 4 "15-17")(18/59 = 5 "18-59")(60/max=6 "60+"), gen(agec7)
lab var agec7 "age groups (7 groups)"	
	   
recode age (0/9 = 1 "0-9") (10/17 = 2 "10-17")(18/59 = 3 "18-59") ///
		   (60/max=4 "60+"), gen(agec4)
lab var agec4 "age groups (4 groups)"



//Marital status of household member
gen marital = 1 if pd19==6
replace marital = 2 if pd19<=2
replace marital = 3 if pd19==5
replace marital = 4 if pd19==4
replace marital = 5 if pd19==3 	
label define lab_mar 1"never married" 2"currently married" ///
					 3"widowed" 4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab pd19 marital, miss


//Total number of de jure hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
drop member


//Subnational region
	/*The sample is representative at the national, urban and rural levels, 4
natural regions, 24 provinces, 9 planning areas and 4 cities self-represented 
(Quito, Guayaquil, Cuenca and Machala) */
rename region region_natural
decode provincia, gen(temp)
replace temp =  proper(temp)
encode temp, gen(region)
codebook region, tab (99)
recode region (5=1) (6=2) (7=3) (8=4) (9=5) (10=6) (11=7) (12=8) (13=9) ///
(14=10) (15=11) (16=12) (17=13) (18=14) (19=15) (20=16) (21=17) (22=18) ///
(23=19) (24=20) (25=21) (26=22) (27=23) (28=24)
label define region_lab 1 "Azuay" 2 "Bolivar" 3 "Carchi" 4 "Cañar" ///
						5 "Chimborazo" 6 "Cotopaxi" 7 "El Oro" 8 "Esmeraldas" ///
						9 "Galápagos" 10 "Guayas" 11 "Imbabura" 12 "Loja" ///
						13 "Los Rios" 14 "Manabi" 15 "Morona Santiago" ///
						16 "Napo" 17 "Orellana" 18 "Pastaza" 19 "Pichincha" ///
						20 "Santa Elena" 21 "Santo Domingo De Los Tsachilas" ///
						22 "Sucumbios" 23 "Tungurahua" 24 "Zamora Chinchipe"
label values region region_lab 
lab var region "Region for subnational decomposition"
tab provincia region, miss 
drop temp


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

	// In Ecuador, the education system: 
	* Entrance age of primary: 6 years
	* Duration of primary: 6 years
	* Entrance age of lower secondary: 12 years
	* Durantion lower secondary: 3 years
	* Entrance age high secondary: 15 years
	* Duration high secondary: 3 years 

tab pe48 pe47, miss

clonevar edulevel = pe47
clonevar eduhighyear = pe48

gen eduyears = .
replace eduyears = 0 if edulevel<=3
replace eduyears = eduhighyear - 1 if edulevel==5
replace eduyears = eduhighyear if edulevel==6
replace eduyears = eduhighyear + 9  if edulevel==7 
	//Level following basic education
replace eduyears = eduhighyear + 6 if edulevel==8 
	//Level following primary education (probably former system)
replace eduyears = eduhighyear + 12 if edulevel==9 | edulevel==10 
	//University
replace eduyears = eduhighyear + 17 if edulevel==11 
	//Post-graduattion
replace eduyears = 0 if eduyears==-1

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

codebook pe18, tab (99)
gen attendance = (pe18<8) if pe18!=.
tab pe18 attendance, miss
 

*** Standard MPI ***
/*The entire household is considered deprived if any school-aged child is not 
attending school up to class 8. */ 
******************************************************************* 
gen child_schoolage = (age>=5 & age<=13)
	/* Note: According to the UIS Statistics, the official age to compulsory 
	education is 3 and the official entrance age to primary school is 6 
	(http:*data.uis.unesco.org/?ReportId=163). The country report presents 
	school age as 5 to 14 years old. 5 years old children enrol in Preparatoria 
	and at 6 years old they start Basica Elementary. We have followed the 
	country report. So we consider 5 the starting age (despite that preparatory 
	year not being counted for eduyears). So, age range is 5-13 (=5+8).  */ 


	
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
	/*Note: Ecuador ECV 2013-14: Anthropometric information were recorded for 
	all individuals aged 0-98 years. This departs from the usual DHS surveys 
	that tend to collect anthropometric data only from children under 5 and 
	adults between the age group of 15-49/15-59 years. In the case of Ecuador, 
	we make use of the anthropometric data for individuals aged 0 - 70 years 
	only, even if the data is available for up to the age of 98 years. This 
	is in line with the global MPI requirement. The age cut-off is captured in 
	the final indicator through the eligibility criteria. */ 

	
***As a first step, construct the eligibility criteria	
*** No Eligible Women, Men or Children for Nutrition
***********************************************	
gen nutri_eligible = age<=70
bysort	hh_id: egen n_nutri_eligible = sum(nutri_eligible) 	
gen	no_nutri_eligible = (n_nutri_eligible==0) 	
lab var no_nutri_eligible "Household has no eligible women, men, or children"
tab no_nutri_eligible, miss	

drop nutri_eligible n_nutri_eligible



********************************************************************************
*** Step 2.3a Adult Nutrition ***
********************************************************************************


*** Standard MPI: BMI Indicator for Adults 20 years and older ***
******************************************************************* 
tab low_bmi, miss

count if age>=20 & age_month==.
	//62,486 adults 20 years and older	

tab low_bmi if age>=20 & age_month==., miss	
	/*2,874 (4.60%) adults 20 years and older have missing value for the 
	low_bmi indicator. */

gen low_bmi_20 = low_bmi if age>=20 & age_month==.
	/*In the context of ECV 2013-14, we focus on BMI measure for individuals 
	aged 20 years and older because BMI-for-age is applied for individuals above 
	5 years and under 20 years */
	
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
	/*Figures are based on information from adults aged 20 years and older.*/


********************************************************************************
*** Step 2.3b Nutrition for Individuals 6-19 ***
********************************************************************************


*** Standard MPI: BMI-for-age for those above 5 years and under 20 years ***
******************************************************************* 	

count if age_month>59 & age_month<240
count if age_month>59 & age_month<240 & youth==1
	//34,766 individuals who are above 5 years and under 20 years
	
	
tab low_bmiage if youth==1, miss	

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
gen child_eligible = age_months<=59
bysort	hh_id: egen n_child_eligible = sum(child_eligible) 	
gen	no_child_eligible = (n_child_eligible==0) 	
lab var no_child_eligible "Household has no eligible children <59"
tab no_child_eligible, miss	

drop child_eligible n_child_eligible


*** Standard MPI: Child Underweight Indicator ***
************************************************************************
	
tab underweight if child==1, miss	

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
	
tab stunting if child==1, miss

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

tab uw_st if child==1, miss


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

	/*As a first step, construct the eligibility criteria for child mortality.
	In the ECV 2013-14, child_mortality, that is, the number of sons and 
	daughters who have died was collected from all women aged 12-49 years.  */
	
*** No Eligible Women 12-49 years
*****************************************
gen fem_eligible = (pf01==1)
bys hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
tab no_fem_eligible, miss
	
			
gen f_child_mortality = pf15-pf17 
replace f_child_mortality = 0 if pf05==0 | pf15==0 
tab f_child_mortality, miss

bys hh_id: egen child_mortality = max(f_child_mortality)
lab var child_mortality "Total child mortality within household reported by women"
tab child_mortality, miss

gen hh_mortality = (child_mortality==0) 
replace hh_mortality = . if child_mortality==.
replace hh_mortality = 1 if no_fem_eligible==1
lab var hh_mortality "Household had no child mortality"
tab hh_mortality, miss


*** Child Mortality: Standard MPI *** 
/*Deprived if any children died in the household in the last 5 years 
from the survey year */
************************************************************************
	/*In the case of Ecuador, there is no birth history data. There is 
	information on the date of the last birth (if after 1999) and the date of 
	the death of that child. So, assuming that any child died in the 
	last 5 years would be the last child born, it would be possible to build a 
	minimum bound for the indicator hh_child_mortality_5y. However, that is 
	a very strong assumption. Thus, we are not able to construct the indicator 
	on child mortality that occurred in the last 5 years */

		
gen hh_mortality_u18_5y = .	
lab var hh_mortality_u18_5y "Household had no under 18 child mortality in the last 5 years"



********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************

*** Standard MPI ***
/*Members of the household are considered deprived if the household has no 
electricity */
****************************************
gen electricity = 1 if vi26==1 | vi26==2 | vi26==3
replace electricity = 0 if vi26==4 | vi26==5
label var electricity "Electricity"
tab vi26 electricity, miss


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


clonevar toilet = vi14
gen shared_toilet = 0 if vi15b>0 & vi15b<.
replace shared_toilet = 1 if vi15b==0


*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************

	/*Note: The ECV 2013-14 recorded 5 categories of toilet facility in the 
	data. The country report (p.24, footnote 24) specifies that toilets with 
	sewer, septic tank and other flush systems as improved.  This suggest that 
	all other categories are non-improved, including the category identified as 
	latrine.*/

gen toilet_mdg = 1 if vi14<4
	//Household is assigned a value of '1' if it uses improved sanitation 
	
replace toilet_mdg = 0 if vi14==4 | vi14==5
 	//Household is assigned a value of '0' if it uses unimproved sanitation 
	
replace toilet_mdg = 0 if vi15b==0 
 	//Household is assigned a value of '0' if it uses shared facility
	
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

clonevar water = vi17
codebook water, tab (99)

gen timeminutes= vi21a * 60  
egen timetowater=rowtotal(timeminutes vi21b), miss 
codebook timetowater, tab (999)
tab water if timetowater>=300 &  timetowater!=.	
	/*Note that 23 individuals live in households that reported more than 5 
	hours distance to obtain water. Since these households 
	are getting their drinking water from deprived sources, we did not replace 
	these potentially unreasonable values as missing.*/

	
gen ndwater = .


*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************
	/*Note: The ECV 2013-14 recorded 6 categories of sources of drinking water 
	in the data. From page 23 of the country report, it may be inferred that 
	individuals in the higher income quintile are more likely to get their 
	drinking water from piped sources (public network and other pipes). 
	This suggest that all other categories including water drawn from well is 
	considered as unimporved. We have followed this standard for the global MPI*/

gen water_mdg = 1 if water==1 | water==2 
	/*Non deprived if source of drinking water is from public network, and 
	other pipe */
	
replace water_mdg = 0 if water==3 | water==4 | water==5 | water==6 
	/*Deprived if source of drinking water is from delivery trolley / tricycle, 
	well, river drainage or ditch or other undocumented sources */

replace water_mdg = 0 if (timetowater>=30 & timetowater!=.)
	//Deprived if water is at more than 30 minutes' walk (roundtrip) 
	
lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water water_mdg, miss



********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
lookfor piso
clonevar floor = vi05
codebook floor, tab(99)
gen floor_imp = 1 if vi05==1 | vi05==2 | vi05==3 | vi05==4 | vi05==5 | vi05==6
replace floor_imp = 0 if vi05==7 | vi05==8
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss


/* Members of the household are considered deprived if the household has walls 
made of natural or rudimentary materials */

	/*Note: For the purpose of hte global MPI, in the case of Ecuador, we 
	classified "adobe" and "wood" as improved, and cane/coated reed 
	as unimproved.*/
lookfor pared
clonevar wall = vi04
codebook wall, tab(99)	
gen wall_imp = 1 if wall<=5
replace wall_imp = 0 if wall>=6 & wall<=8 
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	

	
/* Members of the household are considered deprived if the household has walls 
made of natural or rudimentary materials */
lookfor techo
clonevar roof = vi03
codebook roof, tab(99)	
gen roof_imp = 1 if roof<=5
replace roof_imp = 0 if roof>=6 & roof<=7
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

lookfor cocina
codebook vi11 vi12 vi13
clonevar cookingfuel = vi13
replace cookingfuel = 5 if vi11==5
label define cookingfuel 1 "gas" 2 "electricity" 3 "wood/charcoal"  ///
						 4 "other" 5 "no cooking at home"
label values cookingfuel cookingfuel
tab vi13 cookingfuel, miss


*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
gen cooking_mdg = 0 if cookingfuel==3 
replace cooking_mdg = 1 if cookingfuel==1 | cookingfuel==2 | ///
						   cookingfuel==4 | cookingfuel==5 
replace cooking_mdg = . if cookingfuel==99
lab var cooking_mdg "Househod has cooking fuel according to MDG standards"			 
tab cookingfuel cooking_mdg, miss	


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************
/*Assets that are included in the global MPI: Radio, TV, telephone, bicycle, 
motorbike, refrigerator, car, computer and animal cart */


*Television
	/*Note: if the household has a black/white or color TV it is considered not 
	deprived.*/
gen television=.
replace television=1 if  _TV_bn==1 | _TV_color==1 | _TV_plas_lcd==1
replace television=0 if  _TV_bn==2 & _TV_color==2 & _TV_plas_lcd==2
replace television=. if  _TV_bn==. & _TV_color==. & _TV_plas_lcd==.
gen bw_television   = .

*Radio
	/*Note: if the household has a radio (radio equipment or sound equipment) 
	it is considered not deprived. */
gen radio=.
replace radio=1 if _grabadora==1 | _eqpsonido==1
replace radio=0 if _grabadora==2 & _eqpsonido==2
replace radio=. if _grabadora==. & _eqpsonido==.


*Fix Telephone at home
gen telephone= 1 if  _telfijo==1
replace telephone= 0 if  _telfijo==2

*Mobile phone 
gen mobile = 1 if ph09a==1
tab age if ph09a==., miss 
	//persons <12 y were not asked and we assume they do not have a cell phone 
replace mobile = 0 if ph09a==2 | ph09a==.
egen mobiletelephone = max(mobile), by(identif_hog)


*Refrigerator
gen  refrigerator     = 1 if  _refrigeradora==1
replace  refrigerator = 0 if  _refrigeradora==2


*Car
gen  car = 1 if     _carro==1
replace  car = 0 if _carro==2


*Bicycle
gen bicycle     = 1 if  _bicicleta==1
replace bicycle = 0 if  _bicicleta==2


*Motorcycle
gen  motorbike   = 1 if _moto==1
replace motorbike= 0 if _moto==2 


*Computer
lookfor _comput _lap
gen computer = 1 if _laptop==1 | _computer==1
replace computer=0 if _laptop==2 & _computer==2
tab computer, miss


*Animal cart
gen animal_cart = .


foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer animal_cart {
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Replace missing values
	


	//Combine information on telephone and mobiletelephone
tab telephone mobiletelephone, miss
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
clonevar strata = dominio
clonevar psu = identif_sect 	
codebook strata psu


	//Retain year, month & date of interview:
desc ps81a ps81b ps81c
clonevar year_interview = ps81c 	
clonevar month_interview = ps81b 
clonevar date_interview = ps81a
 

	//Generate presence of subsample
gen subsample = .

	//Destring hh_id ind_id psu
destring hh_id ind_id psu, replace
desc hh_id ind_id psu strata



*** Rename key Global MPI indicators for estimation ***
	/* Note: In the case of Ecuador ECV 2013-14, there is no birth history file. 
	We are not able to identify whether child mortality occured in the last 5 
	years preceeding the survey date. As such, for the estimation, we use the 
	indicator 'hh_mortality' that represent all child mortality that was ever 
	reported. */	
recode hh_mortality         (0=1)(1=0) , gen(d_cm)
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
char _dta[cty] "Ecuador"
char _dta[ccty] "ECU"
char _dta[year] "2013-2014" 	
char _dta[survey] "ECV"
char _dta[ccnum] "218"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(filedate)'."	
save "$path_out/ecu_ecv13-14.dta", replace 

