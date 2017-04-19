##Functions File
##This module contains all the functions that can be called in the routine for processing files
##After they have been edited by the botanists and zoologists

##The clean_name function goes through the files and removes the unecesssary punctuation and the "Current" signifier
import arcpy
import os
import shutil


def clean_name(x):
    clean_name=x.replace("_Current","")
    clean_name=clean_name.replace("var._","var_")
    clean_name=clean_name.replace("ssp._","ssp_")
    arcpy.Rename_management(x,clean_name)
    
#Make a function that takes a feature class, pulls out the features that meet the right criteria, and turns them into a new feature class

## pull_selected_features take the argument a(the feature class to cut) and y (the output location)

def pull_selected_features(x,y):
    infile=x
    out_path=y
    #root=x[:-12]
    #new=root+".shp"
    where_clause='"IN_2015_PR" = ' + "'Y'" +" OR " + ' "IN_2015_PR" = '+"'M'" +" OR " + '"IN_2015_PR" = ' + "'y'" + " OR " + ' "IN_2015_PR" = '+"'m'"  
    try:
        arcpy.FeatureClassToFeatureClass_conversion(infile,out_path,infile,where_clause)
    except:
        print "Something went wrong converting " +str(x)
 
##The check_nulls function goes through the files and checks for null values in the EO_ID field that might throw off the script       
def check_nulls(x):
    Null_counter=0    
    test_fc=x
    
    fields=["FID","EO_ID","SCIEN_NAME"]
    ##The where statement is the most finicky part of the code. If something doesn't work,it is probably the WHERE clause mucking it up
    alt_where= '"EO_ID" = ' + "''" 
    
    try:
        with arcpy.da.SearchCursor(test_fc,fields,where_clause=alt_where) as cursor:
            for row in cursor:
                #print ("FID {0}".format(row[0]))
                Null_counter+=1
            if row:
                del row
            if cursor:
                del cursor
            count=Null_counter
            return count
    except:
        #print "This file has all its EO_IDs"
        return 0
##Check zeros does the same thing, but checks if the value is 0
def check_zeros(x):
    test_fc=x
    Null_counter=0
    fields=["FID","EO_ID","SCIEN_NAME"]
    zero_where= '"EO_ID" = ' + '0'    
    try:
        zero_where= '"EO_ID" = ' + "0"        
        with arcpy.da.SearchCursor(test_fc,fields,where_clause=zero_where) as cursor:
            for row in cursor:
                print ("FID {0}".format(row[0]))
                Null_counter+=1
            if row:
                del row
            if cursor:
                del cursor
            count=Null_counter
            return count
    except:
        #print "This file has all its EO_IDs"
        return 0        
 
#The check_names function examines where the names fields are missing or left blank     
def check_names(x,y):
    Null_counter=0    
    test_fc=x   #The renaming is messy and unnecessary,the test-fc terminology was a hold over from earlier versions of the code. You could just eliminate both the place holder names and replace with "x" and "y"
    field_try=y
    fields=["FID","EO_ID","SCIEN_NAME","COMMONNAME"]
    #sci_where= '"SCIEN_NAME" = ' + "''"
    auto_where=arcpy.AddFieldDelimiters(test_fc,field_try)+' = '+ "''"
    try:
        with arcpy.da.SearchCursor(test_fc,fields,where_clause=auto_where) as cursor:
            for row in cursor:
                #print ("FID {0}".format(row[0]))
                Null_counter+=1
            if row:
                del row
            if cursor:
                del cursor
            count=Null_counter
            return count
    except:
        #print "This file has all its EO_IDs"
        return 0

##Check_emptys test if a featureclass is empty        
def check_emptys(x):
    
    try:
        result=arcpy.GetCount_management(x)
        count=int(result.getOutput(0))
        #print count
        if count==0:
            print str(x)+" has an empty set!"
            #empty_features.append(feature)
        else:
            print str(x)+ "isn't empty! Good job!"
        return count
    except:
        print "Checking for empty feature sets raised a flag"
        
##Function to move the files out of the input folder so I won't process them twice
        
def archive_originals(x,y):
    for file in os.listdir(x):
        #print file
        src_file=os.path.join(x,file)
        dst_file=os.path.join(y,file)
        shutil.move(src_file,dst_file)
    