##Step 1: First get the environmental variables into raster format from Tiff

setwd("C:\\Users\\Public\\Env_Var_Copy\\Env_Variables")
#fn <- dir(pattern=".tif$") # grab only *.aux files
##Only Uncomment if you lose native raster versions of tiffs and need to rebuild the raster stack
# ##Read in tiffs to native rasters and add rasters to stack
# ##create empty stack
# require(raster)
# fn2 <- gsub('.tif', "", fn) # removes the ?tifx? from each string
# raster_list=vector()
# for(i in 1:length(fn2)){
#   fnname <- fn2[[i]]
#   fnraster<-fn[[i]]
#   #clnname<-gsub('tif',"",fn)
#   temp_raster=raster(fnraster)
#   assign(fnname,temp_raster)
#   append(raster_list,fnname)
#   fnname<-writeRaster(temp_raster,filename=paste(fnname,".grd",sep=""),format="raster")
# }

##Step 2: Stack the Rasters
# #Only uncomment if you lose raster stack and need to rebuild
#setwd("C:\\Users\\Public\\Env_Var_Copy\\Env_Variables")
setwd("D:\\Env_Var_Copy\\Env_Variables")
gn <- dir(pattern=".grd") # grab only *.grd files

##If the Environmental Variables are already in the environment then get your Rdata files

##Get Rdata Files
library(randomForest)
#source('C:/Users/Public/2015Pros/RasterPredictMod.R')
#setwd("C:\\Users\\Public\\2015Pros\\RdataFiles")
#setwd("C:\\Users\\Public\\2015Pros\\RdataFiles_subset\\RunonRapunzel2")
#setwd("C:\\Users\\Public\\2015Pros\\RdataFiles_subset\\RunonRapunzel3")
#setwd("C:\\Users\\Public\\2015Pros\\RdataFiles_subset\\RunonRapunzel4")
#setwd("C:\\Users\\Public\\2015Pros\\RdataFiles_subset\\RunonRapunzel5")
#setwd("C:\\Users\\Public\\2015Pros\\RdataFiles_subset\\RunonRapunzel6")
#setwd("C:\\Users\\Public\\2015Pros\\RdataFiles\\July_Rerun")
setwd("C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\RdataFiles")
d_predict <- dir(pattern = ".Rdata$",full.names=FALSE)

load(d_predict[1])
stackOrder <- names(df.in)[indVarCols]
##Makes Stacks first
rasInfo <- vector("list",length(stackOrder))
names(rasInfo) <- stackOrder
#setwd("C:\\Users\\Public\\Env_Variables")
#setwd("C:\\Users\\Public\\Env_Var_Copy\\Env_Variables")
setwd("D:\\Env_Var_Copy\\Env_Variables")
env_vars_ordered<-(character(length(stackOrder)))
for (i in 1:length(stackOrder)){
  basename<-stackOrder[i]
  raster_name<-paste(basename,".grd",sep="")
  env_vars_ordered[i]<-raster_name
}
stack.envar_native<-stack(env_vars_ordered)

##loop through
##Get Rdata Files and loop through AFTER making Rasters and RasterStack
length(d_predict)
require(randomForest)
for (i_predict in 1:8){
  fileName <- d_predict[[i_predict]]
  ## Bring the file into R
  #setwd("C:\\Users\\Public\\2015Pros\\RdataFiles\\July_Rerun")
  #setwd("C:\\Users\\Public\\2015Pros\\RdataFiles")
  setwd("C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\RdataFiles")
  #setwd("C:\\Users\\Public\\2015Pros\\RdataFiles_subset\\RunonRapunzel2")
  load(fileName)
  #library(randomForest)
  #source('C:/Users/Public/2015Pros/RasterPredictMod.R')
  finm <- paste(tolower(ElementNames$Type[length(ElementNames$Type)]),
              "-",
              ElementNames$Code[length(ElementNames$Code)],
              sep="")
  finm

  #library(randomForest)
  
  #setwd("C:\\Users\\Public\\2015Pros\\Predicts2015\\Rrasters")
  setwd("C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\Rrasters")
  #### use this Code when Re-running previously predicted species so as to avoid overwrite
  #setwd("C:\\Users\\Public\\2015Pros\\Predicts2015\\Rrasters\\July_reruns")
  

  outRas <- predictRF(stack.envar_native, rf.full, progress='text', filename=finm, index=2, na.rm=TRUE, type="prob", overwrite=TRUE)
  
  #setwd("C:\\Users\\Public\\2015Pros\\Predicts2015\\ascii_grids")
  #### use this Code when Re-running previously predicted species so as to avoid overwrite
  #setwd("C:\\Users\\Public\\2015Pros\\Predicts2015\\ascii_grids\\July_reruns")
  
  writeRaster(outRas, filename=finm, format = "ascii", overwrite = TRUE)
  #clear all but the items needed for next run
  rm(list=ls()[!ls() %in% c("i_predict","d_predict","stack.envar","stack.envar_native","crop_stack_native","test_extent","predictRF")])

}
