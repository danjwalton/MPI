********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2019 Global Multidimensional Poverty Index - Brazil PNAD 2015 [STATA do-file]. 
Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off
set maxvar 10000
set mem 500m


*** Working Folder Path ***
global path_in "T:/GMPI 2.0/rdta/Brazil PNAD 2015" 
global path_out "G:/GMPI 2.0/cdta"
global path_ado "T:/GMPI 2.0/ado"

	
********************************************************************************
*** BRAZIL PNAD 2015 ***
********************************************************************************
/*
The data for the PNAD 2015 may be downloaded from the link appended below:
ftp://ftp.ibge.gov.br/Trabalho_e_Rendimento/Pesquisa_Nacional_por_Amostra_de_Domicilios_anual/microdados/2015/

The report of the survey may be downloaded from the link appended below:
https://biblioteca.ibge.gov.br/biblioteca-catalogo?view=detalhes&id=298887

There are some table with results from PNAD 2015 with information that is not
available in the report. These tables can be found at:
https://ww2.ibge.gov.br/home/estatistica/populacao/trabalhoerendimento/pnad2015/brasil_defaultxls.shtm
*/


********************************************************************************
*** Step 1: Data preparation 
*** Selecting variables from KR, BR, IR, & MR recode & merging with PR recode 
********************************************************************************

	
/*PNAD 2015: Does not have information on anthropometric. In addition, all data 
from households and individuals interviewed are already merged in a single 
file.*/


********************************************************************************
*** Step 1.1  CONVERTING DATA FILE INTO STATA 
********************************************************************************
	/* The commands below relate to the programme used for getting the dataset 
	into STATA format */

	//Household level data
infile using "$path_in/dictionaries/pnad2015dom.dct", using ("$path_in/dados/DOM2015.txt")
sort V0102 V0103
save "$path_out/DOM2015.dta", replace
count
	//151,189 households 
duplicates report	
	
	
	//Individual level data
clear		
infile using "$path_in/dictionaries/pnad2015pes.dct", using ("$path_in/dados/PES2015.txt")
sort V0102 V0103
save "$path_out/PES2015.dta", replace
count
	//356,904 individuals	
duplicates report

		
merge m:1 V0102 V0103 using "$path_out/DOM2015.dta"
	//Note: 33,205 individuals did not match to households
	
save "$path_out/bra_pnad15_raw.dta", replace

erase "$path_out/PES2015.dta"
erase "$path_out/DOM2015.dta"

clear

********************************************************************************
*** Step 1.2  HOUSEHOLD MEMBER'S INFORMATION
********************************************************************************
use "$path_in/bra_pnad15_raw.dta", clear

rename _all, lower	


*** Generate a household unique key variable at the household level using: 
	***v0102: control number 
	***v0103: serial number
	***v0403: family number
sort v0102 v0103	
egen hh_id = group(v0102 v0103)  
sort hh_id
bysort hh_id: gen id = _n
tab id if id==1 & v0201!=5 [w=v4611], miss
	//68,177,092 households consistent with the tables
tab id if id==1 & v0201!=5 [w=v4729], miss
tab id if id==1 & v0201!=5 [w=v4732], miss
drop id

format hh_id %20.0g
label var hh_id "Household ID"
codebook hh_id  


*** Generate individual unique key variable required for data merging using:
	*** v0301=respondent's line number
	/*Note: Check that the ind_id variable has as many 'unique values' as number 
	of observations you have in the dataset. If it doesn't the individual ID has 
	a mistake and needs to be fixed. Most likely the v0301 var has more than two 
	digits */	
egen ind_id=group(hh_id v0301)
format ind_id %20.0g
label var ind_id "Individual ID"
codebook ind_id
duplicates report ind_id 
	/*Note: Duplicates on ind_id are the missing values from non-particular 
	households that were sampled (but they are not interviewed) */
drop if mi(ind_id)
count
	//356,904 individuals

sort hh_id ind_id



********************************************************************************
*** Step 1.3 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
clonevar weight = v4611 
label var weight "Sample weight"


//Type of place of residency: urban or rural
compare v4728 v4105
	//Both variables are jointly defined	
codebook v4105, tab (10)		
recode v4105 (1/3=1) (4/8=0), gen(area)
	//Redefine the coding and labels to 1/0
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"
tab v4728 area, miss
tab v4105 area, miss


//Sex of household member	
codebook v0302
recode v0302 (2=1) (4=2), gen(gender)
label define gender 1 "Male" 2 "Female"
label values gender gender
label var gender "Sex of household member"
clonevar sex = gender


//Age of household member
codebook v8005, tab (999)
clonevar age = v8005  
label var age "Age of household member"


//Age group (for global MPI estimation)
recode age (0/4 = 1 "0-4")(5/9 = 2 "5-9")(10/14 = 3 "10-14") ///
		   (15/17 = 4 "15-17")(18/59 = 5 "18-59")(60/max=6 "60+"), gen(agec7)
lab var agec7 "age groups (7 groups)"	
	   
recode age (0/9 = 1 "0-9") (10/17 = 2 "10-17")(18/59 = 3 "18-59") ///
		   (60/max=4 "60+"), gen(agec4)
lab var agec4 "age groups (4 groups)"



//Marital status of household member
	/*Note: In PNAD 2015, living together takes precedence over legal status, 
	meaning that even if the person is legally single, widowed or divorced but is 
	living with someone, they are considered as 2-currently married */
gen long marital = .
replace marital = 1 if v4111 == 5 
	//never lived together
replace marital = 2 if v4111 == 1 | v4011 == 1 
	//living together or, even if not, legally married
replace marital = 3 if v4111 == 3 & v4011 == 7 		
	//already lived together and legally windowed
replace marital = 4 if v4111 == 3 & (v4011 == 3 | v4011 == 5) 
	//already lived and divorced
replace marital = 5 if v4111 == 3 & v4011 == 0 
	//already lived together and single
label define lab_mar 1"never married" 2"currently married" 3"widowed" ///
4"divorced" 5"not living together"
label values marital lab_mar	
label var marital "Marital status of household member"
tab v4111 marital if age>=10, miss
tab v4011 marital if age>=10, miss


//Total number of de jure hh members in the household
	/*Note: The variable 'v4620' on household size, doesn't take into 
	consideration of maids and relatives living in the household. However, we 
	opted not to use this variable since we take into account of all 
	householders who are sharing meal within the household.*/
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
drop member


//Subnational region
clonevar region = uf
lab define lab_region 11"Rondônia" 12"Acre"	13"Amazonas" 14"Roraima" /// 
					  15"Pará" 16"Amapá" 17"Tocantins" 21"Maranhão"	///
					  22"Piauí"	23"Ceará" 24"Rio Grande do Norte" ///
					  25"Paraíba" 26"Pernambuco" 27"Alagoas" 28"Sergipe" ///
					  29"Bahia"	31"Minas Gerais" 32"Espírito Santo"	///
					  33"Rio de Janeiro" 35"São Paulo" 41"Paraná" ///
					  42"Santa Catarina" 43"Rio Grande do Sul" ///
					  50"Mato Grosso do Sul" 51"Mato Grosso" 52"Goiás" ///
					  53"Distrito Federal", modify
lab val region lab_region
lab var region "Region for subnational decomposition"
tab region, miss



********************************************************************************
*** Step 1.5 CONTROL VARIABLES
********************************************************************************
/* Households are identified as having 'no eligible' members if there are no 
applicable population, that is, children 0-5 years, adult women 15-49 years or 
men 15-54 / 15-59 years. */


tab v1101 sex, miss
tab age v1101, miss
tab marital v1101, miss  
	/*Note: The question on whether 'had a child born alive' was asked to all 
	women aged 10 years and older regardless of their marital status. */
	

*** No Eligible Women (15 years and older)
*****************************************
gen	fem_eligible = (age>=15 & age<=49 & sex==2)
	/*There is no nutrition variable for women. But questions about fecundity 
	was collected from  all women aged 15 and older. Hence this eligibility
	criteria will be only applied in the child mortality section */
bysort	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the household
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
tab no_fem_eligible, miss


*** No Eligible Men 15-54 years
*****************************************
	//PNAD 2015 has no questions related to children's anthropometrics
	//Thus, this variable is created as missing	
gen no_male_eligible = . 
lab var no_male_eligible "Household has no eligible man"
tab no_male_eligible, miss


*** No Eligible Children 0-5 years
*****************************************
	//PNAD 2015 has no questions related to children anthropometrics
	//In such case, this variable takes missing value	
gen	no_child_eligible = .
lab var no_child_eligible "Household has no children eligible"
tab no_child_eligible, miss


*** No Eligible Women and Men 
***********************************************
	//PNAD 2015 has no questions related to nutrition or child mortality from men 
	//Thus, this variable is created as missing		
gen	no_adults_eligible = .
	//Takes value 1 if the household had no eligible men & women for an interview
lab var no_adults_eligible "Household has no eligible women or men"
tab no_adults_eligible, miss 


*** No Eligible Children and Women  
***********************************************
	/*NOTE: We use this variable as a control variable for the nutrition 
	indicator if nutrition data is present for children and women. However, 
	in the case of PNAD 2015, there is no nutrition data. Thus, this variable 
	is created as missing*/
gen	no_child_fem_eligible = .
lab var no_child_fem_eligible "Household has no children or women eligible"
tab no_child_fem_eligible, miss 


*** No Eligible Women, Men or Children 
***********************************************
	/*NOTE: We use this variable as a control variable for the nutrition 
	indicator if nutrition data is present for children, women & men. However, 
	in the case of PNAD 2015, there is no nutrition data. Thus, this variable 
	is created as as an empty variable. */
gen no_eligibles = .
lab var no_eligibles "Household has no eligible women, men, or children"
tab no_eligibles, miss


*** No Eligible Subsample 
*****************************************
	/*NOTE: Hemoglobin data was not collected as part of PNAD 2015. Thus, this 
	variable is created as an empty variable. */ 
gen no_hem_eligible = . 	
lab var no_hem_eligible "Household has no eligible individuals for hemoglobin measurements"
tab no_hem_eligible, miss


drop fem_eligible hh_n_fem_eligible 



********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************


********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************

codebook v4803, tab(30)
	/*Variable is coded as:
		1: no education or less than 1 year
		2: 1 year of education
		3: 2 years of education
		...
		15: 14 years of education
		16: 15 or more years of education
		17: unkown */	
	
gen  eduyears = v4803 - 1
replace eduyears = . if eduyears == 16
	//total number of years of education
tab eduyears v4803
replace eduyears = . if eduyears>30
	//recode any unreasonable years of highest education as missing value
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
lab var hh_years_edu6 "Household has at least one member with 6 years of edu"


********************************************************************************
*** Step 2.2 Child School Attendance ***
********************************************************************************

codebook v0602, tab (10)
recode v0602 (4=0)(2=1), gen(attendance)
codebook attendance, tab (10)
	

*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
*******************************************************************
gen	child_schoolage = (age>=6 & age<=14)
	/*Note: In Brazil, the official school entrance listed on the UIS UNESCO 
	website is 4 years. However 4 years is for pre-schooling. The official 
	entry age to primary is 6 years. As such, for the purpose of the global MPI 
	work, we follow the compulsory age for primary schooling. It should be noted 
	that according to the law the state has to provide education from 9 to 
	17 years of age.
	Age range applied in the context of PNAD 2015 is 6-14 (=6+8) */

	
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
	/*PNAD 2015 has no information on nutrition. Thus, the indicator on
	nutrition is created as missing */

gen hh_nutrition_uw_st = .
lab var hh_nutrition_uw_st "Household has no child underweight/stunted or adult deprived by BMI/BMI-for-age"


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************
	/* Note: In the case of PNAD 2015, the question on child mortality was only 
	collected from women. */
	
	
tab v1161 v1163, miss   
	//v1163 are for those who don't know how many sons died
tab v1162 v1164, miss   
	//v1164 are for those who don't know how many daughters died

	
	//Total child mortality reported by eligible women
egen temp_f = rowtotal(v1161 v1162), missing 
	//v1161: number of sons who have died; 
	//v1161: number of daughters who have died
replace temp_f = 0 if v1101==3  
	//Women who have never ever given birth is replaced as '0'
replace temp_f = 0 if (age > 49) & sex==2
	/*Women who are older than 49 years who have provided information on child 
	mortality are replaced as having '0' child mortality. The global MPI 
	considers child mortality for women 15-49 years. The aim of the child 
	mortality indicator of the global MPI is to capture recent child mortality, 
	primarily among young children. When the date of death is not known, as in 
	Brazil, limiting the indicator to the reproductive age of a women, that is 
	15-49 years, make sense from a policy perspective. In addition, this 
	maintains comparability to the MICS/DHS datasets that covers women 15-49 
	years. */	
bysort hh_id: egen child_mortality_f = sum(temp_f), missing

clonevar child_mortality = child_mortality_f 
lab var child_mortality "Total child mortality within household reported by women"
tab child_mortality, miss		


*** Child Mortality *** 
/*Deprived if any children died in the household */
************************************************************************

gen	hh_mortality = (child_mortality==0)
	/*Household is replaced with a value of "1" if there is no incidence of 
	child mortality*/
replace hh_mortality = . if child_mortality==.

replace hh_mortality = 1 if no_fem_eligible==1 
	/*In the context of PNAD 2015, child mortality indicator is constructed 
	solely using information from women 15-49 years. Households that do not
	have women within this eligible age group are replaced with a value
	of "1" */
	
lab var hh_mortality "Household had no child mortality"
tab hh_mortality, miss


	/*Note: PNAD 2015 doesn't ask the date of death. This means, there is no 
	information on the date of death of children who have died. As such
	we are not able to construct the indicator on child mortality that occurred 
	in the last 5 years.*/



********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************


*** Standard MPI ***
/*Members of the household are considered 
deprived if the household has no electricity */
***************************************************
clonevar electricity = v0219 
codebook electricity, tab (10)
replace electricity = 0 if electricity==3 | electricity==5
	//Replace missing values
label var electricity "Household has electricity"
tab electricity, miss



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

clonevar toilet = v0217
codebook toilet, tab(30) 
label define lab_toilet 1 "flush toilet to piped sewer" ///
						2 "flush to septic tank" ///
						3 "flush to somewhere else" ///
						4 "pit latrine without slab/open lit" ///
						5 "no facility/bush/field" ///
						6 "direct to the river, lake or sea" ///
						7 "other"
replace toilet = 5 if v0215==3
label values toilet lab_toilet
label var toilet "Type of toilet"

codebook toilet, tab(30) 
	//Check coding

codebook v0216, tab(30)  
	//Check coding for shared toilet
recode v0216 (2=0) (4=1), gen(shared_toilet) 
	//Check coding: 0=no;1=yes;.=missing
codebook shared_toilet

	
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************

	/*The report for 2015 has no information on what is considered adequate. 
	The 2014 report only considers answers 1 (flushed to piped sewer) or 
	2 (flush to septic tank that is connected to piped sewer) as adequate.
	In 2008, IBGE conducted a National Survey on Basic Sanitation. In this 
	survey report (page 40, footnote 7) it is stated that only toilets
	connected to piped sewers (directly or through a septic tank) are considered 
	adequate. Septic tanks alone, even if a major improvement over pit latrines, 
	depends on several other variables to be considered adequate and this 
	information was not obtained in that survey. Following the country's 
	guideline, the indicator is recoded as following: */ 
	
gen	toilet_mdg = (toilet==1 | toilet==2) & shared_toilet!=1
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */
		
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

	/*Note: PNAD 2015 asks if the water is piped to the dwelling or the yard. 
	It also asks if the water is from a well or spring but does not ask if it is 
	protected or not. The 2015 report does not specify what is considered 
	adequate water supply, but for the 2014 report they consider only piped 
	water as adequate. As such, following the 2014 report, we consider wells and 
	spings as unprotected. */

gen water = .
replace water = 1 if v0211==1 & v0212 == 2 
	/*Piped to dwelling: has piped water in at least one room in the home and 
	water is supplied through the general distribution network*/
replace water = 2 if v0211==3 & v0213==1 
	/*Piped to the plot or yard: has no piped water in at least one room in the 
	home but water is piped by the general distribution network to the 
	property*/
replace water = 3 if (v0211==1 & v0212 == 4) | (v0211 == 3 & v0213 == 3 & v0214 == 2) 
	/*Well or spring: has no piped water in at least one room in the home and
	water used in the home is well or spring located on the property*/
replace water = 4 if (v0211 == 1 & v0212 == 6) | (v0211 == 3 & v0213 == 3 & v0214 == 4) 
	//Other source of water
label define lab_water 1 "Piped water into dwelling" ///
					   2 "Piped water into the plot or yard" ///
					   3 "Water from spring or well" ///
					   4 "Other source" 
label values water lab_water
label var water "Source of drinking water"
tab water, miss
		
gen timetowater = .  
	//PNAD 2015 has no observation for time to water
gen ndwater = .  
	//PNAD 2015 has no observation for non-drinking water
	



*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************
	/*PNAD 2015 did not collect data on time to water. As such for Brazil, the 
	indicator on 'drinking water' does not include the distance to water*/

gen	water_mdg = 1 if water==1 | water==2 
	//Non deprived if water is "piped into dwelling", "piped to yard/plot", 
	
replace water_mdg = 0 if water==3 | water==4 
	//Deprived if it is "well", spring", "other"
	
replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. 
	//Deprived if water is at more than 30 minutes' walk (roundtrip) 

replace water_mdg = . if water==. 

lab var water_mdg "Household has drinking water with MDG standards"
tab water water_mdg, miss


********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************
	
/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor 
Note: PNAD 2015 has no information on floor */
	
gen floor = .
gen floor_imp = .
lab var floor_imp "Household has floor that it is not earth/sand/dung"
tab floor floor_imp, miss	


/* Members of the household are considered deprived if the household has wall 
made of natural or rudimentary materials */
clonevar wall = v0203 
codebook wall, tab(100)
label define lab_wall 	1 "stone or brick (masonry)" ///
						2 "wood" ///
						3 "dirt wall without coating" ///
						4 "reused wood" ///
						5 "straw" ///
						6 "others" 
label values wall lab_wall
label var wall "Type of wall"
	
gen	wall_imp = 1
replace wall_imp = 0 if wall== 3 | wall==4 | wall==5 | wall==6
	/*Deprived if "dirt wall without coating" "straw/grass/reeds/thatch" 
	"reused wood" "other"*/
replace wall_imp = . if wall==. 
	//Please check that missing values remain missing
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
	

	
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials */
clonevar roof = v0204
codebook roof, tab(100)
label define lab_roof 	1 "roof tile" ///
						2 "concrete slab" ///
						3 "wood" ///
						4 "zinc" ///
						5 "reused wood" ///
						6 "straw" ///
						7 "other" 						
label values roof lab_roof
label var roof "Type of roof"
		
gen	roof_imp = 1
replace roof_imp = 0 if roof==5 | roof==6 | roof==7 
	//Deprived if "straw/grass" "reused wood" "other" 
replace roof_imp = . if roof==. 
	//Please check that missing values remain missing
lab var roof_imp "Household has roof that it is not of low quality materials"
tab roof roof_imp, miss



*** Standard MPI ***
/* Members of the household is deprived in housing if the roof, 
floor OR walls are constructed from low quality materials.*/
**************************************************************

	/*PNAD 2015: Household is deprived in housing if the roof OR walls uses 
	low quality materials.*/
gen housing_1 = 1
replace housing_1 = 0 if wall_imp==0 | roof_imp==0
replace housing_1 = . if wall_imp==. & roof_imp==.
//lab var housing_1 "Household has roof & walls that it is not low quality material"
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

clonevar cookingfuel = v0223
codebook cookingfuel, tab(100)
replace cookingfuel = 7 if v0221==3 & v0222==4
	//no stove suggesting no food cooked at home
label define lab_fuel 	1 "lpg gas" ///
						2 "piped gas" ///
						3 "firewood" ///
						4 "coal" ///
						5 "electric" ///
						6 "other" ///
						7 "no stove"						
label values cookingfuel lab_fuel
label var cookingfuel "Type of cooking fuel"
tab cookingfuel, miss


*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel==3 | cookingfuel==4 

replace cooking_mdg = . if cookingfuel==. 

lab var cooking_mdg "Household has cooking fuel by MDG standards"
	/* Non deprived if: "lpg gas", "piped gas", "electric", "other", 
						"no stove, no food cooked in household"
	   Deprived if: "firewood", "coal/lignite" */			 
tab cookingfuel cooking_mdg, miss	


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************
/*Assets that are included in the global MPI: Radio, TV, telephone, bicycle, 
motorbike, refrigerator, car, computer and animal cart
Labels: "no ownership"==0 and yes=="1"
*/

recode v2020 (4=0) (2=1), gen(telephone) 
recode v0220 (4=0) (2=1), gen(mobiletelephone)  
recode v0225 (3=0), gen(radio)
recode v0226 (2=1) (4=0), gen(television) 
recode v0227 (3=0), gen(bw_television)
gen bicycle = .
recode v0228 (2 4=1) (6=0), gen(refrigerator) 
recode v2032 (2 6 = 1) (4 8 = 0), gen(car)  
recode v2032 (4 6 = 1) (2 8 = 0), gen(motorbike) 
recode v0231 (3=0), gen(computer)
gen animal_cart = .


	//Combine information on telephone and mobiletelephone
replace telephone=1 if telephone==0 & mobiletelephone==1
replace telephone=1 if telephone==. & mobiletelephone==1

	//Combine information on black and white tv & TV
replace television=1 if television==0 & bw_television==1
replace television=1 if television==. & bw_television==1



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
desc v4602 v4618	
clonevar strata = v4602
clonevar psu = v4618

	//Retain year, month & date of interview:
desc v4600 v4601 v0101
clonevar year_interview = v0101 
	/*Note: In PNAD 2015, the variables on month and day of interview are 
	missing for everyone.*/
gen month_interview = .
gen date_interview = .
	
	
	//Generate presence of subsample
gen subsample = .	


*** Policy if dataset lacks data of child death and lacks nutrition ***

/*

In the case that a dataset lacks the date of child death, and also lacks 
nutritional information, then a person is considered MPI poor if they are 
deprived in one-third of weighted indicators and in more than one indicator. 
Thus if they are deprived in child mortality, they must be deprived in one 
additional indicator to be identified as poor. The PNAD Brazil is unique in the 
global MPI 2018 in that it is the only dataset with this condition.

The justification is as follows. The global MPI 2018 considers child mortality 
in the last 5 years. Datasets that lack the date of child death greatly 
overestimate child mortality in the last five years, including a ‘stock’ of 
tragedies that may not reflect recent multidimensional poverty. When nutrition 
data are present, people are non-poor if they are only deprived in 
child mortality. But if nutrition data are absent, all persons deprived only in 
child mortality (even if this occurred many years ago) would be identified as 
MPI poor, which would overestimate poverty and reduce comparability. So in this 
case persons are identified as MPI poor if they are deprived in at least one 
indicator in addition to child mortality.

*/

count if  hh_mortality==0 & hh_child_atten==1 &  hh_years_edu6==1 & ///
		  electricity==1 & water_mdg==1 & toilet_mdg==1 & housing_1==1 & ///
		  cooking_mdg==1 & hh_assets2==1
	/*Note that 14,700 (4.12%) individuals were identified as deprived as they 
	are living in households that have reported at least one child mortality 
	incidence. However, 5,195 of these 14,700 individuals live in households
	where they are not deprived in any other indicators except in child 
	mortality indicator. As such, these 5,195 individuals are replaced as 
	non-deprived in child mortality, with assumption that they are less likely
	to be multidimesnionally poor. */	  

replace   hh_mortality=1 if ///
	      hh_mortality==0 & hh_child_atten==1 &  hh_years_edu6==1 & ///
		  electricity==1 & water_mdg==1 & toilet_mdg==1 & housing_1==1 & ///
		  cooking_mdg==1 & hh_assets2==1



*** Rename key global MPI indicators for estimation ***
	/* Note: In the case of Brazil PNAD 2015, there is no birth history file. 
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
char _dta[cty] "Brazil"
char _dta[ccty] "BRA"
char _dta[year] "2015" 	
char _dta[survey] "PNAD"
char _dta[ccnum] "076"
char _dta[type] "micro"


*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]'). Last save: `c(filedate)'."	
save "$path_out/bra_pnad15.dta", replace 
