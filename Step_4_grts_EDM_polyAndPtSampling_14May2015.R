# File: grts_EDM_polyAndPtSampling
# Purpose: GRTS sampling of EDM polygons for training/validation
# Programmer: Tim Howard
# Date: winter 2007-2008
# Last Modified: 14 May 2015

# Load the spsurvey 
library(spsurvey)

# Update: This code has been developed to work in tandem with
# python code that does all the aforementioned GIS tasks (plus more). See the
# file named "edm_prepForTrainSet_date.py"

#set the working directory  (this needs to exist and have the python-created 
#files in it)
#setwd("C:\\_NYNHP\\EDM\\Input_Layers\\output")  #Original Code
#setwd ("W:\\Projects\\EDM\\ElementPolys\\Spring2015\\EDMPolyPrep\\output")
#setwd("D:\\GIS Projects\\Lands_Forests\\Prior_Polys_for_No_Prep_Species\\output")
#setwd("D:\\GIS Projects\\Lands_Forests\\Prior_Polys_for_No_Prep_Species\\Renamed_No_Prep_Polys\\output")
#setwd("C:\\Users\\Public\\2015Pros\\EDM_feature_polys\\Exploded_polys")
setwd("C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\Exploded_polys")
###########################
#  make a connection to the information-tracking database to allow writing 
#  to it within the loop. Open up a "channel" to the Access DB. Note that 
#  "EDM_status_Cn" is a User DSN in ODBC Data Sources in administrative tools 
#  in the control panel of your computer. Needs to be set up before this will run.

#fire up RODBC
library(RODBC)
# open the channel
#Cn.MDB.out <- odbcConnect("EDM_status_Cn")
library(RSQLite)
#Fire up SQLite

db_file<-"C:\\Users\\Public\\2015Pros\\BackEnd.sqlite"
db<-dbConnect(SQLite(),dbname=db_file)
###########################

#get a list of what's in the directory
d <- dir()
# remove everything from the directory listing vector BUT the Pt shapfiles
    #(as represented by the .sbx -- can't use .shp because xml file has shp 
    #extension too)
all.expl <- d[grep("_expl.sbx", d)]

#loop through everything in d
for (i in 1:length(all.expl)){
  fileName <- all.expl[[i]]
  shpName <- strsplit(fileName,"\\.")[[1]][[1]]
  #this is better than strsplit as it ignores other underscores in the filename
  elemName <- sub("_expl", "", shpName) 
     #temp code to remove _ply
	 elemName <- sub("_ply", "", elemName) 
      #the name of the point shapefile
      nm.PtFile <- shpName
      #the name of the output shapefile for choosing centroids randomly 
      #(for validation)
      nm.OutFile <- paste(elemName, "_TrEvStrat", sep="")
      #element code only
      sppCode <- elemName
      #polygon shapefile  -- usually the exploded (multi-part to single part) one
      nm.PyFile <- paste(sppCode, "_expl", sep = "")
      #name of output shapefile for random points within polygons
      nm.RanPtFile <- paste(sppCode, "_RanPts", sep = "")

      #tell the console what's up
      print(paste("Beginning on ", 
                   elemName, ", ", i , " of ", length(all.expl), sep = ""))
      #send all the coming GRTS info messages to a file, so it's easier to 
      #track progress on the terminal
      # sinkName <- paste("RunMsgs_",Sys.Date(), ".txt",sep="")
      # sink(file = sinkName, append=TRUE, type="output")

      ###############################
      #####     Placing random points within each sample unit (polygon/EO)
      #####
      ###############################
      
         # the GRTS version of read.dbf would sometimes crash at the next command
         # replace it with the version in the foreign package by loading foreign
         #library(foreign)
      #get the table from the output shapefile from the above GRTS run, as it has
      #important attribute info.
      att.pt <- read.dbf(nm.PtFile)
		#just in case convert to upper
		names(att.pt) <- toupper(names(att.pt))	
      #need to clean up colnames some more (remove extranneous from above),
      #find the locations of the varying named columms (straight grep).
      colList <- c(grep("^EO_ID$",names(att.pt)),
                   grep("SCIEN_NAME",names(att.pt)),
                   grep("COMMONNAME",names(att.pt)),
                   grep("EXPL_ID",names(att.pt)),                                      
                   grep("PY_AREAM2",names(att.pt)))
      #do the extract (colList is a list of column numbers)
      att.pt <- att.pt[,colList]
      #rename
      names(att.pt) <- c("EO_ID", "SCI_NAME",
                         "COMMNAME", "expl_ID", "py_AreaM2")
      #order the dataframe by expl_ID (=the way polygon shapefile is ordered).
          # Note that now that it is sorted the same way as the polygon shapefile, 
          # we'll use this attribute table for the final output, rather than the 
          # attribute table of the polygon shapefile. This, in effect provides the 
          # 'join' so that extra attributes from the above GRTS run can be joined 
          # to the output from this GRTS run.
      att.pt <- att.pt[order(att.pt$expl_ID),]
      #add another copy of the expl_ID field - the original becomes 'mdcaty' in 
      #the final output
      att.pt <- cbind(att.pt, expl_ID2=att.pt$expl_ID)
#### here would be a good place (I think) to add a name field and attribute with elemname
#### use "cbind" e.g. cbind(att.pt, elemCode = elemName)
      #calculate Number of points for each poly
      #calc values into a new field
      att.pt$PolySampNum <- round(400*((2/(1+exp(-(att.pt[,"py_AreaM2"]/900+1)*0.004)))-1))
      #make a new field for the design, providing a stratum name
      att.pt <- cbind(att.pt, "panelNum" = paste("poly_",att.pt$expl_ID, sep=""))

      #create the vector for indicating how many points to put in each polygon, 
      #then each value in the vector needs to be attributed to the sampling unit 
      #(either EO_ID or Shape_ID)
      sampNums <- c(att.pt[,"PolySampNum"])
      names(sampNums) <- att.pt[,"expl_ID"]
      # sample MUST be larger than 1 for any single polygon use OVER to increase 
      # sample sizes in these. To handle this, create a vector that contains 
      # 2 when sample size = 1, otherwise 0
      overAmt <- ifelse(sampNums == 1,2,0)

      #initialize the design list and the names vector so 
      #they are available in the for loop
      SampDesign <- vector("list",length(sampNums))
      namesVec <- vector("list", length(sampNums))

      # whew!  build the sampling design, as required by GRTS
      # this is a list 'SampDesign' with internal lists: 'panel', 'seltype', and 
      # 'over' for each entry of SampDesign
      for (i in 1:length(sampNums)){
        #build a vector of names to apply after the for loop
        namesVec[i] <- paste("poly_",i-1,sep="")
        #initialize the internal list
        SampDesign[[i]] <- vector("list",3)
        #populate the internal list
        SampDesign[[i]] <- list(panel=c(FirstSamp=sampNums[[i]]),
                                seltype="Equal", 
                                over=overAmt[[i]])
      }

      #apply that names vector
      names(SampDesign) <- namesVec

      #if you want to check out this design, 
      #a couple of exploratory commands here, commented out
        #list the names of one of the sub lists
      #names(SampDesign[[1]])
        #show something about the structure of the list
      #summary(SampDesign)  ##str(SampDesign) is even more thorough

      # Create the GRTS survey design
      Unequalsites <- grts(design=SampDesign,
                     src.frame="shapefile", #source of the frame
                     in.shape=nm.PyFile,    #name of input shapefile no extension
                     att.frame=att.pt,      #a data frame of attributes associated with elements in the frame
                     type.frame="area",     #type of frame:"finite", "linear", "area"
                     stratum="panelNum",
                     mdcaty="expl_ID",
                     DesignID= sppCode,  #name for the design, which is used to create a site ID for each site.
                     shapefile=TRUE,
                     prj=nm.PyFile,
                     out.shape=nm.RanPtFile)

## GRTS just wrote the shapefile here. So now would be the time to open it up again and delete columns
	  
	  ###############################
      #####     Write out various stats and data to the database
      #####
      ###############################

      # prep the data
      OutPut <- data.frame(SciName = paste(att.pt[1,"SCI_NAME"]),
                   CommName=paste(att.pt[1,"COMMNAME"]),
                   ElemCode=elemName,
                   RandomPtFile=nm.RanPtFile,
                   TrainPolys = NA, #no longer defining these here... we are bootstrapping instead.
                   EvalPolys = NA,
                   date = paste(Sys.Date()),
                   time = format(Sys.time(), "%X"),
                   Loc_Use=""
                   )

      #write the data to the database
      #sqlSave(Cn.MDB.out, OutPut, tablename = "tblPrepStats", 
      #                            append = TRUE, 
      #                            rownames = FALSE)

      #Write the data to the SQLite database
      dbWriteTable(db,"tblPrepStats",OutPut,append=TRUE)
      ###############################
      
      #stop the sink
      # sink()
      #tell the console what's up
      print(paste("Finished with ", elemName, sep=""))
#close the for loop
}

# close the connection to the Access DB
#close(Cn.MDB.out)

#Close Connection to the SQL DB
dbDisconnect(db)

