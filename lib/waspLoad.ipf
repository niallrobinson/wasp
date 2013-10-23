///////////////////////////////////////////////////////////////////////////////////////////////////
// Wibs Analysis Program v 1.0 alpha                                           
// code for loading data from the raw files												      
// Copyright (C) 2011									            
// Niall Robinson, University of Manchester, 2011				     
// niall.robinson@manchester.ac.uk							     
//														     
// This program is free software; you can redistribute it and/or        
// modify it under the terms of the GNU General Public License     
// as published by the Free Software Foundation; either version 2  
// of the License, or (at your option) any later version.                   
//														    
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied 
// warranty of MERCHANTABILITY or 
// FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

#pragma rtGlobals=1		// Use modern global access method.
#pragma version=1.0
#include <kbcolorizetraces>

constant satVal = 2092 // value of saturation
constant maxBLAvgPeriod = 28800 // threshold value over which the BL average gives a warning
constant minBLpoints = 30 // mimum no of points in baseLineAvgPeriod for it to be considered "good"
constant minSPinAvg = 5 // minimum no of SPs detected in a period that is averaged to make one point
constant BLstdevsAboveMean = 3 // number of stdevs above the mean to set the BL

Function loadFTdata()
	// prompt user for path of data files
	newPath /O myPath
	If(V_Flag == -1) //End if cancelled
		setdatafolder root:
		Abort "Load data cancelled"
	EndIf
	
	titlebox loadStatus title="Loading baseline data"; controlUpdate loadStatus

	// load in a file to see what type of data it is
	SVAR fileEnding = root:Panel:fileEnding
	wave dataMatrix = loadFile(0, fileEnding)
	variable wibsVersion = getWibsVersion(dataMatrix)
	// firstly need to load in all the baseline data (so if there are files with no BL we can interpolate)
	killdatafolder /z root:Baseline
	newdatafolder /o/s root:Baseline
	
	if(wibsVersion != 4)
		wave /wave BLnflThresh = loadBaseLineData()
		updateBLnflThreshdata(BLnflThresh)
		wave BLs = BLnflThresh[0]
		wavestats /z/q BLs
		if(V_nPnts < 2)
			setdatafolder root:
			DoAlert 0, "No forced trigger data. Please load files with suitable data and check that the specified file ending is correct."
		else
			plotBLs()
		endif
	elseif(wibsVersion == 4)
		NVAR gainMode = root:Panel:gainMode
		wave /wave BLnflThreshdata = loadBaseLineData(gainMode = gainMode)
		updateBLnflThreshdata(BLnflThreshdata)
		wave BLs = BLnFlThreshdata[0]
		wavestats /z/q BLs
		if(V_nPnts < 2 && gainMode == 0)
			setdatafolder root:
			DoAlert 0, "No low gain mode forced trigger data. Please load files with suitable data and check the the specified file ending is correct."
		elseif(V_nPnts < 2 && gainMode == 1)
			setdatafolder root:
			DoAlert 0, "No high gain forced trigger data. Please load files with suitable data and check the the specified file ending is correct."
		else
			plotBLs()
		endif
	endif
	
	killwaves /z root:thisDataMatrix0, mode, modeNoNaNs FTmode, returnWave, FTmodeData, returnBLs, noFile, times
	killdatafolder /z root:tempSPD
	setdatafolder root:
	titlebox loadStatus title=""; controlUpdate loadStatus
End

Function plotBLs([title])
	string title
	
	display
	variable i
	string traceName
	Legend
	for(i = 1; i < dimsize(BLs,1); i += 1) // starts at one because zero contains time
		traceName = GetDimLabel(BLs, 1, i) + " BL"
		appendtograph BLs[][i] /TN=$traceName vs BLTimes
		modifygraph mode($traceName)=3,marker($traceName)=19
		traceName = GetDimLabel(flThresh, 1, i) + " Fl thresh"
		appendtograph flThresh[][i] /TN=$traceName vs BLtimes
		modifygraph mode($traceName)=3,marker($traceName)=1
	endfor
	SetAxis left *,*
	Label left "Flourescence"
	Label bottom "Time"
	KBColorizeTraces(0.4, 0.8, 0)
	if(!paramisdefault(title))
		TextBox/N=title/C/A=MT/E title
	endif
End

Function updateBLnFlThreshdata(highGainBLnFlThresh)
	wave /wave highGainBLnFlThresh
	
	wave /z BLs = highGainBLnFlThresh[0]
	wave /z flThresh = highGainBLnFlThresh[1]
	if(!waveexists(BLs) || !waveexists(flThresh))
		return 0
	endif
	
	make /d/o/n=(dimsize(BLs,0)) BLTimes = BLs[p][0]	
	SetScale /I d, 0, 1 , "dat", BLTimes
	
	make /o/n=(numpnts(BLTimes)) index = p
	sort BLTimes, BLTimes, index
	duplicate /free/o BLs, BLs_unordered
	duplicate /free/o flThresh, flThresh_unordered

	BLs = BLs_unordered[index[p]][q]
	flThresh = flThresh_unordered[index[p]][q]

	killwaves index
End

Function /wave initialiseDistribution(startT, endT, tRes, noYbins, name) // initialise a scaled wave.
	variable startT, endT, tRes, noYbins
	string name
	
	variable noTpnts = ceil((endT-startT)/(tRes*60))
	make /o/n=(noTpnts, noYbins) $name
	wave distri = $name
	SetScale /P x, startT, tRes*60, "dat", distri
	distri = 0
	
	return distri
End

Function processFlThresh(BLs, flThresh)
	wave BLs, flThresh

	// process fluorescence threshold
	controlInfo T0_interpFlThresh
	if(V_value)
		variable numNaNsStart = 1 // starts with one so the default is not to abort
	//	if(dimsize(flThresh,0) > 0)
			wavestats /z/q flThresh
			numNaNsStart = V_numNaNs
	//	endif
		wave temp = interpMatrixOverNaNs(flThresh,0)
	//	if(dimsize(flThresh,0) > 0)
			wavestats /z/q flThresh
	//	endif
		if(numNaNsStart == V_numNaNs)
	//		setdatafolder root:
	//		Abort "Interpolation failed. Please try averaging baseline."
		endif
		duplicate /o temp, flThresh; killwaves temp
		wave temp = interpMatrixOverNaNs(BLs,0)
		duplicate /o temp, BLs; killwaves temp
	endif
	controlInfo T0_avgFlThresh
	if(V_value)
		duplicate /o/r=(*)(1) FlThresh, temp
		wavestats /q temp
		FlThresh[][1] = V_avg
		duplicate /o/r=(*)(1) BLs, temp
		wavestats /q temp
		BLs[][1] = V_avg

		duplicate /o/r=(*)(2) FlThresh, temp
		wavestats /q temp
		FlThresh[][2] = V_avg
		duplicate /o/r=(*)(2) BLs, temp
		wavestats /q temp
		BLs[][2] = V_avg

		duplicate /o/r=(*)(3) FlThresh, temp
		wavestats /q temp
		FlThresh[][3] = V_avg
		duplicate /o/r=(*)(3) BLs, temp
		wavestats /q temp
		BLs[][3] = V_avg
	endif
End

Function setMinMaxT() // preloads all the files to see which order they go in
	// prompt user for path of data files
	
	NVAR minT = root:Panel:minT
	NVAR maxT = root:Panel:maxT
	
	minT = inf
	maxT = 0
	
	// loop round file loads
	NVAR loadProg = root:Panel:loadProg
	SVAR fileEnding = root:Panel:fileEnding
	// find out how many files in the folder
	string fileList = indexedFile(myPath, -1, "."+fileEnding)
	variable noOfFiles = itemsInList(fileList)
	if(noOfFiles == 0)
		Abort "No data. Please load files with suitable data and check the the specified file ending is correct."
	endif
	
	variable i
	do
		if(i < noOfFiles)
			wave thisDataMatrix = loadFile(i,fileEnding)
			if(thisDataMatrix[0][0] == -9999) // no data in file)
				break
			endif
		else
			break
		endif
		if(thisDataMatrix[0][0] == -8888) // no more files
			break // break loop round files
		endif
		
		duplicate /o/r=(*)(0) thisDataMatrix, thisDataTime
		redimension /n=(-1,0) thisDataTime
		wavestats /q thisDataTime
		
		if(V_min < minT)
			minT = V_min
		endif
		if(V_max > maxT)
			maxT = V_max
		endif
		
		i += 1
		loadProg = i*100/noOfFiles
		controlUpdate TPB_loadProg
	while(1)
End

Function /wave getThisBL(minT, maxT, BLs, name)
	variable minT, maxT
	wave BLs
	string name
	
	make /n=(dimsize(BLs,1)-1)/o $name /wave=thisBL // -1 to take account of the time column, which we don't want to include
	duplicate /free/r=(*)(0) BLs, BLtimes
	
	variable a, b
	a = binarySearch(BLtimes, minT)	
	b = binarySearch(BLtimes, maxT)
	
	if(a == -1)
		a = 0
	endif
	if(b == -1)
		b = 0
	endif
	if(a == -2)
		a = numpnts(BLtimes)
	endif
	if(b == -2)
		b = numpnts(BLtimes)
	endif
	
	variable i
	for(i = 0; i < numpnts(thisBL); i += 1)
		duplicate /free/r=(*)(i+1) BLs, BLSlice
		if(a == b) // only one point
			thisBL[i] = BLslice[a]
		else
			wavestats /q/r=[a,b] BLslice
			thisBL[i] = V_avg
		endif
	endfor
	
	return thisBL
End

Function loadWIBSdata(timeRes, flowRate, minSizeThresh, sizeBins, flBins, AFBins, loadSDflag, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFflag, protoOrCluster, [prototypes, prototypeNames, clusters]) // main function for all the loading
	variable timeRes, flowRate, minSizeThresh
	wave sizeBins, flBins, AFBins
	variable loadSDflag, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFflag
	variable protoOrCluster // == 1 for load according to prototype and 2 for cluster
	wave prototypes
	wave /t prototypeNames
	wave /wave clusters
	
	if(protoOrCluster == 1 && (paramisdefault(prototypes) || paramisdefault(prototypeNames))) // check we have the right parameters for each mode
		setdatafolder root:
		Abort "wrong input parameters for loadWIBSdata()"
	elseif(protoOrCluster == 2 && paramisdefault(clusters))
		setdatafolder root:
		Abort "wrong input parameters for loadWIBSdata()"
	endif
		
	ControlInfo T0_fitToTimeGrid; variable fitToTimeGrid = V_value
	ControlInfo T0_filterSat; variable filterSatFlag = V_value
	ControlInfo T0_recalcSizes; variable recalcSizesFlag = V_value
	
	newPath /O myPath
	If(V_Flag == -1) //End if cancelled
		setdatafolder root:
		Abort "Load data cancelled"
	EndIf
	
	variable overwriteBlacklist = 0
	if(waveexists(root:Panel:blacklist) && protoOrCluster == 1) // only give the option if doing a proper load not a cluster attribution type load
		DoAlert 1, "overwrite blacklist?"
		if(V_Flag == 1)
			overwriteBlacklist = 1
		endif
	endif
	
	titlebox loadStatus title="Indexing"
	
	if(datafolderexists("root:tempSPD"))
		killdatafolder root:tempSPD
	endif
	newdatafolder /o/s root:tempSPD
	
	setMinMaxT()
	
	// establish start time
	NVAR minT = root:panel:minT
	NVAR maxT = root:panel:maxT
	variable /G root:Panel:startTime
	NVAR startTime = root:Panel:startTime
	startTime = findStartTime(minT, fitToTimeGrid, timeRes)
	NVAR wibsVersion = root:Panel:wibsVersion
	variable noOfRecordingModes // this is one in WIBS 3 but 2 for WIBS 4 - high gain and low gain
	
	wave BLs = root:baseLine:Bls
	wave flThresh = root:baseLine:flThresh
	if(dimsize(BLs,0) > 1)
		processFlThresh(BLs, flThresh)
	endif
	
	if(!datafolderexists("root:Data"))
		newdatafolder /o root:Data
	endif
	
	if(wibsVersion == 4) // loop round WIBS 4 mode, set number of modes to two
		NVAR gainMode = root:Panel:gainMode
		make /o/n=0 root:Data:modeSeries /wave = modeSeries
		make /o/n=0/d root:Data:modeSeries_t /wave = modeSeries_t
		noOfRecordingModes = 2
	elseif(wibsVersion != 4)
		noOfRecordingModes = 1
	endif
//	// initialise data waves to fill up
//	if(wibsVersion == 4) // loop round WIBS 4 mode, set number of modes to two
//		noOfRecordingModes = 2
//		newdatafolder /o root:Data:lowGain
//		newdatafolder /o root:Data:highGain
//		make /o/n=0 root:Data:modeSeries /wave = modeSeries
//		make /o/n=0/d root:Data:modeSeries_t /wave = modeSeries_t
//	elseif(wibsVersion != 4)
//		noOfRecordingModes = 1
//	endif
	// make blacklist
	if(overwriteBlacklist && protoOrCluster == 1) // only give the option if doing a proper load not a cluster attribution type load
		initialiseDistribution(startTime, maxT, timeRes, 0, "root:Panel:blackList")
	elseif(protoOrCluster == 1)
		initialiseDistribution(startTime, maxT, timeRes, 0, "root:Panel:blackList")
	endif
	//make "All" todo
	initialiseDistribution(startTime, maxT, timeRes, numpnts(sizeBins)-1, "root:ToDoWaves:All")
	wave All = root:ToDoWaves:All; All = 1
	
	if(datafolderexists("root:tempSPD"))
		setdatafolder root:tempSPD
	else
		newdatafolder /s root:tempSPD
	endif
	
	titlebox loadStatus title="Loading data"
	
	// if WIBS4 loop round gain modes
	variable i,j,k,l
		string avgWaveRef = ""
		string missedParticlesRef = ""
		string avgdRawDataRef = ""
				
		if(protoOrCluster == 1) // initialise for load in via prototypes
			missedParticlesRef = "root:data:missedParticles"			// again, this is forces to be in :data:
			// make QA wave
			initialiseDistribution(startTime, maxT, timeRes, 0, missedParticlesRef)
			wave missedParticles = $missedParticlesRef
			// loop round prototypes
			for(j = 0; j < dimsize(protoTypes, 1); j += 1)
				avgWaveRef = "root:data:"+prototypeNames[j] // time series doesn't need to be initialised as its calced later from the size distris
				// make size distribution waves
				if(loadSDflag)
					initialiseDistribution(startTime, maxT, timeRes, numpnts(sizeBins)-1, avgWaveRef+"_SD")
				endif
				if(loadFl1Flag)
					initialiseDistribution(startTime, maxT, timeRes, numpnts(flBins)-1, avgWaveRef+"_Fl1D")
				endif
				if(loadFl2Flag)
					initialiseDistribution(startTime, maxT, timeRes, numpnts(flBins)-1, avgWaveRef+"_Fl2D")
				endif
				if(loadFl3Flag)
					initialiseDistribution(startTime, maxT, timeRes, numpnts(flBins)-1, avgWaveRef+"_Fl3D")
				endif
				if(loadAFflag)
					initialiseDistribution(startTime, maxT, timeRes, numpnts(afBins)-1, avgWaveRef+"_AFD")
				endif
			endfor
		elseif(protoOrCluster == 2) // initialise for load via clusters
			// loop round clusters
			avgWaveRef = "root:data:unclassified" // doesn't need to be initialised because it is calced later from the size distri
			
			missedParticlesRef = "root:data:missedParticles" //forced to place this in the data folder even though there maybe should be separate for different modes
			// make QA wave
			initialiseDistribution(startTime, maxT, timeRes, 0, missedParticlesRef)
			wave missedParticles = $missedParticlesRef
			if(loadSDflag)
				initialiseDistribution(startTime, maxT, timeRes, numpnts(sizeBins)-1, avgWaveRef+"_SD")
			endif
			if(loadFl1Flag)
				initialiseDistribution(startTime, maxT, timeRes, numpnts(flBins)-1, avgWaveRef+"_Fl1D")
			endif
			if(loadFl2Flag)
				initialiseDistribution(startTime, maxT, timeRes, numpnts(flBins)-1, avgWaveRef+"_Fl2D")
			endif
			if(loadFl3Flag)
				initialiseDistribution(startTime, maxT, timeRes, numpnts(flBins)-1, avgWaveRef+"_Fl3D")
			endif
			if(loadAFflag)
				initialiseDistribution(startTime, maxT, timeRes, numpnts(afBins)-1, avgWaveRef+"_AFD")
			endif
			
			for(j = 0; j < numpnts(clusters); j += 1)
				avgWaveRef = "root:data:"+nameofwave(clusters[j])
				// make size distribution waves
				if(loadSDflag)
					initialiseDistribution(startTime, maxT, timeRes, numpnts(sizeBins)-1, avgWaveRef+"_SD")
				endif
				if(loadFl1Flag)
					initialiseDistribution(startTime, maxT, timeRes, numpnts(flBins)-1, avgWaveRef+"_Fl1D")
				endif
				if(loadFl2Flag)
					initialiseDistribution(startTime, maxT, timeRes, numpnts(flBins)-1, avgWaveRef+"_Fl2D")
				endif
				if(loadFl3Flag)
					initialiseDistribution(startTime, maxT, timeRes, numpnts(flBins)-1, avgWaveRef+"_Fl3D")
				endif
				if(loadAFflag)
					initialiseDistribution(startTime, maxT, timeRes, numpnts(afBins)-1, avgWaveRef+"_AFD")
				endif
			endfor // end loop round clusters
		endif // end if via prototypes or clusters
	
	// now to load in actual data ////////////////////////
	// loop round file loads
	NVAR loadProg = root:Panel:loadProg
	SVAR fileEnding = root:Panel:fileEnding
	// find out how many files in the folder
	string fileList = indexedFile(myPath, -1, "."+fileEnding)
	variable noOfFiles = itemsInList(fileList)
	
	i = 0
	do // loop round files - indexed with i
		if(i < noOfFiles)
			wave thisDataMatrix = loadFile(i,fileEnding) // load in order so it finds the right BLs/flThreshs
			if(thisDataMatrix[0][0] == -9999) // no data in file)
				break
			endif
		else
			break
		endif
		if(thisDataMatrix[0][0] == -8888) // no more files
			break // break loop round files
		endif
		
		duplicate /o/r=(*)(0) thisDataMatrix, thisDataTime
		redimension /n=(-1,0) thisDataTime
		
		if(recalcSizesFlag)	
			variable sizeColNo = findDimLabel(thisDataMatrix, 1, "Size")
			variable FL2_ScatColNo = findDimLabel(thisDataMatrix, 1, "FL2_Scat")
			thisDataMatrix[][sizeColNo] = calcSizeFromScatter(thisDataMatrix[p][FL2_ScatColNo], thisDataMatrix[p][SizeColNo])
		endif
			
		variable modeCol = FindDimLabel(thisDataMatrix, 1, "FT")
		variable xpnt
		make /o/n=(dimsize(thisDataMatrix,0)) extractTrue, thisMode = thisDataMatrix[p][modeCol] //wave is 1 if FT mode
		// get QA flags for file -  missed particle (i.e. lamp hadn't recharged 1 or signal was saturated 2 ), 3 means noise (ie. < 0.8 um)
		wave QAflags = QA(thisDataMatrix, minSizeThresh)
		// count missed particles
		updateMissedParticles(missedParticles, thisDataMatrix, QAFlags)
		
		// if WIBS4 then calculate what current mode is
		if(noOfRecordingModes > 1)
			if(i == 0)
				insertPoints 0, 1, modeSeries, modeSeries_t
				modeSeries[0] = (thisDataMatrix[0][modeCol]&2^1) != 0
				modeSeries_t[0] = thisDataMatrix[0][0]
			endif
			updateModeSeries(modeSeries, modeSeries_t, thisDataMatrix) // updates a time series of when the recording modes change
		endif

			wave BLs = root:baseline:BLs
			wave flThresh = root:baseline:flThresh
				
			wavestats /q thisDataTime
			wave thisBL = getThisBL(V_min, V_max, BLs, "thisBL")
			wave thisFLThresh = getThisBL(V_min, V_max, FLThresh, "thisFLThresh") // this function is names misleadingly - its works for either.
			
			if(protoOrCluster == 1)
				// loop round prototype
				for(k = 0; k < dimsize(protoTypes, 1); k += 1)
					wave thisProtoSPD = SPDinMode(thisDataMatrix, QAflags, thisMode, thisFLthresh, thisBL, gainMode, k, filterSatFlag, prototypes, prototypeNames) 
					// returns sp data for this time bin, mode, and prototype that has passes the QA, also applied the baseline.
					
					avgWaveRef = "root:data:"+prototypeNames[k]
									
					// build up raw concentration distributions
					updateRawDistributions(avgWaveRef, thisProtoSPD, 1, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFFlag)
										
				endfor // end loop round prototypes
			elseif(protoOrCluster == 2)
				make /free/o/n=(numpnts(QAflags)) useTrue
				useTrue = QAflags == 0 || QAflags == 2
				// remove bad AF data if using AF
				wave aCluster = clusters[0]
				variable AFColNum = findDimLabel(aCluster, 0, "AF") // check if we are using AF
				if(AFColNum != -2) // i.e. if found
					AFColNum = findDimLabel(thisDataMatrix, 1, "AF") // find it in the data
					useTrue = thisDataMatrix[p][AFColNum] != -1 && useTrue // this should be taken care of by recalculation of AF anyway
				endif
				
				wave temp = extractFromMatrix(0, 1, thisDataMatrix, useTrue)
				duplicate /o thisDataMatrix, QAdDataMatrix
				redimension /n=(sum(useTrue), -1) QAdDataMatrix
				QAdDataMatrix = temp
				
				if(dimsize(QAdDataMatrix,0) == 0) // if no data made ti through QA
					i += 1
					continue // skip the remainder of t he loop
				endif
				
				// loop round clusters
				ControlInfo T1_raw
				if(!V_value)
					wave thisSPDforComparison = clusterComparableData(QAdDataMatrix, clusters[0], thisBL) // also applies baseline
				else
					wave thisSPDforComparison = clusterComparableData(QAdDataMatrix, clusters[0], {0,0,0}) // also applies baseline	
				endif
				
				wave thisSPDClusterIndex = SPDClusterIndex(thisSPDforComparison, clusters, thisMode, gainMode, filterSatFlag) // returns sp data for this time bin, mode, and prototype that has passes the QA
				
				//firstly asess unclassified particles
				avgWaveRef = "root:data:unclassified"
				make /o/n=(dimsize(thisSPDClusterIndex,0)) extractTrue = 0
				for(k = 0; k < dimsize(thisSPDClusterIndex,0); k += 1)
					duplicate /o/free/r=(k)(*) thisSPDClusterIndex, slice
					wavestats /q/m=1 slice
					if(V_numNaNs == numpnts(slice)) // all nans == no attribution 
						extractTrue[k] = 1
					endif
				endfor
				make /d/o/n=(sum(extractTrue),dimsize(thisDataMatrix,1)) thisClusterData
				FastExtractFromMatrix(0, 1, QAdDataMatrix, extractTrue, thisClusterData) // fills thisClusterData with the data in that cluster while preserving the dimlabels
				// build up raw concentration distribution
				updateRawDistributions(avgWaveRef, thisClusterData, 1, loadFl1Flag, loadFl2Flag, loadFL3Flag, loadAFFlag)												
								
				for(k = 0; k < numpnts(clusters); k += 1)
					avgWaveRef = "root:data:"+nameofwave(clusters[k])
					duplicate /o/r=(*)(k) thisSPDClusterIndex, weighting
					extractTrue = numtype(weighting) != 2
					make /d/o/n=(sum(extractTrue),dimsize(QAdDataMatrix,1)) thisClusterData
					FastExtractFromMatrix(0, 1, QAdDataMatrix, extractTrue, thisClusterData) // fills thisClusterData with the data in that cluster while preserving the dimlabels
					extract /o weighting, weighting, numtype(weighting) != 2 // get rid of the NaNs
				
					// build up raw concentration distributions
					updateRawDistributions(avgWaveRef, thisClusterData, 1, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFFlag, weighting = weighting)												
				endfor // end loop round prototypes
			endif

	
		i += 1
		loadProg = i/noOfFiles*100
		controlUpdate TPB_loadProg
	while(1) //end of loop round file loads
	
	if(noOfRecordingModes > 1)
		insertpoints inf, 1, modeSeries, modeSeries_t // add on the final point of the final data matrix to end the mode change series
		modeSeries[inf] = (thisDataMatrix[inf][modeCol]&2^1) != 0
		modeSeries_t[inf] = thisDataMatrix[inf][0]
	endif
	
	// apply quantitative corrections
		// calc frac missed
		wave missedParticles = root:data:missedParticles
		setdatafolder root:Data:
		wave this = All_SD
		matrixop /o totalCounts = sumRows(this)
		initialiseDistribution(startTime, maxT, timeRes, 0, "missedCF")
		wave missedCF
		missedCF = (totalCounts + missedParticles)/totalCounts
			
		if(protoOrCluster == 1)
			// loop round prototypes
			for(k = 0; k < dimsize(protoTypes, 1); k += 1)
				avgWaveRef = "root:data:"+prototypeNames[k]
				// if WIBS4 then calculate what current mode is
				if(noOfRecordingModes > 1)
					applyQuantitativeCorr(avgWaveRef, missedCF, flowRate, timeRes, startTime, 1, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFFlag, modeSeries=modeSeries, modeSeries_t=modeSeries_t, recordingMode=gainMode)
				else
					applyQuantitativeCorr(avgWaveRef, missedCF, flowRate, timeRes, startTime, 1, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFFlag)
				endif
			endfor
		else
			avgWaveRef = "root:data:unclassified"
			applyQuantitativeCorr(avgWaveRef, missedCF, flowRate, timeRes, startTime, 1, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFFlag, recordingMode = 2) // the only reason that recordingMode is included is because there was a dodgy igor bug where its convinced its 0 when its not passed :S
			// loop round clusters
			for(k = 0; k < numpnts(clusters); k += 1)
				avgWaveRef = "root:data:"+nameofwave(clusters[k])
				// if WIBS4 then calculate what current mode is
				if(noOfRecordingModes > 1)
					applyQuantitativeCorr(avgWaveRef, missedCF, flowRate, timeRes, startTime, 1, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFFlag, modeSeries=modeSeries, modeSeries_t=modeSeries_t, recordingMode=gainMode)
				else
					applyQuantitativeCorr(avgWaveRef, missedCF, flowRate, timeRes, startTime, 1, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFFlag)
				endif
			endfor
		endif

	killwaves missedParticles, totalCounts, temp
	killdatafolder root:tempSPD
	
	refreshtodolist()
End

Function convertSpace(SPD, clusters, desttype) // converts to log space and also converts from RSD to absolute SD
	wave SPD
	wave /wave clusters
	string desttype
	
	wave /t varNames = $(getCAfolder()+":varNames")
	
	variable i, j
	for(i = 0; i < dimsize(SPD, 1); i += 1)
		if(strsearch(logNormalVars, GetDimLabel(SPD, 1, i), 0) != -1) // if this is in the lognormvar list
			if(cmpstr(desttype,"log") == 0) // if we are converting to log
				SPD[][i] = SPD[p][i] == 0 ? 0 : log(SPD[p][i]) // this deals with zeros causing -infs
			elseif(cmpstr(desttype, "lin") == 0) // if we are converting from log to linear
				SPD[][i] = 10^SPD[p][q] 
			endif
		endif
	endfor
	
	for(i = 0; i < numpnts(clusters); i += 1)
	wave thisCl = clusters[i]
		for(j = 0; j < dimsize(thisCl,0); j += 1)
			if(strSearch(logNormalVars, varNames[j], 0) != -1) // if on the lognorm distri list
				if(cmpstr(desttype,"log") == 0) // if we are converting to log
					thisCl[j][] = thisCl[j][q] == 0 ? 0 : log(thisCl[j][q]) // again, to deal with -infs
				elseif(cmpstr(desttype, "lin") == 0) // if we are converting from log to linear
					thisCl[j][] = 10^(thisCl[j][q]) 
				endif
			else // if not on the log norm distri list
				if(cmpstr(desttype,"log") == 0) // if we are converting to log
					thisCl[j][1] = thisCl[j][1]*thisCl[j][0]
				elseif(cmpstr(desttype, "lin") == 0) // if we are converting from log to linear
					thisCl[j][1] = thisCl[j][1]/thisCl[j][0]
				endif
			endif
		endfor
	endfor
End

Function	updateModeSeries(modeSeries, modeSeries_t, thisDataMatrix)
	wave modeSeries, modeSeries_t, thisDataMatrix
	
	variable modeCol = FindDimLabel(thisDataMatrix, 1, "FT") 
	variable timeCol = 0
	variable i, a, b, a_t, b_t
	for(i = 0; i < dimsize(ThisdataMatrix, 0)-1; i +=1)
		a = (thisDataMatrix[i][modeCol] & 2^1) != 0 // get second bit - 0 if high gain mode and 1 if low gain mode
		a_t = thisDataMatrix[i][timeCol]
		b = (thisDataMatrix[i+1][modeCol] & 2^1) != 0
		b_t = thisDataMatrix[i+1][timeCol]
		
		if(a != b || i == 0 || i+1 == dimsize(thisDataMatrix, 0)) // if mode change
			insertPoints inf, 2, modeSeries, modeSeries_t
			modeSeries[numpnts(modeSeries)-2] = nan
			modeSeries[numpnts(modeSeries)-1] = b
			modeSeries_t[numpnts(modeSeries_t)-2] = a_t
			modeSeries_t[numpnts(modeSeries_t)-1] = b_t
		endif
	endfor
End

Function applyQuantitativeCorr(avgWaveRef, missedCF, flowRate, timeRes, startTime, loadSDflag, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFFlag[, modeSeries, modeSeries_t, recordingMode])
	string avgWaveRef
	wave missedCF
	variable flowRate, timeRes, startTime, loadSDflag, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFFlag
	wave modeSeries, modeSeries_t
	variable recordingMode
	
//	if(!paramisdefault(recordingMode) && recordingMode == 0)
//		make /o/n=(numpnts(missedCF)) root:Data:LowGain:modeCoverCF /wave = modeCoverCF=1
//	elseif(!paramisdefault(recordingMode) && recordingMode == 1)
	make /o/n=(numpnts(missedCF)) root:Data:modeCoverCF /wave = modeCoverCF=1
//	endif
	make /free/o/n=(numpnts(missedCF))/d wibsTimeBE = startTime + p*timeRes*60 - timeRes*60*0.5
			
	if(!paramisdefault(modeSeries))
		sort modeSeries_t, modeSeries_t, modeSeries
	
		variable mode0t, mode1t, totT, i, j

		for(i = 0; i < numpnts(wibsTimeBE); i += 1)
			mode0t = 0
			mode1t = 0
			totT = 0
			variable a = binarySearchInterp(modeSeries_t, wibsTimeBE[i])	
			variable b = binarySearchInterp(modeSeries_t, wibsTimeBE[i+1])
			
			for(j = floor(a); j < ceil(b); j += 1)
				if(modeSeries[j] == 0)
					mode0t += min(modeSeries_t[j+1],wibsTimeBE[i+1]) - max(modeSeries_t[j], wibsTimeBE[i])
				elseif(modeSeries[j] == 1)
					mode1t += min(modeSeries_t[j+1],wibsTimeBE[i+1]) - max(modeSeries_t[j], wibsTimeBE[i])
				endif
			endfor

			totT = mode0t + mode1t			
			//totT = wibsTimeBE[i+1] - wibsTimeBE[i]
			if(recordingMode == 0)
				if(mode0t == 0)
					modeCoverCF[i] = nan
				else
					modeCoverCF[i] = totT/mode0t
				endif
			elseif(recordingMode == 1)
					if(mode1t == 0)
					modeCoverCF[i] = nan
				else
					modeCoverCF[i] = totT/mode1t
				endif
			endif
		endfor
	else // if wibs three with single mode then just make a mode cover corr fac = 1
		make /o/n=(numpnts(missedCF)) root:Data:modeCoverCF /wave = modeCoverCF=1
	endif
	
//	modeCoverCF = 1
		
	if(loadSDflag)
		wave dLogDp = root:panel:dLogDp
		wave thisDist = $(avgWaveRef+"_SD")
		matrixop /o $avgWaveRef = sumrows(thisDist)
		wave timeSeries = $avgWaveRef
		duplicate /o timeSeries, testT2
		timeSeries /= (1/missedCF[p]) * (1/modeCoverCF[p]) * flowRate * timeRes
		SetScale /P x, startTime+(timeRes*0.5), timeRes*60, "dat", timeSeries
		thisDist /= (1/missedCF[p]) * (1/modeCoverCF[p]) * flowRate * timeRes * dLogDp[q] // account for missed particles  in concentration calc and flow rate. modeCoverCF == 1 if only one mode
	endif		

	if(loadFl1Flag)
		wave dFl = root:panel:dFl
		wave thisDist = $(avgWaveRef+"_Fl1D")
		thisDist /= (1/missedCF[p]) * (1/modeCoverCF[p]) * flowRate * timeRes * dFl[q] // account for missed particles  in concentration calc and flow rate
	endif
	
	if(loadFl2Flag)
		wave dFl = root:panel:dFl
		wave thisDist = $(avgWaveRef+"_Fl2D")
		thisDist /= (1/missedCF[p]) * (1/modeCoverCF[p]) * flowRate * timeRes * dFl[q] // account for missed particles  in concentration calc and flow rate
	endif
	
	if(loadFl3Flag)
		wave dFl = root:panel:dFl
		wave thisDist = $(avgWaveRef+"_Fl3D")
		thisDist /= (1/missedCF[p]) * (1/modeCoverCF[p]) * flowRate * timeRes * dFl[q] // account for missed particles  in concentration calc and flow rate
	endif
	
	if(loadAFFlag)
		wave dLogAF = root:panel:dLogAF
		wave thisDist = $(avgWaveRef+"_AFD")
		thisDist /= (1/missedCF[p]) * (1/modeCoverCF[p]) * flowRate * timeRes * dLogAF[q] // account for missed particles  in concentration calc and flow rate
	endif
	
	titlebox loadStatus title=""
End

Function updateMissedParticles(missedParticles, thisSPD, QAFlags)
	wave missedParticles, thisSPD, QAFlags
	
	variable i, xpnt
	for(i = 0; i < dimsize(thisSPD, 0); i += 1)
		xpnt = x2pnt(missedParticles, thisSPD[i][0]) // find point in missedParticles where this SPs time is
		missedParticles[xpnt] = (QAFlags[i] == 1) ? missedParticles[xpnt]+1 : missedParticles[xpnt]
	endfor
End

Function /wave ClusterComparableData(dataMatrix, cluster, BLs)//, minSize) // takes a raw data matrix and returns only data that is comparable to the cluser (and applies fl baseline)
	wave dataMatrix, cluster, BLs
//	variable minSize
	
//	wave QAflags = QA(dataMatrix, minSize)
//	make /free/o/n=(numpnts(QAflags)) useTrue
//	useTrue = QAflags == 0 || QAflags == 2
//	make /o/n=(sum(extractTrue), dimsize(dataMatrix,1)) QAdata
//	FastExtractFromMatrix(0, 1, dataMatrix, extractTrue, QAdata) //only take particles that are OK or saturated, don't take too small or missed
//	wave QAdata
	duplicate /o datamatrix, qadata
	
	variable FL1ColNum = FindDimLabel(QAdata, 1, "FL1_280")
	variable FL2ColNum = FindDimLabel(QAdata, 1, "FL2_280")
	variable FL3ColNum = FindDimLabel(QAdata, 1, "FL2_370")
	// subtract flourescence BL
	controlInfo T1_raw
	if(!V_Value) // this just subtracts the baseline at the time of each single particle to get quantitative flourescance measurements
		QAdata[][FL1ColNum] -= min(BLs[0], QAdata[p][FL1ColNum])
		QAdata[][FL2ColNum] -= min(BLs[1], QAdata[p][FL2ColNum])
		QAdata[][FL3ColNum] -= min(BLs[2], QAdata[p][FL3ColNum])
	endif
	
	make /free/n=(dimsize(QAdata,1)) extractTrue = 0
	
	string thisLabel
	variable thisColNum
	variable i
	for(i = 0; i < dimsize(QAdata,1); i += 1)
		thisLabel = getDimLabel(QAdata, 1, i)
		thisColNum = FindDimLabel(cluster, 0, thisLabel)
		if(thisColNum != -2) // label found
			extractTrue[i] = 1
		endif
	endfor
	
	make /o/n=(dimsize(QAdata,0), sum(extractTrue)) clCompData
	FastExtractFromMatrix(1, 1, QAdata, extractTrue, clCompData) 

	wave clCompData
	
//	clCompData = useTrue[p] ? clCompData[p][q] : NaN // nan the rows that are data we don't want to use
	
	return clCompData	
End

Function updateRawDistributions(avgWaveRef, thisSPD, loadSDFlag, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFFlag [, weighting])
	string avgWaveRef
	wave thisSPD
	variable loadSDFlag,  loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFFlag
	wave weighting // this is used in the fuzzy attribution for cluster analysis.Most of the time it == 1
	
	if(paramisdefault(weighting))
		make /o/n=(dimsize(thisSPD,0)) weighting = 1
	endif
	
	variable i, bigs, binNo
	wave flBins = root:Panel:flBins
	for(i = 0; i < dimsize(thisSPD,0); i += 1)
		if(loadSDflag)
			wave /z SDWave = $avgWaveRef + "_SD"
			wave sizeBins = root:Panel:sizeBins
			SDWave[x2pnt(SDWave,thisSPD[i][0])][BinarySearch(sizeBins, thisSPD[i][FindDimLabel(thisSPD, 1, "Size")])] += weighting[i] // one particle at that size and time
		endif 
		if(loadFl1Flag)
			wave /z FLWave = $avgWaveRef + "_Fl1D"
			variable ch1Col = FindDimLabel(thisSPD,1, "FL1_280")
			binNo = BinarySearch(flBins,thisSPD[i][ch1Col])
			if(binNo >= 0)
				FLWave[x2pnt(FLWave,thisSPD[i][0])][binNo] += weighting[i] // one particle at that total fluorecnece and time - note that the total fluorescence will only be for one channel if that is the prototype
			endif	
		endif
		if(loadFl2Flag)
			wave /z FLWave = $avgWaveRef + "_Fl2D"
			variable ch2Col = FindDimLabel(thisSPD,1, "FL2_280")
			binNo = BinarySearch(flBins,thisSPD[i][ch2Col])
			if(binNo >= 0)
				FLWave[x2pnt(FLWave,thisSPD[i][0])][binNo] += weighting[i] // one particle at that total fluorecnece and time - note that the total fluorescence will only be for one channel if that is the prototype
			endif	
		endif
		if(loadFl3Flag)
			wave /z FLWave = $avgWaveRef + "_Fl3D"
			variable ch3Col = FindDimLabel(thisSPD,1, "FL2_370")
			binNo = BinarySearch(flBins, thisSPD[i][ch3Col])
			if(binNo >= 0)
				FLWave[x2pnt(FLWave,thisSPD[i][0])][binNo] += weighting[i] // one particle at that total fluorecnece and time - note that the total fluorescence will only be for one channel if that is the prototype
			endif	
		endif

		if(loadAFflag)
			wave /z AFWave = $avgWaveRef + "_AFD"
			wave afBins = root:Panel:afBins
			variable AFvalue =  thisSPD[i][FindDimLabel(thisSPD, 1, "AF")]
			if(AFvalue > 0) // check for NaN type valuel
				AFWave[x2pnt(AFWave,thisSPD[i][0])][BinarySearch(afBins, AFvalue)] += weighting[i] // one particle at that AF and time
			endif
		endif
	endfor
End

Function /wave SPDClusterIndex(comparableSPD, clusters, mode, modeNo, filterSatFlag) // returns an index wave that indicates which cluster each particle belongs to
	wave comparableSPD
	wave /wave clusters
	wave mode
	variable modeNo, filterSatFlag
	
	make /o/n=(dimsize(comparableSPD,0),numpnts(clusters)) clusterIndex = -1 // cluster index  != nan if in that cluster (columns == different clusters), value is weighting
	make /o/n=(dimsize(comparableSPD,0)) extractTrue = NaN
	
	NVAR wibsVersion = root:Panel:wibsVersion
	if(filterSatFlag) // don't include particles that have satruated (i.e. qaflag == 0 and only 0)
		if(wibsVersion != 4)
			extractTrue = mode == 0 // needs to have passed the QA tests and be part of the prototype and not be false trigger mode
		elseif(wibsVersion == 4)
			extractTrue = (mode & 2^0) == 0 && (((mode & 2^1) != 0) == modeNo) // needs to have passed the QA tests and be part of the prototype and not be false trigger mode
		//	wavestats /q mode
		endif
	else // do include particles that have satruated (i.e. qaflag == 0 and and qaflag == 2)
		if(wibsVersion != 4)
			extractTrue = mode == 0 // needs to have passed the QA tests and be part of the prototype and not be false trigger mode
		elseif(wibsVersion == 4)
			extractTrue = (mode & 2^0) == 0 && (((mode & 2^1) != 0) == modeNo) // needs to have passed the QA tests and be part of the prototype and not be false trigger mode
		//	wavestats /q mode
		endif
	endif

	convertSpace(comparableSPD, clusters, "log") // converts the relevant variables into log space for the distance calculation
	variable i
	make /o/n=(dimsize(comparableSPD,1)) thisSP
	wave CAinputSdevs = $(getCAfolder() + ":CAinputSdevs")
	for(i = 0; i < dimsize(comparableSPD,0); i += 1)
		thisSP = comparableSPD[i][p]
		wave thisAssignment = assignCluster(thisSP, clusters, CAinputSdevs)
		clusterIndex[i][] = thisAssignment[q]
	endfor
	convertSpace(comparableSPD, clusters, "lin") // converts the relevant variables back from log space
		
	clusterIndex = extractTrue[p] == 0 ? NaN : clusterIndex
	
	return clusterIndex
End

//Function /wave assignCluster(thisSP, clusters, sdevs) // returns a wave of all the clusters that is could be in, with weighted attribution for each in col 2
//	wave thisSP
//	wave /wave clusters
//	wave sdevs
//	
//	wave /z withInThresh
//	if(!waveexists(withInThresh))
//		make /o/n=(1,numpnts(thisSP)) withinThresh = 0
//	else
//		InsertPoints /M=0 inf, 1, withinThresh
//		withinThresh[inf][] = 0
//	endif
//		
//	ControlInfo T5_assignThresh; variable threshNoOfSdevs = 5
//	
//	make /free/o/n=(numpnts(thisSP)) squares, thesesdevs
//	make /o/n=(numpnts(clusters)) distances, probs
//	variable distance, i, clusterNo
//	for(i = 0; i < numpnts(clusters); i += 1)
//		wave thisCluster = clusters[i]
//		thesesdevs = thisCluster[p][1] == 0  ? 1e-6 : thisCluster[p][1] // this means that the maths works when the sdev == 0 i.e. a saturated cluster
//		squares = ((thisCluster[p][0] - thisSP[p])/thesesdevs[p])^2
//	//	duplicate /o/free squares, roots
//	//	roots = sqrt(squares)
//		// testing
//	//	if(numtype(sum(squares)) == 2)
//	//		withinThresh[inf][] = NaN
//	//	else
//	//		withinThresh[inf][] = sqrt(squares[q]) < threshNoOfSdevs || withinThresh[inf][q]
//	//	endif
//	//	// end testing
//		distances[i] = sqrt(sum(squares))
//	endfor
//	
//	make /o/n=(numpnts(distances)) index = p
//	sort distances, distances, index
//	extract /o index, attributedClusters, distances < threshNoOfSdevs
//	extract /o distances, attributedDistances, distances < threshNoOfSdevs
//	
//	make /o/n=(numpnts(attributedClusters))/free score, frac, invDist
//	invDist = 1/attributedDistances
//	score = 1/(attributedDistances*sum(invDist))
//	make /o/n=(numpnts(clusters)) attribution // returns a 0D wave if no clusers
//	for(i = 0; i < numpnts(attribution); i += 1)
//		FindValue /v=(i) attributedClusters
//		if(V_value != -1)
//			attribution[i] = score[V_value]
//		else
//			attribution[i] = NaN
//		endif
//	endfor
//	
////	make /o/n=(numpnts(clusters)) attribution
////	attribution = 0
////	attribution[index[0]] = 1
//	
//	return attribution
//End

Function /wave assignCluster(thisSP, clusters, sdevs) // returns a wave of all the clusters that is could be in, with weighted attribution for each in col 2
	wave thisSP
	wave /wave clusters
	wave sdevs
	
	wave /z withInThresh
	if(!waveexists(withInThresh))
		make /o/n=(1,numpnts(thisSP)) withinThresh = 0
	else
		InsertPoints /M=0 inf, 1, withinThresh
		withinThresh[inf][] = 0
	endif
	
	make /free/o/n=(numpnts(thisSP)) squares
	make /o/n=(numpnts(clusters)) distances, probs
	variable distance, i, clusterNo
	for(i = 0; i < numpnts(clusters); i += 1)
		wave thisCluster = clusters[i]
	//	sdevs = {324, 365, 143, 0.290798, 1.12645}
		squares = ((thisCluster[p][0] - thisSP[p])/sdevs[p])^2
		distances[i] = sqrt(sum(squares))
	endfor
	
	make /o/n=(numpnts(distances)) index = p
	sort distances, distances, index
	
	make /o/n=(numpnts(clusters)) attribution
	attribution = 0
	attribution[index[0]] = 1
	
	return attribution
End

Function /wave SPDinMode(dataMatrix, QAflags, mode, FlThresh, BLs, modeNo, protoNo, filterSatFlag, prototypes, prototypeNames) // applies QA choices, BL, mode and prototype selection and returns the relevant data
	wave dataMatrix, QAflags, mode, FlThresh, BLs
	variable modeNo, protoNo, filterSatFlag
	wave prototypes
	wave /t prototypeNames
	
	STRUCT prototype ThisProto
	StructGet ThisProto, prototypes[protoNo]
	wave inPrototype = inThisPrototype(ThisProto, dataMatrix, FLThresh)
	
	NVAR wibsVersion = root:Panel:wibsVersion
	if(filterSatFlag) // don't include particles that have satruated (i.e. qaflag == 0 and only 0)
		if(wibsVersion != 4)
			make /o/n=(dimsize(dataMatrix,0)) extractTrue = QAflags == 0 && inPrototype == 1 && mode == 0 // needs to have passed the QA tests and be part of the prototype and not be false trigger mode
		elseif(wibsVersion == 4)
			make /o/n=(dimsize(dataMatrix,0)) extractTrue = QAflags == 0 && inPrototype == 1 && (mode & 2^0) == 0 && (((mode & 2^1) != 0) == modeNo) // needs to have passed the QA tests and be part of the prototype and not be false trigger mode
			wavestats /q mode
		endif
	else // do include particles that have satruated (i.e. qaflag == 0 and and qaflag == 2)
		if(wibsVersion != 4)
			make /o/n=(dimsize(dataMatrix,0)) extractTrue = (QAflags == 0 || QAflags == 2) && inPrototype == 1 && mode == 0 // needs to have passed the QA tests and be part of the prototype and not be false trigger mode
		elseif(wibsVersion == 4)
			make /o/n=(dimsize(dataMatrix,0)) extractTrue = (QAflags == 0 || QAflags == 2) && inPrototype == 1 && (mode & 2^0) == 0 && (((mode & 2^1) != 0) == modeNo) // needs to have passed the QA tests and be part of the prototype and not be false trigger mode
			wavestats /q mode
		endif
	endif

	wave returnWave = extractFromMatrix(0, 1, dataMatrix, extractTrue)

	duplicate /o/r=(0)(*) dataMatrix, $prototypeNames[protoNo] + "_SP" //to conserve column labels
	wave SPD = $prototypeNames[protoNo] + "_SP"
	redimension /n=(dimsize(returnWave,0), dimsize(returnWave,1)) SPD
	SPD = returnWave
	
	if(dimsize(SPD,0) == 0) // if there is no data then return nans so that the averaged data will be nans
		redimension /n=(1,-1) SPD
		SPD = NaN
	endif
	
	/// apply fl baseline
	variable FL1ColNum = FindDimLabel(SPD, 1, "FL1_280")
	variable FL2ColNum = FindDimLabel(SPD, 1, "FL2_280")
	variable FL3ColNum = FindDimLabel(SPD, 1, "FL2_370")
	
	SPD[][FL1ColNum] -= min(BLs[0], SPD[p][FL2ColNum])
	SPD[][FL2ColNum] -= min(BLs[1], SPD[p][FL2ColNum])
	SPD[][FL3ColNum] -= min(BLs[2], SPD[p][FL3ColNum])
	
	return SPD
End

Function getWibsVersion(dataMatrix) // returns the number of the wibs version from inspecting the data file
	wave dataMatrix
	
	variable wibsVersion, totalT1ColNo = FindDimLabel(dataMatrix, 1, "TotalT1")
	if(totalT1ColNo == -2) // cant find is
		wibsVersion = 3 // its WIBS 3
	else
		wibsVersion = 4 // its WIBS 4
	endif
	
	return wibsVersion
End

Function /D findStartTime(minT, fitToTimeGrid, timeRes)
	variable minT, fitToTimeGrid, timeRes
	
	variable binStartTime // this is the time that the averaged T series starts at, incrimenting in steps of timeRes
	if(fitToTimeGrid) // i.e. fit totime grid selected
		binStartTime = minT - mod(minT,(timeRes*60))
	elseif(!fitToTimeGrid) // i.e.not fit to time grid
		binStartTime = minT
	endif
	
	return binStartTime
End

Function /wave QA(dataMatrix, minSize) // takes a wave and returns a wave signalling qa passed or varisou fails
	wave dataMatrix
	variable minSize
	
	make /o/n=(DimSize(dataMatrix, 0)) QAfailed = 0 // missed particle (i.e. lamp hadn't recharged 1 or signal was saturated2 ), 3 means noise (ie. < 0.8 um)
	variable sizeColNum = FindDimLabel(dataMatrix, 1, "Size")
	variable Pwr_280ColNum = FindDimLabel(dataMatrix, 1, "Pwr_280")
	variable Pwr_370ColNum = FindDimLabel(dataMatrix, 1, "Pwr_370")
	
	variable i
	for(i = 0; i < numpnts(QAfailed); i += 1) // loops round every particle event and checks them
		duplicate /o/r=(i)(*) dataMatrix, timeSlice
		FindValue /V=(satVal) /Z timeSlice
		if(dataMatrix[i][sizeColNum] < minSize)
			QAfailed[i] = 3 // particle sized less than min size - noise. This is three as I realised it should take priority after writing the rest of the program
		elseif(dataMatrix[i][Pwr_280ColNum] < 100 && dataMatrix[i][Pwr_370ColNum] < 100)
			QAfailed[i] = 1 // lamp hasn't fired but particle detected - missed particle
		elseif(V_value != -1)
			QAfailed[i] = 2 // saturation occured on one measurement
		else
			QAfailed[i] = 0 // didn't fail
		endif
	endfor // end of loop round particle events

	return QAfailed
End

Function /Wave loadBaselineData([gainMode])
	variable gainMode // optional argument for loading baseline data from only one gain mode
		
	make /o/d/n=(0,4) BLs, flThresh; SetDimLabel 1,0,dateNtime,BLs,FlThresh; SetDimLabel 1,1,FL1,BLs,FlThresh; SetDimLabel 1,2,FL2,BLs,FlThresh;SetDimLabel 1,3,FL3,BLs,FlThresh // {time, Ch1BL, Ch2BL, Ch3BL}
	
	SVAR fileEnding = root:Panel:fileEnding
	// find out how many files in the folder
	string temp = indexedFile(myPath, -1, "."+fileEnding)
	variable noOfFiles = itemsInList(temp)
	NVAR loadProg = root:Panel:loadProg
	
	variable i
	do // loops round files
		wave dataMatrix = loadFile(i, fileEnding)
		if(dataMatrix[0][0] == -8888) // no more files
			break // break loop round files
		endif
		
		if(!paramisdefault(gainMode))
			variable modeCol = FindDimLabel(dataMatrix, 1, "FT")
			make /o/free/n=(dimsize(dataMatrix,0)) gainModeSeries = (dataMatrix[p][modeCol]&2^1)!=0
			if(gainMode == 0) // low gain mode
				gainModeSeries = !gainModeSeries
				wave dataThisMode = extractFromMatrix(0, 1, dataMatrix, gainModeSeries) 
			else // high gain mode
				wave dataThisMode = extractFromMatrix(0, 1, dataMatrix, gainModeSeries)
			endif
			redimension /n=(dimsize(dataThisMode,0), -1) dataMatrix; dataMatrix = dataThisMode; killwaves dataThisMode // preserves dim labels
			if(dimsize(dataMatrix,0) == 0) // if no data let
				i += 1
				continue
			endif
		endif
		
		NVAR wibsVersion = root:Panel:wibsVersion
		variable tempVer
		// find WIBS version
		if(i == 0)
			wibsVersion = getWibsVersion(dataMatrix)
		else
			tempVer = getWibsVersion(dataMatrix)
			if(tempVer == 3 && wibsVersion ==2)
				tempVer = 2
			endif
			if(tempVer != wibsVersion)
				setdatafolder root:
				Abort "Inconsistant wibs versions at file no " + num2str(i)
			endif
		endif
		
		redimension /n=(dimsize(BLs,0)+1, -1) BLs, flThresh
		
		if(dataMatrix[0][0] == -9999) // bad load
			BLs[dimsize(BLs,0)][] = NaN
			flThresh[dimsize(BLs,0)][] = NaN
		else
			wave thisBLsAndFlThresh = calcBaselineAndFlThresh(dataMatrix)
			BLs[dimsize(BLs,0)][] = thisBLsAndFlThresh[q][0]
			flThresh[dimsize(BLs,0)][] = thisBLsAndFlThresh[q][1]
		endif
		
		i += 1
		loadProg = (i/noOfFiles)*100
		controlUpdate TPB_loadProg
	while(1) // loops round files
	
	print num2str(i) + " files loaded."
	
	make /o/wave BLsnFlThresh = {BLs, flThresh}
	
	return BLsnFlThresh
End

Function /wave loadFile(fileNo, ending) // function to get nth file in the 
	variable fileNo
	string ending
	
	pathInfo myPath

	string fileName = indexedFile(myPath, fileNo, "."+ending) //generates a semicolon seperated list of files in directory
	if(StrLen(fileName) == 0) //no file found
		make /o noFile = {-8888}
		return noFile // end
	else
		string dataPathAndName = S_path + fileName
		LoadWave/Q/J/D/A=test/K=0/L={0,0,40,0,1} dataPathAndName
		wave /t test0
		string test1 = test0[3]
		string subtest1 = test1[0,18]
		string test2 = test0[28]
		string subtest2 = test2[0,14]
		string test3 = test0[38]
		killwaves test0
				
		if(cmpstr(subtest2, "Use exponential")==0) // FAB
			variable /g root:Panel:wibsVersion = 4
			string /g root:Panel:dataFolder = "root:Data:"
			LoadWave/N=thisStartTime/J/O/Q/D/K=0/V={"\t, "," $",0,1}/L={0,50,1,2,1}/R={English,2,2,2,2,"DayOfMonth/Month/Year",40} dataPathAndName // reads in the start data and time of the file
			LoadWave/J/M/U={0,0,1,0}/O/Q/D/N=thisDataMatrix/K=0/V={"\t,"," $",0,1}/L={51,52,0,0,0} dataPathAndName 
			if(V_flag != 1)
				Print "Problems loading " + S_fileName
			endif
			
			variable recalcAFs = 1
			if(recalcAFs)
				wave thisDataMatrix0
				make /free/n=(dimsize(thisDataMatrix0,0)) recalcedAF
				variable sct1Col = FindDimLabel(thisDataMatrix0, 1, "Scat_EL1") 
				variable sct2Col = FindDimLabel(thisDataMatrix0, 1, "Scat_EL2") 
				variable sct3Col = FindDimLabel(thisDataMatrix0, 1, "Scat_EL3") 
				variable sct4Col = FindDimLabel(thisDataMatrix0, 1, "Scat_EL4") 
				variable AFCol = FindDimLabel(thisDataMatrix0, 1, "AF") 
				recalcedAF = recalcAF(thisDataMatrix0[p][AFCol], thisDataMatrix0[p][sct1Col], thisDataMatrix0[p][sct2Col], 6.4703, 0.969, thisDataMatrix0[p][sct3Col], 0.702, 0.9593, thisDataMatrix0[p][sct4Col], 0.5493, 0.9428, 20, 50)
				thisDataMatrix0[][AFCol] = recalcedAF[p]
			endif
		elseif(cmpstr(subtest1, "Trigger Threshold 1")==0) // WIBS 4
			variable /g root:Panel:wibsVersion = 4
			string /g root:Panel:dataFolder = "root:Data:"
			LoadWave/N=thisStartTime/J/O/Q/D/K=0/V={"\t, "," $",0,1}/L={0,37,1,2,1}/R={English,2,2,2,2,"DayOfMonth/Month/Year",40} dataPathAndName // reads in the start data and time of the file
			LoadWave/J/M/U={0,0,1,0}/O/Q/D/N=thisDataMatrix/K=0/V={"\t,"," $",0,1}/L={38,39,0,0,0} dataPathAndName 
			if(V_flag != 1)
				Print "Problems loading " + S_fileName
			endif
			wave thisDataMatrix0
			variable a = findDimLabel(thisDataMatrix0, 1, "FL2 SctInt") // col labels are different between versions 
			SetDimLabel 1,a, FL2_Scat, thisDataMatrix0
		elseif(strsearch(test3, "/", 13) != -1)  // WIBS 3
			variable /g root:Panel:wibsVersion = 3
			string /g root:Panel:dataFolder = "root:Data:"
			LoadWave/N=thisStartTime/J/O/Q/D/K=0/V={"\t, "," $",0,1}/L={0,38,1,2,1}/R={English,2,2,2,2,"DayOfMonth/Month/Year",40} dataPathAndName 
			LoadWave/J/M/U={0,0,1,0}/O/Q/D/N=thisDataMatrix/K=0/V={"\t,"," $",0,1}/L={39,40,0,0,0} dataPathAndName 
			if(V_flag != 1)
				Print ("Problems loading " + S_fileName)
			endif
		else // WIBS2
			variable /g root:Panel:wibsVersion = 2
			string /g root:Panel:dataFolder = "root:Data:"
			LoadWave/J/O/Q/M/D/A=thisStartTime/K=0/V={"\t, "," $",0,0}/L={0,38,1,2,2}/R={English,2,2,2,2,"Year.Month.DayOfMonth",40} dataPathAndName 
			LoadWave/J/M/U={0,0,1,0}/O/Q/D/N=thisDataMatrix/K=0/V={"\t,"," $",0,1}/L={39,40,0,0,0} dataPathAndName 
			if(V_flag != 1)
				Print ("Problems loading " + S_fileName)
			endif
		endif
		
		If(V_flag == 1) // if loaded correctly
			wave thisStartTime0
			NVAR wibsVersion = root:Panel:wibsVersion
			variable thisStartTime
			if(wibsVersion == 2)
				thisStartTime = thisStartTime0[0][0] + thisStartTime0[0][1]
			else
				thisStartTime = thisStartTime0[0][0]
			endif
			
			wave thisDataMatrix0

			thisDataMatrix0[][0] = thisDataMatrix0[p][0]/1000 + thisStartTime // converts from ms to igor time
		else
			make /o thisDataMatrix0 = {-9999} // no data
		endif
		
		killwaves thisStartTime0
	
		return thisDataMatrix0
	endif
End

Function /wave calcBaselineAndFlThresh(dataMatrix) // returns the BL value of this dataMatrix
	wave dataMatrix
	
	// find the NVARs that store the max and min times
	NVAR wibsVersion = root:panel:wibsVersion
	
	// find flthresh  for this file -- mean value per file + X stdv and find baseline with is not + xstdv

	variable modeCol = FindDimLabel(DataMatrix, 1, "FT")
	variable timeColNum = FindDimLabel(DataMatrix, 1, "Time")
	variable ch1colNum = FindDimLabel(DataMatrix, 1, "FL1_280") //trypto
	variable ch2colNum = FindDimLabel(DataMatrix, 1, "FL2_280") //nadh
	variable ch3colNum = FindDimLabel(DataMatrix, 1, "FL2_370") //nadh

	make /o/n=(dimsize(DataMatrix,0)) mode = (DataMatrix[p][modeCol]& 2^0) != 0 //wave is 1 if FT mode
//	extract /o mode, modeNoNaNs, numtype(mode) != 2
//	if(wibsVersion == 3) 
//	wave returnWave = extractFromMatrix(0, 1, DataMatrix, modeNoNaNs)
	wave returnWave = extractFromMatrix(0, 1, DataMatrix, mode)
//	elseif(wibsVersion == 4)
//		make /o/n=(numpnts(modeNoNaNs)) FTmode = (mode & 2^0) != 0
//		wave returnWave = extractFromMatrix(0, 1, DataMatrix, FTmode)
//	endif
	duplicate /o returnWave, FTmodeData
		
	if(dimsize(FTmodeData,0) > maxBLAvgPeriod) // if being averaged over too long a period promt for OK
		DoAlert 1, ("Warning, the base line average is being performed over an unusually long period of " + secs2time(dimsize(FTmodeData,0),1) + ". Would you still like to continue?")
		if(V_flag == 2) //no
			setdatafolder root:
			Abort "Data loading aborted."
		endif
	endif
		
	make /d/o/n=(4,2) returnBLsandFlThresh //first entry is average time, then base line in order trypto280nm, nadh280nm, nadh370nm. First row is BL and second row is flThres

	duplicate /o/r=(*)(timeColNum) dataMatrix, temp
	wavestats /z/q temp
	
	if(V_avg == 0) // if there is no FT data at all just use the mid time of the file. This is needed to order the load
		wavestats /m=2 DataMatrix
	endif
	
	returnBLsAndFlThresh[0][] = V_avg
	if(dimsize(FTmodeData,0) > minBLpoints)// && numpnts(FTmodeData) > 0) // if enought points for a valid BL average (or indeed any points)
		duplicate /o/r=(*)(ch1colnum) FTmodeData, temp
		wavestats /q temp
		returnBLsAndFlThresh[1][0] = V_avg
		returnBLsAndFlThresh[1][1] = V_avg + BLstdevsAboveMean*V_sdev
		duplicate /o/r=(*)(ch2colnum) FTmodeData, temp
		wavestats /q temp
		returnBLsAndFlThresh[2][0] = V_avg
		returnBLsAndFlThresh[2][1] = V_avg + BLstdevsAboveMean*V_sdev
		duplicate /o/r=(*)(ch3colnum) FTmodeData, temp
		wavestats /q temp
		returnBLsAndFlThresh[3][0] = V_avg
		returnBLsAndFlThresh[3][1] = V_avg + BLstdevsAboveMean*V_sdev
		
		return returnBLsAndFlThresh
	else
		returnBLsAndFlThresh[1,3][] = NaN
		return returnBLsAndFlThresh
	endif
End

Function loadSPD(pc, raw, minSize) // function to load pc% of the single particle data (at random)
	variable pc, raw, minSize
	
	SVAR fileEnding = root:Panel:fileEnding
	wave /z blacklist = root:Panel:blacklist
	if(!waveexists(blacklist))
		setdatafolder root:
		Abort "Please load time series data before trying to load SPD."
	endif
	
	killdatafolder /z root:SP
	newdatafolder /o/s root:SP
	
	NVAR gainMode = root:Panel:gainMode

	variable i
	do // loops round files 
		wave thisSPD = loadFile(i, fileEnding)
		if(thisSPD[0][0] == -8888) // no more files
			break // break loop round files
		elseif(thisSPD[0][0] == -9999) // file contains no data 
			break
		endif
		
		if(!raw)
			wave QAflags = QA(thisSPD, minSize)
			wave BLs = root:Baseline:BLs
			wave flThresh = root:Baseline:flThresh
			variable modeCol = findDimLabel(thisSPD, 1, "FT")
			duplicate /free/r=(*)(modeCol) thisSPD, mode
			duplicate /o/free/r=(*)(0) thisSPD, thisDataTime
			wavestats /q thisDataTime
			wave thisBL = getThisBL(V_min, V_max, BLs, "thisBL")
			wave thisFlThresh = getThisBL(V_min, V_max, FlThresh, "thisFlThesh")
			wave prototypes = root:Prototypes:prototypes
			wave prototypeNames = root:Prototypes:prototypeNames
			wave SPDtemp = SPDinMode(thisSPD, QAflags, mode, thisFlThresh, thisBL, gainMode, 0, 0, prototypes, prototypeNames) 
			duplicate /o SPDtemp, thisSPD; killwaves SPDtemp
		endif
			
		make /o/n=(dimsize(thisSPD, 0)) extractTrue  = enoise(50)+50 
		extractTrue = extractTrue < pc  // generates a random number between 0 and 100. if its less than the pc set to 1
		wave chosenSPD = extractFromMatrix(0, 1, thisSPD, extractTrue)
		redimension /n=(dimsize(chosenSPD,0),-1) thisSPD // this conserves the dim labels for use later
		thisSPD = chosenSPD; killwaves chosenSPD
		
		if(dimsize(thisSPD,0) > 0 && !waveexists(SPD))
			duplicate /o thisSPD, SPD
		elseif(dimsize(thisSPD,0) > 0 && waveexists(SPD))
			concatenate /o/np=0 {SPD, thisSPD}, temp
			duplicate /o temp, SPD
		endif
		
		i += 1
	while(1) // loops round files
	
	killwaves /Z thisDataMatrix0, extractTrue, returnWave, thisSPD, temp, thisStartTime0, noFile
	
	if(!raw)			
	ControlInfo T0_recalcSizes // recalculates the single particle sizes
			if(V_Value && !raw)	
				variable sizeColNo = findDimLabel(SPD, 1, "Size")
				variable FL2_ScatColNo = findDimLabel(SPD, 1, "FL2_Scat")
				SPD[][sizeColNo] = calcSizeFromScatter(SPD[p][FL2_ScatColNo], SPD[p][SizeColNo])
			endif
			
			wave QAflags = QA(SPD, minSize)
			make/o/n=(numpnts(QAflags)) extractTrue
			extractTrue = !(QAflags == 1 || QAflags == 3)
			wave QAdSPD = extractFromMatrix(0, 1, SPD, extractTrue)
			redimension /n=(dimsize(QAdSPD,0),-1) SPD
			SPD = QAdSPD
	endif
	
	
	// Remove if not in todo
	ControlInfo toDoList
	wave thisToDo = $("root:ToDoWaves:"+S_value)
	SPDinThisToDo(thisToDo, SPD)
	
	refreshSPDlist()
	
	setdatafolder root:
End