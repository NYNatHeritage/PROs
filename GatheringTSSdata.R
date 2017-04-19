##Script to evaluate the TSS scores coming out of the models
##Script will loop through a folder of Rdata files, load the file, extract the Scientific name, commin name, # EOs, #Polys, #points,and Mean TSS score

##Get the files in the director
#setwd("D:\\GIS Projects\\Lands_Forests\\BackUpRDataFiles\\BaldEagles\\")
#setwd("D:\\GIS Projects\\Lands_Forests\\BackUpRDataFiles")
setwd("C:\\Users\\Public\\2015Pros\\RdataFiles")
d_test <- dir(pattern = "*.Rdata",full.names=FALSE,recursive=FALSE,include.dirs=FALSE)
n=length(d_test)
sample<-d_test[1:10]
n=length(sample)
TSS_check<-function(n){
  

# scientific_name<-vector("list",length=length(sample))
# common_name<-vector("list",length=length(sample))
# EDM_code<-vector("list",length=length(sample))
# number_EOs<-vector("list",length=length(sample))
# number_polys<-vector("list",length=length(sample))
# number_pts<-vector("list",length=length(sample))
# habitat_type<-vector("list",length=length(sample))
# TSS_score<-vector("list",length=length(sample))
  
  scientific_name<-list()
  common_name<-list()
  EDM_code<-list()
  number_EOs<-list()
  number_polys<-list()
  number_pts<-list()
  habitat_type<-list()
  TSS_score<-list()

for (i in seq(185)) {
  fileName <- d_test[i]
  setwd("C:\\Users\\Public\\2015Pros\\RdataFiles")
  load(fileName)
  scientific_name.element<-as.character(ElementNames[[1]])
  common_name.element<-as.character(ElementNames[[2]])
  EDM_code.element<-as.character(ElementNames[[3]])
  number_EOs.element<-length(unique(df.in$eo_id))
  number_polys.element<-numPys
  number_pts.element<-nrow(subset(df.full,pres==1))
  TSS_score.element<-tss.summ$mean
  if (length(ElementNames<5)){
    habitat_type.element<-""
  }
  else{
    if (is.na(ElementNames[[5]])){
      habitat_type.element<-""
    }
    else{
      habitat_type.element<-as.character(ElementNames[[5]])
      
      
    }
  }
  
  scientific_name<-c(scientific_name,scientific_name.element)
  common_name<-c(common_name,common_name.element)
  EDM_code<-c(EDM_code,EDM_code.element)
  number_EOs<-c(number_EOs,number_EOs.element)
  number_polys<-c(number_polys,number_polys.element)
  number_pts<-c(number_pts,number_pts.element)
  habitat_type<-c(habitat_type,habitat_type.element)
  TSS_score<-c(TSS_score,TSS_score.element)
  #return TSS_score
  
  rm(list=ls()[!ls() %in% c("i","d_test","scientific_name","common_name","EDM_code","number_EOs","number_polys","number_pts","habitat_type","TSS_score")])
}

#Results<-data.frame(scientific_name,common_name,habitat_type,EDM_code,number_EOs,number_polys,number_pts,TSS_score,stringsAsFactors=FALSE)
Results<-cbind(scientific_name,common_name,habitat_type,EDM_code,number_EOs,number_polys,number_pts,TSS_score)
Data_Results<-data.frame(Results)
Data_Results$TSS_score<-as.numeric(Data_Results$TSS_score)
Data_Results$number_EOs<-as.numeric(Data_Results$number_EOs)
Data_Results$number_polys<-as.numeric(Data_Results$number_polys)
Data_Results$number_pts<-as.numeric(Data_Results$number_pts)
Data_Results$scientific_name<-as.character(Data_Results$scientific_name)
Data_Results$common_name<-as.character(Data_Results$common_name)
Data_Results$habitat_type<-as.character(Data_Results$habitat_type)
Data_Results$EDM_code<-as.character(Data_Results$EDM_code)
sapply(Data_Results,class)


}