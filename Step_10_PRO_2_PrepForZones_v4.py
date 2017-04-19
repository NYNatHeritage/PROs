#
# Created by Tim Howard, 2014
# New York Natural Heritage Program.
#
# This script prepares a hypergrid for use in the hyperzone script. The intent is to follow
#   the approach taken by Heidi Krahling (GIS extraordinnaire) on the very first round
#   of PRO development, a method developed through a team effort.
#
# inputs:
#   1. file geodatabase containing the hypergrid, created using "PRO_1_HyperGrid..."
#       assumes hypergrid is named "hyp<<some number>>"
#   2. file geodatabase containing state forest units, buffered 100m, as a raster.
#       see other instructions for preparing this raster.
#   3. A snapraster, for consistency

# For 32-bit arcpy, this script creates memory problems, need to use within 
# ArcGIS to get access to LAA technology. This should repair itself with upgrades
# to 64-bit arcpy. 

import os
#when running from NPP to python window, keep window open after exception or script completion
#os.environ['PYTHONINSPECT'] = "True"

# Import system modules
import arcpy

# Check out any necessary licenses
from arcpy.sa import *
arcpy.CheckOutExtension("Spatial")
from arcpy import env
from arcpy import management as man

#wrk = "D:/PRO2014/workspace/wrk_Plant.gdb"
#wrk= "C:\\Users\\Public\\2015Pros\\Hypergrid\\Workspace2.gdb"
#wrk= "C:\\Users\\Public\\2015Pros\\Hypergrid\\Workspace3.gdb"
#wrk="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_Animals.gdb"
wrk="C:\\Users\\Public\\2015Pros\\Hypergrid\\PROs2015_Plants.gdb"
#slf = "D:/PRO2014/workspace/SF_UA_2014.gdb/sf_ua_121014_dissolve_buff100m_grid"
#slf= "C:\\Users\\Public\\2015Pros\\Hypergrid\\SF_UA_2014.gdb\\sf_ua_121014_dissolve_buff100m_grid"
slf="C:\\Users\\Public\\2015Pros\\DEC_Lands_2015_July\\SF_UA_GIS.gdb\\sf_ua_dissolve_grid_buff100m"
# set the workspace for the input grids
env.workspace = wrk

#set the snapraster
#env.snapRaster = "C:/_Howard/SnapRasters/snapras30met"
env.snapRaster= "C:\\Users\\Public\\Rapunzel\\SnapRasters\\snapras30met"
env.cellSize = env.snapRaster
env.overwriteOutput = True
outCoord = env.snapRaster

# what's the name of the hypergrid
hyp = arcpy.ListRasters("hyp*","All")[0]

# clip the hypergrid
print('clipping')
hyp_cl = Con(Raster(slf)>=0, hyp, Raster(slf))
man.JoinField(hyp_cl, "VALUE", hyp, "VALUE", ["Richness"])

print('reclassifying')
# reclassify to four groups based on richness
# 0 = 0 (none)
# 1 = 1 (low)
# 2-4 = 2 (medium)
# 5 and up = 3 (high)

#get the max of the raster
rows = arcpy.SearchCursor(hyp_cl, "", "", "Richness", "Richness A")
val = 0
for row in rows:
    if val < row.Richness:
        val = row.Richness
del row
del rows

### use that max in the reclass setup
remapVals= [[0,0,0],[1,1,1],[2,4,2],[5,val,3]] #need to have at least Richness=5 for this to work
remap = RemapRange(remapVals)
reclassField = "Richness"
outReclass = Reclassify(hyp_cl, reclassField, remap, "NODATA")
outF = wrk + "/hyp_rcl"
outReclass.save(outF)

#get a list of the classes used in Reclassify, above
classes = [i[2] for i in remapVals]

for i in range(len(classes)):
    cl_str = str(classes[i])
    cl_int = classes[i]
    print("extracting class " + cl_str)
    selStr = '"Value" = ' + cl_str
    outR = ExtractByAttributes(outReclass, selStr)
    outName = "hyp_Class_" + cl_str
    outR.save(outName)
    print(" .. to poly")
    outPoly = "hyp_pol_Class_" + cl_str
    arcpy.RasterToPolygon_conversion(outR, outPoly, "NO_SIMPLIFY","VALUE")
    print(" .. buffering")
    outBuff = "hyp_pol_buff_Class_" + cl_str
    arcpy.Buffer_analysis(outPoly, outBuff, 32, "FULL", "ROUND", "ALL")
    man.Delete(outPoly)
    print(" .. removing singletons")
    outMultiPart = "hyp_pol_buff_m_Class_" + cl_str
    arcpy.MultipartToSinglepart_management(outBuff, outMultiPart)
    man.Delete(outBuff)
    tmpSelLyr = "tmpSelectSet"
    expr = '"Shape_Area" < 7900'
    arcpy.MakeFeatureLayer_management(outMultiPart, tmpSelLyr)
    arcpy.SelectLayerByAttribute_management(tmpSelLyr, "NEW_SELECTION", expr)
    if int(arcpy.GetCount_management(tmpSelLyr).getOutput(0)) > 0:
        arcpy.DeleteFeatures_management(tmpSelLyr)
    #add a field to the attribute table
    fldName = "Class"
    fldVal = cl_int
    arcpy.AddField_management(outMultiPart, fldName, "SHORT")
    #expr = '"' + cl_int + '"'
    expr = cl_int
    arcpy.CalculateField_management(outMultiPart, fldName, expr, "PYTHON")
                          
# erase through the classes
print("removing overlaps")
for i in range(len(classes)-1,0,-1):
    # cookie cutter highest class into next lower class
    if i == (len(classes)-1):
        cl = str(classes[i])
        cl_lower = str(classes[i]-1)
        print(" .. cutting " + cl + " into " + cl_lower)
        eraseFeat = "hyp_pol_buff_m_Class_" + cl
        featGettingErased = "hyp_pol_buff_m_Class_" + cl_lower
        outFeat = "hyp_erased_" + cl_lower
        arcpy.Erase_analysis(featGettingErased, eraseFeat, outFeat)
        #join them to cookie cutter next layer
        outMerge = "hyp_erased_" + cl + "_" + cl_lower
        arcpy.Merge_management([eraseFeat, outFeat],outMerge)
        man.Delete(outFeat)
    else:
        cl = str(classes[i])
        cl_lower = str(classes[i]-1)
        cl_upper = str(classes[i]+1)
        print(" .. cutting " + cl + " into " + cl_lower)
        eraseFeat = "hyp_erased_" + cl_upper + "_" + cl
        featGettingErased = "hyp_pol_buff_m_Class_" + cl_lower
        outFeat = "hyp_erased_" + cl_lower
        arcpy.Erase_analysis(featGettingErased, eraseFeat, outFeat)
        outMerge =  "hyp_erased_" + cl + "_" + cl_lower
        arcpy.Merge_management([eraseFeat, outFeat],outMerge)
        man.Delete(eraseFeat)
        man.Delete(outFeat)
        
#explode the final layer
outMultiPart = "hyp_erased_expl_All_Levels"
arcpy.MultipartToSinglepart_management(outMerge, outMultiPart)
man.Delete(outMerge)
    
# Write separate classes back out, *with* slivers from adjacent lower level
# then merge using eliminate
# drop class 0 from the list
for i in reversed(range(len(classes)-1)):
    cl_str = str(classes[i+1])
    cl_int = classes[i+1]
    cl_lower_str = str(classes[i])
    print("merging slivers and writing class " + cl_str)
    tmpSelLyr = "tmpSelectSet"
    #get the slivers from the next class down
    expr = '"Shape_Area" < 900 AND "Class" = ' + cl_lower_str
    arcpy.MakeFeatureLayer_management(outMultiPart, tmpSelLyr)
    arcpy.SelectLayerByAttribute_management(tmpSelLyr, "NEW_SELECTION", expr)
    #get the non-slivers from this class 
    expr = '"Shape_Area" > 899.99 AND "Class" = ' + cl_str
    arcpy.SelectLayerByAttribute_management(tmpSelLyr, "ADD_TO_SELECTION", expr)
    #write out the selection
    outFeat = "hyp_backOut_" + cl_str
    arcpy.CopyFeatures_management(tmpSelLyr, outFeat)
    #now use eliminate on this feature class
    inFeat = "hyp_backOut_" + cl_str
    tmpSelLyr2 = "tmpSelectSet2"
    expr = '"Shape_Area" < 900'
    arcpy.MakeFeatureLayer_management(inFeat, tmpSelLyr2)
    arcpy.SelectLayerByAttribute_management(tmpSelLyr2, "NEW_SELECTION", expr)
    outFeat = "hyp_backOut_Elim_" + cl_str
    arcpy.Eliminate_management(tmpSelLyr2, outFeat)
    man.Delete(inFeat)
    # Heidi's notes indicate there may be cases where slivers
    # are present but not adjacent the next higher up class
    # and in these cases they should be deleted. 
    tmpSelLyr3 = "tmpSelectSet3"
    #get any remaining slivers and remove them.
    expr = '"Shape_Area" < 900'
    arcpy.MakeFeatureLayer_management(outFeat, tmpSelLyr3)
    arcpy.SelectLayerByAttribute_management(tmpSelLyr3, "NEW_SELECTION", expr)
    if int(arcpy.GetCount_management(tmpSelLyr3).getOutput(0)) > 0:
        arcpy.DeleteFeatures_management(tmpSelLyr3)
    # merge pieces back up (dissolve), original PRO seems to have this
    polysToDiss = "hyp_backOut_Elim_" + cl_str
    outFeatFin = "hyp_backOut_dissolve_" + cl_str
    arcpy.Dissolve_management(polysToDiss, outFeatFin, "ORIG_FID", "", "MULTI_PART")
    #finally make raster zones for each class
    print(" .. writing to raster")
    inPolys = outFeatFin
    outRas = "hyp_Zones_Class_" + cl_str
    arcpy.PolygonToRaster_conversion(inPolys, "OBJECTID", outRas)
    # looks like Heidi didn't clip but used the full raster, if clip is wanted:
        #inMask = "hyp_Class_" + cl_str
        #outMasked = ExtractByMask(outRas, inMask)
        #outMasked.save("hyp_Zones_Class_clipped_" + cl_str)
    ## clean up
    man.Delete(polysToDiss)
        

# could delete outMultipart here


