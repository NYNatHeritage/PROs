#
# Created by Tim Howard, 2014
# New York Natural Heritage Program.
# Modified July 2015, Amy Conley, NYNHP
#
# This was built to mimic the AML script built by Jason Karl (hypergrid.aml)
# in 1999. Credit for the insight into building it goes to him.
#
# inputs:
#  1. you need a single folder containing species distribution models
#       represented as binary (0/1, not habitat/yes habitat)
#       grids (GeoTIFF). File name convention: <<sppcode>>_c.tif
#  2. a csv listing the species you want to include in the hypergrid.
#       This csv need to have the species code as the first column, and this code
#       needs to match the code name for the SDM (#1, above).
#   ** the list should (needs to?) be in alphabetical order and have no duplicates
#       (could check for both of these in code)

import os
#when running from NPP to python window, keep window open after exception or script completion
#os.environ['PYTHONINSPECT'] = "True"

# Import system modules
import arcpy
import sys
# import math

# Check out any necessary licenses
from arcpy.sa import *
arcpy.CheckOutExtension("Spatial")
from arcpy import env
from arcpy import management as man

#inPath = "D:/PRO2014/allCut_zro2"
#inPath="C:\\Users\\Public\\2015Pros\\Predicts2015\\cutGrids"
# For testing use just the subset of grids that were re-reun in July to include missing polys
#inPath="C:\\Users\\Public\\2015Pros\\Predicts2015\\cutGrids\\July_Reruns"
#inPath="C:\\Users\\Public\\2015Pros\\Predicts2015\\cutGrids\\Sample50"
inPath="C:\\Users\\Public\\OPRHP_Nat_Heritage_Ranks\\cutGrids"
#inPath="C:\\Users\\Public\\2015Pros\\Predicts2015\\CutGrids_All"
##outPath = "D:/PRO2014/hypergrids"

#wrk = "D:/PRO2014/workspace/wrk_Plant.gdb"
wrk= "C:\\Users\\Public\\2015Pros\\Hypergrid\\Workspace.gdb"
#wrk="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_Animals.gdb"
#wrk="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_Plants.gdb"
#wrk="C:/Users/Public/OPRHP_Nat_Heritage_Ranks/Nat_Heritage_Ranks.gdb"
# set the workspace for the input grids
env.workspace = inPath

# get a list of everything in the workspace
rasL = arcpy.ListRasters("*", "All")

#set the snapraster for reprojecting
#env.snapRaster = "C:/_Howard/SnapRasters/snapras30met"
env.snapRaster= "C:\\Users\\Public\\Rapunzel\\SnapRasters\\snapras30met"
env.overwriteOutput = True
outCoord = env.snapRaster

#get list of elems to run:
import csv
codeL = []
#fi = "D:/PRO2014/lists/PlantList_5Jan15.csv"
#fi = "C:\\Users\\Public\\2015Pros\\Hypergrid\\test_csv.csv"
#fi= "C:\\Users\\Public\\2015Pros\\Hypergrid\\Sample50.csv"
fi="C:\\Users\\Public\\2015Pros\\Hypergrid\NHSPRanks.csv"
#fi="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_All_Animals.csv"
#fi="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_All_Plants.csv"
with open(fi, 'rb') as csvf:
    reader = csv.reader(csvf)
    for row in reader:
        codeL.append(row[0])

# remove header
codeL = codeL[1:]

#make sure we have a raster for each item in codeL
for k in range(len(codeL)):
    ras = codeL[k] + "_c.tif"
    if ras not in rasL:
        sys.exit("lists don't match! " + "Check "+str(ras))

# currently the MAX number of species is 250
listLen = len(codeL)
if listLen > 250:
    sys.exit("too many elements!")
    
#####
# if restarting from midway through, change start value.
# otherwise start should be 0
start = 0
#####

# loop through all binary (0/1) grids, build the hypergrid
# with info stored in a single text column 
for i in range(start, len(codeL)):
    elem = codeL[i]
    rasName = elem + "_c.tif"
    if rasName in rasL:
        if i==0:
            inRas = inPath + "/" + rasName
            curHyp = wrk + "/hyp" + str(i)
            print("working on " + rasName)
            man.CopyRaster(inRas, curHyp)
            man.BuildRasterAttributeTable(curHyp)
            man.AddField(curHyp,"spp0", "TEXT","","",251)
            man.AddField(curHyp,"temp", "SHORT",1)
            expr = "str( !Value! )"
            man.CalculateField(curHyp,"spp0",expr,"PYTHON")
        else:
            iminus = i-1
            prevHyp = wrk + "/hyp" + str(iminus)
            print("working on " + elem + ", " + str(i) + " of " + str(listLen))
            curHyp = Combine([prevHyp,rasName])
            curHyp.save(wrk + "/hyp" + str(i))
            man.AddField(curHyp,"spp0", "TEXT","","",251)
            jval = "hyp" + str(iminus)
            man.JoinField(curHyp, jval, prevHyp, "VALUE", ["spp0"])
            rasNoDot = rasName[0:rasName.find(".")]
            newCol = rasNoDot[0:11].upper()
            expr = "str(!spp0_1!) + str(!" + newCol + "!)"
            man.CalculateField(curHyp,"spp0",expr,"PYTHON")
            #clean up
            man.Delete(prevHyp)

# clean up a little more
man.DeleteField(curHyp, [jval.upper(),newCol,"spp0_1"])

#needed to continue below if you comment out the previous loop for any reason 
#curHyp = wrk + "/hyp" + str(len(codeL)-1)

# expand information out to one col for each spp. 
print("adding columns...")
for i in range(len(codeL)):
    newCol = codeL[i].upper()
    print("..." + newCol)
    man.AddField(curHyp, newCol, "SHORT")
    #expr="str(!supp0!)[i:i+1]"
    expr = "str(!spp0!)["+str(i)+":"+str(i+1)+"]"
    print (expr)
    man.CalculateField(curHyp,newCol,expr,"PYTHON")
    
# create a richness col
print("calculating richness")
newCol = "Richness"
man.AddField(curHyp, newCol, "SHORT")
expr = "sum(int(i) for i in !spp0!)"
man.CalculateField(curHyp,newCol,expr,"PYTHON")

print("done!")
