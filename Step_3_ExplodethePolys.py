#Created on April 18 2015
#The purpose of this script is to cycle through a series of polygon shapefiles
#and:
#1. Explode them (multi-part to single-part)
#2. Attach a prj file if there isn't one already (GRTS requires one)
#The final product is then used in a GRTS routine to create random point datasets
#for running through EDM. (Tim Howard, NYNHP from original script)
#Original code was written pre-development of the arcpy library.
#This code is intended to perform the same functions with the arcpy toolsets.
#(Amy Conley, NYNHP)

#Files in this script start out in the "EDM_feature_polys" folder and end up in the "Exploded_polys" folder
####Places that you need to update when changing projects
#1: Location of the intial files "shpPath"
#shpPath="C:\\Users\\Public\\2015Pros\\EDM_feature_polys"
shpPath="C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\Submitted_Polys"
#outPath="C:\\Users\\Public\\2015Pros\\EDM_feature_polys\\Exploded_polys"
#Where do the files go?
#Output Workspace- Create output folder to write exploded files into

out_name="Exploded_polys"
outPath=arcpy.CreateFolder_management(shpPath,out_name)
#Import system modules

import os
import sys
import arcpy
print "Running multipart to single part features now, prepare to explode...."
# Allow overwriting of output
arcpy.env.overwriteOutput = True

#Workspace and Environment Settings

##For all runs AFTER the initial run, use this to make sure you only explode the new files
#arcpy.env.workspace="C:\\Users\\Public\\2015Pros\\EDM_feature_polys\\Exploded_polys\\Exploded_Archive"
fc_already_exploded=arcpy.ListFeatureClasses()

#shpPath = "W:\Projects\EDM\ElementPolys\Spring2015\EDMPolyPrep\Test"
#shpPath="C:\\Users\\Public\\2015Pros\\EDM_feature_polys"

arcpy.env.workspace =shpPath

#Output Workspace- Create output folder to write exploded files into

out_name="Exploded_polys"
outPath=arcpy.CreateFolder_management(shpPath,out_name)
#outPath="C:\\Users\\Public\\2015Pros\\EDM_feature_polys\\Exploded_polys"

#Get a list of all the shapefiles in the folder- after the initial run this will include a mix of species that have been processed and those that have yet to be processed

fcs_raw = arcpy.ListFeatureClasses()
#print (fcs) #Checking that folder creation was working

##Now compare list of input features with list of already processed features to only
##select the unprocessed
fcs=[]  #create empty list of features for the unprocessed features to be added to
new_fcs=0 #set counter
old_fcs=0
for fc in fcs_raw:
    root=fc[:-4]
    post_name=root+"_expl.shp"    
    if post_name in fc_already_exploded:
        old_fcs+=1
    else:
        fcs.append(fc)
        new_fcs+=1

#Find total count of shapefiles in list
fc_count = len(fcs)
print str(fc_count)+" species to explode."

#Select all shapefiles in the input directory

k= 0  #set a counter for the number shapefiles processed

for fc in fcs: #Everything below here is in the for loop
    k+=1
    elemName = fc[:-4] #chop the rightmost four chars (.shp)
    out1 = elemName + "_expl.shp"     # exploded
   # print (fc) #Checking that folder creation was working
   # print (out1) #Checking that folder creation was working
   # print (outPath) #Checking that folder creation was working
    
    try:
    # Run the tool to create a new fc 
     outFeatureClass=arcpy.CreateFeatureclass_management(outPath,out1)
     #print (outFeatureClass) #Checking that folder creation was working.
	 #Populate new feature class with exploded polys with only single part features
     arcpy.MultipartToSinglepart_management(fc, outFeatureClass)
    except:
        #If an error occured print out the error message
     print "Error occurred while running multipart to single part"
     print (arcpy.GetMessages(2))
    try:    
    # Add field and calculate area in SQ meters just to be sure to have accurate calculation
        arcpy.AddField_management(outFeatureClass, "py_AreaM2", "double")
        arcpy.CalculateField_management(outFeatureClass, "py_AreaM2", "float(!shape.area!)", "PYTHON")
    #Add a field to give a unique ID to each polygon
        #Get the unique ID from FID
        arcpy.AddField_management(outFeatureClass, "expl_ID", "long")
        arcpy.CalculateField_management(outFeatureClass, "expl_ID",  "!FID!", "PYTHON")
    except:
        #If an error occurs, print the message
        print "Error in field calculation"
        print arcpy.GetMessages(2)
    try:
        coordinateSystem = "C:\Users\Public\Coordinate_Systems\NAD 1983 UTM Zone 18N.prj"
         # define projection for the _expl (exploded polygon file) as this is 
          # used for GRTS second step
        arcpy.DefineProjection_management(outFeatureClass, coordinateSystem)
    except:
        #If an error occurs, print the message
        print "Error occurred while projecting"
        print arcpy.GetMessages(2)     
    print ""
    print "Shapefile " + str(k) + "(" + elemName + ") of " + str(fc_count) + " has been processed."
    if fc_count <> k:
        print "...on to the next shapefile..."
    print ""
print "Boom goes the dynamite."        
        
