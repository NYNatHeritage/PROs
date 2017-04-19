

library(raster)
library(randomForest)
library(ROCR)

#get a list of Rdata files
#setwd("G:/_Beauty/_NYNHP/GIS_data/ElementData/RdataFiles/NYSERDA/NoRun")
#setwd("D:\\GIS Projects\\Lands_Forests\\Predicts\\RdataFiles")

setwd("C:\\Users\\Public\\2015Pros\\RdataFiles")
setwd("C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\RdataFiles")
#setwd("C:\\Users\\Public\\2015Pros\\RdataFiles\\July_Rerun")
#setwd("C:\\Users\\Public\\2015Pros\\RdataFiles_subset\\RunonRapunzel5")
#setwd("C:\\Users\\Public\\2015Pros\\RdataFiles_subset\\RunonRapunzel6")
R.fn <- dir(pattern = ".Rdata")


##Original Code works with Tiff files, 
#setwd("G:/Projects/LF_PRO_2014/testArea2/clippedEDMs")
#Tiff.fn <- dir(pattern = ".tif")
#Tiff.fn <- gsub(".tif", "", Tiff.fn)

##See if works with grids
#setwd("D:\\GIS Projects\\Lands_Forests\\Predicts\\Rrasters")
#setwd("C:\\Users\\Public\\2015Pros\\Predicts2015\\Rrasters")
#setwd("C:\\Users\\Public\\2015Pros\\Predicts2015\\Rrasters\\July_reruns")
setwd("C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\Rrasters")
Tiff.fn <- dir(pattern = ".grd$")
Tiff.fn <- gsub(".grd$", "", Tiff.fn)

#set i for future looping
# fn.i <- 4

for(fn.i in 1:9){
#for(fn.i in 1:3){
#for(fn.i in 1:20){
    #setwd("G:/_Beauty/_NYNHP/GIS_data/ElementData/RdataFiles/NYSERDA/NoRun")
    #setwd("D:\\GIS Projects\\Lands_Forests\\Predicts\\RdataFiles")
    #setwd("C:\\Users\\Public\\2015Pros\\RdataFiles")
    setwd("C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\RdataFiles")
    #setwd("C:\\Users\\Public\\2015Pros\\RdataFiles\\July_Rerun")
    #get the Rdata file
    load(R.fn[[fn.i]])
    ##Just for working out the bugs
    #load(R.fn[[1]])
    ###Original code placed 'a' in front of all codes, but there are both plant and animals in this file
    ElementNames$Type
    e_type<-(tolower(ElementNames$Type))
	#tfn <- paste("a-",abbr,sep="")
  tfn<-paste(e_type,"-",abbr,sep="")
    if(tfn %in% Tiff.fn){
        print(paste("working on ",abbr, sep = ""))
        #get the associated raster
        #setwd("G:/Projects/LF_PRO_2014/testArea2/clippedEDMs")
        #setwd("D:\\GIS Projects\\Lands_Forests\\Predicts\\Rrasters")
        #setwd("C:\\Users\\Public\\2015Pros\\Predicts2015\\Rrasters")
        #setwd("C:\\Users\\Public\\2015Pros\\Predicts2015\\Rrasters\\July_reruns")
        setwd("C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\Rrasters")
        #ras <- raster(paste(tfn, ".tif", sep=""))
        ras<-raster(paste(tfn,".grd",sep=""))

        #### need to decide whether this is the appropriate cutoff to use !!
        #calculate a new cutoff using alpha = 0.5
        #No, stick with alpha  = 0.01 for now as that's what the pdf reports as one option
        alph <- 0.01
        #alph <- 0.2
        #create the prediction object for ROCR
        rf.full.pred <- prediction(rf.full$votes[,2],df.full$pres)
        #use ROCR performance to get the f measure
        rf.full.f <- performance(rf.full.pred,"f",alpha = alph)
        #extract the data out of the S4 object, then find the cutoff that maximize the F-value.
        rf.full.f.df <- data.frame(cutoff = unlist(rf.full.f@x.values),fmeasure = unlist(rf.full.f@y.values))
        rf.full.ctoff50 <- c(1-rf.full.f.df[which.max(rf.full.f.df$fmeasure),][[1]], rf.full.f.df[which.max(rf.full.f.df$fmeasure),][[1]])
        ctpt <- rf.full.ctoff50[[2]]
        #print(paste(abbr," = ", ctpt))
        #setwd("G:/Projects/LF_PRO_2014/testArea2/cutGrids")
        #setwd("D:\\GIS Projects\\Lands_Forests\\Predicts\\cutGrids")
        #setwd("C:\\Users\\Public\\2015Pros\\Predicts2015\\cutGrids")
        setwd("C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\cutGrids")
        #setwd("C:\\Users\\Public\\2015Pros\\Predicts2015\\cutGrids\\Trouble")
        # ## using calc  -- a tiny bit faster than reclass
        func <- function(x){x > ctpt}
        rasCtc <- calc(ras, fun=func,dataType="INT1U")
        writeRaster( rasCtc, filename=paste(abbr,"_c",sep=""), format = "GTiff", datatype = "INT1U", overwrite = TRUE)
    } else { 
    print(paste("skipped ", abbr, sep=""))
    }
    rm(list=ls()[!ls() %in% c("fn.i","R.fn", "Tiff.fn")])
}

#### test data+



#load("Asio flammeus.Rdata")


# r <- raster(ncol=100, nrow=100)
# r[] <- round(runif(ncell(r)) * 10)
# ctpts <- c(0,3.5,10)
# rc <- cut(r,breaks=ctpts)
# subdf <- data.frame(from=c(1,2), to=c(0,1))
# rs <- subs(rc, subdf, subsWithNA=TRUE)
# plot(rs)
# rs

# class <- matrix(c(0,3.5,0,3.5,10,1),nrow=2,byrow=T)

# rc <-reclass(r, class)

# rc



