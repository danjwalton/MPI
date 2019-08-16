required.packages <- c("reshape2","ggplot2","data.table","jsonlite","RCurl","XML","xml2","RStata","stringr","foreign","pkgload")
lapply(required.packages, require, character.only=T)

install.packages("https://cran.rstudio.com//src/contrib/Archive/haven/haven_1.1.2.tar.gz")
unload("haven")
require(haven)

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
# urls <- urls[c(184:length(urls))]
uniquesavs=c()

for(url in urls){
  if(exists("ch")){rm(ch)}
  if(exists("hh")){rm(hh)}
  if(exists("hl")){rm(hl)}
  if(exists("wm")){rm(wm)}
  if(exists("mn")){rm(mn)}
  if(exists("bh")){rm(bh)}
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
  if(length(ch.sav)>0){
    ch <- read.spss(ch.sav, use.value.labels = F)
    ch["FILTER_$"] <- NULL
    #ch.labs <- data.frame(var.name=names(ch),var.lab=attributes(ch)$variable.labels)
    #ch$filename <- uniquename
  }else{
    ch <- NULL
    #ch.labs <- NULL
  }
  if(length(hh.sav)>0){
    hh <- read.spss(hh.sav, use.value.labels = F)
    hh["FILTER_$"] <- NULL
    #hh.labs <- data.frame(var.name=names(hh),var.lab=attributes(hh)$variable.labels)
    #hh$filename <- uniquename
  }else{
    hh <- NULL
    #hh.labs <- NULL
  }
  if(length(hl.sav)>0){
    hl <- read.spss(hl.sav, use.value.labels = F)
    hl["FILTER_$"] <- NULL
    #hl.labs <- data.frame(var.name=names(hl),var.lab=attributes(hl)$variable.labels)
    #hl$filename <- uniquename
  }else{
    hl <- NULL
    #hl.labs <- NULL
  }
  if(length(wm.sav)>0){
    wm <- read.spss(wm.sav, use.value.labels = F)
    wm["FILTER_$"] <- NULL
    #if(length(attributes(wm)$variable.labels)>0){
    #wm.labs <- data.frame(var.name=names(wm),var.lab=attributes(wm)$variable.labels)
    #}else{
    #  wm.labs=data.frame(var.name=NA,var.lab=NA)
    #}
    #wm$filename <- uniquename
  }else{
    wm <- NULL
    #wm.labs <- NULL
  }
  if(length(mn.sav)>0){
    if(grepl("mnmn",tolower(mn.sav))){
      mn.sav <- mn.sav[grepl("mnmn",tolower(mn.sav))]
    }
    mn <- read.spss(mn.sav, use.value.labels = T)
    mn["FILTER_$"] <- NULL
    #if(length(attributes(mn)$variable.labels)>0){
    #mn.labs <- data.frame(var.name=names(mn),var.lab=attributes(mn)$variable.labels)
    #}else{
    #  mn.labs=data.frame(var.name=NA,var.lab=NA)
    #}
    #mn$filename <- uniquename
  }else{
    mn <- NULL
    #mn.labs <- NULL
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
  uncaptured=all.sav[which(!all.sav %in% c(
      ch.sav
      ,hh.sav
      ,hl.sav
      ,wm.sav
      ,mn.sav
      ,bh.sav
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
    write_dta(as.data.frame(ch),paste0(dtapath,"/ch.dta"),version=13.1)
    write_dta(as.data.frame(hh),paste0(dtapath,"/hh.dta"),version=13.1)
    write_dta(as.data.frame(hl),paste0(dtapath,"/hl.dta"),version=13.1)
    write_dta(as.data.frame(wm),paste0(dtapath,"/wm.dta"),version=13.1)
    write_dta(as.data.frame(mn),paste0(dtapath,"/mn.dta"),version=13.1)
    write_dta(as.data.frame(bh),paste0(dtapath,"/bh.dta"),version=13.1)
  },error=function(e){return(NULL)})
  rm(zip.contents)
}
