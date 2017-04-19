# New RF methods
# Built by Tim Howard, New York Natural Heritage Program
# thoward@tnc.org, tghoward@gw.dec.state.ny.us
# Last modified, Spring 2011
library(RSQLite)
library(ROCR)    #for ROC plots and stats
library(vcd)     #for kappa stats
library(abind)   #for collapsing the nested lists
library(RODBC)   #for talking to other databases
library(foreign) #for reading dbf files
library(randomForest)
#library(bigmemory)
#library(ff)

#####
#
#
#  Lines that require editing
#
# directory for file locations
#setwd("C:/_BeautyArchive/_NYNHP/GIS_data/ElementData/InputFiles")
setwd("C:/Users/Public/2015Pros")
# the names of the files to be uploaded
# presence points
#df.in <-read.dbf("Lycmelsa_att_grd.dbf")
#The second method requires that you have the project workspace loaded that contains att_pres_points, the list of data frames
#With species points attributed
#But could also export each to a seperate file, for backup in case the .RData file becomes comprimised
#Need to drop some fields from the att_pres_points
drop_list<-c("siteID","xcoord","ycoord","mdcaty","wgt","panel","EvalStatus","EvalReason","COMMNAME","expl_ID","py_AreaM2","expl_ID2","PolySampNu")
for (i in 83:89){
  

df.in<-att_pres_points[[i]][,!(names(att_pres_points[[i]]) %in% drop_list)]
# absence points
#df.abs <- read.dbf("10k_backgroundPts_July2011_att.dbf")
df.abs<-att_background
#
#  End, lines that require editing
#
#
#####

# add pres
df.in <- cbind(df.in, pres=1)
# add matching cols from df.in to df.abs
df.abs <- cbind(df.abs, stratum="pseu-a", EO_ID=99999, pres=0)

##lower case column names
names(df.in) <- tolower(names(df.in))
names(df.abs) <- tolower(names(df.abs))

#remove nulls
df.in <- df.in[(rowSums(df.in == -9999, na.rm = TRUE))==0,]
df.abs <- df.abs[(rowSums(df.abs == -9999, na.rm = TRUE))==0,]
#Try a new method for removing Nulls
df.abs<-df.abs[complete.cases(df.abs),]
df.in<-df.in[complete.cases(df.in),]

colList <- c("sci_name","eo_id","pres","stratum", 
		"ccapnhp6","ccapnhp09","gclass09","nyaspct09",
		"surfg2209","awc_mm09","canopy01","canopy10","canopy33","ccapfor10","ccapfor33","ccapopn10",
		"ccapopn33","ccapscs10","ccapscs33","ccapwet10","ccapwet33","ccapwtr10", "ccapwtr33",
		"cec1t09", "clay1t09", "devpct01", "devpct10", "devpct33", "distcal09", 
		"nyelev09", "nyslope09", "om1t09", "perm1t09", 
		"ph1t09", "prec05n09", "prec06n09", "prec07n09", "prec13n09", 
		"solrad09", "tmef05dm", "tmef06dm", "tmef07dm", "tmef14dm", 
		"topo1809", "topo3309", "topoall09", "twi_t09", "znhist_03"
		   )
# if colList gets modified, also modify the locations for the independent and dependent variables, here
#If we aren't using the grid method than reduce count of ind variables
depVarCol <- 3
indVarCols <- c(5:48)

# create a list of definitions for each envar that is a factor
factor.defs <- list(
	pres = c(0,1),
	ccapnhp09 = c(2:15,17:23,"-9999"),
	ccapnhp6 = c("12","1323","1921","2345","67820","91011","-9999"),
	gclass09 = c(seq(100,700, by=100),"900","997","999","-9999"),
	nyaspct09 = c(1:9,"-9999"),
	surfg2209 = c("1", "3", 8:12, "15", "16", "26", "27", "32", "33", "35", "417", "562", "1830", "2229", "3134", "142513", "192021", "723248","-9999"))
	
#re-arrange
df.in <- df.in[,colList]
df.abs <- df.abs[,colList]

# fix a couple of items missing a period after ssp
#df.in$sci_name <- gsub("Euryea longicauda", "Eurycea longicauda", df.in$sci_name)
#df.in$SCI_NAME <- sub(" ssp ", " ssp. ", df.in$SCI_NAME)

#table(df.in$sci_name)
# grab a list of names
elems <- unique(df.in$sci_name)

#subset based on what's already been run
#elems <- elems[-c(1:9)]

for (elem.i in 1:length(elems)){
	df.in.ss <- subset(df.in,sci_name == elems[elem.i])

	#Fire up SQLite
	db_file<-"C:\\Users\\Public\\2015Pros\\BackEnd.sqlite"
	db<-dbConnect(SQLite(),dbname=db_file)  
  
  ##  open up a "channel" to the Access DB to lookup common name and code
	#Cn.MDB.in.i <- odbcConnect("EDM_in_i")  #attribute data about the element and record processsing (i=info)
	##set up an object to store the names
	ElementNames <- as.list(c(SciName="",CommName="",Code="",Type=""))
	ElementNames[1] <- as.character(df.in.ss[1,"sci_name"])

	##get the names used in metadata output
	##could return multiple rows, so get RedoStat as well, sort descending by RedoStat
	SQLquery <- paste("SELECT Code, RedoStat FROM tblInputs WHERE SCIEN_NAME = '", ElementNames[1],
	                    "' ORDER BY RedoStat DESC;", sep="")
	#ElementNames[3] <- as.list(sqlQuery(channel = Cn.MDB.in.i, query = SQLquery)[1,1]) #grab most recent code
	ElementNames[3] <- as.list(dbGetQuery(db, statement = SQLquery)[1,1])
  SQLquery <- paste("SELECT Commonname FROM tblInputs WHERE SCIEN_NAME = '", ElementNames[1],"';", sep="")
	#ElementNames[2] <- sqlQuery(channel = Cn.MDB.in.i, query = SQLquery)
	ElementNames[2] <- dbGetQuery(db, statement = SQLquery)
	#ElementNames[2] <- as.list(sqlQuery(channel = Cn.MDB.in.i, query = SQLquery)[1,1]) #grab only one
	ElementNames[2] <- as.list(dbGetQuery(db, statement = SQLquery)[1,1]) 
	SQLquery <- paste("SELECT ELEMTYPE FROM tblInputs WHERE SCIEN_NAME = '", ElementNames[1],"';", sep="")
	#ElementNames[4] <- as.list(sqlQuery(channel = Cn.MDB.in.i, query = SQLquery)[1,1]) #grab only one
	ElementNames[4] <- as.list(dbGetQuery(db, statement = SQLquery)[1,1])
	ElementNames
	#
	#close(Cn.MDB.in.i)
	#rm(Cn.MDB.in.i)
	dbDisconnect(db)
	abbr <- as.character(ElementNames$Code) #needed for export - but not used right now
	
	##row bind the pseudo-absences with the presence points
	df.abs$eo_id <- factor(df.abs$eo_id)
	df.full <- rbind(df.in.ss, df.abs)
	#
	##display
	#fncDC(df.full)
	##make factors using definitions set up earlier
	for(colName in names(factor.defs)) {
        df.full[[colName]] <- factor(df.full[[colName]],
		levels=factor.defs[[colName]])
      } 
	#reset these factors to remove values from other species 
	df.full$stratum <- factor(df.full$stratum)
	df.full$eo_id <- factor(df.full$eo_id)
	
	#now that entire set is cleaned up, split back out to use any of the three DFs below
	df.in2 <- subset(df.full,pres == "1")
	df.abs2 <- subset(df.full, pres == "0")
  
	df.in2$stratum <- factor(df.in2$stratum)
	df.abs2$stratum <- factor(df.abs2$stratum)
  
	df.in2$eo_id <- factor(df.in2$eo_id)
	df.abs2$eo_id <- factor(df.abs2$eo_id)
	
	#reset the row names, needed for random subsetting method of df.abs2, below
	row.names(df.in2) <- 1:nrow(df.in2)
	row.names(df.abs2) <- 1:nrow(df.abs2)

	#display
	#fncDL(df.full)

	### RF ###
	  #fncTuneRF2(df.full[,indVarCols], df.full[,depVarCol], "full",10,1)
	  #fncTuneRF2(df.full[,indVarCols], df.full[,depVarCol], "full",5,2)
	  #fncTuneRF2(df.full[,indVarCols], df.full[,depVarCol], "full",6,3)
	  #full.tuneRF1
	  #full.tuneRF2
	  #full.tuneRF3

	##### set mtry
	mtry <- 5
	#####

	#how many polygons do we have?
	numPys <-  nrow(table(df.in2$stratum))
	#how many EOs do we have?
	numEOs <- nrow(table(df.in2$eo_id))

	#initialize the grouping list,
	group <- vector("list")

	# if we are stratifying by grid, set up the groups that way
	# if we are stratifying by polygon, likewise
	if(sum(grep("point", df.in$stratum)) > 0) {
		group$colNm <- "fid_10kgrd"
		group$JackknType <- "10 km grid"
		group$vals <- names(table(df.in2$fid_10kgrd))
	} else {
		group$colNm <- ifelse(numEOs < 10,"stratum","eo_id")
		group$JackknType <- ifelse(numEOs < 10,"polygon","element occurrence")
		#if we have fewer than 10 EOs, move forward with jackknifing by polygon, otherwise
		#jackknife by EO.
		if(numEOs < 10) {
	            group$vals <- unique(df.in2$stratum)
	            } else {
	            group$vals <- unique(df.in2$eo_id)
	            }
	}

	# reduce the number of groups, if there are more than 100, to 100 groups
	# this groups the groups simply if they are adjacent in the order created above.
	#  -- the routine runs out of memory if groups go over about 250 (WinXP 32 bit, 3GB avail RAM)
	if(length(group$vals) > 100) {
		in.cut <- cut(1:length(group$vals), b = 100)
		in.split <- split(group$vals, in.cut)
		names(in.split) <- NULL 
		group$vals <- in.split	
		group$JackknType <- paste(group$JackknType, ", grouped to 100 levels,", sep = "")	
	}		
	
	#reduce the number of trees if group$vals has more than 15 entries
	if(length(group$vals) > 15) {
		ntrees <- 200
		} else {
		ntrees <- 500
	}

	##initialize the Results vectors for output from the jackknife runs
	trRes <- vector("list",length(group$vals))
	   names(trRes) <- group$vals[]
	evSet <- vector("list",length(group$vals))
	   names(evSet) <- group$vals[]	   
	evRes <- vector("list",length(group$vals))
	   names(evRes) <- group$vals[]
	t.f <- vector("list",length(group$vals))
	   names(t.f) <- group$vals[]
	t.ctoff <- vector("list",length(group$vals))
	   names(t.ctoff) <- group$vals[]
	v.rocr.rocplot <- vector("list",length(group$vals))
	   names(v.rocr.rocplot) <- group$vals[]
	v.rocr.auc <- vector("list",length(group$vals))
	   names(v.rocr.auc) <- group$vals[]
	v.y <- vector("list",length(group$vals))
	   names(v.y) <- group$vals[]
	v.kappa <- vector("list",length(group$vals))
	   names(v.kappa) <- group$vals[]
	v.tss <- vector("list",length(group$vals))
	   names(v.tss) <- group$vals[]
	v.OvAc <- vector("list",length(group$vals))
	   names(v.OvAc) <- group$vals[]
	t.importance <- vector("list",length(group$vals))
	   names(t.importance) <- group$vals[]
	t.rocr.pred <- vector("list",length(group$vals))
	   names(t.rocr.pred) <- group$vals[]
	v.rocr.pred <- vector("list",length(group$vals))
	   names(v.rocr.pred) <- group$vals[]

	###print(paste("starting on ", ElementNames[[1]], sep=""))
	cat("starting on", ElementNames[[1]], "\n")

	if(length(group$vals)>1){
		for(i in 1:length(group$vals)){
			   # Create an object that stores the select command, to be used by subset.
			  trSelStr <- parse(text=paste(group$colNm[1]," != '", group$vals[[i]],"'",sep=""))
			  evSelStr <- parse(text=paste(group$colNm[1]," == '", group$vals[[i]],"'",sep=""))
			   # apply the subset. do.call is needed so selStr can be evaluated correctly
			  trSet <- do.call("subset",list(df.in2, trSelStr))
			  evSet[[i]] <- do.call("subset",list(df.in2, evSelStr))
			   # use sample to grab a random subset from the background points
			  BGsampSz <- nrow(evSet[[i]])
			  evSetBG <- df.abs2[sample(nrow(df.abs2), BGsampSz , replace = FALSE, prob = NULL),]
			   # get the other portion for the training set
			  TrBGsamps <- attr(evSetBG, "row.names") #get row.names as integers
			  trSetBG <-  df.abs2[-TrBGsamps,]  #get everything that isn't in TrBGsamps
			   # join em, clean up
			  trSet <- rbind(trSet, trSetBG)
			  evSet[[i]] <- rbind(evSet[[i]], evSetBG)
			  rm(trSetBG, evSetBG)
			   # run RF on subsets
			  trRes[[i]] <- randomForest(trSet[,indVarCols],y=trSet[,depVarCol],
			                             importance=TRUE,ntree=ntrees,mtry=mtry)
			   # run a randomForest predict on the validation data
			  evRes[[i]] <- predict(trRes[[i]], evSet[[i]], type="prob")
			   # use ROCR to structure the data
			  v.rocr.pred[[i]] <- prediction(evRes[[i]][,2],evSet[[i]]$pres)
			   # extract the auc for metadata reporting
			  v.rocr.auc[[i]] <- performance(v.rocr.pred[[i]], "auc")@y.values[[1]]
				##print(paste("finished run ", i, " of ", length(group$vals), sep=""))
				cat("finished run", i, "of", length(group$vals), "\n")
		}

		# restructure validation predictions so ROCR will average the figure
		v.rocr.pred.restruct <- v.rocr.pred[[1]]
		#send in the rest
		for(i in 2:length(v.rocr.pred)){
			v.rocr.pred.restruct@predictions[[i]] <- v.rocr.pred[[i]]@predictions[[1]]
			v.rocr.pred.restruct@labels[[i]] <- v.rocr.pred[[i]]@labels[[1]]
			v.rocr.pred.restruct@cutoffs[[i]] <- v.rocr.pred[[i]]@cutoffs[[1]]
			v.rocr.pred.restruct@fp[[i]] <- v.rocr.pred[[i]]@fp[[1]]
			v.rocr.pred.restruct@tp[[i]] <- v.rocr.pred[[i]]@tp[[1]]
			v.rocr.pred.restruct@tn[[i]] <- v.rocr.pred[[i]]@tn[[1]]
			v.rocr.pred.restruct@fn[[i]] <- v.rocr.pred[[i]]@fn[[1]]
			v.rocr.pred.restruct@n.pos[[i]] <- v.rocr.pred[[i]]@n.pos[[1]]
			v.rocr.pred.restruct@n.neg[[i]] <- v.rocr.pred[[i]]@n.neg[[1]]
			v.rocr.pred.restruct@n.pos.pred[[i]] <- v.rocr.pred[[i]]@n.pos.pred[[1]]
			v.rocr.pred.restruct@n.neg.pred[[i]] <- v.rocr.pred[[i]]@n.neg.pred[[1]]
		}

		# run a ROC performance with ROCR
		v.rocr.rocplot.restruct <- performance(v.rocr.pred.restruct, "tpr","fpr")
		# send it to perf for the averaging lines that follow
		perf <- v.rocr.rocplot.restruct

		## for infinite cutoff, assign maximal finite cutoff + mean difference
		## between adjacent cutoff pairs  (this code is from ROCR)
		if (length(perf@alpha.values)!=0) perf@alpha.values <-
			lapply(perf@alpha.values,
				function(x) { isfin <- is.finite(x);
					x[is.infinite(x)] <-
						(max(x[isfin]) +
							mean(abs(x[isfin][-1] -
							x[isfin][-length(x[isfin])])));
					x[is.nan(x)] <- 0.001; #added by tgh to handle vectors length 2
			x})

		for (i in 1:length(perf@x.values)) {
			ind.bool <- (is.finite(perf@x.values[[i]]) & is.finite(perf@y.values[[i]]))
			if (length(perf@alpha.values) > 0)
				perf@alpha.values[[i]] <- perf@alpha.values[[i]][ind.bool]
			perf@x.values[[i]] <- perf@x.values[[i]][ind.bool]
			perf@y.values[[i]] <- perf@y.values[[i]][ind.bool]
		}
		perf.sampled <- perf

		# create a list of cutoffs to interpolate off of
		alpha.values <- rev(seq(min(unlist(perf@alpha.values)),
								max(unlist(perf@alpha.values)),
								length=max(sapply(perf@alpha.values, length))))
		# interpolate by cutoff, values for y and x
		for (i in 1:length(perf.sampled@y.values)) {
			perf.sampled@x.values[[i]] <-
			  approxfun(perf@alpha.values[[i]],perf@x.values[[i]],
						rule=2, ties=mean)(alpha.values)
			perf.sampled@y.values[[i]] <-
			  approxfun(perf@alpha.values[[i]], perf@y.values[[i]],
						rule=2, ties=mean)(alpha.values)
		}

		## compute average curve
		perf.avg <- perf.sampled
		perf.avg@x.values <- list(rowMeans( data.frame( perf.avg@x.values)))
		perf.avg@y.values <- list(rowMeans( data.frame( perf.avg@y.values)))
		perf.avg@alpha.values <- list( alpha.values )

		# find the best cutoff based on the averaged ROC curve
		cutpt <- which.max(abs(perf.avg@x.values[[1]]-perf.avg@y.values[[1]]))
		cutval <- perf.avg@alpha.values[[1]][cutpt]
		cutX <- perf.avg@x.values[[1]][cutpt]
		cutY <- perf.avg@y.values[[1]][cutpt]
		cutval.rf <- c(1-cutval,cutval)

		for(i in 1:length(group$vals)){
			#apply the cutoff to the validation data
			v.rf.pred.cut <- predict(trRes[[i]], evSet[[i]],type="response", cutoff=cutval.rf)
			#make the confusion matrix
			v.y[[i]] <- table(observed = evSet[[i]][,"pres"],
				predicted = v.rf.pred.cut)
			#add estimated accuracy measures
			v.y[[i]] <- cbind(v.y[[i]],
				"accuracy" = c(v.y[[i]][1,1]/sum(v.y[[i]][1,]), v.y[[i]][2,2]/sum(v.y[[i]][2,])))
			#add row, col names
			rownames(v.y[[i]]) <- c("background/abs", "known pres")
			colnames(v.y[[i]]) <- c("pred. abs", "pred. pres", "accuracy")
			print(v.y[[i]])
			#Generate kappa statistics for the confusion matrices
			v.kappa[[i]] <- Kappa(v.y[[i]][1:2,1:2])
			#True Skill Statistic
			v.tss[[i]] <- v.y[[i]][2,3] + v.y[[i]][1,3] - 1
			#Overall Accuracy
			v.OvAc[[i]] <- (v.y[[i]][[1,1]]+v.y[[i]][[2,2]])/sum(v.y[[i]][,1:2])
			### importance measures ###
			#count the number of variables
			n.var <- nrow(trRes[[i]]$importance)
			#get the importance measures (don't get GINI coeff - see Strobl et al. 2006)
			imp <- importance(trRes[[i]], class = NULL, scale = TRUE, type = NULL)
			imp <- imp[,"MeanDecreaseAccuracy"]
			#get number of variables used in each forest
			used <- varUsed(trRes[[i]])
			names(used) <- names(imp)
			t.importance[[i]] <- data.frame("meanDecreaseAcc" = imp,
										"timesUsed" = used )
			#housecleaning to save memory
			trRes[[i]]$forest <- NULL
			trRes[[i]]$oob.times <- NULL
			trRes[[i]]$votes <- NULL
			trRes[[i]]$predicted <- NULL
		} #close loop

		#housecleaning
		rm(trSet, evSet)

		#average relevant validation/summary stats
		# Kappa - wieghted, then unweighted
		K.w <- unlist(v.kappa, recursive=TRUE)[grep("Weighted.value",
							names(unlist(v.kappa, recursive=TRUE)))]
		Kappa.w.summ <- data.frame("mean"=mean(K.w), "sd"=sd(K.w),"sem"= sd(K.w)/sqrt(length(K.w)))
		K.unw <- unlist(v.kappa, recursive=TRUE)[grep("Unweighted.value",
							names(unlist(v.kappa, recursive=TRUE)))]
		Kappa.unw.summ <- data.frame("mean"=mean(K.unw), "sd"=sd(K.unw),"sem"= sd(K.unw)/sqrt(length(K.unw)))
		#AUC - area under the curve
		auc <- unlist(v.rocr.auc)
		auc.summ <- data.frame("mean"=mean(auc), "sd"=sd(auc),"sem"= sd(auc)/sqrt(length(auc)))
		#TSS - True skill statistic
		tss <- unlist(v.tss) 
		tss.summ <- data.frame("mean"=mean(tss), "sd"=sd(tss),"sem"= sd(tss)/sqrt(length(tss)))
		#Overall Accuracy
		OvAc <- unlist(v.OvAc)
		OvAc.summ <- data.frame("mean"=mean(OvAc), "sd"=sd(OvAc),"sem"= sd(OvAc)/sqrt(length(OvAc)))
		#Specificity and Sensitivity
		v.y.flat <- abind(v.y,along=1)  #collapsed confusion matrices
		v.y.flat.sp <- v.y.flat[rownames(v.y.flat)=="background/abs",]
		specif <- v.y.flat.sp[,1]/(v.y.flat.sp[,1] + v.y.flat.sp[,2])   #specificity
		specif.summ <- data.frame("mean"=mean(specif), "sd"=sd(specif),"sem"= sd(specif)/sqrt(length(specif)))
		v.y.flat.sn <- v.y.flat[rownames(v.y.flat)=="known pres",]
		sensit <- v.y.flat.sn[,2]/(v.y.flat.sn[,1] + v.y.flat.sn[,2])    #sensitivity
		sensit.summ <- data.frame("mean"=mean(sensit), "sd"=sd(sensit),"sem"= sd(sensit)/sqrt(length(sensit)))

		summ.table <- data.frame(Name=c("Weighted Kappa", "Unweighted Kappa", "AUC",
										"TSS", "Overall Accuracy", "Specificity",
										"Sensitivity"),
								 Mean=c(Kappa.w.summ$mean, Kappa.unw.summ$mean,auc.summ$mean,
										tss.summ$mean, OvAc.summ$mean, specif.summ$mean,
										sensit.summ$mean),
								 SD=c(Kappa.w.summ$sd, Kappa.unw.summ$sd,auc.summ$sd,
										tss.summ$sd, OvAc.summ$sd, specif.summ$sd,
										sensit.summ$sd),
								 SEM=c(Kappa.w.summ$sem, Kappa.unw.summ$sem,auc.summ$sem,
										tss.summ$sem, OvAc.summ$sem, specif.summ$sem,
										sensit.summ$sem))
		summ.table
	} else {
	cat("Only one polygon, can't do validation", "\n")
	cutval <- NA
	}
	#reduce the number of trees if number of rows exceeds 20k
	if(nrow(df.full) > 20000) {
		ntrees <- 300
		} else {
		ntrees <- 600
	}
	####
	#   run the full model
	#####
	cat("running full model", "\n")
	rf.full <- randomForest(df.full[,indVarCols],
	                        y=df.full[,depVarCol],
	                        importance=TRUE,
	                        ntree=ntrees,
	                        mtry=mtry)

	####
	# get cutoff data
	####
	# open the channel
	#Cn.MDB.out <- odbcConnect("EDM_status_Cn")
	db<-dbConnect(SQLite(),dbname=db_file)
	    #extract the precision-recall F-measure from training data
	    #set alpha very low to tip in favor of 'presence' data over 'absence' data
	    # based on quick assessment in Spring 07, set alpha to 0.01
	alph <- 0.01
			#create the prediction object for ROCR
	rf.full.pred <- prediction(rf.full$votes[,2],df.full$pres)
			#use ROCR performance to get the f measure
	rf.full.f <- performance(rf.full.pred,"f",alpha = alph)
	    #extract the data out of the S4 object, then find the cutoff that maximize the F-value.
	rf.full.f.df <- data.frame(cutoff = unlist(rf.full.f@x.values),fmeasure = unlist(rf.full.f@y.values))
	rf.full.ctoff <- c(1-rf.full.f.df[which.max(rf.full.f.df$fmeasure),][[1]], rf.full.f.df[which.max(rf.full.f.df$fmeasure),][[1]])
	rf.full.ctoff

  ##get the mean cutoff values for the validation runs
		#	t.ctoff.mean <- cbind(mean(abind(t.ctoff, along=2)[1,]), mean(abind(t.ctoff,along=2)[2,]))
		#	t.ctoff.mean <- c(mean(abind(t.ctoff, along=2)[1,]), mean(abind(t.ctoff,along=2)[2,]))
		#	t.ctoff.mean

	# prep the data
	OutPut <- data.frame(SciName = as.character(ElementNames$SciName),
	             CommName=as.character(ElementNames$CommName),
	             ElemCode=as.character(ElementNames$Code),
	             numValidaRuns=length(group$vals),
	             meanValidaCutoff = cutval,
	             fullRunCutoff = rf.full.ctoff[2],
	             date = paste(Sys.Date()),
	             time = format(Sys.time(), "%X")
	             )
	#write the data to the database
	#sqlSave(Cn.MDB.out, OutPut, tablename = "tblCutoffs",
	#                            append = TRUE,
	#                            rownames = FALSE)
	dbWriteTable(db,"tblCutoffs",OutPut,append=TRUE)
  #close(Cn.MDB.out) #close connection
	#rm(Cn.MDB.out)

	####
	# Importance measures
	####
	#get the importance measures (don't get GINI coeff - see Strobl et al. 2006)
	f.imp <- importance(rf.full, class = NULL, scale = TRUE, type = NULL)
	f.imp <- f.imp[,"MeanDecreaseAccuracy"]
	#  open up a "channel" to the Access DB to full env var name
	#Cn.MDB.in.i <- odbcConnect("EDM_in_i")  #attribute data about the element and record processsing (i=info)
	db<-dbConnect(SQLite(),dbname=db_file)  
  # get importance data, set up a data frame
	EnvVars <- data.frame(code = names(f.imp), impVal = f.imp, fullName="", stringsAsFactors = FALSE)
	#set the query for the following lookup, note it builds many queries, equal to the number of vars
	SQLquery <- paste("SELECT code, fullName FROM tblEnvVarNames WHERE code in ('", paste(EnvVars$code,sep=", "),
	                    "'); ", sep="")
	#cycle through all select statements, put the results in the df
	for(i in 1:length(EnvVars$code)){
	  #EnvVars$fullName[i] <- as.character(sqlQuery(channel = Cn.MDB.in.i, query = SQLquery[i])[,2])
	  EnvVars$fullName[i] <- as.character(dbGetQuery(db, statement = SQLquery[i])[,2])
	  }
	##clean up
	#close(Cn.MDB.in.i)
	#rm(Cn.MDB.in.i)
	dbDisconnect(db)
  
	###
	# partial plot data
	###
	#get the order for the importance charts
	ord <- order(EnvVars$impVal, decreasing = TRUE)[1:n.var]
	#set up a list to hold the plot data
	pPlots <- vector("list",8)
			names(pPlots) <- c(1:8)
	#get the partial plots
	for(i in 1:8){
		pPlots[[i]] <- partialPlot(rf.full, df.full[,indVarCols],
							names(f.imp[ord[i]]),
							which.class = 1,
							plot = FALSE)
		pPlots[[i]]$code <- names(f.imp[ord[i]])
		pPlots[[i]]$fname <- EnvVars$fullName[ord[i]]
		}
	
	#save the project, return to the original working directory
	wdSave <- getwd()
	#setwd("C:/_BeautyArchive/_NYNHP/GIS_data/ElementData/RdataFiles/build_eval_Out")
  setwd("C:/Users/Public/2015Pros/RdataFiles")
	save.image(file = paste(ElementNames$SciName, ".Rdata", sep=""))
	#Sweave("MetadataEval_17Sept09.rnw",
	#        syntax="SweaveSyntaxNoweb",
	#				output=paste(ElementNames$SciName, ".tex",sep=""))
	setwd(wdSave)
	#remind me what I just ran
	##print(paste("done with ", ElementNames[[1]], sep=""))
	cat("done with", ElementNames[[1]], "\n")
	#clear all but the items needed for next run
	rm(list=ls()[!ls() %in% 
		c("att_pres_points","att_background","drop_list")])
	#end the loop
}
}