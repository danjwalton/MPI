required.packages <- c("reshape2","ggplot2","data.table","jsonlite","RCurl","XML","xml2","RStata","stringr","foreign")
lapply(required.packages, require, character.only=T)

wd <- "G:/My Drive/Work/GitHub/MPI/"
setwd(wd)

basename.url=function(path){
  path_sep=strsplit(path,split="/")[[1]]
  path_len=length(path_sep)
  return(path_sep[path_len])
}
mics_dat <- fromJSON("project_data/mics.json",flatten=T)
mics_dat <- subset(mics_dat,dataset.url!="")
urls <- mics_dat$dataset.url
uniquesavs=c()

for(url in urls){
  if(exists("ch")){rm(ch)}
  if(exists("hh")){rm(hh)}
  if(exists("hl")){rm(hl)}
  if(exists("wm")){rm(wm)}
  if(exists("mn")){rm(mn)}
  if(exists("bh")){rm(bh)}
  if(exists("ph")){rm(bh)}
  if(exists("who_z")){rm(who_z)}
  if(exists("fg")){rm(fg)}
  if(exists("tn")){rm(tn)}
  if(exists("fs")){rm(fs)}
  if(exists("uncaptured_list")){rm(uncaptured_list)}
  filename <- gsub("%20","_",basename.url(url))
  uniquename <- substr(filename,1,nchar(filename)-4)
  message(paste(uniquename)," ... ",match(url,urls),"/",length(urls))
  tmp <- tempfile()
  download.file(url,tmp,quiet=T)
  zip.contents <- unzip(tmp,exdir="large.data")
  if(!(exists("zip.contents"))){ next; }
  file.remove(tmp)
  
  if("zip" %in% str_sub(zip.contents,-3)){
    message("multiple zips")
     zip.contents=unzip(zip.contents[which(str_sub(zip.contents,-3)=="zip")],exdir="large.data")
  }else{
  zip.contents <- zip.contents[which(str_sub(zip.contents,-3)=="sav")]
  }
  all.sav <- zip.contents[which(grepl("(.*)sav",tolower(basename(zip.contents))))]
  # uniquesavs=unique(c(uniquesavs,all.sav))
  ch.sav <- zip.contents[which(grepl("^ch(.*)sav|(.*)ch.sav",tolower(basename(zip.contents))))]
  ch.sav2 <- zip.contents[which(grepl("^under5(.*)sav|(.*)under5.sav",tolower(basename(zip.contents))))]
  ch.sav3 <- zip.contents[which(grepl("^underfive(.*)sav|(.*)underfive.sav",tolower(basename(zip.contents))))]
  ch.sav=c(ch.sav,ch.sav2,ch.sav3)
  hh.sav <- zip.contents[which(grepl("^hh(.*)sav|(.*)hh.sav",tolower(basename(zip.contents))))]
  hl.sav <- zip.contents[which(grepl("^hl(.*)sav|(.*)hl.sav",tolower(basename(zip.contents))))]
  wm.sav <- zip.contents[which(grepl("^wm(.*)sav|(.*)wm.sav",tolower(basename(zip.contents))))]
  wm.sav2 <- zip.contents[which(grepl("^woman(.*)sav|(.*)woman.sav",tolower(basename(zip.contents))))]
  wm.sav <- c(wm.sav,wm.sav2)
  mn.sav <- zip.contents[which(grepl("^mn(.*)sav|(.*)mn.sav",tolower(basename(zip.contents))))]
  mn.sav2 <- zip.contents[which(grepl("^man(.*)sav|(.*)man.sav",tolower(basename(zip.contents))))]
  mn.sav <- c(mn.sav,mn.sav2)
  bh.sav <- zip.contents[which(grepl("^bh(.*)sav|(.*)bh.sav",tolower(basename(zip.contents))))]
  ph.sav <- zip.contents[which(grepl("^ph(.*)sav|(.*)ph.sav",tolower(basename(zip.contents))))]
  who_z.sav <- zip.contents[which(grepl("^who_z(.*)sav|(.*)who_z.sav",tolower(basename(zip.contents))))]
  fg.sav <- zip.contents[which(grepl("^fg(.*)sav|(.*)fg.sav",tolower(basename(zip.contents))))]
  tn.sav <- zip.contents[which(grepl("^tn(.*)sav|(.*)tn.sav",tolower(basename(zip.contents))))]
  fs.sav <- zip.contents[which(grepl("^fs(.*)sav|(.*)fs.sav",tolower(basename(zip.contents))))]
  if(length(ch.sav)>0){
    ch <- read.spss(ch.sav, use.value.labels = F)
    ch["FILTER_$"] <- NULL
  }else{
    ch <- NULL
  }
  if(length(hh.sav)>0){
    hh <- read.spss(hh.sav, use.value.labels = T)
    hh["FILTER_$"] <- NULL
  }else{
    hh <- NULL
  }
  if(length(hl.sav)>0){
    hl <- read.spss(hl.sav, use.value.labels = T)
    hl["FILTER_$"] <- NULL
  }else{
    hl <- NULL
  }
  if(length(wm.sav)>0){
    wm <- read.spss(wm.sav, use.value.labels = T)
    wm["FILTER_$"] <- NULL
  }else{
    wm <- NULL
  }
  if(length(mn.sav)>0){
    if(grepl("mnmn",tolower(mn.sav))){
      mn.sav <- mn.sav[grepl("mnmn",tolower(mn.sav))]
    }
    mn <- read.spss(mn.sav, use.value.labels = T)
    mn["FILTER_$"] <- NULL
  }else{
    mn <- NULL
  }
  if(length(bh.sav)>0){
    if(grepl("bhbh",tolower(bh.sav))){
      bh.sav <- bh.sav[grepl("bhbh",tolower(bh.sav))]
    }
    bh <- read.spss(bh.sav, use.value.labels = T)
    bh["FILTER_$"] <- NULL
  }else{
    bh <- NULL
  }
  if(length(ph.sav)>0){
    if(grepl("phph",tolower(ph.sav))){
      ph.sav <- ph.sav[grepl("phph",tolower(ph.sav))]
    }
    ph <- read.spss(ph.sav, use.value.labels = T)
    ph["FILTER_$"] <- NULL
  }else{
    ph <- NULL
  }
  if(length(who_z.sav)>0){
    who_z <- read.spss(who_z.sav, use.value.labels = F)
    who_z["FILTER_$"] <- NULL
  }else{
    who_z <- NULL
  }
  if(length(fg.sav)>0){
    fg <- read.spss(fg.sav, use.value.labels = F)
    fg["FILTER_$"] <- NULL
  }else{
    fg <- NULL
  }
  if(length(tn.sav)>0){
    tn <- read.spss(tn.sav, use.value.labels = F)
    tn["FILTER_$"] <- NULL
  }else{
    tn <- NULL
  }
  if(length(fs.sav)>0){
    fs <- read.spss(fs.sav, use.value.labels = F)
    fs["FILTER_$"] <- NULL
  }else{
    fs <- NULL
  }
  uncaptured=all.sav[which(!all.sav %in% c(
      ch.sav
      ,hh.sav
      ,hl.sav
      ,wm.sav
      ,mn.sav
      ,bh.sav
      ,ph.sav
      ,who_z.sav
      ,fg.sav
      ,tn.sav
      ,fs.sav
    ))]
  uncaptured_list=list()
  if(length(uncaptured)>0){
    for(uncap in uncaptured){
      data.tmp= read.spss(uncap, use.value.labels = T)
      #uncap.labs <- data.frame(var.name=names(data.tmp),var.lab=attributes(data.tmp)$variable.labels)
      data.tmp$filename <- uniquename
      uncap.list=list("data"=data.tmp)#,"labs"=uncap.labs)
      uncaptured_list[[basename(uncap)]]=uncap.list
    }
  }
  dtapath <- paste0("project_data/DHS MICS data files/",uniquename)
  dir.create(dtapath)
  tryCatch({
    write.dta(as.data.frame(ch),paste0(dtapath,"/ch.dta"),version=12)
  },error=function(e){return(NULL)})
  tryCatch({
    write.dta(as.data.frame(hh),paste0(dtapath,"/hh.dta"),version=12)
  },error=function(e){return(NULL)})
  tryCatch({
    write.dta(as.data.frame(hl),paste0(dtapath,"/hl.dta"),version=12)
  },error=function(e){return(NULL)})
  tryCatch({
    write.dta(as.data.frame(wm),paste0(dtapath,"/wm.dta"),version=12)
  },error=function(e){return(NULL)})
  tryCatch({
    write.dta(as.data.frame(mn),paste0(dtapath,"/mn.dta"),version=12)
  },error=function(e){return(NULL)})
  tryCatch({
    write.dta(as.data.frame(bh),paste0(dtapath,"/bh.dta"),version=12)
  },error=function(e){return(NULL)})
  tryCatch({
    write.dta(as.data.frame(ph),paste0(dtapath,"/ph.dta"),version=12)
  },error=function(e){return(NULL)})
  tryCatch({
    write.dta(as.data.frame(who_z),paste0(dtapath,"/who_z.dta"),version=12)
  },error=function(e){return(NULL)})
  tryCatch({
    write.dta(as.data.frame(fg),paste0(dtapath,"/fg.dta"),version=12)
  },error=function(e){return(NULL)})
  tryCatch({
    write.dta(as.data.frame(tn),paste0(dtapath,"/tn.dta"),version=12)
  },error=function(e){return(NULL)})
  tryCatch({
    write.dta(as.data.frame(fs),paste0(dtapath,"/fs.dta"),version=12)
  },error=function(e){return(NULL)})
  rm(zip.contents)
}
