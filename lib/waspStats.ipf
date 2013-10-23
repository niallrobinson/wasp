///////////////////////////////////////////////////////////////////////////////////////////////////
// Wibs Analysis Program v 1.0 alpha                                           
// Stats code												      
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

strconstant logNormalVars = "Size;AF" // "Size;AF;FL1_280;FL2_280;FL2_370;"

Function doPCA()
	wave /t xSPDwaves = root:Panel:xSPDwaves
	wave xSPDwavesSW = root:Panel:xSPDwavesSW
	wave /z SPD = root:SP:SPD
	
	
	if(!waveexists(SPD))
		setdatafolder root:
		Abort "Please load single particle data in the SPD tab first."
	endif
	
	killdatafolder /z root:PCAdata
	newdatafolder /o/s root:PCAdata
	
	Extract /o xSPDwaves, varNames, xSPDwavesSW // used in the biplots later
	
	wave returnWave = extractFromMatrix(1, 1, SPD, xSPDwavesSW)
	duplicate /o returnWave, PCAinput_allToDo; killwaves returnWave
	
	ControlInfo toDoList
	wave thisToDo = $("root:ToDoWaves:"+S_value)
	make /o/n=(dimsize(SPD,0)) timeSW
	variable sizeCol = FindDimLabel(SPD, 1, "Size")
	timeSW = thisToDo(SPD[p][0])(SPD[p][sizeCol]) == 1 ? 1: 0
	wave returnWave = extractFromMatrix(0, 1, PCAinput_allToDo, timeSW)
	duplicate /o returnWave, PCAinput; killwaves returnWave	

	duplicate /o PCAinput, temp
	
	make /o/n=(dimsize(PCAinput,0), dimsize(PCAinput,1)) normedPCAinput
	MatrixOp /o normedPCAinput = SubtractMean(temp, 1)
	duplicate /o normedPCAinput, temp
	MatrixOp /o normedPCAinput = NormalizeRows(temp)
	duplicate /o normedPCAinput, temp
	MatrixOp /o normedPCAinput = NormalizeCols(temp)
	
	PCA  /SCMT/SEVC/RSD/SRMT/SDM/LEIV/CVAR normedPCAinput
	
	Display W_CumulativeVAR
	
	setdatafolder root:
End

#pragma rtGlobals=1		// Use modern global access method.

Function doVarimax()
	String ctrlName


	SetDataFolder root:PCAdata
	Wave/z M_R
	if(WaveExists(M_R)==0)
		Abort "PCA operation did not complete; Missing M_R wave.\r"
		return 0
	endif
	
	variable useNEigenValues=3
	Variable i
	if(useNEigenValues>0)
		Duplicate/O/R=[][0,(useNEigenValues-1)] M_R, VarimaxInputWave
		WM_VarimaxRotation(VarimaxInputWave,1e-7)
		Wave varimaxWave
		Display/K=1
		for(i=0;i<useNEigenValues;i+=1)
			AppendToGraph varimaxWave[][i]
		endfor
		KBColorizeTraces( 0.4, 0.8, 0)
	else
		Abort "Nothing to rotate.\r"
	endif
End

// AGNOV02
// The following function performs a Varimax rotation of inWave subject to the specified epsilon.  
// The algorithm follows the paper by Henry F Kaiser 1959 and involves normalization followed by
// rotation of two vectors at a time.
// The value of epsilon determines convergence.  The algorithm computes the tangent of 4*rotation 
// angle and the value is compared to epsilon.  If it is less than epsilon it is assumed to be essentially
// zero and hence no rotation.

Function WM_VarimaxRotation(inWave,epsilon)
	Wave inWave
	Variable epsilon
	
	Variable rows=DimSize(inWave,0)
	Variable  cols= DimSize(inWave,1)
	
	// start by computing the "communalities"
	 Make/O/N=(cols) communalities
	 Variable i,j,theSum
	 for(i=0;i<cols;i+=1)
	 	theSum=0
	 	for(j=0;j<rows;j+=1)
	 		theSum+=inWave[j][i]*inWave[j][i]
	 	endfor
	 	communalities[i]=sqrt(theSum)
	 endfor
	 
	 Make/O/N=(2,2) rotationMatrix
	 Make/O/N=(rows,2) twoColMatrix
	 Duplicate/O inWave, varimaxWave
	 // normalize the wave
	 for(i=0;i<cols;i+=1)
	 	for(j=0;j<rows;j+=1)
	 		varimaxWave[j][i]/=communalities[i]
	 	endfor
	 endfor
	 
	 // now start rotating vectors:
	 Variable convergenceLevel=cols*(cols-1)/2
	 Variable rotation,col1,col2
	 Variable rotationCount=0
	 do
	 	for(col1=0;col1<cols-1;col1+=1)
	 		for(col2=col1+1;col2<cols;col2+=1)
				rotation=doOneVarimaxRotation(varimaxWave,rotationMatrix,twoColMatrix,col1,col2,rows,epsilon)
				rotationCount+=1
				if(rotation)
					convergenceLevel=cols*(cols-1)/2
				else
					convergenceLevel-=1
					if(convergenceLevel<=0)
						 for(i=0;i<cols;i+=1)
						 	for(j=0;j<rows;j+=1)
						 		varimaxWave[j][i]*=communalities[i]
						 	endfor
						 endfor
						KillWaves/Z rotationMatrix,twoColMatrix,communalities,M_Product
						printf "%d rotations\r",rotationCount
						return 0
					endif
				endif
			endfor
		endfor
	while(convergenceLevel>0)

	KillWaves/Z rotationMatrix,twoColMatrix,communalities,M_Product
	printf "%d rotations\r",rotationCount
End

// this function is being called by WM_VarimaxRotation(); it has no use on its own.
Function  doOneVarimaxRotation(norWave,rotationMatrix,twoColMatrix,col1,col2,rows,epsilon)
	wave norWave,rotationMatrix,twoColMatrix
	Variable col1,col2,rows,epsilon
	
	Variable A,B,C,D
	Variable i,xx,yy
	Variable sqrt2=sqrt(2)/2
	
	A=0
	B=0
	C=0
	D=0
	
	for(i=0;i<rows;i+=1)
		xx=norWave[i][col1]
		yy=norWave[i][col2]
		twoColMatrix[i][0]=xx
		twoColMatrix[i][1]=yy
		A+=(xx-yy)*(xx+yy)
		B+=2*xx*yy
		C+=xx^4-6.*xx^2*yy^2+yy^4
		D+=4*xx^3*yy-4*yy^3*xx
	endfor
	
	Variable numerator,denominator,absNumerator,absDenominator
	numerator=D-2*A*B/rows
	denominator=C-(A*A-B*B)/rows
	absNumerator=abs(numerator)
	absDenominator=abs(denominator)
	
	Variable cs4t,sn4t,cs2t,sn2t,tan4t,ctn4t
	
	// handle here all the cases :
	if(absNumerator<absDenominator)
		tan4t=absNumerator/absDenominator
		if(tan4t<epsilon)
			return 0								// no rotation
		endif
		cs4t=1/sqrt(1+tan4t*tan4t)
		sn4t=tan4t*cs4t
		
	elseif(absNumerator>absDenominator)
		ctn4t=absDenominator/absNumerator
		if(ctn4t<epsilon)							// paper sec 9
			sn4t=1
			cs4t=0
		else
			sn4t=1/sqrt(1+ctn4t*ctn4t)
			cs4t=ctn4t*sn4t
		endif
	elseif(absNumerator==absDenominator)
		if(absNumerator==0)
			return 0;								// undefined so we do not rotate.
		else
			sn4t=sqrt2
			cs4t=sqrt2
		endif
	endif
	
	// at this point we should have sn4t and cs4t
	cs2t=sqrt((1+cs4t)/2)
	sn2t=sn4t/(2*cs2t)
	
	Variable cst=sqrt((1+cs2t)/2)
	Variable snt=sn2t/(2*cst)
	
	// now converting from t to the rotation angle phi based on the signs of the numerator and denominator
	Variable csphi,snphi
	
	if(denominator<0)
		csphi=sqrt2*(cst+snt)
		snphi=sqrt2*(cst-snt)
	else
		csphi=cst
		snphi=snt
	endif
	
	if(numerator<0)
		snphi=-snt
	endif
	
	// perform the rotation using matrix multiplication
	rotationMatrix={{csphi,snphi},{-snphi,csphi}}
	MatrixMultiply twoColMatrix,rotationMatrix
	// now write the rotation back into the wave
	Wave M_Product
	for(i=0;i<rows;i+=1)
		norWave[i][col1]=M_Product[i][0]
		norWave[i][col2]=M_Product[i][1]
	endfor
	return 1
End

////////////////////////////////////////////////////////////////////////////////////// cluster analysis /////////////////////////////////////////////////////////////////////////////////////////

constant maxdim = 46335 // maximum 2d matrix side length allowed by Igor

Function  /wave prepCAinput()
	
	variable i,j,k
	
	NVAR loadProg = root:Panel:loadProg
	loadProg = 0
	controlUpdate TPB_loadProg

	wave /t xSPDwaves = root:Panel:xSPDwaves
	wave xSPDwavesSW = root:Panel:xSPDwavesSW
	wave /z SPD = root:SP:SPD
	if(!waveexists(SPD))
		setdatafolder root:
		Abort "Please load single particle data first from the SPD tab."
	endif
	extract /o xSPDwaves, varNames, xSPDwavesSW
	NVAR minSizeThresh = root:Panel:minSizeThresh

	variable sizeColNum = FindDimLabel(SPD, 1, "Size")
	variable SumScatColNum = FindDimLabel(SPD, 1, "Sum_scat")
	variable FL2ScatColNum = FindDimLabel(SPD, 1, "FL2_scat")
	variable AFColNum = FindDimLabel(SPD, 1, "AF")
	variable FL1ColNum = FindDimLabel(SPD, 1, "FL1_280")
	variable FL2ColNum = FindDimLabel(SPD, 1, "FL2_280")
	variable FL3ColNum = FindDimLabel(SPD, 1, "FL2_370")
	variable Pwr280ColNum = FindDimLabel(SPD, 1, "Pwr_280")
	variable Pwr370ColNum = FindDimLabel(SPD, 1, "Pwr_370")

	// only SPD data in todo wave
	ControlInfo toDoList
	wave thisToDo = $("root:ToDoWaves:"+S_value)
	make /free/o/n=(dimsize(SPD,0)) timeSW
	timeSW = thisToDo(SPD[p][0])(SPD[p][sizeColNum])
	wave returnWave = extractFromMatrix(0, 1, SPD, timeSW)
	duplicate /o SPD, rawCAinput // preserves column labels
	redimension /n=(dimsize(returnWave,0),-1) rawCAinput
	rawCAinput = returnWave
	
	// QA spd data	
	make /o/free/n=(dimsize(rawCAinput,0)) extractTrue = 0
	extractTrue = rawCAinput[p][sizeColNum] > minSizeThresh && rawCAinput[p][AFColNum] != -1 && rawCAinput[p][Pwr280ColNum] > 100 && rawCAinput[p][Pwr370ColNum] > 100 ? 1 : 0
	wave returnWave = extractFromMatrix(0, 1, rawCAinput, extractTrue)
	redimension /n=(dimsize(returnWave,0),-1) rawCAinput
	rawCAinput = returnWave
	
	// remove blacklisted data
	wave blacklist = root:panel:blacklist
	make /free/o/n=(dimsize(rawCAinput,0)) extractTrue = 0
	extractTrue = !blacklist(rawCAinput[p][0])
	wave returnwave = extractFromMatrix(0,1,rawCAinput, extractTrue)
	redimension /n=(dimsize(returnwave,0),-1) rawCAinput
	rawCAinput = returnWave
	
	// find all saturated fl measurements before applying the baseline. also make total fl (not including saturated values
	make /o/free/n=(dimsize(rawCAinput,0),3) saturated = 0
	saturated[][0] = rawCAinput[p][FL1ColNum] == satVal
	saturated[][1] = rawCAinput[p][FL2ColNum] == satVal
	saturated[][2] = rawCAinput[p][FL3ColNum] == satVal

	// normalise to scattering - also save an un-normalised version to use in plotting
	duplicate /o rawCAinput, normedCAinput
	controlInfo T4_normaliseCA
	make /free/o/t normaliseTheseTags = {"FL"} // this quantities with these words in the heading by the square of the size.
	if(V_Value)
		for(i = 0; i < dimsize(normedCAinput,1); i += 1)
			string thisColName = GetDimLabel(normedCAinput, 1, i)
			for(j = 0; j < numpnts(normaliseTheseTags); j += 1)
				if(strsearch(thisColName, normaliseTheseTags[j], 0) != -1)
					for(k = 0; k < dimsize(normedCAinput,0); k += 1)
						if(!saturated[k][0] || !saturated[k][1] || !saturated[k][2])
							normedCAinput[k][i] /= rawCAinput[k][FL2ScatColNum] // this needs to be tested empirically
						endif
					endfor
				endif
			endfor
		endfor
	endif
	
		// extract columns chosen for analysis
	make /o/n=(dimsize(rawCAinput,0), sum(xSPDwavesSW)) returnWave
	FastExtractFromMatrix(1, 1, rawCAinput, xSPDwavesSW, returnWave)
	duplicate /o returnWave, rawCAinput
	make /o/n=(dimsize(normedCAinput,0), sum(xSPDwavesSW)) returnWave
	FastExtractFromMatrix(1, 1, normedCAinput, xSPDwavesSW, returnWave)
	duplicate /o returnWave, normedCAinput
	
	// normalise to total fluorescence of chosen channels (if there is no saturation in any channel) - also save an un-normalised version to use in plotting
	controlInfo T4_normaliseCA
	if(V_Value)
		variable FL1_280ColNum = finddimlabel(rawCAinput, 1, "FL1_280")
		variable FL2_280ColNum = finddimlabel(rawCAinput, 1, "FL2_280")
		if(FL1_280ColNum == -2 || FL2_280ColNum == -2)
			Abort "FL1_280 and FL2_280 must be chosen to use normalisation"
		endif
		rawCAinput[][FL1_280ColNum] /= rawCAinput[p][FL2_280ColNum]
		DeletePoints /M=1 rawCAinput[FL2_280ColNum], 1, rawCAinput
		SetDimLabel 1, FL1_280ColNum, FL1_280toFL2_280, rawCAinput 
	endif

	variable removedCounter = 0, type
	for(i = 0; i < dimsize(normedCAinput,0); i += 1)
		for(j = 0; j < dimsize(normedCAinput, 1); j += 1)
			type = numtype(normedCAinput[i][j])
			if(type == 1 || type == 2)
				deletepoints /M=0 i, 1, normedCAinput, rawCAinput
				i -= 1
				removedCounter += 1
			endif
		endfor
	endfor
	
	// log data if its a log normal distribution. Checks a list of log normal variables in constant
	for(i = 0; i < dimsize(normedCAinput,1); i += 1)
		if(strsearch(logNormalVars,  getdimlabel(normedCAinput, 1, i), 0) != -1) // if the col name is one of the log normal waves
			normedCAinput[][i] = numtype(log(normedCAinput[p][i])) != 1 ? log(normedCAinput[p][i]) : 0
		endif
	endfor
	
	make /n=(dimsize(normedCAinput, 1))/o CAinputSdevs
	
	// normalises data to same magnetude and variance
	for(i = 0; i < dimsize(normedCAinput,1); i += 1)
		duplicate /free/o/r=(*)(i) normedCAinput, temp
		wavestats /q temp	
		make /o/n=(numpnts(temp)) temp2
		temp2 = (temp-V_avg)/V_sdev
		normedCAinput[][i] = temp2[p]
		CAinputSdevs[i] = V_sdev
	endfor
	
	print num2str(removedCounter) + " measurements were removed"
	
	duplicate /o normedCAinput, CAinput
	killwaves /z normedCAinput, returnWave

	MatrixTranspose CAinput // cluster analysis expects a matrix of different memebers (particles) per column
	matrixtranspose rawCAinput // just so its all consistant

	return CAinput
End

Function groupAvgCA(CAinput) // performs group average cluster analysis (where distance is calculated as average of all members of clusters), accepting a matrix of items (columns) and variables (rows)
 	wave CAinput
 	
	// start timer
 	variable timeTaken, timerRefNum
 	timerRefNum = StartMSTimer

	//newdatafolder /s/o root:CAdata:centroid:
	NVAR loadProg = root:Panel:loadProg
	
	make /i/o/n=(dimsize(CAinput,1), dimsize(CAinput,1)) clusterNos = q // clusterNos stores which particles are members of which cluster as a fn of iteration - members of a greater cluster number are changed to the lesser when they agglomorate
	make /i/o/n=(dimsize(CAinput,1)) thisClusterNames = p // stores the number name of each of the averaged clusters for this iteration
	
	variable i,j, k,a
	
	// construct matrix of distances between all members
	make /o/n=(dimsize(CAinput, 1), dimsize(CAinput,1)) dMat = NaN
	make /o/n=(dimsize(CAinput, 0)) temp

	for(i = 0; i < dimsize(CAinput, 1); i += 1)
		for(j = 0; j < i; j += 1) //  This means that it is suitably sparse i.e. we know it will be symmetric so there is no point this halves the calc
			temp = (CAinput[p][i] - CAinput[p][j])^2
			dMat[i][j] = sqrt(sum(temp)) // euclidian distance between the two points
		endfor
	endfor
	
	variable minPos, dimN = dimsize(dMat, 0), row, col
	make /u/i/o/n=(dimN) clustermap
	duplicate /o dMat, thisdMat
	wavestats /q /m=2 dMat
	row = V_minRowLoc
	col = V_minColLoc
	for(i = 0; i < dimsize(CAinput,1)-1; i += 1)
		clusterNos[i+1][] = clusterNos[i][q] == thisClusterNames[row] ? thisClusterNames[col] : clusterNos[i][q]
		DeletePoints  row, 1, thisClusterNames // remove the higher cluster name as it is agglomorated to the lower one and no longer exist	
		
		// find nearest cluster
		clustermap = findclust(thisclusternames, clusternos[i+1][p])
		minPos = cluster_proc(clusterMap, dMat)
		col = floor(minPos/dimN)
		row = mod(minPos, dimN)
		
		loadProg = (i/dimsize(CAinput,1))*100
		controlUpdate TPB_loadProg
	endfor
	
	// stop timer
	variable processors = ThreadProcessorCount
	timeTaken = StopMSTimer(timerRefNum)
	print "On a machine using", processors,"cores, group average cluster analysis of",dimsize(CAinput,1)," particles took",timeTaken/1000000,"seconds."
	
End

Function /wave calcDmat(dMat, clusterNos, clusterNames, iteration)
	wave dMat, clusterNos, clusterNames
	variable iteration
	
	variable i, j, n, m
	n=dimsize(dmat,0)
	m=numpnts(clusternames)
	
	make /o/n=(m, m) thisDmat
	make /o/n=(m, m)/i thisDmat_n
	
	fastop thisdmat = (0)
	fastop thisdmat_n = (0)
	make /u/i/o/n=(n) clustermap = findclust(clusternames, clusternos[iteration][p])
	variable p1, p2
	for (i = 0; i < n; i += 1)
		p1 = clustermap[i]
		for (j = 0; j < i; j+=1)
			p2 = clustermap[j]
			if(p1 > p2)
				thisdmat[p1][p2] += dmat[i][j]
				thisdmat_n[p1][p2] += 1
			endif
		endfor
	endfor
	
	matrixop /o thisdmat = thisdmat/thisdmat_n
	


	return thisDmat	
End

function findclust(wav,val)
	wave wav
	variable val
	
	findvalue /i=(val) wav // If wav can be made as an integer wave, you can use /i on findvalue, which will be quicker still
	return v_value
end				

Function centroidCA(CAinput) // performs centroid cluster analysis (where distance is calculated as between the mean of clusters), accepting a matrix of items (columns) and variables (rows)
	wave CAinput
	
	// start timer
 	variable timeTaken, timerRefNum
 	timerRefNum = StartMSTimer
	
	NVAR loadProg = root:Panel:loadProg

	make /o/n=(dimsize(CAinput,1), dimsize(CAinput,1)) clusterNos = q // clusterNos stores which particles are members of which cluster as a fn of iteration - members of a greater cluster number are changed to the lesser when they agglomorate
	duplicate /o CAinput, lastIteration // this stores the average clusters from the last iteration (first time it is just all the single particle clusters)
	make /o/n=(dimsize(CAinput,1)) noOfMembers = 1 // stores the number of consituent particles for the current iteration. Allows efficient averageing
	make /o/n=(dimsize(CAinput,1)) thisClusterNames = p // stores the number name of each of the averaged clusters for this iteration
	make /o/n=2 nearestClustersNames
	make /o/n=(dimsize(CAinput,1)) RMS, R2, majClusters = 0 // these are the scores used for assesing the number of clusters to retain
	variable majClThresh = 0.03*dimsize(CAinput,1) // used for determining when a cluster becomes "major" i.e. contains more than 3% of objects
	
	variable i
	for(i = 0; i < dimsize(CAinput,1); i += 1)
		wave nearestClustersCols = findNearestClusters(lastIteration) // this is column number NOT cluster name
		wave thisIteration = agglomorateNearestClusters(nearestClustersCols, lastIteration, noOfMembers) // agglomorate these two columns
		nearestClustersNames = {thisClusterNames[nearestClustersCols[0]], thisClusterNames[nearestClustersCols[1]]} // work out the name number fo the two nearest clusters
		clusterNos[i+1][] = clusterNos[i][q] == nearestClustersNames[1] ? nearestClustersNames[0] : clusterNos[i][q] // populate row of cluster members with new names for this iteration
		noOfMembers = p == nearestClustersCols[0] ? noOfMembers[nearestClustersCols[0]] + noOfMembers[nearestClustersCols[1]] : noOfMembers // add the numbere of members in each cluster and store in the lower cluster slot
		DeletePoints nearestClustersCols[1], 1, noOfMembers // remove the point that was in the higher cluster slot
		DeletePoints nearestClustersCols[1], 1, thisClusterNames // remove the higher cluster name as it is agglomorated to the lower one and no longer exist
				
		extract /o noOfMembers, temp, noOfMembers > majClThresh
		majClusters[i] = numpnts(temp); killwaves temp
		
		RMS[i] = getThisRMSdist(thisIteration)
		
		duplicate /o thisIteration, lastIteration
		
		loadProg = (i/dimsize(CAinput,1))*100

		controlUpdate TPB_loadProg
	endfor
	
	RMS /= RMS[0]
	
	timeTaken = StopMSTimer(timerRefNum)
	variable processors = ThreadProcessorCount
	print "On a machine using", processors,"cores, centroid cluster analysis of",dimsize(CAinput,1)," particles took",timeTaken/1000000,"seconds."
	
	setdatafolder root:
End


Function /D getThisRMSdist(thisIteration)
	wave thisIteration
	
	variable n = dimsize(thisIteration,1)
	variable k = 2
	variable combinations = factorial(n)/factorial(k)/factorial(n-k)
	if(numtype(combinations) == 2 || numtype(combinations) == 1) // only one cluster
		return NaN
	endif
	make /o/n=(combinations) dist
	make /o/n=(dimsize(thisIteration,0)) holder
	
	variable i, j, z
	for(i = 0; i < dimsize(thisIteration,1); i += 1)
		for(j = 0; j < dimsize(thisIteration,1); j += 1)
			if(i != j)
				holder = thisIteration[p][i] - thisIteration[p][j]
				holder = holder^2
				dist[z] = sqrt(sum(holder))
				z += 1
			endif
		endfor	
	endfor
	
	wavestats /q dist
	
	return V_rms
End

Function /wave agglomorateNearestClusters(nearestClusters, lastIteration, numberOfMembers)
	wave nearestClusters, lastIteration, numberOfMembers // nearestClusters is cluster cols
	
	make /o/n=(dimsize(lastIteration,0), dimsize(lastIteration,1)-1) thisIteration // stores the average clusters after the agglomoration for this iteration has occured
	variable clA = nearestClusters[0]
	variable clB = nearestClusters[1]

	variable i, j = 0
	for(i = 0; i < numpnts(numberOfMembers); i += 1)
		if(i != clA && i != clB)
			thisIteration[][j] = lastIteration[p][i]
			j += 1
		elseif(i == clA)
			thisIteration[][j] = (lastIteration[p][clA]*numberOfMembers[clA] + lastIteration[p][clB]*numberOfMembers[clB])/(numberOfMembers[clA] + numberOfMembers[clB])
			j += 1
		elseif(i == clB)
			// do nothing
		endif
	endfor
	
	return thisIteration
End

Function /Wave findNearestClusters(lastIteration)
	wave lastIteration
	
	variable smallestDistance = inf
	make /o/n=2 nearestClusters
	variable i, j, distance
	for(i = 0; i < dimsize(lastIteration,1); i += 1)
		for(j = 0; j < dimsize(lastIteration, 1); j += 1)
			duplicate /o/r=(*)(i) lastIteration, A
			duplicate /o/r=(*)(j) lastIteration, B
			distance = groupAverageDistance(A, B)
			if(i != j && distance < smallestDistance)
				smallestDistance = distance
				nearestClusters = {i, j}
			endif
		endfor
	endfor
	
	return nearestClusters
End

Function /D groupAverageDistance(A, B)
	wave A, B
	
	make /o/n=(numpnts(A)) squaredDiff = (A-B)^2
	
	return sum(squaredDiff)
End

Function /wave  findAvgClusterFit(noOfClusters, thisClusterName, CAinput, clusterNos, name) // finds cluster centroid and sdevs using gaussian fit
	variable noOfClusters, thisClusterName
	wave CAinput, clusterNos
	string name
	
	controlInfo T4_withPlots; variable withPlots = V_Value
	variable errorFlag
	
	make /o/n=(dimsize(CAinput,1)) extractTrue = 0
	variable solutionRow = dimsize(clusterNos,0)-noOfClusters
	extractTrue = clusterNos[solutionRow][p] == thisClusterName ? 1 : 0
	
	make /o/n=(dimsize(CAinput,0),sum(extractTrue)) thisClusterMembers // don't use extractFromMatrix fn here to save cost i.e. it doesn't need to be transposed
	variable i, j, useFit
	for(i = 0; i < numpnts(extractTrue); i += 1)
		if(extractTrue[i] == 1)
			thisClusterMembers[][j] = CAinput[p][i]
			j += 1
		endif
	endfor
	
	for(i = 0; i < dimsize(thisClusterMembers,0); i += 1)	
		errorFlag = 0 // flags if histogram or fit error
	
		duplicate /free/o/r=(i)(*) thisClusterMembers, thisVariable
		make /o/n=(dimsize(thisClusterMembers,0),2) $name /wave=clusterAvg // mean,stdev
		
		if(strsearch(logNormalVars, getdimlabel(CAinput, 0, i),0) != -1) // if a log normally distributed variable
			thisVariable = log(thisVariable)
		endif
	
		matrixtranspose thisVariable; redimension /n=-1 thisVariable
		
		if(withPlots)
			make /o/n=70 thisVariableHisto // arbitraty n as /B=3 rescales it
			Histogram/B=3 thisVariable, thisVariableHisto
		
			variable V_fitError // this means that the procedure can handle it if the fit doesn't converge. It also acts as a flag if a mode doesn't form in the histogram
			if(numpnts(thisVariableHisto) > 3)
				wavestats /q thisVariable
				Make/D/N=3/O W_coef
				W_coef[0] = {V_sdev, V_avg,V_npnts}
				FuncFit/W=2/Q/NTHR=0 standardGauss W_coef  thisVariableHisto /D 
				errorFlag = V_fitError
			else 
				errorFlag = 1 // histo failed
			endif
			
			if(!errorFlag) // if no errors
				display /N=histo thisVariableHisto
				wave fit_thisVariableHisto
				appendtograph /W=histo fit_thisVariableHisto
				TextBox/C/N=text0/A=MC name
				DoAlert 1, "Use fit?"
				useFit = V_flag == 1
				DoWindow  /K histo
			else // if fit error
				useFit = 0
			endif
		else
			useFit = 0
		endif
			
		if(useFit ==  1)
			wave W_coef
			if(strsearch(logNormalVars, getdimlabel(CAinput, 0, i),0) != -1) // if a log normally distributed variable
				clusterAvg[i][0] = max(10^W_coef[1], 0)
				clusterAvg[i][1] = 10^W_coef[0] // gives RSD
			else 
				clusterAvg[i][0] = max(W_coef[1], 0)
				clusterAvg[i][1] = W_coef[0]/W_coef[1] // to get RSD
			endif
		elseif(useFit == 0) // if user doesn't use the fit, then just use wavestats for the average, which should give big stdev and effectively downweight that variable
			wavestats /q thisVariable
			if(strsearch(logNormalVars, getdimlabel(CAinput, 0, i),0) != -1) // if a log normally distributed variable
				clusterAvg[i][0] = 10^V_avg
				clusterAvg[i][1] = 10^V_sdev
			else // if user doesn't use the fit, then just use wavestats for the average, which should give big stdev and effectively downweight that variable
				clusterAvg[i][0] = V_avg
				clusterAvg[i][1] = V_sdev/V_avg
			endif
		endif

	endfor
		
	return clusterAvg
End

Function standardGauss(w,x) : FitFunc
	Wave w
	Variable x

	return w[2](1/(w[0]*sqrt(2*pi)))*exp(-((x-w[1])^2)/(2*w[0]^2))
End

Function viewClusters(clusterNos, CAinput, solNo, varNames)
	wave clusterNos, CAinput
	variable solNo
	wave /t varNames
	
	controlInfo T4_withPlots; variable withPlots = V_Value
	
	make /o/n=(numpnts(varNames)+2, solNo,2) means
	duplicate /o/r=(dimsize(clusterNos,0)-solNo)(*) clusterNos, thisSolClusterNos
	sort thisSolClusterNos, thisSolClusterNos
	variable thisClusterName = thisSolClusterNos[0]
	variable i, j
	string name = ""

	for(i = 1; i <= solNo; i += 1) // as cluster number starts counting from one
		name = "Cluster" + num2str(i)
		wave thisAvg = findAvgClusterFit(solNo, thisClusterName, CAinput, clusterNos, name) // changed from findAvgCluster() so that it now uses a gauss fit
		extract /o thisSolClusterNos, lastSolClusterNos, thisSolClusterNos == thisClusterName
		extract /o thisSolClusterNos, thisSolClusterNos, thisSolClusterNos != thisClusterName
		thisClusterName = thisSolClusterNos[0]
		
		for(j = 0; j < dimsize(thisAvg,0); j += 1)
			SetDimLabel 0, j, $varNames[j], thisAvg  
		endfor
		
		means[2,*][i-1][0] = thisAvg[p-2][0]
		means[1][i-1][0] = numpnts(lastSolClusterNos)
		means[2,*][i-1][1] = thisAvg[p-2][1]
		means[1][i-1][1] = sqrt(numpnts(lastSolClusterNos))
	endfor
	
	duplicate /free/o/r=(1)(*)(0) means, npnts
	redimension /n=(-1,-1) npnts
	matrixtranspose npnts
	make /o/n=(numpnts(npnts)) clusterName = p+1
	sort /r npnts, clusterName
	duplicate /free means, temp
	temp = means[p][clusterName[q]-1][r]
	means = temp
	matrixtranspose clusterName
	means[0][][] = clusterName[q]
	
	make /o/t/n=(numpnts(varNames)+2) rowNames
	rowNames[0] = "Name"
	rowNames[1] = "#"
	rowNames[2,*] = varNames[p-2]
	edit rowNames, means
End

Function plotCAinput()

	controlInfo T4_centroid
	variable centroidFlag = V_value
	controlInfo T4_grpavg
	variable grpavgFlag = V_value
	controlInfo T4_FP
	variable FPFlag = V_value
	
	if(!datafolderexists("root:CAdata:"))
		newdatafolder /o/s root:CAdata
	else
		setdatafolder root:CAdata
	endif
	
	if(centroidFlag)
		newdatafolder /o/s root:CAdata:Centroid
		wave CAinput = prepCAinput()
	elseif(grpavgFlag)
		newdatafolder /o/s root:CAdata:GrpAvg
		wave CAinput = prepCAinput()
	elseif(FPFlag)
		newdatafolder /o/s root:CAdata:FP
		wave CAinput = prepCAinput()
	else
		Abort
	endif
	
	// make plots
	display
	ModifyGraph margin(left)=100
	ModifyGraph margin(bottom)=100
	
	variable i,j,k = 0
	variable range = dimsize(CAinput, 0)
	string leftAx, bottomAx
	for(i = 0; i < range; i += 1)
		for(j = 0; j < range; j += 1)
			if(i != j)
				leftAx = "L"+num2str(i)//+num2str(j)
				bottomAx = "B"+num2str(j)//+num2str(j)
				appendtograph /L=$leftAx /B=$bottomAx CAinput[i][] vs CAinput[j][]
				ModifyGraph freePos($bottomAx)=20
				ModifyGraph freePos($leftAx)=20
				ModifyGraph mode[k] = 2
				k += 1
			else
				leftAx = "L"+num2str(i)+num2str(j)
				bottomAx = "B"+num2str(i)+num2str(j)
				duplicate /o/r=(i)(*) CAinput, $"H"+num2str(i)
				wave thisData = $"H"+num2str(i)
				Make/N=46/O  $nameofwave(thisData)+"_histo" /wave=thisHisto
				Histogram/B=4 thisData, thisHisto
				appendtograph /L=$leftAx /B=$bottomAx thisHisto
				ModifyGraph mode[k] = 5
				ModifyGraph freePos($bottomAx)={0,$leftAx}
				ModifyGraph freePos($leftAx)={0,$bottomAx}
				k += 1
			endif
			ModifyGraph axisEnab($leftAx)={i/range, (i+1)/range}
			ModifyGraph axisEnab($bottomAx)={j/range, (j+1)/range}
			if(i == 0)
				Label $bottomAx, GetDimLabel(CAinput, 0, j) 
				ModifyGraph lblPos($bottomAx)=60
			endif
			if(j == 0)
				Label $leftAx, GetDimLabel(CAinput, 0, i) 
				ModifyGraph lblPos($leftAx)=60
			endif			
			
		endfor			
	endfor
	
	setdatafolder root:
End

Function FPCA(CAinput) // farthest point cluster analysis
	wave CAinput
	
	// start timer
 	variable timeTaken, timerRefNum
 	timerRefNum = StartMSTimer
	
	matrixtranspose CAinput // FPClustering takes its input matrix in a different orientation from the home made routines

	nvar loadProg = root:Panel:loadProg
	variable i
	variable n = dimsize(CAinput,0)
	make /o/n=(n,n) clusterNos = NaN
	for(i = 0; i <= n; i += 1) 
		FPClustering /CAC/MAXC=(i+1)/Q CAinput
		
		wave W_FPClusterIndex
		clusterNos[n-i][] = W_FPClusterIndex[q]
		
		loadProg = i/n*100
		controlUpdate TPB_loadProg
	endfor
	
	matrixtranspose CAinput // return to its origional orientation
	
	timeTaken = StopMSTimer(timerRefNum)
	variable processors = ThreadProcessorCount
	print "On a machine using", processors,"cores, furthest point cluster analysis of",dimsize(CAinput,1)," particles took",timeTaken/1000000,"seconds."
	
	setdatafolder root:
End

Function calcCAstats(clusterNos, normedCAinput)
	wave clusterNos, normedCAinput
	
	make /o/n=(dimsize(clusterNos,0)) noOfClusters = dimsize(clusterNos,0)-p
	wave Rsq = getRsqstat(clusterNos, normedCAinput)
	wave Npc = noOfClustersGt3pc(clusterNos)
	wave N = noOfMajorClusters(clusterNos)
	wave RMS = RMSClusterDist(clusterNos, normedCAinput)
	
	Display /W=(35.25,42.5,1131,447.5) Rsq vs noOfClusters
	AppendToGraph/R N vs noOfClusters
	AppendToGraph/R=r2 RMS vs noOfClusters
	ModifyGraph margin(right)=142
	ModifyGraph lSize=2
	ModifyGraph rgb(Rsq)=(0,0,0),rgb(N)=(0,0,52224)
	ModifyGraph fStyle=1
	ModifyGraph axThick=2
	ModifyGraph lblPos(right)=42,lblPos(r2)=52
	ModifyGraph lblLatPos(right)=-6,lblLatPos(r2)=-11
	ModifyGraph freePos(r2)=61.5
	Label left "normed R\\S2\\M"
	Label bottom "No. of clusters"
	Label right "No of major clusters"
	Label r2 "RMS"
	SetAxis/R bottom *,2
	Legend/C/N=text0/J/A=MC/X=21.10/Y=-32.68 "\\f01\\s(Rsq) R\\S2\\M\r\\s(RMS) RMS\r\\s(N) No. of major clusters"
End


Function /wave RMSClusterDist(clusterNos, normedCAinput)
	wave clusterNos, normedCAinput
	
	nvar loadProg = root:Panel:loadProg
	make /o/n=(dimsize(clusterNos,0)) RMS
	make /o/n=(dimsize(normedCAinput,1)) thisClustTrue, otherClustTrue, done
	make /o/n=(dimsize(normedCAinput, 0)) thisMeas, thatMeas
	
	variable i, j, thisClName, n, k, l, thisDist, runningTotal, counter
	for(i  = 0; i < numpnts(RMS); i += 1) // loop round solution number
		duplicate /o/r=[i](*) clusterNos, thisSolution, sortedSolutions
		sort sortedSolutions, sortedSolutions
		
		n = dimsize(clusterNos,0)-i
		make /o/n=(dimsize(normedCAinput,0), n) clustAvgs
		
		thisClName = sortedSolutions[0]
		thisClustTrue = thisSolution == thisClName
		j  = 0
		runningTotal = 0
		counter = 0
		done = 0
		do
			wave temp = extractFromMatrix(1, 1, normedCAinput, thisClustTrue)
			duplicate /o temp, thisClusterData
			otherClustTrue = !thisClustTrue && !done
			wave otherClusterData = extractFromMatrix(1, 1, normedCAinput, otherClustTrue)
			
			for(k = 0;  k < dimsize(thisClusterData, 1); k += 1)
				thisMeas = thisClusterData[p][k]
				for(l = 0; l < dimsize(otherClusterData,1); l += 1)
					thatMeas = otherClusterData[p][l]
					thisDist = euclidDist(thisMeas, thatMeas) 
					runningTotal += thisDist^2
					counter += 1
				endfor
			endfor
									
			extract /o sortedSolutions, sortedSolutions, sortedSolutions != sortedSolutions[0]
			thisClName = sortedSolutions[0]
			done = thisClustTrue == 1 && !done ? 1 : done
			thisClustTrue = thisSolution == thisClName && !done
			
			j += 1
		while(sum(thisClustTrue) != 0)

		loadProg = i/numpnts(Rsq)*100
		controlupdate TPB_loadProg
	
		RMS[i] = sqrt(runningTotal/counter)	
	endfor
	
	return RMS
End


Function /D SSW(CAdata, clusterNos)
	wave CAdata, clusterNos
	
	wave clusterNames = getClusterNameList(clusterNos)
	make /o/n=(dimsize(CAdata,1)) extractTrue
	variable i, j, SSW = 0
	for(i = 0; i < numpnts(ClusterNames); i += 1)
		extractTrue = clusterNos == clusterNames[i]
		wave thisCl = extractFromMatrix(1, 1, CAdata, extractTrue)
		make /o/n=(dimsize(CAdata,0)) ClBar, thisPt
		matrixop /o ClBar = sumrows(thisCl)
		ClBar /= dimsize(thisCl,1)
		make /o/n=(dimsize(thisCl,1))/free sqDist
		for(j = 0; j < numpnts(sqDist); j += 1)
			thisPt = thisCl[p][j]
			sqDist[j] = euclidDist(thisPt, ClBar)^2
		endfor
		SSW += sum(sqDist)
	endfor
	
	return SSW
End

Function /D SST(CAdata)
	wave CAdata
	
	make /n=(dimsize(CAdata,0))/o/free CAdataAvg, thisPt
	matrixop /o CAdataAvg = sumrows(CAdata)
	CAdataAvg /= dimsize(CAdata,1)
	variable SST = 0, i
	for(i = 0; i < dimsize(CAdata,1); i += 1)
		thisPt = CAdata[p][i]
		SST += euclidDist(thisPt, CAdataAvg)^2
	endfor
	
	return SST
End

Function /wave getClusterNameList(clusters)
	wave clusters
	
	duplicate /o clusters, cls
	sort cls, cls
	make /o/n=1 clusterNames
	clusterNames[0] = cls[0]
	do
		extract /free/o cls, temp, cls != cls[0]
		duplicate /o temp, cls
		if(numpnts(cls) > 0)
			insertpoints inf, 1, clusterNames
			clusterNames[inf] = cls[0]
		else
			break
		endif
	while(1)
	
	return clusterNames
End

Function /wave centroidRMSClusterDist(clusterNos, normedCAinput)
	wave clusterNos, normedCAinput
	
	nvar loadProg = root:Panel:loadProg
	make /o/n=(dimsize(clusterNos,0)) RMS
	make /o/n=(dimsize(normedCAinput,1)) extractTrue
	
	variable i, j, thisClName, n, k, l, thisDist
	for(i  = 0; i < numpnts(RMS); i += 1) // loop round solution number
		duplicate /o/r=(i)(*) clusterNos, thisSolution, sortedSolutions
		sort sortedSolutions, sortedSolutions
		
		n = dimsize(clusterNos,0)-i
		make /o/n=(dimsize(normedCAinput,0), n) clustAvgs
		
		thisClName = sortedSolutions[0]
		extractTrue = thisSolution == thisClName
		j  = 0
		do
			wave thisClusterData = extractFromMatrix(1, 1, normedCAinput, extractTrue)
			matrixop /o avgCl = sumrows(thisClusterData); avgCl /= dimsize(thisClusterData,1)
			clustAvgs[][j] = avgCl[p]
			
			extract /o sortedSolutions, sortedSolutions, sortedSolutions != sortedSolutions[0]
			thisClName = sortedSolutions[0]
			extractTrue = thisSolution == thisClName
			
			j += 1
		while(sum(extractTrue) != 0)
		
		if(dimsize(clustAvgs,1) > 1) // because if not there is no distance
			RMS[i] = RMSdistance(clustAvgs)
		endif
		
		loadProg = i/numpnts(Rsq)*100
		controlupdate TPB_loadProg
	endfor
	
	variable RMSforAll = RMSdistance(normedCAinput)
	RMS /= RMSforAll
	
	return RMS
End

Function /D RMSdistance(clustAvgs)
	wave clustAvgs
	
	variable n = dimsize(clustAvgs,1)
//	make /o/n=(factorial(n)/(factorial(2)*factorial(n-2))) dist doesn't work cos it overflows, increase wave size as we go
	make /o/n=0 dist
	make /o/n=(dimsize(clustAvgs,0)) clA, clB
	variable i, j, k=0
	for(i = 0; i < n-1; i += 1)
		clA = clustAvgs[p][i]
		for(j = i; j < n; j += 1)
			clB = clustAvgs[p][j]
			if(i != j)
				redimension /n=(numpnts(dist)+1) dist
				dist[k] = euclidDist(clA, clB)
				k += 1
			endif
		endfor
	endfor
		
	wavestats /q dist
	
	return V_rms		
End

Function /wave noOfClustersGt3pc(clusterNos)
	wave clusterNos
	
	nvar loadProg = root:Panel:loadProg
	make /o/n=(dimsize(clusterNos,0)) N
	
	variable thresh = dimsize(clusterNos,1)*0.03 // set thresh for "major cluster" at more than 3% of particles
	variable i, j, noOfMajCls
	for(i = 0; i < numpnts(N); i += 1)
		noOfMajCls = 0
		duplicate /o/r=[i](*) clusterNos, sortedSolution
		sort sortedSolution, sortedSolution
		extract /o sortedSolution, thisCl, sortedSolution == sortedSolution[0]
		extract /o sortedSolution, otherCls, sortedSolution != sortedSolution[0]
		do
			if(numpnts(thisCl) > thresh)
				noOfMajCls += 1
			endif
			extract /o otherCls, thisCl, otherCls == otherCls[0]
			extract /o otherCls, otherCls, otherCls != otherCls[0]
		while(numpnts(thisCl) != 0)
		N[i] = noOfMajCls
		
		loadProg = i/numpnts(N)*100
		controlUpdate TPB_loadProg
	endfor
	
	return Npc
End

Function /wave noOfMajorClusters(clusterNos)
	wave clusterNos
	
	nvar loadProg = root:Panel:loadProg
	make /o/n=(dimsize(clusterNos,0)) N
	variable i, j, noOfMajCls
	for(i = 0; i < numpnts(N); i += 1)
		noOfMajCls = 0
		duplicate /o/r=[i](*) clusterNos, thisSol
		matrixtranspose thisSol
		redimension /n=-1 thisSol
		wave clNames = getClusterNameList(thisSol)
		for(j = 0; j < numpnts(clNames); j += 1)
			extract /o/free thisSol, temp, thisSol == clNames[j]
			if(numpnts(temp) > numpnts(thisSol)/numpnts(clNames)/2) // if greater than half the avg clusters size
				noOfMajCls += 1
			endif
		endfor
		
		N[i] = noOfMajCls
		
		loadProg = i/numpnts(N)*100
		controlUpdate TPB_loadProg
	endfor
	
	return N
End

Function /wave getRsqstat(clusterNos, normedCAinput)
	wave clusterNos, normedCAinput
	
	nvar loadProg = root:Panel:loadProg
	make /o/n=(dimsize(normedCAinput,1)) Rsq
	
	variable i
	for(i  = 0; i < numpnts(Rsq); i += 1)
		duplicate /o/r=[i](*) clusterNos, thisClusterNos
		matrixtranspose thisClusterNos
		redimension /n=-1 thisclusterNos
		Rsq[i] = SSW(normedCAinput, thisClusterNos)
		loadProg = (i/numpnts(Rsq))*100
		ControlUpdate TPB_loadProg
	endfor
	 
	duplicate /o/free Rsq, temp
	Rsq = 1-(temp/SST(normedCAinput))
	
	return Rsq
End

//Function /wave getRsqstat(clusterNos, normedCAinput)
//	wave clusterNos, normedCAinput
//	
//	nvar loadProg = root:Panel:loadProg
//	
//	variable i, j, thisName, littlen, N, K
//	N = dimsize(normedCAinput,1)
//	
//	make /o/n=(N) extractTrue
//	make /o/n=(dimsize(normedCAinput, 0)) thisYbar, overallYbar
//	matrixop /o overallYbar = sumrows(normedCAinput); overallYbar /= N
//	make /o/n=(dimsize(clusterNos, 0)) Rsq, F
//	
//	
//	for(i  = 0; i < numpnts(Rsq); i += 1) // loop round solution number
//		K = dimsize(clusterNos, 0)-i
//		duplicate /o/r=[i](*) clusterNos, thisSolution, sortedSolutions
//		sort sortedSolutions, sortedSolutions
//		
//		make /o/n=(K) a, b
//		for(j = 0; j < K; j += 1) // loop round clusters in each solution
//			thisName = sortedSolutions[0]
//			extractTrue = thisSolution == thisName
//			wave thisClusterData = extractFromMatrix(1, 1, normedCAinput, extractTrue)
//			littlen = sum(extractTrue)
//			matrixop /o thisYbar = sumrows(thisClusterData); thisYbar /= littlen
//					
//			a[j] = euclidDist(thisYbar, overallYbar)
//			b[j] = clusterSDev(thisClusterData)
//			
//			extract /o sortedSolutions, sortedSolutions, sortedSolutions != thisName
//		endfor
//		
//		variable thisBetweenGroupVar = sqrt((sum(a)^2)/(K-1))
//		variable thisWithinGroupVar = sum(b)/K
//		
//		F[i] = thisWithinGroupVar/thisBetweenGroupVar
//		Rsq[i] = thisWithinGroupVar
//				
//		loadProg = (i/numpnts(Rsq))*100
//		ControlUpdate TPB_loadProg
//	endfor
//	
//	Rsq = 1-(Rsq/Rsq[inf])
//
//	return Rsq
//End

Function /D clusterSDev(theseY)
	wave theseY
	
	variable i
	make /free/o/n=(dimsize(theseY,1)) temp
	for(i = 0; i < dimsize(theseY,1); i += 1)
		duplicate /o/r=(*)(i) theseY, thisY // extracts a single particle from the particles in the cluser
		make /o/free/n=(numpnts(thisY)) thisYsq = thisY^2 // convert to mag
		temp[i] = sqrt(sum(thisYsq))
	endfor
	
	wavestats /q temp
	if(numtype(V_sdev) == 2)
		return 0
	else
		return V_sdev
	endif
End


Function /D euclidDist(A, B) // returns the euclidian distance between two (normalised) vectors
	wave A, B
	
	make /free/n=(numpnts(A)) distSq
	distSq = (A-B)^2
	return sqrt(sum(distSq))
End