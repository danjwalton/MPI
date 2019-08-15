/*	Example: survey_who2007.do using survey_who2007.dta */

clear

set more 1

/*	Higher memory might be necessary for larger datasets */
set memory 50m
set maxvar 10000


/* Indicate to the Stata compiler where the who2007.ado file is stored*/
adopath + "D:\WHO 2007 Stata/"


/* Load the data file */
use "D:\WHO 2007 workdata\survey_who2007.dta", clear

/* generate the first three parameters reflib, datalib & datalab	*/
gen str60 reflib="D:\WHO 2007 Stata"
lab var reflib "Directory of reference tables"

gen str60 datalib="D:\WHO 2007 workdata"
lab var datalib "Directory for datafiles"

gen str30 datalab="survey_2007"
lab var datalab "Working file"


/*	check the variable for "sex"	1 = male, 2=female */
desc sex
tab sex


/*	check the variable for "age"	*/
desc agemons
summ agemons


/*	define your ageunit	*/
gen str6 ageunit="months"				/* or gen ageunit="days", gen ageunit="years" */
lab var ageunit "=days or =months or =years"


/*	check the variable for body "weight" which must be in kilograms*/
/* 	NOTE: if not available, please create as [gen weight=.]*/
desc weight
summ weight

/* 	check the variable for "height" which must be in centimeters*/ 
/* 	NOTE: if not available, please create as [gen height=.]*/
desc height 
summ height 


/* 	check the variable for "oedema"*/
/* 	NOTE: if not available, please create as [gen str1 oedema="n"]*/
desc oedema
tab oedema


/*	check the variable for "sw" for the sampling weight*/
/* 	NOTE: if not available, please create as [gen sw=1]*/
desc sw
summ sw

/* 	Fill in the macro parameters to run the command */
who2007 reflib datalib datalab sex agemons ageunit weight height oedema sw 

