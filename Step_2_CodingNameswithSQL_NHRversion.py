#This code is designed to rename input files according to their assigned codes, 
    #The codes are availible in an SQLite table
#Files in this script are read in from the "Renamed_No_Prep_Polys" folder, after already having been processed
    #to only include features flagged "Y" or "M" by the botanists and zoologists
    #and to check for missing SCIEN_NAME and EO_ID information (See "Step_1_Pre_explode_processing" script)
#After being renamed the files are moved out of the "Renamed_No_Prep_Polys" folder
    #and sent to the "EDM_feature_polys" for exploding
#At the end of the script the Renamed_No_Prep_Polys folder should be left empty, ready for the next batch of files
#May 18,2015
#Amy Conley, NYNHP

import arcpy

arcpy.env.workspace="C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\Submitted_Polys"

source="C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\Submitted_Polys\\"
dest="C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\Renamed_No_Prep_Polys\\"

test_features=arcpy.ListFeatureClasses()

test_features
import sqlite3
#Create connection to the SQLite database
#The tblInputs actually only has the 2015 Model Codes by accident but that simplifies this
db=sqlite3.connect('C:/Users/Public/2015Pros/BackEnd.sqlite')
sqlcursor=db.cursor()    
#sqlcursor.execute('''SELECT Code from tblInputs WHERE SCIEN_NAME=?''',(sci_name,))
#test_one=sqlcursor.fetchone()

for fc in test_features:
    if len(fc[:-4])>=10:    
        try:
            
            field1="SCIEN_NAME"
            field=["SCIEN_NAME"]
            values = [row[0] for row in arcpy.da.SearchCursor(fc, (field))]
            uniquevalues=set(values)
            sci_name=list(uniquevalues)[0]
            sqlcursor.execute('''SELECT Code from tblInputs WHERE SCIEN_NAME=?''',(sci_name,))
            test_one=sqlcursor.fetchone()
            print fc
            print test_one[0]
        except:
            print "There may be a problem grabbing the code for "+str(fc)
        try:
            root_name=fc[:-4]
            print root_name
            new_name=test_one[0]+".shp"
            print new_name
            arcpy.Rename_management(fc,new_name)
        except:
            print "There may be a problem renaming "+str(fc)
    else:
        print "Features already encoded: "+str(fc)

#Moving the files from the input folder into the EDM_Folder
import Functions


Functions.archive_originals(source,dest)