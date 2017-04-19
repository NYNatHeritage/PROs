#
# Created by Tim Howard, 2014
# New York Natural Heritage Program.
#
# modeled after hyperzone.aml, created by Jason Karl & Leona Svancara (v3: 03/18/02)


import os
import csv
#when running from NPP to python window, keep window open after exception or script completion
#os.environ['PYTHONINSPECT'] = "True"
#import re # regex library

# Import system modules
import arcpy

# Check out any necessary licenses
from arcpy.sa import *
arcpy.CheckOutExtension("Spatial")
from arcpy import env
from arcpy import management as man

# move the workspace
#wrk = "D:/PRO2014/workspace/wrk_Plant.gdb"
#wrk= "C:\\Users\\Public\\2015Pros\\Hypergrid\\Workspace3.gdb"
#wrk="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_Animals.gdb"
wrk="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_Plants.gdb"
env.workspace = wrk

#set the snapraster
#env.snapRaster = "G:/_Beauty/_Howard/SnapRasters/snapras30met"
env.snapRaster= "C:\\Users\\Public\\Rapunzel\\SnapRasters\\snapras30met"
env.cellSize = env.snapRaster
env.overwriteOutput = True
outCoord = env.snapRaster

# what are the zone rasters
#polZ = arcpy.ListFeatureClasses("zon_Joined_final_C*","All")
polZ = arcpy.ListFeatureClasses("zon_Joined_final_Ctest*","All")

###Check that reads file well
#input_file=csv.DictReader(open("C:\\Users\\Public\\2015Pros\\Hypergrid\\Sample501.csv"))
#for row in input_file:
#    print row

# get full names, can be larger list
##namesFile = "G:/Projects/LF_PRO_2014/lists/PRO2014_allSpp.csv"
#namesFile = "D:/PRO2014/lists/PlantList_5Jan15.csv"
#namesFile= "C:\\Users\\Public\\2015Pros\\Hypergrid\\Sample501.csv"
#namesFile="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_All_Animals.csv"
namesFile="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_All_Plants.csv"
### New naming conventions need to be added due to the inclusion of multiple habitat use classes for species
##Adding "Loc_Use" field to be included

#field_names = ["code","sciname","commname"]
field_names = ["code","sciname","commname","Loc_Use"]
csv_file = open(namesFile)
csv_reader = csv.DictReader(csv_file, fieldnames=field_names)


lst = []
for i in csv_reader:
    lst.append(i)
sciNames = {}
for i in lst:
    sciNames[i['code']] = i['sciname']
commNames = {}
for i in lst:
    commNames[i['code']] = i['commname']
habitat_Use = {}
for i in lst:
    habitat_Use[i['code']] = i['Loc_Use']    
# cycle through each zone raster
for i in range(len(polZ)):
    print("working on " + polZ[i])
    # don't assume i is the class level -- extract class here
    #classLevel = polZ[i][-1:]
    classLevel = "test"
    curZo = "zon_Joined_final_C" + classLevel
    fldCodeList = [f.name for f in arcpy.ListFields(curZo, "codeList","Text")]
    if not fldCodeList:
        man.AddField(curZo,"codeList","TEXT","","","500")
    fldSciNmList = [f.name for f in arcpy.ListFields(curZo, "SciNames","Text")]
    if not fldSciNmList:
        man.AddField(curZo,"SciNames","TEXT","","","550")
    fldCmNmList = [f.name for f in arcpy.ListFields(curZo, "CommNames","Text")]
    if not fldCmNmList:
        man.AddField(curZo,"CommNames","TEXT","","","500")
    fldHabUseList = [f.name for f in arcpy.ListFields(curZo, "HabitatUse","Text")]
    if not fldHabUseList:
        man.AddField(curZo,"HabitatUse","TEXT","","","500")
    flds = [f.name for f in arcpy.ListFields(curZo, "VAT_zon*")]
    # messy, could be cleaner with regex and list comprehensions!
    flds = [x for x in flds if "OBJECTID" not in x]
    flds = [x for x in flds if "Value" not in x]
    flds = [x for x in flds if "Count" not in x]
    flds = [x for x in flds if "spp0" not in x]
    flds = [x for x in flds if "Richness" not in x]
    namesOnly = [i[11:] for i in flds]
    rows = arcpy.UpdateCursor(curZo)
    for row in rows:
        sppString = ""
        sciString = ""
        comnString = ""
        habString = ""
        for i in range(len(flds)):
            if row.getValue(flds[i]) == 1:
                sppCd = flds[i][11:]
                sppString = sppString + ", " + sppCd
                #find the full name
                Sci = sciNames[sppCd.lower()]
                sciString = sciString + ", " + Sci
                Comm = commNames[sppCd.lower()]
                comnString = comnString + ", " + Comm
                Hab = habitat_Use[sppCd.lower()]
                ##Consider 
                if Hab=="": 
                    habString = habString 
                else:
                    habString= habString + ", " + Sci+": " + Hab
                #habString = habString + ", " + Hab
        row.codeList = sppString[2:] #chop the first comma-space
        row.SciNames = sciString[2:]
        row.CommNames = comnString[2:]
        row.HabitatUse= habString[2:]
        rows.updateRow(row)
    del rows, row
    ## delete unwanted fields
    #outFeat = "zon_FullLists_C_test" + classLevel
    outFeat = "zon_FullLists_C_test_actest"
    man.CopyFeatures(curZo, outFeat)
    fldList = [f.name for f in arcpy.ListFields(outFeat, "VAT_zon_*")]
    man.DeleteField(outFeat,fldList)
    fldList = [f.name for f in arcpy.ListFields(outFeat, "hyp_backOut*")]
    man.DeleteField(outFeat,fldList)
    print("  final file is " + outFeat)

    
# consider automating the labeling of all pro polys with Facility name, and also other attribute fields we need to add     