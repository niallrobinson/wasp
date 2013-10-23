///////////////////////////////////////////////////////////////////////////////////////////////////
// Wibs Analysis Program v 1.0 alpha                                           
// various stand alone functions used by the other ipfs
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
#include <Percentile and Box Plot>

Constant noOfBins = 24 // number of bins in the diurnal plots

Function addToBlackList()
	GetMarquee /K bottom
	
	wave blackList = root:Panel:blackList
	blackList[x2pnt(blackList,V_left),x2pnt(blackList,V_right)] = 1
End

Function setToDoWave()
	GetMarquee /K left, bottom
	wave blacklist = root:panel:blackList // just use this for the time stamp

	if(strsearch(S_marqueeWin,"Series",0) != -1) // time series
		NVAR todoStartPoint = root:Panel:toDoStartPt
		toDoStartPoint = x2pnt(blacklist, V_left)
		NVAR toDoEndPoint = root:Panel:toDoEndPt
		toDoEndPoint = x2pnt(blacklist, V_right)
		
		wave sizeBinsListSW = root:Panel:sizeBinsListSW
		wave sinBinsList = root:Panel:sizeBinsList
		sizeBinsListSW = 1
	elseif(strsearch(S_marqueeWin,"SizeImage",0) != -1) // size distribution
		NVAR todoStartPoint = root:Panel:toDoStartPt
		toDoStartPoint = x2pnt(blacklist, V_left)
		NVAR toDoEndPoint = root:Panel:toDoEndPt
		toDoEndPoint = x2pnt(blacklist, V_right)
						
		wave sizeBinsListSW = root:Panel:sizeBinsListSW
		wave sizeBins = root:Panel:sizeBins
		sizeBinsListSW = 0
		sizeBinsListSW[ceil(binarysearchinterp(sizeBins,V_bottom)), floor(binarysearchinterp(sizeBins,V_top))] = 1
	elseif(strsearch(S_marqueeWin, "SizeDist",0) != - 1)
		NVAR todoStartPoint = root:Panel:toDoStartPt
		toDoStartPoint = 0
		NVAR toDoEndPoint = root:Panel:toDoEndPt
		toDoEndPoint = numpnts(blackList)
				
		wave sizeBinsListSW = root:Panel:sizeBinsListSW
		wave sizeBins = root:Panel:sizeBins
		sizeBinsListSW = 0
		sizeBinsListSW[ceil(binarysearchinterp(sizeBins,V_left)), floor(binarysearchinterp(sizeBins,V_right))] = 1
	endif
End

Function /wave parseToDoStr(str)
	string str
	
	variable andPos = strsearch(str, "AND", 0 , 2)
	variable orPos = strsearch(str, "OR", 0 , 2)
	variable notPos = strsearch(str, "NOT", 0 , 2)
	
	if(((andPos != -1) + (orPos != -1) + (notPos != -1)) > 1)
		abort "Cannot parse more than one condition at a time"
	elseif(((andPos != -1) + (orPos != -1) + (notPos != -1))  == 0) // nothing to parse - just a normal todo wave name
		Abort
	endif
	
	string name = ""
	Prompt name, "Name: " // Set prompt for x param
	DoPrompt "Enter a name for the new to do wve", name
	if (V_Flag)
		Abort
	endif
	
	variable firstBreak = strsearch(str, " ", 0)
	variable secondBreak = strsearch(str, " ", strlen(str), 1)
	
	string td1name = str[0,firstBreak-1]
	string td2name = str[secondBreak+1, strlen(str)]
	
	wave td1 = $("root:ToDoWaves:" +td1name)
	wave td2 = $("root:ToDoWaves:" +td2name)
	
	if(andPos != -1) // if and found
		wave newToDo = toDoAndToDo(td1, td2, name+"uninit")
	elseif(orPos != -1) // if or found
		wave newToDo = toDoOrToDo(td1, td2, name+"uninit")
	elseif(notPos != -1) // if not found
		wave newToDo = toDoNotToDo(td1, td2, name+"uninit")
	endif
	
	duplicate /o root:ToDoWaves:All, $("root:ToDoWaves:"+name)
	wave initToDo = $("root:ToDoWaves:"+name)
	initToDo = newToDo; killwaves newToDo
	
	return initToDo
End

Function /wave toDoAndToDo(td1, td2, name)
	wave td1, td2
	string name
	
	if(cmpstr(note(td1), note(td2)) != 0)
		Abort "To dos are different types"
	endif
		
	make /o/n=(dimsize(td1,0),dimsize(td1,1)) $("root:ToDoWaves:"+name)
	wave newToDo = $("root:ToDoWaves:"+name); Note /K newToDo, note(td1)
	
	newToDo = (td1 == 1 && td2 == 1) ? 1 : 0
	
	return newToDo
End

Function /wave toDoNotToDo(td1, td2, name)
	wave td1, td2
	string name
	
	if(cmpstr(note(td1), note(td2)) != 0)
		Abort "To dos are different types"
	endif
	
	make /o/n=(dimsize(td1,0),dimsize(td1,1)) $("root:ToDoWaves:"+name)
	wave newToDo = $("root:ToDoWaves:"+name); Note /K newToDo, note(td1)
	
	newToDo = (td1 == 1 && td2 == 0) ? 1 : 0
	
	return newToDo
End

Function /wave toDoOrToDo(td1, td2, name)
	wave td1, td2
	string name
	
	if(cmpstr(note(td1), note(td2)) != 0)
		Abort "To dos are different types"
	endif
	
	make /o/n=(dimsize(td1,0),dimsize(td1,1)) $("root:ToDoWaves:"+name)
	wave newToDo = $("root:ToDoWaves:"+name); Note /K newToDo, note(td1)
	
	newToDo = (td1 == 1 ||  td2 == 1) ? 1 : 0
	
	return newToDo
End

Function /wave createToDo(startPt, endPt, varSW, type, name) // binary selection waves for the time (x) axis and whatever variable is on the y, string for note about type 
	variable startPt, endPt
	wave varSW // currently this is size selection wave, but in future may be extended to other variables
	string type // select from size, flour, asym - not used yet
	string name
	
	wave all = root:ToDoWaves:All
	wave blacklist = root:Panel:Blacklist
	duplicate /o all, $("root:ToDoWaves:"+name) 
	wave toDo = $("root:ToDoWaves:"+name)
	toDo = 0
	Note /K toDo, "Type:"+type
	
	make /o/free/n=(dimsize(todo,0)) temp = p > startPt && p < endPt ? 1 : 0
	
	toDo = temp[p] == 1 && varSW[q] == 1 ? 1 : 0
	
 	Note /K ToDo, "Type:"+type
	
	return ToDo
End

Function /Wave inThisToDo(td, dw) // returns a wave populated with data that is in that todo
	wave td
	wave dw
	
	wave blackList = root:Panel:blackList
	
	duplicate /o dw, $nameofwave(dw)+"_"+nameofwave(td)
	wave returnWave = $nameofwave(dw)+"_"+nameofwave(td)
	returnWave = td[p][q] == 0 || blackList[p] == 1 ? NaN : returnWave	
	
	return returnWave
End

Function SPDinThisToDo(td, SPD)
	wave td, SPD
	
	wave blacklist = root:Panel:Blacklist
	wave sizeBins = root:Panel:SizeBins

	variable SizeColNum =  FindDimLabel(SPD, 1, "Size")
	variable TimeColNum =  FindDimLabel(SPD, 1, "Time")
	
	make /o/n=(dimsize(SPD,0)) extractTrue = 0
	
	variable i, thisTime, thisSize, thisSizeBin
	for(i = 0; i < dimsize(SPD, 0); i += 1)
		thisTime = SPD[i][TimeColNum]
		thisSize = SPD[i][SizeColNum]
		thisSizeBin = binarysearchinterp(sizeBins, thisSize)
		
		if(td(thisTime)[thisSizeBin] == 1 && blackList(thisTime) == 0)
			extractTrue[i] = 1
		endif
	endfor
	
	wave temp = extractFromMatrix(0, 1, SPD, extractTrue)
	redimension /n=(dimsize(temp,0),-1) SPD //keeps dim lables the same
	SPD = temp
	killwaves temp
End

// this structure defines what a prototype should be. -1 signifies no threshold to be applied
Structure Prototype
	variable FL1Min
	variable FL1Max
	variable FL2Min
	variable FL2Max
	variable FL3Min
	variable FL3Max
	variable minSize
	variable maxSize
	variable AndOr //1 for and and 2 for or
	variable not
EndStructure

Function /WAVE inThisPrototype(pt, dw, FlThresh)
	STRUCT prototype &pt 
	wave dw, FlThresh
	
	make /o/n=(dimsize(dw,0)) inPrototype = 0
	variable sizeCol = FindDimLabel(dw,1, "Size")
	variable ch1Col = FindDimLabel(dw,1, "FL1_280")
	variable ch2Col = FindDimLabel(dw,1, "FL2_280")
	variable ch3Col = FindDimLabel(dw,1, "FL2_370")
		
	make /free/o/n=(numpnts(dw)) minSizeMet = dw[p][sizeCol] > pt.minSize ? 1 : 0
	make /free/o/n=(numpnts(dw)) maxSizeMet = dw[p][sizeCol] < pt.maxSize ? 1 : 0
	make /free/o/n=(numpnts(dw)) FL1MinMet = dw[p][ch1Col] > (pt.FL1Min+FlThresh[0]) ? 1 : 0
	make /free/o/n=(numpnts(dw)) FL1MaxMet = dw[p][ch1Col] < (pt.FL1Max+FlThresh[0]) ? 1 : 0
	make /free/o/n=(numpnts(dw)) FL2MinMet = dw[p][ch2Col] > (pt.FL2Min+FlThresh[1]) ? 1 : 0
	make /free/o/n=(numpnts(dw)) FL2MaxMet = dw[p][ch2Col] < (pt.FL2Max+FlThresh[1]) ? 1 : 0
	make /free/o/n=(numpnts(dw)) FL3MinMet = dw[p][ch3Col] > (pt.FL3Min+FlThresh[2]) ? 1 : 0
	make /free/o/n=(numpnts(dw)) FL3MaxMet = dw[p][ch3Col] < (pt.FL3Max+FlThresh[2]) ? 1 : 0

	if(pt.AndOr == 1)
		minSizeMet = pt.minsize != -1 ? minSizeMet : 1
		maxSizeMet = pt.minsize != -1 ? minSizeMet : 1
		FL1MinMet = pt.FL1Min != -1 ? FL1MinMet : 1
		FL1MaxMet = pt.FL1Max != -1 ? FL1MaxMet : 1
		FL2MinMet = pt.FL2Min != -1 ? FL2MinMet : 1
		FL2MaxMet = pt.FL2Max != -1 ? FL2MaxMet : 1
		FL3MinMet = pt.FL3Min != -1 ? FL3MinMet : 1
		FL3MaxMet = pt.FL3Max != -1 ? FL3MaxMet : 1
		inPrototype = minSizeMet && maxSizeMet && FL1MinMet && FL1MaxMet && FL2MinMet && FL2MaxMet && FL3MinMet && FL3MaxMet
	elseif(pt.AndOr == 2)
		minSizeMet = pt.minsize != -1 ? minSizeMet : 0
		maxSizeMet = pt.minsize != -1 ? minSizeMet : 0
		FL1MinMet = pt.FL1Min != -1 ? FL1MinMet : 0
		FL1MaxMet = pt.FL1Max != -1 ? FL1MaxMet : 0
		FL2MinMet = pt.FL2Min != -1 ? FL2MinMet : 0
		FL2MaxMet = pt.FL2Max != -1 ? FL2MaxMet : 0
		FL3MinMet = pt.FL3Min != -1 ? FL3MinMet : 0
		FL3MaxMet = pt.FL3Max != -1 ? FL3MaxMet : 0
		inPrototype = minSizeMet || maxSizeMet || FL1MinMet || FL1MaxMet || FL2MinMet || FL2MaxMet || FL3MinMet || FL3MaxMet		
	endif
	
	if(pt.not)
		inPrototype = !inPrototype
	endif

	return inPrototype
End

// this function takes a text wave and return a ; separated string list
Function /S textwave2list(tw)
	wave /t tw
	
	string returnString = ""
	variable i
	for(i = 0; i < numpnts(tw); i += 1)
		returnString += (tw[i] + ";")
	endfor
	
	return returnString
End

Function /S wave2list(w)
	wave w
	
	string returnString = ""
	variable i
	for(i = 0; i < numpnts(w); i += 1)
		returnString += (num2str(w[i])+";")
	endfor
	
	return returnString
End

Function /WAVE FastExtractFromMatrix(dim, preserveLabels, origdw, trueWave, destW)
     variable dim, preserveLabels // 0 for rows and 1 for columns, preserve is -1 for not, 0 for rows and 1 for columns
     wave origdw, trueWave, destW // tw is 1 for remove and 0 for don't

     variable i, j = 0, n = dimsize(origdw,dim)

	 fastop destW=(nan)	

	if(preserveLabels == -1)
		if (dim)
		     for(i = 0; i < n; i += 1)
		         if(trueWave[i] == 1)
		         	multithread destW[][j] = origdw[p][i] // As with everything, you might not get a speed up from multithread, so test it first
			         j += 1
	      		  endif
		     endfor
		else
		     for(i = 0; i < n; i += 1)
		         if(trueWave[i] == 1)
		      	       multithread destW[j][] = origdw[i][q]
      			       j += 1
		         endif
		     endfor
	     endif
	else
		if (dim)
			for(i = 0; i < n; i += 1)
				if(trueWave[i] == 1)
		      	      		multithread destW[][j] = origdw[p][i] // As with everything, you might not get a speed up from multithread, so test it first
		      	      		j += 1
                   		endif
		     endfor
		else
			for(i = 0; i < n; i += 1)
				if(trueWave[i] == 1)
		      	      		multithread destW[j][] = origdw[i][q]
		     		       j += 1
	      			endif
		     endfor
	     endif
	endif
	
	j = 0
	string name
	   
	if(preserveLabels == 0) // rows
		if(dim == 0) // same dimension as extraction
			for(i = 0; i < dimsize(origdw, 0); i += 1)
				if(trueWave[i])
					name = getdimlabel(origdw, 0, i)
					SetDimLabel 0, j, $name, destW
					j += 1
				endif
			endfor
		else // different dim from extraction
			for(i = 0; i < dimsize(origdw, 0); i += 1)
				name = getdimlabel(origdw, 0, i)
				SetDimLabel 0, i, $name, destW
			endfor
		endif
	elseif(preserveLabels == 1) // columns
		if(dim == 1) // same dimension as extraction
			for(i = 0; i < dimsize(origdw, 1); i += 1)
				if(trueWave[i])
					name = getdimlabel(origdw, 1, i)
					SetDimLabel 1, j, $name, destW
					j += 1
				endif
			endfor
		else // different dim from extraction
			for(i = 0; i < dimsize(origdw, 1); i += 1)
				name = getdimlabel(origdw, 1, i)
				SetDimLabel 1, i, $name, destW
			endfor
		endif
	endif
     
 //    multithread destw[j,dimsize(destW,0)-1][]=nan // It might be faster to do fastop returnwave=(nan) before the loop, I don't know
End

Function /WAVE extractFromMatrix(dim, overwritetrue, origdw, trueWave) // generic extract but for a matrix
	variable dim // 0 for rows and 1 for columns
	variable overwritetrue
	wave origdw, trueWave // tw is 1 for remove and 0 for don't
	
	duplicate /o origdw, dw
	if(dim == 1)
		MatrixOp /o temp = dw^t
		duplicate /o temp,dw; killwaves temp
	endif
	 
	variable sumTrueWave = sum(trueWave)
	variable numCols = dimsize(dw,1)
	if(overwritetrue)
		make /o/d/n=(sumTrueWave,numCols) returnWave
	elseif(!overwritetrue)
		make /d/n=(sumTrueWave,numCols) returnWave
	endif

	variable i, j
	for(i = 0; i < dimsize(dw,0); i += 1)
		if(trueWave[i] == 1)
			returnWave[j][] = dw[i][q]
			j += 1
		endif
	endfor
	
	if(dim == 1)
		matrixtranspose returnWave
	endif
	
	killwaves dw
	return returnWave
End

Function interpolateOverNaNs(dw)
	wave dw
	
	make /o/n=(numpnts(dw)) pointIsNaN = 0
	variable i,j
	for(i = 0; i < numpnts(dw); i += 1)
		if(numtype(dw[i])==2)
			pointIsNaN[i] = 1
		endif
	endfor
	
	variable beginNo, endNo, inNaNregion = 0, NaNsInARow = 0, endFlag=1
	for(i = 0; i < numpnts(dw); i += 1)
		if(!pointIsNaN[i] && !inNaNregion)
			endFlag = 0
			beginNo = dw[i]
		elseif(pointIsNaN[i])
			inNaNregion = 1
			NaNsInARow += 1
			if(i+1 == numpnts(dw))
				endFlag = 2
			endif
		elseif(inNaNregion == 1 && !pointIsNaN[i] && !endFlag)
			endNo = dw[i]
			for(j = 0; j < NaNsInARow; j += 1)
				dw[i-NaNsInARow+j] = beginNo + ((endNo-beginNo)/(NaNsInARow+1)*(j+1))
			endfor
			beginNo = dw[i]
			inNaNregion = 0
			NaNsInARow = 0
		elseif(endFlag == 1 && !pointIsNaN[i])
			for(j = 0; j < NaNsInARow; j += 1)
				dw[i-NaNsInARow+j] = dw[i] - (NaNsInARow-j)*(dw[i+1]-dw[i])
			endfor
			
			beginNo = dw[i]
			inNaNregion = 0
			NaNsInARow = 0
		endif
		
		if(endFlag == 2)
			for(j = 0; j < NaNsInARow; j += 1)
				variable npnts = numpnts(dw)
				dw[npnts-NaNsInARow+j] = dw[npnts-NaNsInARow+j-1]+dw[(npnts-NaNsInARow-1)]-dw[npnts-NaNsInARow-2]
			endfor
		endif
	endfor
	
	killwaves pointIsNaN
End

Function /wave interpMatrixOverNaNs(dw, dim)
	wave dw
	variable dim
	
	duplicate /o dw, returnWave
	
	if(dim == 1)
		matrixtranspose returnWave
	endif
	
	variable i
	for(i = 0; i < dimsize(returnWave,1); i += 1)
		duplicate /o/r=(*)(i) returnWave, temp
		redimension /n=(-1,0) temp
		interpolateOverNaNs(temp)
		returnWave[][i] = temp[p]
	endfor
	killwaves temp
	
	if(dim == 1)
		matrixtranspose returnWave
	endif
	
	return returnWave
End

Function /wave textWave2NumWave(tw)
	wave /t tw
	
	make /o/n=(numpnts(tw)) returnWave
	variable i
	for(i = 0; i < numpnts(tw); i += 1)
		returnWave[i] = str2num(tw[i])
	endfor
		
	return returnWave
End

Function /wave calcAvgDistri(d) // returns size distributions
	wave d
	
	make /o/n=(dimsize(d,1),6) $(getwavesdatafolder(d,2)+"avg")
	wave avgd = $(getwavesdatafolder(d,2)+"avg")
		
	variable i
	for(i = 0; i < dimsize(d,1); i += 1)
		duplicate /o/r=(*)(i) d, temp
		sort temp, temp
		extract /o temp, temp2, numtype(temp) != 2
		avgd[i][0] = mean(temp2)
		variable l = numpnts(temp2)
		avgd[i][1] = temp2[l*0.5]
		avgd[i][2] = temp2[l*0.25]
		avgd[i][3] = temp2[l*0.75]
		avgd[i][4] = temp2[l*0.1]
		avgd[i][5] = temp2[l*0.9]		
	endfor
		
	killwaves temp, temp2
	
	return avgd
End

Function /wave NumTimeDist2VolTimeDist(ntdw, bm) // takes num/time image and returns vol/time image
	wave ntdw, bm
	
	duplicate /o ntdw, $(nameofwave(ntdw)+"vol")
	wave vtdw = $(nameofwave(ntdw)+"vol")
	
	vtdw = ntdw * (4/3) * pi * (bm[q]/2)^3
	
	return vtdw
End

Function /wave NumTimeDist2SATimeDist(ntdw, bm) // takes num/time image and returns sa/time image
	wave ntdw, bm
	
	duplicate /o ntdw, $(nameofwave(ntdw)+"SA")
	wave sadw = $(nameofwave(ntdw)+"SA")
	
	sadw = ntdw * 4 *pi * (bm[q]/2)^2
	
	return sadw
End

Function /wave getSizeBE(size)
	wave size
	
	make /o/n=(numpnts(size)+1) sizeBE
	duplicate /o size, logsize
	logsize = log(size)
	sizeBE = 10^(logsize[p-1] + (logsize[p]-logsize[p-1])/2)
	sizeBE[numpnts(sizeBE)] = 10^(logsize[numpnts(sizeBE)-1] + (logsize[numpnts(sizeBE)] - logsize[numpnts(sizeBE)-1])/2)

	make /o/n=(numpnts(size)) diffLogSize = logsize[p+1]-logsize[p]

	wavestats /q diffLogSize

	sizeBE[0] = 10^(logSize[0]-V_avg)
	sizeBE[numpnts(sizeBE)] = 10^(logSize[numpnts(logsize)]+V_avg)

	killwaves diffLogSize, logSize

	return sizeBE
End

Function /wave getLogBM(BE, name)
	wave BE
	string name
	
	make /o/n=(numpnts(BE)-1) $(name+"BM")
	wave BM = $(name+"BM")
	duplicate /o BE, logX
	logX = log(BE)
	BM = 10^(logX[p] + (logX[p+1]-logX[p])/2)
	killwaves logX

	return BM
End

Function diurnalPlot(dw)
	wave dw
	
	ControlInfo T2_Number; variable NumberFlag = V_Value // these are just used to set the label
	ControlInfo T2_Volume; variable VolumeFlag = V_Value
	ControlInfo T2_SA; variable SAFlag = V_Value
		
	variable binSize = 24*60*60/noOfBins
 
	string dwName = NameOfWave(dw) + "_diurnal"
	duplicate /O dw, $dwName
	wave dwd = $dwName
	string twName = NameOfWave(dwd) + "_t"
	duplicate /o dw, $twName
	wave twd = $twName
	Redimension /D twd
	twd = x // makes a wave of times at each point of weave scaline - admittedly a bit of a hack as this function was written for something else.
	
	twd = mod(twd[p], (24*60*60)) // removes all the day components just leaving time
	sort twd, twd, dwd
	
	make /O/N=(noOfBins) myMean, median, boxTop, boxBottom, whiskerTop, whiskerBottom, Xwave, BoxWidth
	
	variable i
	for(i=0; i < (noOfBins); i += 1)
		extract /o dwd, thisBindw, twd > i*binSize && twd < (i+1)*binSize
		extract /o thisBindw, thisBinDwNoNaNs, numtype(thisBinDW) != 2
		
		Sort thisBinDwNoNaNs, thisBinDwNoNaNs// Sort clone
		SetScale/P x 0,1,thisBinDwNoNaNs
		
		median[i] = thisBinDwNoNaNs[(numpnts(thisBinDwNoNaNs)-1)*0.5]
		boxTop[i] = thisBinDwNoNaNs[(numpnts(thisBinDwNoNaNs)-1)*0.75]
		boxBottom[i] = thisBinDwNoNaNs[(numpnts(thisBinDwNoNaNs)-1)*0.25]
		whiskerTop[i] = thisBinDwNoNaNs[(numpnts(thisBinDwNoNaNs)-1)*0.95]
		whiskerBottom[i] = thisBinDwNoNaNs[(numpnts(thisBinDwNoNaNs)-1)*0.05]
		Xwave[i] = ((i+0.5)*(24*60*60))/noOfBins
		SetScale d 0, (NumPnts(Xwave)),"dat", Xwave

		if(numpnts(thisBinDwNoNaNs) > 1)
			wavestats /z/q thisBinDwNoNaNs
			myMean[i] = V_avg
		else
			myMean[i] = NaN
		endif

		KillWaves thisBinDwNoNaNs, thisBinDW
	endfor
	
	string plotName = dwName+"DiurnalSeries"
	doWindow /K $plotName
	fBoxPlot(median, boxTop, boxBottom, whiskerTop, whiskerBottom, XWave, ((24*60*60*0.4)/noOfBins), 0, $"", $"", 0, 0, 0) 	
	doWindow /C $plotName
	appendToGraph myMean vs XWave
	ModifyGraph mode(myMean)=3
	ModifyGraph dateInfo(bottom)={1,0,0}
	Label bottom, "Time of day"
	if(NumberFlag)
		Label left, "Conc (#/l)"
	elseif(VolumeFlag)
		Label left, "Conc (um\S3\M/l)"
	elseif(SAFlag	)
		Label left, "Conc (um\S2\M/l)"
	endif
	
	killwaves twd, dwd
End

Function /WAVE diurnalImagePlot(dw)
	wave dw
 
	duplicate /o dw, tw
	redimension /D/N=-1 tw
	tw = x 
	duplicate /o tw, tod
	tod = mod(tw, 24*60*60)
	make /o/n=(numpnts(tw)) trueWave = 0
	
	make/o/n=(noOfBins, dimsize(dw, 1)) $nameofwave(dw)+"_d"
	wave diurnalMean = $nameofwave(dw)+"_d"
	SetScale /I d, 0, 24*60*60, "dat", diurnalMean
	
	variable i,j
	for(i=0; i < (noOfBins); i += 1)
		trueWave = tod > i*((24*60*60)/noOfBins) && tod < (i+1)*((24*60*60)/noOfBins) ? 1 : 0
		wave thisBin = extractFromMatrix(0, 1, dw, trueWave)
		for(j = 0; j < dimsize(thisBin,1); j += 1)
			duplicate /o/r=(*)(j) thisBin, sizeSlice
			if(numpnts(sizeSlice) > 1)
				wavestats /q sizeSlice
				diurnalMean[i][j] = V_avg
			else
				diurnalMean[i][j] = NaN
			endif
		endfor
	endfor
	
	killwaves tw, tod
	return diurnalMean
End

Function /WAVE sortMatrixByKey(m, key, name)
	wave m, key
	string name
	
	make /o/n=(numpnts(key)) index = p
	duplicate /o m, $name 
	wave returnM = $name
	
	Sort key, index
	returnM = m[index[p]][q]
	
	return returnM
End

Function /WAVE sumRowsWithNaNs(dm, name)
	wave dm
	string name
	
	make /o/n=(dimsize(dm,0)) $name
	wave returnWave = $name
	
	variable i
	for(i = 0; i < numpnts(returnWave); i += 1)
		duplicate /o/r=[i][*] dm, temp
		extract /o temp, temp2, numtype(temp)  != 2
		if(numpnts(temp2) > 0)
			returnWave[i] = sum(temp2)
		else
			returnWave[i] = NaN
		endif
	endfor
	
	killwaves temp, temp2
	return returnWave
End

Function /wave makeHistogram(dw, noBins)
	wave dw
	variable noBins
	
	make /o/n=(noBins-1) $nameofwave(dw)+"_histo"
	wave histo = $nameofwave(dw)+"_histo"
	
	wavestats /q dw
	variable i
	for(i = 0; i < numpnts(histo); i += 1)
		extract /o dw, temp, dw < V_max/noBins*(i+1) && dw > V_max/noBins*i
		histo[i] = numpnts(temp)
	endfor
	
	SetScale /I x, 0, V_max, histo
	
	killwaves temp
	return histo
End

Function /wave changeTimeBases(timeBase1, data1, timeBase2, data2, tol, newName)
	wave timeBase1
	wave data1
	wave timeBase2
	wave data2
	variable tol // in units being used not point number
	string newName
	
	make /O/N=(numpnts(timeBase1)) $newName
	wave data2onBase1 = $newName
	make /O/N=(numpnts(timeBase1)) ptNo, withinTol = 0
	
	multithread ptNo = BinarySearchInterp(timeBase2, timeBase1[p])
	multithread withinTol = numtype(ptNo[p]) == 2 ? NaN : timeBase2[ceil(ptNo[p])]-timeBase2[floor(ptNo[p])] < tol
//	multithread data2onBase1 = withintol[p] && (numtype(ptNo[p]) != 2) ? data2[ptNo[p]] : NaN // don't know why this line doesn't work. It should do the same as the for+if below
	
	variable i
	for(i = 0; i < numpnts(data2onbase1); i += 1)
		if(withintol[i] && (numtype(ptNo[i]) != 2))
			data2onbase1[i] = data2[ptNo[i]]
		else
			data2onbase1[i] = NaN
		endif
	endfor
	
	killwaves ptNo, withinTol
	
	return data2onBase1
End

Function applyBLtoSPD(SPD, BLs, BLtimes)
	wave SPD, BLs, BLtimes

	variable i, Ch1, Ch2, Ch3, thisBLpt
	Ch1 = findDimLabel(SPD, 1, "FL1_280")
	Ch2 = findDimLabel(SPD, 1, "FL2_280")
	Ch3 = findDimLabel(SPD, 1, "FL2_370")
	
	for(i = 0; i < dimsize(SPD, 0); i += 1)
		thisBLpt = binarySearchInterp(BLtimes, SPD[i][0])
		
		SPD[i][Ch1] = SPD[i][Ch1] > BLs[thisBLpt][1] ? SPD[i][Ch1]-BLs[thisBLpt][1] : 0
		SPD[i][Ch2] = SPD[i][Ch2] > BLs[thisBLpt][2] ? SPD[i][Ch2]-BLs[thisBLpt][2] : 0
		SPD[i][Ch3] = SPD[i][Ch3] > BLs[thisBLpt][3] ? SPD[i][Ch3]-BLs[thisBLpt][3] : 0
	endfor
End

Function /D recalcAF(origAF, scat1, scat2, scat2C, scat2M, scat3, scat3C, scat3M, scat4, scat4C, scat4M, offSet, k)
	variable origAF, scat1, scat2, scat2C, scat2M, scat3, scat3C, scat3M, scat4, scat4C, scat4M, offSet, k
	
	variable a, a2, b, b2, c, c2, d, d2, avg, sumSq, AF
	a = max(0,scat1+offSet)
	b = max(0,scat2/scat2M-scat2C+offSet)
	c = max(0,scat3/scat3M-scat3C+offSet)
	d = max(0,scat4/scat4M-scat4C+offSet)
	avg = (a+b+c+d)/4
	
	if(origAF == -1)
		a2 = (avg-a)^2
		b2 = (avg-b)^2
		c2 = (avg-c)^2
		d2 = (avg-d)^2
		sumSq = a2+b2+c2+d2
		AF = k * sqrt(sumSq) / avg
	else
		AF = origAF
	endif
	
	return AF
End

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


