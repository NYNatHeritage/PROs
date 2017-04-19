##Code to read rasters from tiffs into a Raster Stack ,then collect the shapefiles for species
#of interest, and extract the the values for all rasters in the stack for each point in each one of
#the shapefiles.

##Prevoiusly wrote script to do this in python but is used every speck of the computer's memory and 
##Windows begged me to shut it down. Hopefully since raster doesn't hold all the values in memory, running
##it this way will be a gentler option

#First need to remove old Spatial Points data Frames so that only the new ones that are created get added to the att_pres_points

rm(list=ls()[!ls() %in% 
               c("att_pres_points","att_background","background_points","Env_vars","list_df")])

#UnComment THIS IF YOU LOSE THE ENV_VARS data.
require(raster)
##Set Working Directory to the rasters location
#setwd("C:\\Users\\Public\\Env_Variables")
#setwd("C:\\Users\\Public\\Env_Var_Copy\\Env_Variables")
###The director has the tifs already converted to native raster format
setwd("D:\\Env_Var_Copy\\Env_Variables")
## List files that have "tif" at the end
##raster_list<-list.files("C:\\Users\\Public\\Env_Variables",pattern="*.tif$")
##Use native raster format
#raster_list<-list.files("C:\\Users\\Public\\Env_Var_Copy\\Env_Variables",pattern="*.grd$")
raster_list<-list.files("D:\\Env_Var_Copy\\Env_Variables",pattern="*.grd$")
##Create an empty raster stack
Env_vars<-stack()


Env_vars<-stack(raster_list,quick=FALSE)
#Check that names all worked properly
names(Env_vars)
##Get list of the shapefiles that have "RanPts" at the end

#species<-list.files("C:\\Users\\Public\\2015Pros\\PointstobeAttributed\\New_No_Dataframe",pattern="*RanPts.shp$")

species<-list.files("C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\PointstobeAttributed",pattern="*RanPts.shp$")

##Read these files into a SpatialPoints dataframe within R

require (rgdal)
require (tools)

## reading in the shapefiles requires giving the name without shp
##create empty list
names=list()
for (e in species){
  base<-basename(file_path_sans_ext(e)) ##basename gets rid of the directory path,file_path_sans_ext removes the extension
  names[[length(names)+1]]<-base##Add the new stripped name to the list we need the base for the function to read in the shapefile
  
} 
#Create the Spatial DataFrame Objects
##Note: Need to use assign so that each value in names will create a seperate file, 

##For every name in names, read the shapefile with that name into a Spatial Data frame
#Create a list of the SpatialDataframes for iterating through later

for (i in names){
  assign(i,readOGR("C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\PointstobeAttributed",layer=i))
}

#Now for every item in names, there is a corresponding Spatial data frame
#Go through each Spatial Data Frame and Extract the Raster Values for each Raster in the Stack
#Raster_Stack is named Env_vars
#List of Points is called "names"
#Make a list of SpatialPointsDataFrames in the Workspace to use for "lapply"
##Look for files that have the "RanPts" without the Shapefile extension and that are SpatialPointsDataFrame objects

new_list_df<-lapply(ls(pattern="*RanPts$"),function(x)
  if (class(get(x))==
        "SpatialPointsDataFrame")get(x))

#Get a list of the codes (this assumes all the input files had '_RanPts.shp' that shall be stripped)
code_names<-substr(species,1,(nchar(species)-11))

##Add names to the list
names(new_list_df)<-code_names

## First you extract the raster values for each point
#v<-as.data.frame(extract(Env_vars,Abagrotis_barnesi_RanPts))
##and then you join it to the spatial data frame
##attach raster values to the original point data frame:
#Abagrotis_barnesi_RanPts@data=data.frame(Abagrotis_barnesi_RanPts@data,v[match(rownames(Abagrotis_barnesi_RanPts@data),rownames(v)),])
##Now just need a way to iterate through the dataframe without having to run this one by one

#make a list of the extract methods so that the categorical variables are not extracted bilinearly
#methods_list<-c("bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","simple","simple","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","simple","simple","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","simple","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear","bilinear")
#Accessing individual species in the data frame list :
##list_df$Woodsia_glabella_RanPts@data <- this is what needs to be used each time the points are attributed


extract_and_save= function(PntFile){
  env_values=as.data.frame(extract(Env_vars,PntFile,method='simple'))
  PntFile@data=data.frame(PntFile@data,env_values[match(rownames(PntFile@data),rownames(env_values)),])}

#If this is the first time through, then create the att_pres_points table
#att_pres_points<-lapply(list_df,extract_and_save)

#If this is a second or greater run, you don't want to overwrite the old table.
new_att_pres_points<-lapply(new_list_df,extract_and_save)

#Get a list of the codes (this assumes all the input files had '_RanPts.shp' that shall be stripped)
code_names<-substr(species,1,(nchar(species)-11))
names(new_att_pres_points)<-code_names

##Add the new data on the to the end of the att_pres_points dataframe to keep all species in one place
att_pres_points<-append(att_pres_points,new_att_pres_points)
#then to access the data for each species use
#shiny_new_data$Woodsia_glabella_RanPts
#It isn't a spatial points data frame, so you don't need to use the '@data' signifier

#read in the background points
#Only uncomment this if you have lost the att_background_points file

#Files is in:"C:\\Users\\Public\\BackgroundPoints\\10k_backgroundPts_2011.shp"
#background_points<-readOGR("C:\\Users\\Public\\BackgroundPoints",layer="10k_backgroundPts_2011.shp")
