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

setwd(wd)
###Retrieve MICS survey details
mics_dat = fromJSON("project_data/mics.json",flatten=T)
mics_dat=mics_dat[which(mics_dat$dataset.status=="Available"),]
datasets=sapply(mics_dat$dataset.url,strsplit,split="/")
datasets=sapply(datasets,`[[`,i=9)
datasets=substring(datasets,0,nchar(datasets)-4)
filename = gsub("%20","_",datasets)
mics_dat$filename=filename
mics_dat=mics_dat[,c("round","country","year","filename")]
#mics_dat$year[which(nchar(mics_dat$year)>4)]=substring(mics_dat$year[which(nchar(mics_dat$year)>4)],1,4)

mics.dirs <- as.data.table(list.dirs(wd2, full.names = F,recursive = F))
mics.dirs <- merge(mics.dirs,mics_dat,by.x="V1",by.y="filename",all.x=T)
mics.dirs[country=="Côte d'Ivoire"]$country <- "CÃ´te d'Ivoire"
mics.dirs[country=="Lao People's Democratic Republic"]$country <- "Lao PDR"
mics.dirs[country=="Moldova, Republic of"]$country <- "Moldova"
mics.dirs[country=="State of Palestine"]$country <- "Palestine, State of"
mics.dirs[country=="South Sudan, Republic of"]$country <- "South Sudan"
mics.dirs[country=="Macedonia, The Former Yugoslav Republic of"]$country <- "TFYR of Macedonia"
mics.dirs[country=="Viet Nam"]$country <- "Vietnam"
mics.dirs[country=="Swaziland"]$country <- "eSwatini"
mics.dirs[country=="Vanuatu" & year=="2007-2008"]$year <- "2007"
mics.dirs[country=="Mongolia" & year=="2013-2014"]$year <- "2013"

###Download do files for most recent MPI
url <- "https://ophi.org.uk/multidimensional-poverty-index/mpi-resources/"
wp <- read_html(url)
doc <- htmlParse(wp)
links <- xpathSApply(doc, "//a/@href")
do.links <- links[grepl("2019.do", links)]
do.names <- substr(do.links,40,nchar(do.links))

###Edit do files and pull survey info
docodelist <- list()
for(i in 1:length(do.links)){
  download.file(do.links[i],paste0("project_code/do files/",do.names[i]), quiet=T)
  do <- readLines(paste0("project_code/do files/",do.names[i]))
  
  do.details <- do[grep("char _dta",do)]
  do.details <- strsplit(do.details,'[\"]',fixed=F)
  tmpcodelist <- list()
  for(j in 1:length(do.details)){
    tmpcodelist[[j]] <- do.details[[j]][2]
  }
  docodelist[[i]] <- unlist(tmpcodelist)
  rm(tmpcodelist)
  rm(do.details)
  
  if(docodelist[[i]][4]=="DHS"){
    do[grepl("global path_in",do)] <- paste0("global path_in ",wd,"/project_data/DHS MICS data files")
    do[grepl("global path_out",do)] <- paste0("global path_out ",wd,"/project_data/MPI out")
    do[grepl("global path_ado",do)] <- paste0("global path_ado ",wd,"/project_data/ado")
    do <- str_replace(do,"FL.dta","FL.DTA")
  } else {
    if(docodelist[[i]][4]=="MICS"){
      dir <- mics.dirs[country==docodelist[[i]][1] & year==docodelist[[i]][3]]$V1
      do[grepl("global path_in",do)] <- paste0("global path_in ",wd,"/project_data/DHS MICS data files/",dir)
      do[grepl("global path_out",do)] <- paste0("global path_out ",wd,"/project_data/MPI out")
      do[grepl("global path_ado",do)] <- paste0("global path_ado ",wd,"/project_data/ado")
    }
  }
  
  writeLines(do, paste0("project_code/do files/",do.names[i]))
}

docodelist <- as.data.table(t(as.data.frame(docodelist)))
row.names(docodelist) <- c()
colnames(docodelist) <- c("Country","Code","Year","Type","x","y")
docodelist$do <- do.names

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

###Set Stata options
options("RStata.StataPath"="\"D:\\Program Files (x86)\\Stata13\\StataMP-64\"")
options("RStata.StataVersion"=13.1)
stata("set more off, permanently")

###Iterate through surveys
pb <- txtProgressBar(0,length(mics.names),style=3)
for(i in 1:length(mics.names)){
    stata(paste0("project_code/do files/",mics.names[i]))
  setTxtProgressBar(pb,i)
}
close(pb)