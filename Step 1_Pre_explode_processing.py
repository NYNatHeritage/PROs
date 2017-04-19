##Files in this script start by being submitted in the "Submitted_Polys" Folder
##Files end up in the "Renamed_No_Prep_Polys" folder
## Then run the renaming script "CodingNameswithSQL"
##But only after manually renaming the animals files with habitat use modifications "Breeding""hibernacula"
#Because the naming code will not select the correct code for those.

##Code to process features that have been submitted for EDM
## This code will rename files which have unsuitable names for subsequent analysis
#Will extract from the features in each file those features that have been assessed as
##EDM-Worthy
#Will examine the attributes of these features to identify missing data that will muck up
#code going forward (missing scientific names,common names,eo_ids)

print "Importing modules and setting environments"
import os
import shutil
import arcpy
import fnmatch
import Functions

##Directory where the files are stored

#"C:\Users\Public\Submitted_Polys"
#First grab the raw submitted files from the "Done" folder that has been put in the "Submitted" polys
#Regular workspace will be the "Submitted Polys" folder in the 2015Pros directory
arcpy.env.workspace="C:\\Users\\Public\\2015Pros\\Submitted_Polys\\"
#dirpath="C:\\Users\\Public\\2015Pros\\Submitted_Polys\\"
#The temporary folder and dir path used for the "no prep" speecies is hte "Renamed_No_prep_Polys"
#arcpy.env.workspace="C:\\Users\\Public\\2015Pros\\Renamed_No_Prep_Polys\\"
dirpath="C:\\Users\\Public\\2015Pros\\Renamed_No_Prep_Polys\\"
dirpath="C:\\Users\\Public\\2015Pros\\Submitted_Polys\\"

print "Getting a list of all the submitted files"
raw_files=arcpy.ListFiles()

print str(len(fnmatch.filter(os.listdir(dirpath), '*_Current*'))) + " files with _Current in name that need to be fixed!"
print str(len(fnmatch.filter(os.listdir(dirpath), '*var.*'))) + " files with var. in name that need to be fixed!"
print str(len(fnmatch.filter(os.listdir(dirpath), '*ssp.*'))) + " files with ssp. in name that need to be fixed!"
print "Cleaning up file names"

raw_file_counter=0
no_change_needed=0
for raw in raw_files:
    raw_file_counter+=1    
    try:
        Functions.clean_name(raw)
        
    except:
        no_change_needed+=1

print "All "+str(raw_file_counter)+" features checked!"
print str(len(fnmatch.filter(os.listdir(dirpath), '*_Current*'))) + " files with _Current in name that need to be fixed."
print str(len(fnmatch.filter(os.listdir(dirpath), '*var.*'))) + " files with var. in name that need to be fixed."
print str(len(fnmatch.filter(os.listdir(dirpath), '*ssp.*'))) + " files with ssp. in name that need to be fixed."

print "On to selecting modeling features...."
    
##Next need to extract the flagged features and place these in a new folder
#The folder to extract to: "C:\Users\Public\2015Pros\EDM_feature_polys"
    
select_folder="C:\\Users\\Public\\2015Pros\\Renamed_No_Prep_Polys"
##where_clause='"IN_2015_PR" = ' + "'Y'" +" OR " + ' "IN_2015_PR" = '+"'M'"
where_clause='"IN_2015_PR" = ' + "'Y'" +" OR " + ' "IN_2015_PR" = '+"'M'" +" OR " + '"IN_2015_PR" = ' + "'y'" + " OR " + ' "IN_2015_PR" = '+"'m'"  

#Get list of shapefiles from raw

raw_features=arcpy.ListFeatureClasses()
print len(raw_features)
extracted_features=0

for feature in raw_features:
    select_folder="C:\\Users\\Public\\2015Pros\\Renamed_No_Prep_Polys"
    Functions.pull_selected_features(feature,select_folder)
    #arcpy.FeatureClassToFeatureClass_conversion(feature,select_folder,feature,where_clause)
    extracted_features+=1
print str(extracted_features)+" have been extracted to "+str(select_folder)

##Move the original features into the archive. We're done with them but keep them around in case need to re-process
source="C:\\Users\\Public\\2015Pros\\Submitted_Polys\\"
dest="C:\\Users\\Public\\2015Pros\\Archive\\"

Functions.archive_originals(source,dest)
print "Submitted polys archived. On to processing features!"
#Check the selected features for missing key elements
print "Checking feature information..."

arcpy.env.workspace="C:\\Users\\Public\\2015Pros\\Renamed_No_Prep_Polys"

edm_features=arcpy.ListFeatureClasses()
print str(len(edm_features)) +" features to check for completeness"
problem_children=[]

no_issue_files=[]

for fc in edm_features:
    feature=fc
    field1="SCIEN_NAME"
    field2="COMMONNAME"
    #print str(feature)
    fc_value=Functions.check_nulls(feature)
    zero_value=Functions.check_zeros(feature)
    sci_names_value=Functions.check_names(feature,field1)
    comm_names_value=Functions.check_names(feature,field2)
    if fc_value>0:
        print str(feature)+" has "+str(fc_value)+" empty EO_IDs!"
    
    if zero_value>0:
        print str(feature)+" has "+str(zero_value)+" zero value EO_IDs!"
    
    if sci_names_value>0:
        print str(feature)+" has "+str(sci_names_value)+" blank "+str(field1)+" fields!"
    
    if comm_names_value>0:
        print  str(feature)+" has "+str(comm_names_value)+" blank "+str(field2)+" fields!"  
    if (fc_value+zero_value+sci_names_value+comm_names_value)==0:
        no_issue_files.append(fc)
    else:
        problem_children.append(fc)
        
        
print "Features have been prepped and checked!"
print str(len(no_issue_files))+ " files have no issues!"
print str(len(problem_children))+ " files have issues and need fixing before proceeding:"
print problem_children
    