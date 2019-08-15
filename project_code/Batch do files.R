required.packages <- c("reshape2","ggplot2","data.table","jsonlite","RCurl","XML","xml2","RStata","haven","stringr")
lapply(required.packages, require, character.only=T)

wd <- "G:/My Drive/Work/GitHub/MPI/"
wd2 <- "G:/My Drive/Work/GitHub/MPI/project_data/DHS MICS data files/"
setwd(wd2)

###Extract downloaded DHS zips
zips <- list.files(pattern="*.zip", ignore.case = T)

pb <- txtProgressBar(0,length(zips),style=3)
for(i in 1:length(zips)){
  file <- paste0(substr(zips[i],0,nchar(zips[i])-6),"FL")
  suppressWarnings(unzip(zips[i],
                         files=paste0(file,".DTA")
                         ,overwrite=F))
  setTxtProgressBar(pb,i)
}
close(pb)
dta.files <- list.files(pattern="*.dta", ignore.case = T)
file.rename(dta.files, toupper(dta.files))
file.remove(zips)

###Download do files for most recent MPI
url <- "https://ophi.org.uk/multidimensional-poverty-index/mpi-resources/"
wp <- read_html(url)
doc <- htmlParse(wp)
links <- xpathSApply(doc, "//a/@href")
do.links <- links[grepl("2019.do", links)]
do.names <- substr(do.links,40,nchar(do.links))

setwd(wd)

###Edit do files to set data path to wd
for(i in 1:length(do.links)){
  download.file(do.links[i],paste0("project_code/do files/",do.names[i]), quiet=T)
  do <- readLines(paste0("project_code/do files/",do.names[i]))
  do[grepl("global path_in",do)] <- paste0("global path_in ",wd,"/project_data/DHS MICS data files")
  do[grepl("global path_out",do)] <- paste0("global path_out ",wd,"/project_data/MPI out")
  do[grepl("global path_ado",do)] <- paste0("global path_ado ",wd,"/project_data/ado")
  do <- str_replace(do,"FL.dta","FL.DTA")
  writeLines(do, paste0("project_code/do files/",do.names[i]))
}

###Specific do file changes because consistency is obviously a bit  difficult for those DHS and MPI people
do <- readLines("project_code/do files/ner_dhs12_dp2019.do")
do <- gsub("ner12","NER12",do)
writeLines(do,"project_code/do files/ner_dhs12_dp2019.do")
do <- readLines("project_code/do files/nam_dhs13_dp2019.do")
do <- gsub("NMMR60FL.DTA","NMMR61FL.DTA",do)
writeLines(do,"project_code/do files/nam_dhs13_dp2019.do")
do <- readLines("project_code/do files/uga_dhs16_dp2019.do")
do <- gsub("7HFL","7BFL", do)
writeLines(do,"project_code/do files/uga_dhs16_dp2019.do")
do <- readLines("project_code/do files/jor_dhs17-18_dp2019.do")
do <- gsub("71FL","72FL", do)
writeLines(do,"project_code/do files/jor_dhs17-18_dp2019.do")
do <- readLines("project_code/do files/tjk_dhs17_dp2019.do")
do <- gsub("70FL","71FL", do)
writeLines(do,"project_code/do files/tjk_dhs17_dp2019.do")
do <- readLines("project_code/do files/mdg_dhs08-09_dp2019.do")
do <- gsub("mDG","mdg", do)
writeLines(do,"project_code/do files/mdg_dhs08-09_dp2019.do")
do <- readLines("project_code/do files/tza_dhs15-16_dp2019.do")
do <- gsub("7H","7A", do)
writeLines(do,"project_code/do files/tza_dhs15-16_dp2019.do")

dhs.names <- do.names[grepl("dhs",do.names)]
mics.names <- do.names[grepl("mics",do.names)]

###Set Stata options
options("RStata.StataPath"="\"D:\\Program Files (x86)\\Stata13\\StataMP-64\"")
options("RStata.StataVersion"=13.1)
stata("set more off, permanently")

###Iterate through DHS surveys
pb <- txtProgressBar(0,length(dhs.names),style=3)
for(i in 1:length(dhs.names)){
  stata(paste0("project_code/do files/",dhs.names[i]))
  setTxtProgressBar(pb,i)
}
close(pb)