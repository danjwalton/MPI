install.packages("haven",version="1.1.2")
require(pkgload)
unload("haven")
require(haven)

wd2 <- "G:/My Drive/Work/GitHub/p20_private_data/project_data/MICS auto/"
wd <- "G:/My Drive/Work/GitHub/MPI/"
setwd(wd2)
rdatas <- list.files(pattern="*.RData")

setwd(wd)
for(rdata in rdatas){
  load(paste0(wd2,rdata))
  name <- substr(rdata,0,nchar(rdata)-6)
  dir.create(paste0(wd,"project_data/DHS MICS data files/",name))
  tryCatch({
  if(exists("ch")){ch["FILTER_$"] <- NULL
    write_dta(as.data.frame(ch),paste0(wd,"project_data/DHS MICS data files/",name,"/ch.dta"),version=13.1)}
  if(exists("hh")){hh["FILTER_$"] <- NULL
    write_dta(as.data.frame(hh),paste0(wd,"project_data/DHS MICS data files/",name,"/hh.dta"),version=13.1)}
  if(exists("hl")){hl["FILTER_$"] <- NULL
    write_dta(as.data.frame(hl),paste0(wd,"project_data/DHS MICS data files/",name,"/hl.dta"),version=13.1)}
  if(exists("wm")){wm["FILTER_$"] <- NULL
    write_dta(as.data.frame(wm),paste0(wd,"project_data/DHS MICS data files/",name,"/wm.dta"),version=13.1)}
  
  if(exists("uncaptured_list")){
    bh <- uncaptured_list$bh.sav$data
    mn <- uncaptured_list$mn.sav$data
    fg <- uncaptured_list$fg.sav$data
    tn <- uncaptured_list$tn.sav$data
    who_z <- uncaptured_list$who_z.sav$data
    fs <- uncaptured_list$fs.sav$data
  }
    
  if(exists("mn")){mn["FILTER_$"] <- NULL
    write_dta(as.data.frame(mn),paste0(wd,"project_data/DHS MICS data files/",name,"/mn.dta"),version=13.1)}
  if(exists("bh")){bh["FILTER_$"] <- NULL
    write_dta(as.data.frame(bh),paste0(wd,"project_data/DHS MICS data files/",name,"/bh.dta"),version=13.1)}
  if(exists("fg")){fg["FILTER_$"] <- NULL
    write_dta(as.data.frame(fg),paste0(wd,"project_data/DHS MICS data files/",name,"/fg.dta"),version=13.1)}
  if(exists("tn")){tn["FILTER_$"] <- NULL
    write_dta(as.data.frame(tn),paste0(wd,"project_data/DHS MICS data files/",name,"/tn.dta"),version=13.1)}
  if(exists("who_z")){who_z["FILTER_$"] <- NULL
    write_dta(as.data.frame(who_z),paste0(wd,"project_data/DHS MICS data files/",name,"/who_z.dta"),version=13.1)}
  if(exists("fs")){fs["FILTER_$"] <- NULL
    write_dta(as.data.frame(fs),paste0(wd,"project_data/DHS MICS data files/",name,"/fs.dta"),version=13.1)}
  },error=function(e) return(NULL))
}
