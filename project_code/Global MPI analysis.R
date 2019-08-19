required.packages <- c("reshape2","ggplot2","data.table","stringr","haven","weights","WDI")
lapply(required.packages, require, character.only=T)

wd <- "G:/My Drive/Work/GitHub/MPI/"
setwd(wd)

if(!("all_mpi.RData" %in% list.files("project_data"))){
  memory.limit(size=32000)
  datas <- list.files("project_data/MPI out", pattern=".dta")
  keep <- c("hhsize","region","weight","area","sex","age","marital","d_cm","d_nutr","d_satt","d_educ","d_elct","d_wtr","d_sani","d_hsg","d_ckfl","d_asst")
  deps <- list()
  pb <- txtProgressBar(0,length(datas),style=3)
  for(i in 1:length(datas)){
    cc <- substr(datas[i],0,3)
    mpi <- read_dta(paste0("project_data/MPI out/",datas[i]))
    labels <- unlist(lapply(mpi, function(x) attributes(x)$`label`))
    cols <- colnames(mpi)
    mpi <- mpi[,(cols %in% keep)]
    mpi$weight <- mpi$weight/sum(mpi$weight,na.rm = T)
    mpi <- as.data.table(sapply(mpi, as.numeric))
    mpi$cc <- cc
    deps[[i]] <- mpi
    setTxtProgressBar(pb,i)
    rm(mpi)
  }
  all.mpi <- rbindlist(deps, fill=T)
  rm(deps)
  save(all.mpi, file="project_data/all_mpi.RData")
}

load("project_data/all_mpi.RData")

all.mpi$d_health <- rowMeans(cbind(all.mpi$d_nutr,all.mpi$d_cm), na.rm=T)
all.mpi$d_education <- rowMeans(cbind(all.mpi$d_satt,all.mpi$d_educ), na.rm=T)
all.mpi$d_living <- rowMeans(cbind(all.mpi$d_ckfl,all.mpi$d_sani,all.mpi$d_wtr,all.mpi$d_elct,all.mpi$d_hsg,all.mpi$d_asst), na.rm=T)
all.mpi$d_all <- rowMeans(cbind(all.mpi$d_health,all.mpi$d_education,all.mpi$d_living),na.rm=T)

pop2018 <- as.data.table(WDI("all","SP.POP.TOTL",start=2018, end=2018,extra=T))
pop2018[iso2c=="MK"]$iso3c <- "MKD"
pop2018 <- pop2018[,c("iso3c","SP.POP.TOTL")]
pop2018$iso3c <- tolower(pop2018$iso3c)
all.mpi <- merge(all.mpi,pop2018,by.x="cc",by.y="iso3c")

all.mpi$global.weight <- (all.mpi$weight*all.mpi$SP.POP.TOTL)/sum(all.mpi$weight*all.mpi$SP.POP.TOTL,na.rm=T)
all.mpi[is.na(global.weight)]$global.weight <- 0
