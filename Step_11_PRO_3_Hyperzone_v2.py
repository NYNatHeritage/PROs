#PROs Final Prep 3: Hyperzones
# Created by Tim Howard, 2014
# New York Natural Heritage Program.
#
# modeled after hyperzone.aml, created by Jason Karl & Leona Svancara (v3: 03/18/02)


import os
#when running from NPP to python window, keep window open after exception or script completion
#os.environ['PYTHONINSPECT'] = "True"
import re # regex library

# Import system modules
import arcpy

# Check out any necessary licenses
from arcpy.sa import *
arcpy.CheckOutExtension("Spatial")
from arcpy import env
from arcpy import management as man

##Looks like the inpath should be the folder that contains the binaries, like in Step 9
#inPath = "D:/PRO2014/allCut_zro2"
#inPath="C:\\Users\\Public\\2015Pros\\Predicts2015\\cutGrids\\Sample50"
inPath="C:\\Users\\Public\\2015Pros\\Predicts2015\\CutGrids_All"
##outPath = "D:/PRO2014/hypergrids"

# get a list of the EDMs
#env.workspace = inPath
#rasL = arcpy.ListRasters("*","All")

#get list of elems to run:
import csv
rasL = []
#fi = "D:/PRO2014/lists/PlantList_5Jan15.csv"
#fi= "C:\\Users\\Public\\2015Pros\\Hypergrid\\Sample50.csv"
#fi="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_All_Animals.csv"
fi="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_All_Plants.csv"
with open(fi, 'rb') as csvf:
    reader = csv.reader(csvf)
    for row in reader:
        rasL.append(row[0])

#strip header
rasL = rasL[1:]
        
# move the workspace
#wrk = "D:/PRO2014/workspace/wrk_Plant.gdb"
#wrk= "C:\\Users\\Public\\2015Pros\\Hypergrid\\Workspace3.gdb"
#wrk="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_Animals.gdb"
wrk="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_Plants.gdb"
env.workspace = wrk

#set the snapraster
#env.snapRaster = "C:/_Howard/SnapRasters/snapras30met"
env.snapRaster= "C:\\Users\\Public\\Rapunzel\\SnapRasters\\snapras30met"
env.cellSize = env.snapRaster
env.overwriteOutput = True
outCoord = env.snapRaster

# what are the zone rasters
hypZ = arcpy.ListRasters("hyp_Zones_Class*","All")
# subset the list to exclude the ones containing the word 'clipped'
m = "clipped"
hypZ = [l for l in hypZ if l.find(m) == -1]

##rasL = rasL[3:8] #some test rasters

# cycle through each zone raster
for i in range(len(hypZ)):
    print("working on " + hypZ[i])
    # don't assume i is the class level -- extract class here
    classLevel = hypZ[i][-1:]
    curZo = wrk + "/zon_C" + classLevel
    # cycle through each edm
    for j in range(len(rasL)):
        if j==0:
            inRas = inPath + "/" + rasL[j] + "_c.tif"
            curZoT_out = wrk + "/zonTab_C" + str(i) + "_" + str(j)
            print(".. zoning " + rasL[j])
            curZoT = ZonalStatisticsAsTable(hypZ[i],"Value", inRas, curZoT_out, "DATA", "MAXIMUM")
            man.CopyRaster(hypZ[i], curZo)
            man.AddField(curZo,"spp0","TEXT","","",251)
            man.JoinField(curZo, "Value", curZoT, "VALUE", ["MAX"])
            expr = "str( !MAX! )"
            man.CalculateField(curZo,"spp0",expr,"PYTHON")
            man.DeleteField(curZo,"MAX")
            man.Delete(curZoT_out)
        else:
            #jminus = j-1
            inRas = inPath + "/" + rasL[j] + "_c.tif"
            print(".. zoning " + rasL[j])
            curZoT_out = wrk + "/zonTab_C" + str(i) + "_" + str(j)
            curZoT = ZonalStatisticsAsTable(hypZ[i],"Value", inRas, curZoT_out, "DATA", "MAXIMUM")
            man.JoinField(curZo,"Value",curZoT,"VALUE",["MAX"])
            expr = "str(!spp0!) + str(!MAX!)"
            man.CalculateField(curZo,"spp0",expr,"PYTHON")
            man.DeleteField(curZo,"MAX")
            man.Delete(curZoT_out)
    # expand information out to one col for each spp. 
    print("adding columns...")
    for i in range(len(rasL)):
        #rasName = rasL[i] + "_c.tif"
        #rasNoUnderscore = rasName[0:rasName.find("_")]
        rasNoUnderscore = rasL[i]
        newCol = rasNoUnderscore[0:11].upper()
        print("..." + newCol)
        man.AddField(curZo, newCol, "SHORT")
        # rarely the join may result in an empty row, handle that issue here
        tmpVw = "tmpVw"
        expr = "\"spp0\" <> ''"
        arcpy.MakeTableView_management(curZo,tmpVw, expr)
        # now do the calculation
        expr = "str(!spp0!)[i:i+1]"
        print (expr)
        expr = "str(!spp0!)["+str(i)+":"+str(i+1)+"]"
        print (expr)
        man.CalculateField(tmpVw,newCol,expr,"PYTHON")
    # create a richness col
    print("calculating richness")
    newCol = "Richness"
    man.AddField(curZo, newCol, "SHORT")
    expr = "sum(int(i) for i in !spp0!)"
    man.CalculateField(curZo,newCol,expr,"PYTHON")


# cycle through each zone raster
for i in range(len(hypZ)):
    print("linking zones up to polys")
    print("working on " + hypZ[i])
    # don't assume i is the class level -- extract class here
    classLevel = hypZ[i][-1:]
    curZo = wrk + "/zon_C" + classLevel
    polyZo = wrk + "/hyp_backOut_dissolve_" + classLevel
    polyZoLyr = "polyZoLayer"
    # join the table from the raster to the poly zone layer
    man.MakeFeatureLayer(polyZo, polyZoLyr)
    man.AddJoin(polyZoLyr,"OBJECTID", curZo, "OBJECTID", "KEEP_ALL")
    # find any polys with Richness below zone level
    # each dict entry is [zone: min richness]
    dictMinRich = {1:1,2:2,3:5}
    targMinRich = dictMinRich[int(classLevel)]
    expr = "Richness >= " + str(targMinRich)
    man.SelectLayerByAttribute(polyZoLyr, "NEW_SELECTION", expr)
    # write out the selected set
    outFeat = wrk + "/zon_Joined_C" + classLevel
    man.CopyFeatures(polyZoLyr, outFeat)
    # if rows were dropped AND we are above level 1, then need
    # to add dropped polys to one level down.
    numRowsSelSet = int(man.GetCount(polyZoLyr).getOutput(0))
    numRowsLyr = int(man.GetCount(polyZo).getOutput(0))
    if numRowsSelSet < numRowsLyr & int(classLevel) > 1:
        expr = "Richness < " + str(targMinRich)
        man.SelectLayerByAttribute(polyZoLyr, "NEW_SELECTION", expr)
        destinedLevel = int(classLevel) - 1
        # write out the selected set
        outFeat = wrk + "/zon_AddThesePolysTo_C" + str(destinedLevel)
        man.CopyFeatures(polyZoLyr, outFeat)
    # if the prev if statement was acted on, then grab
    # those data in the next loop
    feats = arcpy.ListFeatureClasses()
    primFeat = wrk + "/zon_Joined_C" + classLevel
    outFeat = wrk + "/zon_Joined_final_C" + classLevel
    targFeat = "zon_AddThesePolysTo_C" + classLevel
    if targFeat in feats:
        man.Merge([primFeat, targFeat],outFeat)
    else:
        man.CopyFeatures(primFeat, outFeat)

print("done!")

 

            
