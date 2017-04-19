#Step 13 PROs- Finishing up
##Trying to make sense of the nonsensical "FinishUpMethods" that doesn't tell you the goal of the script, so how do you know what your are doing?
##So, the goal is to add a field to the PROS polygons that identify which Facilities they overlap
#Use the Intersect tool

import arcpy
# Check out any necessary licenses
from arcpy.sa import *
arcpy.CheckOutExtension("Spatial")
from arcpy import env
##Set the location for the Input Polys  ##You will need to loop through all three overlap categories


#wrk="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_Animals.gdb"
wrk="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_Plants.gdb"

env.workspace = wrk
#Set Location for the Buffered Individual Forest Unit Polys

zone_polys="C:\\Users\\Public\\2015Pros\\DEC_Lands_2015_July\\SF_UA_GIS.gdb\\sf_ua_individ_buff100m"



#set the snapraster
#env.snapRaster = "G:/_Beauty/_Howard/SnapRasters/snapras30met"
env.snapRaster= "C:\\Users\\Public\\Rapunzel\\SnapRasters\\snapras30met"
env.cellSize = env.snapRaster
env.overwriteOutput = True
outCoord = env.snapRaster

# Get all three of the PolyFiles
#polZ = arcpy.ListFeatureClasses("zon_Joined_final_C*","All")
polyF = arcpy.ListFeatureClasses("zon_FullLists_C_test*","All")


for i in range(len(polyF)):
    classLevel = polyF[i][-1:]
    inEDMs=polyF[i]
   
    inSFpolys=zone_polys
    inFeat=[inEDMs,inSFpolys]
    #print inFeat
    outFeat="zon_C"+classLevel+"_intersect_sfBuff100m"
    print "working on "+outFeat
    arcpy.Intersect_analysis(inFeat,outFeat)
    print "done with "+outFeat
    
inter_polys=arcpy.ListFeatureClasses("*_intersect_sfBuff100m","All")
##Dissolve the polys
for i in range(len(inter_polys)):
    inFeat=inter_polys[i]    
    classLevel=inter_polys[i][5:6]
    #print classLevel
    dissolveA='FID_zon_FullLists_C_test'+classLevel
    dissolveFields=[str(dissolveA),'FAC_ID']
    print dissolveFields
    outFeat="zon_C"+classLevel+"_intersect_sfBuff100m_diss"
    arcpy.Dissolve_management(inFeat,outFeat,dissolveFields,[["codeList","LAST"],["SciNames","LAST"],["CommNames","LAST"],["HabitatUse","LAST"],["FACILITY","LAST"],["FAC_ID","LAST"]],"MULTI_PART","DISSOLVE_LINES")

###Need to rename the fields to get rid of the "LAST_" leading 5 characters
polyD=arcpy.ListFeatureClasses("*_intersect_sfBuff100m_diss")   

for fc in polyD:
    fieldList=arcpy.ListFields(fc)
    for field in fieldList:
        if field.name.lower()=="last_codelist":
            print str(field.name)
            arcpy.AlterField_management(fc,field.name,"codeList","codeList")
        if field.name.lower()=="last_scinames":
            print str(field.name)
            arcpy.AlterField_management(fc,field.name,"SciNames","SciNames")
        if field.name.lower()=="last_commnames":
            print str(field.name)
            arcpy.AlterField_management(fc,field.name,"CommNames","CommNames")
        if field.name.lower()=="last_habitatuse":
            print str(field.name)
            arcpy.AlterField_management(fc,field.name,"HabitatUse","HabitatUse")
   
##Need to add Overlap Category Field, Overlap Definition Fields, Richness Fields

for fc in polyD:
    classLevel=fc[5:6]
    expression="'Overlap Category "+str(classLevel)+"'"
    print expression
##Add the Overlap Category Field    
    arcpy.AddField_management(fc,"OVERLAP","TEXT",20)
##Add the Overlap Definition Field
    arcpy.AddField_management(fc,"OVERLAPDEF","TEXT",150)  
###Depending on the classLevel, add the appropriate labels
    arcpy.CalculateField_management(fc,"OVERLAP",expression,"PYTHON")
    definition_1="'1 EDM per pixel. There may be more than one species listed in a polygon because more than one non-overlapping EDM may occur there.'"
    definition_2="'2 to 4 EDMs per pixel. There may be more than four species listed for a polygon because different EDMs may overlap in different locations.'"
    definition_3="'5 or more EDMs per pixel. There may be more than five species listed for a polygon because different EDMs may overlap in different locations.'"
    if str(classLevel)=='1':
        arcpy.CalculateField_management(fc,"OVERLAPDEF",definition_1,"PYTHON")
    if str(classLevel)=='2':
        arcpy.CalculateField_management(fc,"OVERLAPDEF",definition_2,"PYTHON")
    if str(classLevel)=='3':
        arcpy.CalculateField_management(fc,"OVERLAPDEF",definition_3,"PYTHON")
    else:
        print "These definitions did not work right"
   
    join_layer=wrk+"\\zon_Joined_final_C"+str(classLevel)
    print join_layer
    arcpy.AddField_management(fc,"Richness","SHORT")
### Need to Join the dissolved layer to the last layer that retained the richness data zon_Joined_final
#    ##First need to make a Table View from the desired Join Layer because arcpy for reasons passing understanding have decided you cannot join a feature class to another feature class
    join_table= wrk+"\\zon_Joined_final"+str(classLevel)+"_tableview"  
    if arcpy.Exists(join_table):
        print "Join tableview ready to go!"
    else: 
        arcpy.MakeTableView_management(join_layer,join_table)
## VAT_zon_C1_Richness is the form of the field
    field_List=str("VAT_zon_C"+classLevel+"_Richness")
    field_form=[field_List]
##Join based on the codelists and add the Richness field Directly, rather than doing Join, then Update
    arcpy.JoinField_management(fc,"codeList",join_table,"codeList",field_form)
    arcpy.CalculateField_management(fc,"Richness","!"+field_List+"!","PYTHON")
##Merge the Three Category classes together
##Create an empty Feature Class and append the three files into it
#outFeatures=arcpy.CreateFeatureclass_management(wrk,"All_species_2015","POLYGON",template=fc)
#outFeatures=wrk+"\\All_species_2015"

#arcpy.Append_management(polyD,outFeatures)
#arcpy.Merge_management(inputs=polyD,output=wrk+"\\All_Animals_2015") 
arcpy.Merge_management(inputs=polyD,output=wrk+"\\All_Plants_2015")    