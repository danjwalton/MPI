********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Jamaica JSLC 2014 [STATA do-file]. 
Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************



/* FOR JAMAICA: Raw dta files that we will be using in JSLC 2014:
anthro14 Section C  - Children anthropometrics
rec001	 Cover Data - gives you the weights
rec003	 Section R  - Roster : list all members of each household, and relation 
					          with hh head.
rec004	 Section A  - Health
rec005	 Section B  - Education
rec017	 Section I  - Housing and Related Expenses
rec018	 Section J  - Inventory of Durable Goods
hhsizes	 Household Population Data - gives the household size of the steal 
									 members of the hh. 

Its important to review the Survey Questionnaire, the dataset description, 
dictionary and each raw data set. This is because several variables and coding 
of those variables could change between year.
*/

clear all 
set more off
set maxvar 10000
set mem 500m


*** Working Folder Path ***
global path_in G:/My Drive/Work/GitHub/MPI//project_data/DHS MICS data files
global path_out G:/My Drive/Work/GitHub/MPI//project_data/MPI out
global path_ado G:/My Drive/Work/GitHub/MPI//project_data/ado


********************************************************************************
*** JAMAICA JSLC 2014 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
********************************************************************************

	
/*Jamaica JSLC 2014: Anthropometric information were recorded for a 
subsample of 1/3 of all eligible children age 0-59 months and eligible women 
aged 15-49 (p.4). Anthropometric information was not collected from men 15-54 */


********************************************************************************
*** Step 1.1 CHILDREN UNDER 5 RECODE 
********************************************************************************

use "$path_in/anthro14.dta", clear 


*** Generate individual unique key variable required for data merging
*** serial=household number; 
*** ind=child's line number in household; 
gen double ind_id = serial*100 + ind 
format ind_id %20.0g
label var  ind_id "Individual ID"


duplicates report ind_id
	//0 duplicates

gen child_KR=1 
	//Generate identification variable for observations in KR recode


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
gen str30 datalab = "children_nutri_jam" 
lab var datalab "Working file"


*** Next check the variables that WHO ado needs to calculate the z-scores:
*** sex, age, weight, height, measurement, oedema & child sampling weight


*** Variable: SEX ***
tab sex, miss 
	//"1" for male ;"2" for female
clonevar gender = sex
desc gender
tab gender


*** Variable: AGE ***
tab months, miss 
codebook months 
clonevar age_months = months  
desc age_months
summ age_months
gen  str6 ageunit = "months" 
lab var ageunit "Months"

	
*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook c10, tab (999) 
gen	weight = c10
tab c10 ,m nol   
tab	c9 c10 if c10==., miss 
	//c9: result of the measurement
desc weight 
summ weight


*** Variable: HEIGHT (CENTIMETERS)
codebook c11, tab (999)
gen	height = c11
tab c11,m nol   
tab	c9 c11   if  c11==., miss
desc height 
summ height


*** Variable: MEASURED STANDING/LYING DOWN		
codebook c12
	//How was the at the measurement 1"lying down" 2 "Standing up"
gen measure = "l" if c12==1 
	//Child measured lying down
replace measure = "h" if c12==2 
	//Child measured standing up
replace measure = " " if c12==. 
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
	//Not available for JSLC, so created sw=1
gen  sw = 1
desc sw
summ sw



/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age_months ageunit weight ///
height measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores */
use "$path_out/children_nutri_jam_z_rc.dta", clear 

	
	
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
keep ind_id child_KR underweight* stunting* wasting*  
order ind_id child_KR underweight* stunting* wasting*
sort ind_id
save "$path_out/JAM14_KR.dta", replace


	//Erase files from folder:
erase "$path_out/children_nutri_jam_z_rc.xls"
erase "$path_out/children_nutri_jam_prev_rc.xls"
erase "$path_out/children_nutri_jam_z_rc.dta"
	
	
********************************************************************************
*** Step 1.2 HOUSEHOLD MEMBER'S RECODE 
********************************************************************************

use "$path_in/rec003.dta", clear


gen double hh_id = serial 
format hh_id %20.0g
label var hh_id "Household ID"
codebook hh_id  


gen double ind_id = serial*100+ ind  
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id


	
********************************************************************************
*** 1.3 DATA MERGING
*********************************************************************************

merge m:1 serial using "$path_in/rec001.dta", nogen
	//Data at hh level
	
merge m:1 serial using "$path_in/rec017.dta", nogen
	//Housing and related expenses at hh level
	
merge m:1 serial using "$path_in/rec018.dta", nogen
	//Inventory of durable good at hh level
	
merge m:1 serial using "$path_in/hhsizes.dta", nogen
	//Household size at hh level
	
merge 1:1 serial ind using "$path_in/rec005.dta", nogen
	//Education at individual level
	
merge 1:1 serial ind using "$path_in/rec004.dta", nogen
	//Heath at individual level
	
merge 1:1 ind_id using "$path_out/JAM14_KR.dta", nogen
	//Measured children data at individual level
erase "$path_out/JAM14_KR.dta"	

sort hh_id ind_id


********************************************************************************
*** Step 1.4 KEEPING ONLY DE JURE HOUSEHOLD MEMBERS ***
********************************************************************************

desc hhmember
codebook hhmember, tab (10)
count if hhmember!=2 

clonevar resident = hhmember
replace resident =1 if hhmember==3
label var resident "Permanent (de jure) household member"


drop if resident==2
tab resident, miss
	/*In the context of Jamaica JSLC 2014, 240 (4.27%) individuals who were 
	non-usual residents were dropped from the sample*/


********************************************************************************
*** 1.5 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
desc finwght
clonevar weight = finwght 


//Area: urban or rural	
desc area
codebook area, tab (5)
recode area (3=0) (2=1)		
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"
tab area, miss

//Sex of household member	
codebook sex, tab (5)
recode sex (2=0)  
label define lab_sex 1 "male" 0 "female"
label values sex lab_sex


//Age of household member
codebook age, tab (999)


//Age group 
recode age (0/4 = 1 "0-4")(5/9 = 2 "5-9")(10/14 = 3 "10-14") ///
		   (15/17 = 4 "15-17")(18/59 = 5 "18-59")(60/max=6 "60+"), gen(agec7)
lab var agec7 "age groups (7 groups)"	
	   
recode age (0/9 = 1 "0-9") (10/17 = 2 "10-17")(18/59 = 3 "18-59") ///
		   (60/max=4 "60+"), gen(agec4)
lab var agec4 "age groups (4 groups)"



//Marital status of household member
clonevar marital = marital_stat 
codebook marital, tab (20)
recode marital (1=2)(2=1)(3=4)(4=5)(5=3)(97/99=.)
label define lab_mar 1"never married" 2"currently married" ///
					 3"widowed" 4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab marital_stat marital, miss


//Total number of hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
drop member


//Subnational region
gen region = parish
codebook region, tab (99)
lab define lab_region 1 "Kingston" 2 "St. Andrew"	3 "St. Thomas"	///
					  4 "Portland" 5 "St. Mary" 6 "St. Ann" 7 "Trelawny" ///
					  8 "St. James" 9 "Hanover" 10 "Westmoreland" ///
					  11 "St. Elizabeth" 12 "Manchester" 13 "Clarendon" ///
					  14 "St. Catherine"
lab values region lab_region
lab var region "Region for subnational decomposition"



********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

gen edulevel = b21  
	/*Highest educational level attended//check with the questionnaire the 
	values of each year*/  
replace edulevel = . if b21 == . | b21 >= 97 
	//Missing value
replace edulevel = 0 if b21 == 18  
	//None
label define lab_edulevel 0 "None" 1"Basic/infant/Kindergarten" ///
						  2 "Primary" 3 "Preparatory" ///
						  4 "All age school(grades1-6)"  ///
						  5 "Primary/junior high" ///
						  6 "Junior high (grades7-9)" 7 "New Secondary" ///
						  8 "Comprehensive" 9 "Secondary high" ///
						  10 "Technical" 11 "Vocat/Agri" 12 "University" ///
						  13 "Other tertiary (public)" ///
						  14 "Other tertiary (private)" ///
						  15 "Adult literacy classes" ///
						  16 "Adult education/night" 17 "Special school" ///
						  18 "None", modify
label values edulevel lab_edulevel


codebook b22, tab(30)
clonevar  eduyears = b22   
	//Total number of years of education
replace eduyears = . if b22 >=97 | b22 ==.
	//Recode any unreasonable years of highest education as missing value
replace eduyears = 14 if edulevel >= 12 & edulevel <= 14  
	//Assumes 14 years of education for all tertiary education 
replace eduyears = 0 if edulevel >= 15 & edulevel <= 18  
	//Assumes that adult education is not measured as formal schooling
replace eduyears = 0 if edulevel == 1  & eduyears== .  
	//Assumes kindergarden represents 0 years
replace eduyears = 1 if (edulevel == 2 | edulevel== 4) & eduyears== .
replace eduyears = 7 if edulevel == 6 & eduyears== .
replace eduyears = 3 if edulevel == 5 & eduyears== .
replace eduyears = 7 if (edulevel >= 7 & edulevel <= 9) & eduyears== .
replace eduyears = 9 if (edulevel >= 10 & edulevel <= 11 | edulevel==14 ) & eduyears== .
gen lastgrade = b4
replace eduyears = 0 if edulevel == 0 | b1 == 1 
replace eduyears = lastgrade - 1 if eduyears==. & edulevel ==. & b1>= 3 & b1<=  9 & lastgrade!=.
replace eduyears = 8 if eduyears==. & edulevel ==. & b1==10 & lastgrade!=.
replace eduyears = 8 if eduyears==. & edulevel ==. &  b1>=8 & b1<=10 & lastgrade==.
replace eduyears = 12 if eduyears==. & edulevel ==. &  b1>=11 & b1<=13 & lastgrade==.
replace eduyears = 0 if eduyears==. & edulevel ==. & (b1<=2 | b1>=14 & b1<=99 ) 
lab var eduyears "Highest year of education completed"

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
	//Values for 0 are less than 1%
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

/*For Jamaica JSLC 2014 b1 is the type of school that individual is attending 
the current year:
        1   NURSERY/DAYCARE(INCLUDE NEWBORN BABIES)
        2   BASIC/INFANT/KINDERGARTEN
        3   PRIMARY
        4   PREPARATORY
        5   ALL AGE SCHOOL
        6   PRIMARY AND JUNIOR HIGH
        7   JUNIOR HIGH (GRADES 7 - 9)
        8   SECONDARY HIGH
        9   TECHNICAL
        10  VOCAT./AGR.
        11  UNIVERSITY
        12  OTHER TERTIARY (PUBLIC)
        13  OTHER TERTIARY (PRIVATE)
        14  ADULT LITERACY CLASSES
        15  ADULT EDUCATION/NIGHT
        16  SPECIAL SCHOOL
        17  JFLL
        18  NONE
        96  INDIVIDUAL NON-RESPONSE*/
		
gen	attendance = .
replace attendance = 1 if b1>=3 & b1<=16 
	//Currently attending formal education//
replace attendance = 0 if b1==17 | b1<=2  
	//Not attending school or attending below formal (primary) education//
replace attendance = . if age<6 | age>97 
	
	

*** Standard MPI ***
******************************************************************* 
/*The entire household is considered deprived if any school-aged child is not 
attending school up to class 8. */ 

gen	child_schoolage = (age>=6 & age<=14)
	/*Note: In Jamaica, the official school entrance age is 6 years.  
	  So, age range is 6-14 (=6+8)  
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

********************************************************************************
*** Step 2.3a Child Nutrition ***
********************************************************************************


/* As a first step, create the child eligibility criteria. Households that do
not have eligible children, that is, children under 5, are identified as non-
deprived */
gen	child_eligible = (child_KR==1) 
bys	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible"
tab no_child_eligible, miss 



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
*** Step 2.3b Household Nutrition Indicator ***
********************************************************************************

*** Standard MPI (union: child underweight or stunting) ***

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
	/*NOTE: Jamaica JSLC 2014 has no data on child mortality. As such the 
	indicators under this section is assigned with missing value */

gen child_mortality = .
lab var child_mortality "Total child mortality within household"

	
gen hh_mortality_u18_5y = .
lab var hh_mortality_u18_5y "Household had no under 18 child mortality in the last 5 years"

	
clonevar hh_mortality_u =hh_mortality_u18_5y
	

********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************


*** Standard MPI ***
/*Members of the household are considered 
deprived if the household has no electricity */
***************************************************
gen electricity = (i34==1) 
	/*Main source of lightening assumes that they have no electricity when they 
	use kerosene or other */
codebook electricity, tab (10)
replace electricity = . if i34 >= 97 | i34== .  
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


	//Type of toilet 
gen toilet = i5  
replace toilet=. if toilet == 97

gen toilet_facilities = (i4 != 3)
	//i4=3 : do not have toilet facility
	
gen shared_toilet = (i6 == 2)
	//1=shared toilet
replace shared_toilet = . if i6== .  
	
	
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************
gen toilet_mdg = 0 if toilet_facilities==0  | shared_toilet==1
	//Do not have toilet facility & if there is toilet facility, it is shared 
	
replace toilet_mdg = (toilet <= 2 & shared_toilet!=1) if toilet!=.
	//Have water closet toilets that are linked / not linked to the sewer
	
replace toilet_mdg = . if toilet==. & shared_toilet==. & toilet_facilities!=0
	/* Note: There are 12 individuals who reported that the toilet facilities 
	are inside their dwelling, but did not provide information on the type of 
	toilet facility or whether it is shared or non-shared facility. For the 
	purpose of the global MPI, we have coded these individuals as missing. */

lab var toilet_mdg "Household has improved sanitation with MDG Standards"
tab toilet_facilities toilet_mdg, miss



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
clonevar water = i27  

gen ndwater = .

clonevar timetowater = i33_1  
replace timetowater = . if timetowater > 999
replace timetowater = timetowater * 1000 if i33_2 == 1 
	//convert from kilometers to meters
replace timetowater = timetowater * 1609.34 if i33_2 == 3 
	//miles to meters
replace timetowater = timetowater * 0.9144 if i33_2 == 4 
	//yards to meters
replace timetowater = timetowater * 20.1168 if i33_2 == 5 
	//chains to meters
codebook timetowater, tab (999)


*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************
	/* Note: In Jamaica, the National Water Commission (NWC) and the Ministry of 
	Health restrict the definition of imporved drinking water sources to only 
	treated water, that is, household connection (piped into yard/dwelling) and 
	public standpipe. The country report (p.84(5.7)) adds bottled water and 
	trucked water (from NWC) to the definition of imporved drinking water 
	sources. Furthermore, the report identifies trucked water from private 
	companies as unimporved source of drinking water because of the difficulty 
	in determining the safety of the drinking water from the multiple private 
	companies. The country report summarise that untreated sources of drinkng 
	water are: rainwater tank, well, river/lake/spring/pond or water trucked 
	from private company (p.84(5.7)).*/

codebook water, tab(99)
gen water_mdg = 1 if (water <=3)| water==8 | water==9 | water==12 
	/*Non deprived if water is indoor tap/pipe; outside private tap/pipe; 
	  public standpipe; trucked water(NWC); bottled water */
	  
replace water_mdg = 0 if water==4  | water==5  | water==6 | water==7 | ///
						 water==10 | water==11 | water==13 
	/*Deprived if it is well; river/lake/spring/pond; rainwater (tank);
	  trucked water (private companies)*/

replace water_mdg = 0 if water_mdg==1 & timetowater>=1000 & timetowater!=.  
	//Deprived if water is at more than 1000 meters (30 minutes walk, roundtrip)
	
replace water_mdg = . if water >= 97 

lab var water_mdg "Household has drinking water with MDG standards (considering distance)"
tab water water_mdg, miss


********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************
/*Note: In Jamaica, housing was only constructed using information on wall, as 
the survey did not collect data on floor and roof. The country report included 
only walls made of concrete block & steel in the housing quality index. The 
report states that this type of walls has durability for withstanding the 
elements of weather and for providing occupants with a greater level of 
security (p.78 (5.1); Table 5.5, p.83 (5.6)). Following the country report, we 
identify only walls made of concrete block & steel as non-deprived. All other 
wall materials including wood, stone, brick, cocrete nog, wattle/adobe and 
others as non-improved. */



/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor. 
Jamaica JSLC 2014 has no data on floor. */
gen floor = .
gen floor_imp = .
lab var floor_imp "Household has floor that it is not earth/sand/dung"


/* Members of the household are considered deprived if the household has wall 
made of natural & low quality materials. */
lookfor wall
clonevar wall = i2
label def walls 1 "Wood" 2 "Stone" 3 "Bricks" 4"Concrete nog" ///
				5 "Concrete block & steel" 6 "Wattle/Adobe" 7"Other"
label values wall walls
codebook wall, tab(99)	
gen	wall_imp = 1 
replace wall_imp = 0 if wall==1 | wall==2 | wall==3 | wall==4 | ///
						wall==6 | wall==7  
replace wall_imp = . if wall==. 
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	

/* Members of the household are considered deprived if the household has roof 
made of natural & low quality materials.
Jamaica JSLC 2014 has no data on roof.*/	
gen roof = .	
gen	roof_imp = . 
lab var roof_imp "Household has roof that it is not of low quality materials"



*** Standard MPI ***
****************************************
/*Household is deprived in housing if the roof, floor OR walls uses 
low quality materials.*/
gen housing_1 = 1
replace housing_1 = 0 if wall_imp==0 
replace housing_1 = . if wall_imp==. 
lab var housing_1 "Household has wall that it is not low quality material"
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


clonevar cookingfuel = i45  
label def cookingfuel 1 "Gas" 2 "Electricity" 3 "Wood" 4"Kerosene" ///
				      5 "Charcoal" 6 "Biogas" 97 "Other" 98 "Other"
label values cookingfuel cookingfuel
codebook cookingfuel, tab(99)


*** Standard MPI ***
****************************************
gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel == 3  | cookingfuel == 5 |  ///
						   cookingfuel == 97 | cookingfuel == 98 
	//3=wood; 5=charcoal
replace cooking_mdg = . if cookingfuel==. | cookingfuel==99
lab var cooking_mdg "Househod has cooking fuel according to MDG standards"			 
tab cookingfuel cooking_mdg, miss	


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************

/* Members of the household are considered deprived if the household does not 
own more than one of: radio, TV, telephone, bike, motorbike or refrigerator and 
does not own a car or truck. */


clonevar television = j608 
gen bw_television   = .
clonevar radio = j607 
clonevar telephone =  i38_1 
gen mobiletelephone = (i38_2==1 | i38_3==1)
clonevar refrigerator = j604 
clonevar car = j615  
clonevar bicycle = j613 
clonevar motorbike = j614 
clonevar computer = j616
gen animal_cart = .


foreach var in television radio telephone mobiletelephone refrigerator ///
			   car bicycle motorbike computer animal_cart  {
replace `var' = 0 if `var'==2 
	//0=no; 1=yes
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
clonevar strata = region
clonevar psu = district


	//Retain year, month & date of interview:
clonevar year_interview = int_day 	
clonevar month_interview = int_mth 
clonevar date_interview = int_yer

 
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
char _dta[cty] "Jamaica"
char _dta[ccty] "JAM"
char _dta[year] "2014" 	
char _dta[survey] "JSLC"
char _dta[ccnum] "388"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(filedate)'."	
save "$path_out/jam_jslc14.dta", replace 

