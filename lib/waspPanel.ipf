///////////////////////////////////// WASP ///////////////////////////////////////////////////
// Wibs Analysis Program v 1.0 alpha                                           
// main panel code												      
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
///////////////////// Known bugs and unimplemented features ///////////////
//
// - 3D PCA biplot can cause a crash with large datasets
////////////////////// Future plans ////////////////////////////////////////////////////////
//
// To do wave implementation for Fl and AF variables
// extension of the Clustering XOP to 64-bit Igor
//////////////////////////////////////////////////////////////////////////////////////////////////


#pragma rtGlobals=1		// Use modern global access method.
#pragma version=1.0
#include <PopupWaveSelector>

Menu "Wasp"
	"Launch Wasp panel", openWaspPanel()
End

Menu "GraphMarquee"
	"Set ToDo list", setToDoWave()
	"Black List", addToBlackList()
End

Function openWaspPanel()
	variable resetFlag = 1
	if(DataFolderExists("root:Panel"))
		DoAlert 1, "Do you want to reset all globals?"
		if(V_flag == 2) // yes
			resetFlag = 0
		endif
	endif
	
	if(resetFlag)
		initialiseWaspPanel()
		execute "waspPanel()"
		finaliseWaspPanel()
	else
		execute "waspPanel()"
	endif
End

Function initialiseWaspPanel() // things that need doing before constructing the panel
	// ToDo frame setup
	newdatafolder /o root:ToDoWaves
	newdatafolder /o root:Data
	newdatafolder /o root:DataProducts
	newdatafolder /o/s root:Panel
	variable /g toDoStartPt = 0
	variable /g toDoEndPt = 0
	//setup distribution y values
	make /o defSizeBins = {0.5,0.52,0.6,0.69,0.8,0.93,1.074,1.24,1.432,1.654,1.91,2.205,2.547,2.941,3.396,3.922,4.529,5.23,6.04,6.974,8.054,9.3,10.74,12,13.837,15.954,18.396,21.212}
	make /o defFlBins = {0,100,200,300,400,500,600,700,800,900,1000,1100,1200,1300,1400,1500,1600,1700,1800,1900}
	make /o defAFBins = {1,1.7,2.88,4.9,8.32,14.1,24,40.7,69.2,117}
	duplicate /o defSizeBins, sizeBins
	duplicate /o defFlBins, flBins
	duplicate /o defAFBins, afBins
	// setup distribution dn/dLogX  - size
	make /o/n=(numpnts(sizeBins)-1) dLogDp = log(sizeBins[p+1])-log(sizeBins[p])
	wave sizeBM = getLogBM(sizeBins, "Size")
	make /o/t/n=(numpnts(defSizeBins)) sizeBinsList = num2str(defSizeBins[p])
	make /o/n=(numpnts(defSizeBins)) sizeBinsListSW = 0
	// setup distribution dn/dLogX  - fl
	make /o/n=(numpnts(flBins)-1) dFl = flBins[p+1]-flBins[p]
	make /o/n=(numpnts(flBins)-1) flBM = (flBins[p+1] + flBins[p])/2
	make /o/t/n=(numpnts(defFlBins)) flBinsList = num2str(defFlBins[p])
	make /o/n=(numpnts(defFlBins)) flBinsListSW = 0
	// setup distribution dn/dLogX  - af
	make /o/n=(numpnts(AFBins)-1) dLogAF = log(AFBins[p+1])-log(AFBins[p])
	wave  AFBM = getLogBM(afBins, "AF")
	make /o/t/n=(numpnts(defAFBins)) AFBinsList = num2str(defAFBins[p])
	make /o/n=(numpnts(defAFBins)) AFBinsListSW = 0	
	string /g newToDoName = ""
	string /g toDoList = ""
	// Load params setup
	variable /g timeRes = 5 // in mins
	variable /g flowRate = 0.238 // in l/min
	variable /g minSizeThresh = 0.8
	variable /g FLbinsize = 0
	variable /g AFlogbinsize = 0
	variable /g loadProg = 100
	variable /g minT = NaN
	variable /g maxT = NaN
	string /g fileEnding = "csv"
	variable /g gainMode = 1
	// Scatter SPD setup
	variable /g pcSPDtoLoad = 1
	make /o/t/n=1 xSPDwaves = {"X waves"}
	make /o/t/n=1 ySPDwaves = {"Y waves"}
	make /o/n=1 xSPDwavesSW = {0}
	make /o/n=1 ySPDwavesSW = {0}
	// Load prototypes setup
	variable /g FL1Min, FL1Max, FL2Min, FL2Max, FL3Min, FL3Max 
	variable /g maxSize
	variable /g minSize
	make /o/t/n=2 seriesList = {"All","Fluorescant"}
	make /o/n=2 seriesSW = {1,0}
	string /g newProtoName
	string /g prototypeList
	newdatafolder /o/s root:prototypes
	make /o/n=0/t prototypeNames
	make /o/n=0 prototypes
	make /t/o/n=0 root:panel:types
	make /o/n=0 root:panel:typesSW
End

Function finaliseWaspPanel() //things that need doing after construction the panel
	addNewPrototype({-1,-1,-1,-1,-1,-1,-1,-1}, 1, 0, "All")
	addNewPrototype({0,-1,0,-1,0,-1,-1,-1}, 2, 0, "Fl")
	addNewPrototype({0,-1,0,-1,0,-1,-1,-1}, 2, 1, "NonFl")
	addNewPrototype({0,-1,-1,-1,-1,-1,-1}, 2, 0, "FL1")
	addNewPrototype({-1,-1,0,-1,-1,-1,-1,-1}, 2, 0, "FL2")
	addNewPrototype({-1,-1,-1,-1,0,-1,-1,-1}, 2, 0, "FL3")

	setdatafolder root:
End

Window waspPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(197,149,734,495)
	ModifyPanel frameStyle=1
	SetDrawLayer UserBack
	DrawPICT 11,13,0.7,0.7,ProcGlobal#manLogo
	DrawPICT 355,13,0.9,0.9,ProcGlobal#waspPic
	DrawText 156,45,"Wibs AnalysiS Program"
	SetDrawEnv fsize= 22,fstyle= 1
	DrawText 192,30,"Wasp"
	TabControl PanelCont1,pos={11,53},size={395,270},proc=waspTabProc
	TabControl PanelCont1,tabLabel(0)="Load",tabLabel(1)="Scatter SPD"
	TabControl PanelCont1,tabLabel(2)="Series",tabLabel(3)="Distris"
	TabControl PanelCont1,tabLabel(4)="CA",value= 0
	GroupBox todoGroup,pos={413,53},size={121,270},title="To Do"
	SetVariable toDoStartPt,pos={421,79},size={104,16},title="Start pt"
	SetVariable toDoStartPt,value= root:Panel:toDoStartPt
	SetVariable ToDoEndPt,pos={424,99},size={100,16},title="End pt"
	SetVariable ToDoEndPt,value= root:Panel:toDoEndPt
	ListBox sizeBinList,pos={424,120},size={97,121},listWave=root:Panel:sizeBinsList
	ListBox sizeBinList,selWave=root:Panel:sizeBinsListSW,mode= 4
	Button newToDo,pos={423,271},size={47,19},proc=newToDoButtonProc
	PopupMenu toDoList,pos={425,295},size={97,21},bodyWidth=64,title="To Do"
	PopupMenu toDoList,mode=1,popvalue="All",value= #"root:panel:toDoList"
	SetVariable newToDoName,pos={424,249},size={99,16},bodyWidth=67,title="Name"
	SetVariable newToDoName,value= root:Panel:newToDoName
	Button delToDo,pos={474,271},size={50,20},proc=delToDoButtonProc,title="Del"
	SetVariable T0_timeRes,pos={27,99},size={107,16},bodyWidth=33,title="Time Res (min)"
	SetVariable T0_timeRes,value= root:Panel:timeRes
	SetVariable T0_flowRate,pos={27,125},size={107,16},bodyWidth=49,title="Flow (l/min)"
	SetVariable T0_flowRate,value= root:Panel:flowRate
	Button T0_loadData,pos={234,199},size={155,35},proc=loadDataButtonProc,title="Load data"
	Button T0_newSizeBins,pos={32,174},size={92,20},proc=custSizeBinsButtonProc,title="Custom Bins"
	ValDisplay TPB_loadProg,pos={24,289},size={184,14}
	ValDisplay TPB_loadProg,limits={0,100,0},barmisc={0,0},highColor= (0,0,65280)
	ValDisplay TPB_loadProg,value= #"root:Panel:loadProg"
	GroupBox T0_inputParams,pos={22,77},size={119,204},title="Load Parameters"
	CheckBox T0_fitToTimeGrid,pos={29,205},size={83,14},title="Fit to time grid"
	CheckBox T0_fitToTimeGrid,value= 1
	Button T0_viewTSeries,pos={235,239},size={154,38},proc=ViewSeriesButtonProc,title="View series"
	SetVariable T0_fileEnding,pos={40,260},size={81,16},bodyWidth=26,title="File ending"
	SetVariable T0_fileEnding,value= root:Panel:fileEnding
	SetVariable T1_pcSPDtoLoad,pos={22,83},size={132,16},bodyWidth=60,disable=1,title="% SPD to load"
	SetVariable T1_pcSPDtoLoad,value= root:Panel:pcSPDtoLoad
	Button T1_loadSPD,pos={221,82},size={41,20},disable=1,proc=loadSPDButtonProc,title="Load"
	ListBox TVL_xSPDwaves,pos={21,115},size={175,170},disable=1
	ListBox TVL_xSPDwaves,listWave=root:Panel:xSPDwaves
	ListBox TVL_xSPDwaves,selWave=root:Panel:xSPDwavesSW,mode= 4
	ListBox T1_ySPDwaves,pos={218,114},size={175,170},disable=1
	ListBox T1_ySPDwaves,listWave=root:Panel:ySPDwaves,mode= 2,selRow= 0
	Button T1_plotSelected,pos={319,83},size={75,20},disable=1,proc=PlotSelectedSPDwavesButtonProc,title="Plot selected"
	TitleBox T1_vs,pos={200,190},size={14,16},disable=1,title="vs",fSize=15,frame=0
	CheckBox T0_interpFlThresh,pos={152,98},size={47,14},proc=InterpBLsCheckProc,title=" interp"
	CheckBox T0_interpFlThresh,value= 0,mode=1,side= 1
	CheckBox T0_avgFlThresh,pos={163,119},size={36,14},proc=AvgBLCheckProc,title="avg"
	CheckBox T0_avgFlThresh,value= 1,mode=1,side= 1
	Button T1_del,pos={268,82},size={41,20},disable=1,proc=DelSPDButtonProc,title="Delete"
	Button T0_loadBaseline,pos={233,160},size={74,34},proc=LoadFTButtonProc,title="Load BL"
	ListBox T23_typeList,pos={22,96},size={135,190},disable=1
	ListBox T23_typeList,listWave=root:Panel:types,selWave=root:Panel:typesSW
	ListBox T23_typeList,mode= 4
	CheckBox T0_loadSizeCheckBox,pos={155,191},size={38,14},disable=2,title="Size"
	CheckBox T0_loadSizeCheckBox,value= 1
	CheckBox T0_loadFl1CheckBox,pos={155,207},size={36,14},title="FL1",value= 0
	CheckBox T0_loadAFCheckBox,pos={155,254},size={31,14},title="AF",value= 0
	Button T3_imagePlot,pos={285,250},size={95,24},disable=1,proc=ImagePlotTab3ButtonProc,title="View Image Plot"
	Button T2_imagePlot,pos={285,214},size={95,24},disable=1,proc=ImagePlotTab2ButtonProc,title="Image Plot"
	Button T3_avgDistri,pos={176,250},size={95,24},disable=1,proc=DistriPlotButtonProc,title="View Distribution"
	Button T1_importSeries,pos={316,291},size={73,23},disable=1,proc=importSeriesButtProc,title="Import Series"
	CheckBox T3_NumberSize,pos={212,97},size={78,14},disable=1,proc=NumberSizeCheckProc,title="Number/size"
	CheckBox T3_NumberSize,value= 1,mode=1
	CheckBox T3_VolumeSize,pos={212,134},size={76,14},disable=1,proc=VolumeSizeCheckProc,title="Volume/size"
	CheckBox T3_VolumeSize,value= 0,mode=1
	CheckBox T3_SASize,pos={212,115},size={102,14},disable=1,proc=SASizeCheckProc,title="Surface area/size"
	CheckBox T3_SASize,value= 0,mode=1
	CheckBox T3_NumberFl1,pos={212,161},size={78,14},disable=1,proc=NumberFl1CheckProc,title="Number/FL1"
	CheckBox T3_NumberFl1,value= 0,mode=1
	CheckBox T3_NumberAF,pos={212,223},size={117,14},disable=1,proc=NumberAFCheckProc,title="Number/Asymm. Fac"
	CheckBox T3_NumberAF,value= 0,mode=1
	CheckBox T2_Number,pos={212,120},size={55,14},disable=1,proc=NumberCheckProc,title="Number"
	CheckBox T2_Number,value= 1,mode=1
	CheckBox T2_Volume,pos={212,158},size={53,14},disable=1,proc=VolumeCheckProc,title="Volume"
	CheckBox T2_Volume,value= 0,mode=1
	CheckBox T2_SA,pos={212,139},size={79,14},disable=1,proc=SACheckProc,title="Surface area"
	CheckBox T2_SA,value= 0,mode=1
	Button T2_viewSeries,pos={171,213},size={99,25},disable=1,proc=ViewTimeSeries_ButtonProc,title="Time series"
	Button T2_diurnalImage,pos={285,255},size={95,28},disable=1,proc=DiurnalImage_ButtonProc,title="Diurnal Image"
	Button T2_DiurnalTimeSeries,pos={172,254},size={98,28},disable=1,proc=DiurnalTSereis_ButtonProc,title="Diurnal time series"
	Button T4_viewCAstats,pos={218,205},size={104,26},disable=1,proc=viewCAstats_ButtonProc,title="Calc stats"
	Button T4_assignClusters,pos={218,266},size={104,28},disable=1,proc=assignClusters_ButtonProc,title="Assign remaining"
	SetVariable T4_clusterSolChooser,pos={325,240},size={32,16},disable=1
	SetVariable T4_clusterSolChooser,limits={0,inf,1},value= _NUM:10
	Button T4_viewCASolution,pos={218,234},size={104,28},disable=1,proc=ViewCASolution_ButtonProc,title="View solution"
	CheckBox T4_normaliseCA,pos={207,142},size={55,26},disable=1,title="Norm to\rscat"
	CheckBox T4_normaliseCA,value= 0
	CheckBox T0_filterSat,pos={29,241},size={105,14},title="Remove saturated"
	CheckBox T0_filterSat,value= 0
	CheckBox T0_recalcSizes,pos={29,224},size={78,14},proc=RecalcSizes_CheckProc,title="Recalc sizes"
	CheckBox T0_recalcSizes,value= 0
	Button T4_CAinputStats,pos={218,84},size={104,26},disable=1,proc=ViewInputStatsButtonProc,title="View input stats"
	Button T4_doCA,pos={218,172},size={103,28},disable=1,proc=doCA_ButtonProc,title="Do cluster analysis"
	CheckBox T4_centroid,pos={206,120},size={57,14},disable=1,proc=Centroid_CheckProc,title="Centroid"
	CheckBox T4_centroid,value= 0,mode=1
	CheckBox T4_GrpAvg,pos={275,114},size={57,26},disable=1,proc=GrpAvg_CheckProc,title="Group\raverage"
	CheckBox T4_GrpAvg,value= 1,mode=1
	CheckBox T4_FP,pos={340,114},size={59,26},disable=1,proc=FP_CheckProc,title="Fartherst\rpoint"
	CheckBox T4_FP,value= 0,mode=1
	Button T1_DataWaveSelector,pos={21,293},size={124,20},disable=1,proc=PopupWaveSelectorButtonProc,title="\\JRSelect a data wave\\Z09\\W623"
	Button T1_DataWaveSelector,help={"root:DataMy:datain"}
	Button T1_DataWaveSelector,userdata(popupWSInfo)= A"!!*(D@<6Ba@;]Xmzzzzzzzzzzzzzzzzzzzzzz"
	Button T1_DataWaveSelector,userdata(popupWSInfo) += A"!!!!u0jd=WFCA6ZG%FT`Ch7*uDfPgXzzzzzzzzzzzzzzzzzzz"
	Button T1_DataWaveSelector,userdata(popupWSInfo) += A"zzzzzzzzzzzzzzzz5]Asgz5]-Q%z5Tg%,zzzzz5O\\XQz"
	Button T1_DataWaveSelector,userdata(PopupWS_FullPath)=  "root:DataMy:datain"
	Button T1_TimeWaveSelector,pos={155,292},size={124,21},disable=1,proc=PopupWaveSelectorButtonProc,title="\\JRSelect a time wave\\Z09\\W623"
	Button T1_TimeWaveSelector,help={"root:DataMy:datain_t"}
	Button T1_TimeWaveSelector,userdata(popupWSInfo)= A"!!*(D@<6Ba@;]Xmzzzzzzzzzzzzzzzzzzzzzz"
	Button T1_TimeWaveSelector,userdata(popupWSInfo) += A"!!!!u0jdmoD.QdWG%FT`Ch7*uDfPgXzzzzzzzzzzzzzzzzzzz"
	Button T1_TimeWaveSelector,userdata(popupWSInfo) += A"zzzzzzzzzzzzzzzz5]Asgz5]-Q%z5Tg%,zzzzz5O\\XQz"
	Button T1_TimeWaveSelector,userdata(PopupWS_FullPath)=  "root:DataMy:datain_t"
	CheckBox T1_raw,pos={166,84},size={35,14},disable=1,title="raw",value= 0
	SetVariable T4_toClusters,pos={326,272},size={73,16},disable=1
	SetVariable T4_toClusters,value= _STR:"1;2;3;"
	CheckBox T4_withPlots,pos={360,241},size={41,14},disable=1,title="Plots"
	CheckBox T4_withPlots,value= 1
	SetVariable T4_upToSol,pos={325,211},size={76,16},disable=1,title="up to sol"
	SetVariable T4_upToSol,value= _NUM:20
	SetVariable T0_minSize,pos={25,151},size={109,16},title="Min. size (um)"
	SetVariable T0_minSize,value= _NUM:0.8
	CheckBox T0_loadFl2CheckBox,pos={155,223},size={36,14},title="FL2",value= 0
	CheckBox T0_loadFl3CheckBox,pos={155,238},size={36,14},title="FL3",value= 0
	GroupBox T0_BLtype,pos={146,76},size={60,74},title="BL"
	GroupBox T0_loadDistris,pos={150,156},size={51,124},title="Load\rDist."
	CheckBox T3_numberFL2,pos={212,178},size={78,14},disable=1,proc=NumberFl2CheckProc,title="Number/FL2"
	CheckBox T3_numberFL2,value= 0,mode=1
	CheckBox T3_NumberFL3,pos={212,196},size={78,14},disable=1,proc=NumberFl3CheckProc,title="Number/FL3"
	CheckBox T3_NumberFL3,value= 0,mode=1
	Button T0_manualBL,pos={318,160},size={72,34},proc=ManualBL_ButtonProc,title="Manual BL"
	TitleBox loadStatus,pos={26,304},size={62,13},frame=0
	GroupBox T0_GainMode,pos={219,76},size={90,73},title="Gain Mode"
	CheckBox T0_highGain,pos={233,96},size={63,14},proc=highGain_CheckProc,title="High gain"
	CheckBox T0_highGain,value= 1,mode=1,side= 1
	CheckBox T0_lowGain,pos={235,118},size={61,14},proc=LowGain_CheckProc,title="Low gain"
	CheckBox T0_lowGain,value= 0,mode=1,side= 1
	SetWindow kwTopWin,hook(PopupWS_HostWindowHook)=PopupWSHostHook
EndMacro

// Custom size bins window

Window custSizeBins() : Panel
	string /g root:Panel:sizeBinsTextList = textwave2list(root:Panel:sizeBinsList)
	string /g root:Panel:flBinsTextList = textwave2list(root:Panel:flBinsList)
	string /g root:Panel:afBinsTextList = textwave2list(root:Panel:AFBinsList)

	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(372,406,758,553) as "Custom Size Bins"
	SetDrawLayer UserBack
	DrawText 40,25,"Input colon separated lists of bins"
	SetVariable custSizeBins,pos={15,37},size={284,16},bodyWidth=237,title="Size Bins"
	SetVariable custSizeBins,value= root:Panel:sizeBinsTextList
	Button setToDefSizeBins,pos={315,35},size={50,20},proc=defSizeBinsButtonProc,title="Default"
	Button cancelCustSizeBins,pos={137,111},size={50,20},proc=cancelButtonProc,title="Cancel"
	Button okCustSizeBins,pos={197,111},size={50,20},proc=custSizeBinsOKButtonProc,title="OK"
	SetVariable custAFbins,pos={22,85},size={277,16},bodyWidth=237,title="AF Bins"
	SetVariable custAFbins,value= root:Panel:AFBinsTextList
	SetVariable custFlBins,pos={27,61},size={272,16},bodyWidth=237,title="Fl Bins"
	SetVariable custFlBins,value= root:Panel:FlBinsTextList
	Button setToDefFlBins,pos={315,60},size={50,20},proc=defFlBinsButtonProc,title="Default"
	Button setToDefAFBins,pos={315,84},size={50,20},proc=defAFBinsButtonProc,title="Default"
EndMacro

// manual BL panel
Window ManualBL() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(315,347,554,500)
	SetVariable FL1BL,pos={37,31},size={81,16},title="FL1",value= _NUM:0
	SetVariable FL2BL,pos={37,56},size={82,16},title="FL2",value= _NUM:0
	SetVariable FL3BL,pos={37,80},size={82,16},title="FL3",value= _NUM:0
	TitleBox BL,pos={64,10},size={40,13},title="Baseline",frame=0
	SetVariable FL1Thresh,pos={134,31},size={59,16},value= _NUM:0
	SetVariable FL2Thresh,pos={134,56},size={58,16},value= _NUM:0
	SetVariable FL3Thresh,pos={134,80},size={59,16},value= _NUM:0
	TitleBox FLThresh,pos={135,10},size={53,13},title="Fluo. Tresh",frame=0
	Button ManualBLOK,pos={57,116},size={50,20},proc=ManualBLOK_ButtonProc,title="OK"
	Button ManualBLCancel,pos={135,116},size={50,20},proc=ManualBLCancel_ButtonProc,title="Cancel"
EndMacro

// JPEG: width= 58, height= 66
Picture waspPic
	ASCII85Begin
	s4IA0!"_al8O`[\!<E1.!+5d,s4[N@!!<9(!s/N+!s8W.!s8Z0#R(A7"9f,;#6kGB$4I=N$4@4N%MB
	<^%M90Y$P4'b&JGin'bq,f(Dmo%(_RMt'`Znf6NI8l"9eo3#mCJ='FbEZ'GM5q'GM5q'GM5q'GM5q'
	GM5q'GM5q'GM5q'GM5q'GM5q'GM5q'GM5q'GM5q'GUS_!"fJ:63'%K!?qLF&HMtG!WU(<*rl9A"T\W
	)!<E3$z!!!!"!WrQ/"pYD?$4HmP!4<@<!W`B*!X&T/"U"r.!!.KK!WrE*&Hrdj0gQ!W;.0\RE>10ZO
	eE%*6F"?A;UOtZ1LbBV#mqFa(`=5<-7:2j.Ps"@2`NfY6UX@47n?3D;cHat='/U/@q9._B4u!oF*)P
	JGBeCZK7nr5LPUeEP*;,qQC!u,R\HRQV5C/hWN*81['d?O\@K2f_o0O6a2lBFdaQ^rf%8R-g>V&OjQ
	5OekiqC&o(2MHp@n@XqZ"J6*ru?D!<E3%!<E3%!<<*"!!!!"!WrQ/"pYD?$4HmP!4<C=!W`?*"9Sc3
	"U"r.!<RHF!<N?8"9fr'"qj4!#@VTc+u4]T'LIqUZ,$_k1K*]W@WKj'(*k`q-1Mcg)&ahL-n-W'2E*
	TU3^Z;(7Rp!@8lJ\h<``C+>%;)SAnPdkC3+K>G'A1VH@gd&KnbA=M2II[Pa.Q$R$jD;USO``Vl6SpZ
	EppG[^WcW]#)A'`Q#s>ai`&\eCE.%f\,!<j5f=akNM0qo(2MHp@n@XqZ#7L$j-M1!YGMH!'^J^;l35
	/U2^hr86"th?,.N"N/Wg6ML?0>_V+_=<q,j>mBfY*g06udnIb$^onMS8\Wi;6,`RXo,pO?pB34:9GK
	F.@=4AcQF\=0c05[Gr[?YpW"R$jGH5/OS?O:tppAId?SflQ8FNa@If8&0N`M>Pg><BMOCm*PrB[c-'
	4(Nm/@iI<D[nA=S3)liU-$8%=\S=7Ig3u0Sk*>H!_pW;rZV&@%//Hg&Z2(jfQO\!T&4S[**:OYhP!B
	//56:P+`B&^kIO+Hcr3k=TN:L1tG>>\!AYqr>'La0=IB$OmcR)IC5$Fm&4urKcr*.R`B`":6'^D%Bg
	R^(G'gf+W'&M)098,SVZth5&Ei;>rmURH&nu4$$LpPV![9ZlRAOY#,O$@;?[DS.s'@B8[4inQ$P.dr
	(06a_flgk%_BVeG8q&;.f7<BCN@S;'O6)mV29s_CZ:-=s)]4I4HaEYj;!9E2qc>g=PRC/Y!gLsO?7r
	nk+K&_%+['?(]<._l4`f7=nF_hNu4B0_oQ?-5ddRIapBHC@^/cFM$B0OtmEn.,u@d8!Ak.b,i_@fM2
	P3MiBKe5s:G$8,a$aS/bUhq6_g.TV>:>#=\f]/Xe^Dt"%/Mg,rh;^Xk`"s*CM]F8RD4"Yp<u3L@\aq
	Ed+Y+=g-'hILBE/3Fgd^;VrAX\Nr(@g!i+pXJaeW]Qdd&U"&F/MWq:>8TN&Z%'nsRk3CUefU*+0b89
	RM*5A,(O^W*a9X^PM;?D5lifDlQ)\ZqG)4AsJM4<&kT4!$XS!r3@?C]*ikHY+?sPW:+NTfr\V2P'Z?
	)[^T57\C'J3h=^cZqO^o>_S7*UZ$[X+iD0mW9O)<J0(J3C.5S*5B_&-[@Q*-\o-Ygbamooq(b0ugpg
	-oo1="T4&hGs)L%aoU!sIYn9)P%SRuWp+a2M,kpP8DP&Pq@1p1`]B<.uK\k<V/OXV);2*-4;(")oOI
	E,5+ciO=ZFFXpFLF5#J+#sQIQ^0JL&G+QHGO]@"68(onKG.sI2pZgX2a]k`EBiJ&q\$*tNldYC%XG?
	=XP.IG-EaM=VI5*^5h_MKgeXpM:(UdNM26U@Q)9-m^GHp>R&r!l]XqZRUmEI4ppm59A_]BoLF_c\F+
	gQ[^0qhFlD$5Mt`!sq0#"[g4Eb[&6Cl(a*fcDO2F2kp8]D.A&iN6u$^%,2<K#s[NB9CB5nk+[V7u]o
	Ur8E*'*:(3s6h#lueY_W',M+a_Ld!Q_Y(P]A]eR=VD2+l4pTaod1JK%"fts"]Q(&Xu^!1tJU?P8/lS
	"'tEf+AtTsh^u+aZf6V^g.dX6)Em\<>pW$j[?9J3gBbce;+dNsp8C5dh@$b4eZ#;7hY<Gin935[(S-
	+GNF1Jr6ia3TCta7Tk"$TDa(YEU\\KWbZBRl#S,Rj_'!'/*_O79KK(=7=JP=lKmB"1Y[%fm7Y;\#rF
	.Q-UH0tr%fJ(^9tQ"jcX+)1*)AqA[dWdFIPL9S=G.h=5#mFG-ZL>nFo3"As,fV\Lm`iVn0<=A8+m9E
	k"DsU"Ke^E)`re*T@"u%:/7^kbA(:`4+SNP=Ys/X`I<AXl5jU=U_RQ(Z&LMp2#aMI%[++Ipub(8#1C
	9`?#VW6E;BP;71$L0ph=I/mX<15l3dg0QLFY*7ieD2KPp5^1?''D)T!*!%s`4.i!h3L5O5ko'1Y*Vs
	2ddCaC[+NY'6PCf!&4;sJTLQ!1')Eh]+3FW4OPjrU^&Xr$*Bg;Ti'%$JXFH^`u2aK6H1+<FKp4K/t+
	Ee[mjPODf-E0dpNT8@[u]h;M7HW]9jBQW&faS?PW:GtZFL1q1B#=VJ!k9d_/Q^&pn42:%;o(2LaeV:
	GDm2OgVe,9&gf]G:0i5'!oo(!_kP%f&1,^\:V+puf/"WN$>DH7m'ghZKlj0"_k*hWCa[X+O!2OUY)D
	mW]Gfe$#:,XAS'naA3C5a&KI]5%9$0k:(crL*VTUfls/aXkPP&jR_5pW2;Y).r;33Bc]i?eVFO7+=>
	5G;"e8*/sW91Sjl5T+/tJ4L-A7o9#8KNl;$\S/n@A-+!0qNa"Fl<TpKpG$cofrr@Mg[=lN8WRIm6Uj
	VA&5?NnDi[r^HBp72iBaVj\l8["FG3oCV<@oV,bh6\MJhcie/(4D:GRjI5nUZlsBjnTWeX,WO8D5],
	CLFKZ#:Z!0O=8qm8/XPAD=A)0C=[be1H"9IQ6tloEI07l1m2\`p#lDR13k.;Tks]LY)D9YS(h^dZ-.
	IsWsh\3PQ73/[h"g>&j@"gS=W@nmtT"k*%YLL]mIN+rW4:H2,:c!<GR(kH.[@+>u)(-Ia7m:BM=:a8
	>HAF;C`KE%RB,Y=FM!o>b6l4S"154HCa`(_O=5t)Tcu86O-hl!CX!60[YEP0L+*]mVAo-WM8J4n*g3
	jo/o(6.UM8pet4(ZMCW`\(AlW+oV.5f'_W)g%6/p%HfBo266_KZ<7FcF&::&Lf`
	ASCII85End
End


// PNG: width= 190, height= 59
Picture manLogo
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!#6!!!!\#Qau+!2Z[=T)\ik&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U+94u$5u`*!mCd^g>h=*OqHJ<=F(XQ._4Yu`,QSH%5S@mBVasAn.EQ=j.9Vu(\E3NI^7S>AS<n8e3
	;:/Z>W[t:`/,L9.C*F+<\L6sM%mS?.T'Xg!>6Y=#/KjkAZtjK)1Vf#/<Z9Gn)!7#nXFGNB:llh?>Jr
	9=503d&,l\3hu\SRTV)Dj!s2:q">T^4"4DO_!C;=*>po_.[A2tP!FFXdJAHhj@RZL-:^e]!_!JHP,&
	i!I!XKHhH2X\bLLDmVd@8S+[(p&R';uHUYEOQF"98I':^dkI0hl!g5[\38N5CdI&1LYD8+BmhO3dQ(
	+92Vq[G%p<"<\&=cJuS2R"!Sb#[=/9W]`LXG&(0u78.*=RHW]tJH^l$Ch&(,^3O#e`jl6SQkba67t$
	uWCj\]t$5^F'#n%rnXI'jCbfZ,lYai0#'Y2?cj:+:*!=Tcp!o_R<eWa,^M$n[f4:J-cA7>AYVf:I2F
	jY10WB^Ri5`lZf5k6n<-b`h5B]IRU3hd9S3h^K)=-PY.J5E<M8RdGT70"GIaF@j=U0rc`6B`StP[He
	MafA>@?m5f2!@CJQ*(:&-`d:6_.kk)p,uFYn^b1FG\;FN[$4Nmj!f."'YDAP_Gnt_9',<(BM,-PmJV
	X[Ud,Yqf+@]Z?Q1s+PCgtuk(:]%Z'[8I;mH)BUpf-aKOTMJCe:kslU.HnD(.'FGLkstE6O:M#+o`e!
	/-P1M9'b#L&)\p6+R"$WS1?-7)_?&E-;2rm:95V(hlV];$,D-cIS98=,"P8/VQs*&.PF_GMC;QgA3e
	Uc[Oap[FK'Xen<>c'#=qFUa^p3lZ,nm,CRu58/5:j3RZMuQjtJ6g,UM+Zb#6An!\:Q^kqK)E-s0\T5
	GN3f;7%a>8tLJ*>[L9F.[>$j>::qoCUu,,.,dMFbX/Nd>[:M!g56UNK#*Obpb^E)#<%79^eu%:BlLB
	k8^^'O7mRL/TR<hg@%msf#TL#(>`kR/!sbbiGeic6bpY8:#u,)^h4ZCc(+CDl`[$4HO8rMc&7AOrfs
	+eAFX-+6RL>`?2/*=pZC_uXCcQYgPt7cMUki.%*1\7lFX*[O\CFE+T/SgaYT3.6s5_B&8u&9&+0Hnu
	ik'^<_P?#cGq`I(_$;1'PI=$e,nX@rH23g+H:s)4*p?M$MmREg_8h'%Zo+^k*\Asrd;YBKb$TV&rRQ
	]>*o$EBJ+YV`@b+<U`?Y_a4L/Spb54B6\Yd%c=p$""n,ME$T)%6Gb^caX:Tts4!">Zc?G1CTX`nVql
	mOBd(R\.=]%t9-^%7.0SfTjUU_3N9U1HXNL[M`j_>NFh&q/qQ_ZR//-ud4mS'%d[_o^:B?JMf8l_2O
	a[<DM;)`OmuD@K!KV-o8UW;b9!?-huop>V*+,&=udUKgAZd675@>&h_0ZQ,)WiA*m7EH:NYY*0*b70
	>>M"tJna$m1XP3B$.MVi'.tj8o<3^R=fmmG0j%5Q,"ARk9in;;OtaLN*uY)<6dBB@RTIB@AQ!Jtngh
	W`@71G[PT4UJ]DIb<^:_M%ODXY3?cs#XmSdO8\ZOSj>\llr+u`W`2]J?pa"g3rO@kEt-#7_ki)@X=j
	2T55t"H]lWE0kdcWoU$EC5!-C06Ek1h$Dpn!86Qp)Ap&<7/rl,sc>d!t3j<8p5hVT@>[S8BkA0Xa0E
	nRm[`*`Gs+"k4$<qFd!^ANWHJ$_^="@XpcP`aj@Tb83QlVm+6rhWiBg57ZapqQ:tgJ\?'$tW%E!5#J
	#B%_abRX5g!lAtA4DlLT-IeX`*54PCLZ:!u23PJD5KakponDKa^(Ou93pE"bUeA$Ln\^:dF@J_T7>;
	N>Pf=pa:e[MoX51TUM5CE=KrjSE)Jg(g=#1&amE6j/\YI^WKkhX1$s2RoZ^UD;klQ?#k]-$grAsF+g
	rNjP9r8EP7]3&/r.?,GbPgXAL:Bt[s8,pbL+9(&t,Osh*s6@]RroNrbT@2fBq+J=`qLtq0$_-m/msX
	cS'BIFM#a0-,iB"M?EH9U`QLsCrn,L9j.M:3a"QbFp+;^+>1Ba`YEIc+2,sX)U5aU.YbUd!hPHJfIh
	`0f&rr)T?,M'$<NrAT?:IIS3!WiL:A\3-abj*N%rnb[:g%I)Vr3u69EG<&aaKBID1A6aKhtWD]Hp+9
	lBY*[:7Iu,NhtulW>M=hW^$5Rm?iO3Zg"p1+!I_8Q:akB.<\mIhcBAD91r.XDc_XXsc&M?BQ,W5;e:
	P+d/[%?e.$/KVZ9[pk6]E7tD!?NhbJTbk0Y0@C13#C?o*Ntrho<pX$AS_QDd0qohkB/ZL#qtR*UDE@
	:\EGHS:F(Z+:6)T8rT9i[kBP+[0E<nYiUde>j1Y2q:$Q8U$;&lCJ7(3,(ag>X$8e<8.9$,UUJ;OLN@
	%Ok%B2<mPT3s^[gaM8&"uHKbJkq"oOG^0`sFbGCSN%hYG2+J)no02H2L9'N8UC%:9rF``'uC]Ba9?.
	cm&EKT_jL8H;hu?#?Ab1!hdmVi_rl%1SA#Nb#%Cc-G8*k\*YB><P)^++;t0G.iW.O:;K73AS1:XI.a
	ImIOs'aY@IP31?paFGljojbcaSl5pi^m$B2'*=,fE<Pq^10dA>=j/*<k7KNoHQRtGZAI`hn6c$01s1
	.pjqqeL,l36Jr#2h!*`8T")?r^.]4C[P%[I/sd\,_bDF$eNV@>BP)0'+."l.nR"r8!uokI5'[D#X1D
	rQUCPpiA`g4rAY^^N:Hu@eVQ!(p<"93jbhggAbcN6HRrikf15P4M(2rf!5_hN>p7J0_6[s5P(B=C$A
	H7&8!645Yr8GadQj/10>-dH/s_ACSLF<:]9/AJS8Rg7:bd[.pmX@J'Vd:ap/2]d\(CFBe2iR7t:I.(
	$c[\=Z#`.?hqpmq=q5H:('>(+:s/*SY-@e_'3S4;Ak?Jd\+kZgq;S=\S'deJ+a,N??iBocOgJs?icC
	?0fh4sm?'alb@_$:FC"K"((9=/kuotrW@8q*!5sPg-Wiq'b12.i"@FWW/i<8n6uD"L>7=R<#GD3<_m
	!c(PS7k`!(XRg(XGG%2P:AOYIVp1Gj>g4:oM#',."@!0+A_cn"(HMp$2'<Z$bKiG7r\)<eAc20iCtC
	N_62/!BX:M643pd9WI1B^V5obJc]$[jjVj=m#XKh*`[0LAF@gi2^@Y3JfGN.PjCc_dgf8BQgdRJC2b
	11D]_.4luUo&r,3OTD`0Li>.=7F_\EGa;fj_]Ets"!H1EFE!eMO3Q@LA4.^b&q0E1T^^\6;%XSU;6p
	)ga0g&@:L#rs'2;;_iq/Mh"*/N:E<mI,PqUE9tGQ:-WTj!KY=[rC!A@dL6LX.0jN_3=-Ps4sG+(KNA
	rX^ASHp>EnuG=60*&LPgCB#9ZN-]Ymmr>U7#AbP,Pci<N&htlC%T6gI1c]K,&9INZ^`rIQe,fVat\8
	Ltf$_jKsIspt:A,B'u3@lP]'/-'n7^Vc+c`Wn4Z7OfbbnO%mNtdBOT1B]E-X?49R&52[='2Y`!92G`
	F.&V@h3JuF=C_9[QWoIlmJc8Jl:HpL8KeNBad$YAm_!I,8Tj%>_'=U2aWGp)jk*t.ARFbd`7Ma%IpM
	7up?9CIm=)%_YE_&j;RbM'>@hqfL_?%7B9Ge?.mRd.d<Vgsle#!*:mr/0'.i9=%Nkj?5g)4^WFKRKD
	q#55ohA(cH?&\%8<1a;.m=LOapXa@'JrOLde<,k?k:uti6DSri]tN*0.\e+#>Q&&c[>_c`!O!KKf@H
	%$lG,d0XM.D.R7R,SDDt&[P[Krc5k"mkO=&_A+(b;@F`WG_IW`a3R1:h,qu=Zp$G8@qTb-#F!IeG=$
	694G;Zg/gG7g+#$?F>_r%5G"4q1C<U8d*cDipP@c6mh*d0@Bk2d`m!bj>FfDjPtqt@dJLi%..R+C?-
	i*!5e"It9Z!%\IrpRGub.4\pqdp.LhZK;\?=UU+47fV5@[LS@#;U'_J,Fbc`D<JI%5IN^g7SI1RSt2
	FWJV_=jE/R!h+p3s<!cosH9tfB!I=&Ol_6O-KJ]GGE`N0b&dTrg[adQ$15q7"+8jY?`r':m%afN.:R
	B,-/Lc8Y/]XUZ*GY:sHUh@Y^&:m(h*_S;IV]O][c!&<YYBJ0L"j97u&SI3,/ur1P5iXf<orZWXUe21
	KR&1tb;A`+oAWXE;bO).+D"#Po1$X[kr.XS[l0f[![WYDG<N-UkkLgXYKJ![m!ma(.b-$4WRI#&sh`
	:GV?b<SAc>Ojh*Ye;L"ouPlm40qYm=nZ%c;WmrqiVSH(Gip>,U#F'ZLMaSbS#p_+Kr3':IKW76sMD;
	UqdE0lkNT1YcK1VG\MjL[V[&pKUmu-T2-Da(>FS+AAeM7.!@DQNkSpao@'tiG:LqO'9HlMBTj6qV\a
	u'[^>q5F8k"&c;?5q`Gc-Z821fG3LWl&]4C<22aAjIbtp`_4L_5VP"UDEd1?^G[W?-.RjN_g17>&Uo
	W*tkK?3QCO:ViC<'"Tpq<UnLcZS?BiR^9lTG>\\E#;E/Eu<[&aUa0_n=eltm4@GKJe^W",*mM>ceoK
	M%5eSF+.0B_pZl)e]c(Sc6k17t1>4fZ7G)_>7UNRI;0F/72]g!b*s+2<pr8s)e%o[WZAUe/^M;;)D,
	fTW.-$#03BpYEE/R=UVWe=>co7=5b=K])dm=TR@Z=KfM=;WD9:$n3T;%EA5t?SJ$98g+.:g8:afjVA
	O-<l_-;P<nPS#ZdQq<oqc7mT/ThbBDe]mGb^:$`3Z4+/sC2>R;%9BRf\EK5?68EccqItbqi*^l4jMW
	dbl\pX\Qi[k]QnJ,BO:'%K6uQFiaU`n)UrH:\)0A:!<PFt3=EBeQ=LtrY<>IrINWR%<H(!@Y1(k#96
	7tW^P%`pBNOQ\hlCdh:dk=*dHC`KZNKYKWZ's>&$-Z3K*Dj=S(74!^,70tLoq!!\nD)"UNQn*ph%)[
	GK3+6cb7A;1>uk0Mj#rATs6'TF'P.sBO^Z:Q3>)dbbZb/V80E*U*?Qa;8"]b!Zg"/O5XqPBK*)4Z]m
	.&]\Rb;t7GFEjqI]afFokUl+bBPF(&2QOq16[+CEArES)="NK^mh.G$BeS0HOh];K0KAVVh"HYd0S#
	o>0^Dh$&)u3%lnNfJBd,2`-kNkmorus/`>L;&M$oVjKb&3KB4PD=AEO?sj>($1'tf/Qn#sqW]igD9N
	S\)9iu!DDo,<qCQJN6YU9dpVrfrbBHH\g;BQ[Ed$F4lr-,/H/VH@8^1cu<c4!A^`$KQ&P=Auf"jBaB
	%XS<bNee]H%'1b&rKg"M7Rm1^1Yc'<Q:(jSq7WD*5MtB+D49#Aqd;Y0E1t6k-(pNp&*I/*r(A.bVGh
	uO2HZe`L6f=_pSE\PTcWUlg/\Xh"Jtc'b<4d2<K\^^\rrFGtb(l#J"D]<qm-]9@(;G-d7O=b%*)9KH
	hg8j_[:AZB:fjEdb!,/?kdYiLD[o;+RobfWfCgLi&e#Mf2aCiqN\X0,K.iJuf^i!!Np+%jW4pQ`#_@
	c%WXOrq(-a5C,&hla\682Q&\3MZH(8.4Cg^/'NKK!PGq4Mh2Ahcqn3+9<Xn3o5*%b"%!TU]jNX4fWL
	fKZ!lV2)/F2js7))-!%BSn`a3uUN,Ste@A]RA]%]`TMaM&RC4N0)d!`4gOmemPmpjo>(<P)cf@8Bqf
	^[D*U"u:<h*\>NcQ&fE@d^T?1Dn==c!t*5B,s'[in;A]7a4h/;CNA.DRt6JQmHi^P*I8gW2ck"\nl@
	_'q8W=;-dl&]aO#Z=T.$M]>*r]&$(X16kjUD=8+Da+>I0197\CR"5!#K'I0/B9%NnG*SGf;buZPL]5
	RE>>?<r`j%%Rt\.8JOHTuWIp%.@l?-lll!g<)<Enru?.&>uC_AT/8X_oY[CW8iGRr@"3>tqO-O@tlc
	dkp8eV-%`tU?DOC[DBTTIT2C7+om4JT>TjKlMJCVT(kY&8*6tEEW>L_Q5[s6HL5j1C^'un+>T@TA_R
	1d_1:t&SS8?q"J1crALR7M<5cnPo[/*Um!n,9Yp^uc(f,^6a^NB_-S%e^h%/UY7q'9[B0ZQcp%=:2I
	RTT($#phN`_tJl:[uk%AX\Q4>R=>?)NGod@KU+!hAf\53Ac*!=S3(R>><HBU4:c&=WOUQs4,6l-;=Y
	=:7XU(Yk=Di2>R_Z;DGN8ECRn+q+H+(?TEBb1='@&E$RD]iEX8,l)%R3F%>hW9UjjOH'+>KTroZHe&
	!t`m&[uld%i@l',d.-0EjtKoZnV)B)ZY>Dd4/b]"\.-B3sE,G]VD_hd^$LR7q79p^+g_fus_U!YJif
	_-(;kTmu-S]5tmD?[h)i#;;&"dJuSCJu'BB&$<QgjlcW8HY7P%Y$/C"flOd-Ga?/ZVF<\>_PBP3"HV
	nqkD=-FM3LD3<nD`[o:%i=cfS1n_1_kT`aaj!.LVoDW\dO_Ulb<:U+7+m9Ze:X?tT+uXH%h69\g/8H
	m%)%JIoncEhoHF,UReAIQRfPm$PqU#cAPF:<5tjT0&;Wlar7=l^GjZ/o`XYpZ_[Lp7-R&XY]^$]XFZ
	m^Mp_a>Z0`sL\AE)6???kmjAIXbH%Y[M?4@Z"9L--nnT5lXcS(Q:i=j1HiMdudrDT+5b[`/\uMg3qs
	g<V/1?Arkrc`ZaY2A?>'9l#<HklQLB%+Z55p>:==c]L!C;*M%ocAVjfAg/;<,O9E&Co'&5Qgneqao(
	pk@m<aUI8B_<(u?b_1^8nV'&qo:`YfFipd4ThEIK.]&@KM2&qI#a:`DU9_M5HDUGc/$F,fl:q!qEDa
	\.W-GM0luplLE7ZnL&%rp7Nhu%WLWb&TXMVs>7=,%`YQhe..\?G0B7Kc;QNkdUQY`)_aks_2@V/K_8
	HVRO-:bApTc>W-=jU,K?fJk5;O7gX.A?p`UgQH$?<Inl`8pkLDo<;9l7n)W[s*5#'-L/^5nH<*S9KB
	-L!tmQhB'__q':>q#$bUZ3>K*Cg`s![rQd.;^\p*rSo^X"`V@B<aqh0TVD&9hn4Jfs0ru9(XlZ[,Sn
	(c\3t<CXe^?h<$`>UDH&-_eWTRTlA#X9B=`M9QqXBpF++<QqIeM;T,)bSX7??m9X2o+>i\AEB?W?&7
	[deJ'UtjbUi]Z-7#:aBkLrd_A?jS5I!?]O`^@k#C@BJA@Z#TGr<@e$/4neNhE*?b(!/AR+E_<Uo-\D
	H7'%SH8ms\YCBqkCDX2d3&q,Bn/!o?/d%0j@&Q#p>]o#OYrf]!XPRci8;n$m>W6ZJ"SRDSmZP'po?H
	1'YYYQ"$)ZIchh'C5)cjDF!i'l[G!H?R4ep"Jo^\P1Q?UA=14r=PGdAm3;b3&YfR[F(hO(KNDZ4-u2
	?(HES@eXDp/B4`2$7R:A@8Y3R5%m#$/5-P@T"'fOc!g,cuBT+CZXHQj;S@6Y_d[f.V8)H=M^,m+1:X
	,8<$Wp_j4Is]SHiQJ>.bm&j1a,OjYRW"qeH/ns@+`W5j:AKqKS6LL_!ab:<9XqmmO-okZ_&Cq:fHTD
	5Q%RMm8YSDO3_L.ZG?T9-N>f'Re"1[h_^/I3fZ]Z_,PusT0<+1FE\Whr5I:fLXd@#n\T13%VX3S/:_
	ghXd&BH&Ln:D,"HSfI]RYSX!c2b*g;W1$eSe.OFd<`?[[7P^tBmE&W8To2p;.Pgk+YVI1i1U'Z8I0a
	E6q1J,%!k+23m([r:!-ZDhu$br.:j*8%fEn#8IJOi-Qj2D8:LJ;pX^244Ze?jDuJF),Z!Z=McR=3J/
	g_9]b(VMRPM-=cW'J=41[=m:jjCsLkH8RJ]$$,)sn?mn8G"LEq&LN]#u\ih@V@DcIRM+K$";gpmm=[
	\j:a:81O$`M7d&h[uNSA+edlP?U.R,G5s4>8u)*q*.pm,PVL`';!,[pOS`&F*="rqm".T"B/8S-KoA
	]UHl'29%Fi*iQ,.<uE8$(;gTI"@/2=g4n]%"P>snQ*Pl<iuRAp[V-HTioe&n8<+VX"+l6m_T=bT"sX
	+(W[D=nmHr(AdI?jH0;h=HSjP>[,hF/g:Nuj/=*dc^eqZJuTsh5M6H59N&4:XbCmQ-'42.ID622#8%
	')n4rR7Mp^9)4e#F5o46%o*G@o#4qoAm1Eg4c6T5J:t.Jqg?tg+q[qgD,`A[Nfh$QANf;V?_"QB?U.
	ChG[_Cc3"Jq),(sAYp'G6'^Q;<\-fAh>ZXir!(;^/K#L7_A"XMa#EdR==i3pphC4FZiTh2l0&c,,j*
	8*+jP5HhVSS\JS6^9$hkn::qcLc[;M#n?OdU=4b1$i\8/j0I0l2ZIJ-'PK6^.Zc5T4U0PllrdJQM:c
	*J\[<bh,D=e^BbG[e+Z:98#q4_k13%C,m59LU&U!"J;YDfIgup""8aX@*21<fq5qTNSj^A8Q781s7N
	jN]4l^]![F#&EaW1]L]@G7b#YhV!1*9!TI,sUCY(C'F'dD]j!Nd0%S;BZA(S.J54W&=R"g+F;`eP_"
	-eDcK3F\!1po1X4rj^TZR[OuMnen2+0,a8jfE"6oHC9?jjJC]Tn4ISIT$V!3&iaVa^p)>`psRs3_uB
	KDlO79bgo3W-h_a2#9C7cU:s:BJH,jDcAd8N%t?-gBZ9?HLa4)K.YONTSj,t1q3g-RC\bP%e`C05l$
	&^^YiB[\B"8\58.1<DR?]_gEW<U33f`QTB@lj$UeT7r:h`AJ1^!a2?pd<SnPDL'`&[NXD%$TI%%erJ
	/hX=Xdennh6<2!9!F=0%A""77.'ni+%-hVu26u?[k@3U76`,YR+C$k'qZiFhW`n%][!g]`HJ#q.F*!
	PrkW=Pq3k7#bXr/4J[m7'$eC;#dG@Zak:dUDq[(%cRNL&8E7WcNtMSf#)Kc5"Q6gB!=oU"*n5TgX3c
	X5M6A7\t1KJi<6Z!pc#p`mdQ>?54IeNJ.0iXaR>Q(f>2X#85&S'bK3l>\[>S?tps5go`i(Oc.P?a0g
	js8'bHRBuhknAOdFkA/B`fQJr1lssTg7<<eW,$T'I($(-$jP&b*hJr:ejVsMNBYO',bdr[7rS<+DnP
	RChJRYm875J"hmZ"uooi4-gdR["RH,gqpDn1;6ioTPgq4&9'DIhUo[Y@ooSC&Qb`QXd:pi(O94pI8_
	XuLBPOhe9a95dq;AC9t%V8^D'.E]ohb0oQ$906aM<`T@hb+^aSRDZ:,.qd=Ue\)b>2W,ZLN+S:IbaO
	uYmu3brdcG"BLT\PPe(&g1eCe)1S)%2Sr.`02m7Zb[As?@t[^NU!Z?a@M4)_*:XF#*U^7YDj1U.=E"
	UdA/\oiGA%<KF\0J\I\MlTJhiJ?.UM!HGiiPH'=q3N^@]^b\)F5'lML8iU)&1%p`3,"2HVJ+#EL5PQ
	+'aHaq[FH9R)],rkcC*-:CJO2sf"&-L[F[=_WD+Z?qfh^DP0"Ft1c<c@=-g7^Au*#LFS2*5b?)+^pZ
	(6$*U^ZRekdqU=]H2AYc)m<igPtTZkEYU9iAB213u&q2`J-^]^<^=CMtUON[+k"LbI1?DfNgL`QOPu
	>.f+MU8:Ku0C?8Xc-j.>NC,(pmZW'7<iroTo.>+4P0n_i.&4M`.2o/sY1D@b-QkS<?]^MTs6Q_+8)H
	EI6s2KShVQgEBD/u`XW7Z@*3timq+[';Y^?3$J,@[WkT5+_MUY=eg(*JllLN*o;HM1!4&Qs-nA"koK
	s@m;NHKtc+Z#mm0pf9QHAA:H$#j:uRFbn;%?%NB_bbr5:f,"POE:p[H*O]*,W7-:oVBN]UD[6`@uW]
	`#X^W#B!S9!P:R`[=U8;)!I^b.e^lTbB:[5kClf$/#1]g+)4=@6[sLAC8jHlq`NCf!iF7::D+.Sr=_
	UH1-l@+IPtG\j9KJS4%LimAp@P6%CnCu4<0`\K7EMGIi=JA>Y&Y6B*?FDa;2u9N$B?1S.VgPlb<lbU
	=4eX/b&8Tm<+<Y@V#oeHcsf[/"t=,H$6gQBne0%^P*V[3&+mA*WObQkhf&@u;SPGh)gWj%8B&V%oV;
	\;+fPUe,cQZYW4:(%bor'E9Zg@(R<[E3O@l@JXL+_-TnEh5-Sp?W."d`a5q"IZaCQY3"L?.NPu?#h-
	qW$QQ6IUmRL6Pb$sjnmllX`MX8K46\8X]LMc@&7>Zk:ip\T*X%*658SO_@EOY:HW>Gf+!YcC>+PB+b
	k#"61c>.K`r0sP*m5`mQf.-:97/4d?kLm9Jr*]Js(H:*-Z67<.l\?p=f7'&q1#srpJ:4g]VB]_Gr,,
	GTREcjMl_D"XnTY*%!YLYkoJ/GAPE#%%O=m2$%:bFi<&k^W;!6F3*+rB>"P(h1f5D"_oHD`M4.7FT^
	jAi!3K1QW*/4!F51lu8[OT?5^n(&i.!>aT#6&Gd2KSai5_dj(Z1a>M:dW$g=K'atsj[t6B#(`0n^_4
	Kc.=u)=0c["kj;'OE-!VYU*>?hR:eE/\+V\/_Z-&[V!l.VF!/(`A@R.Fi8LBb+`[&K6E?.K*fQ@@b>
	gJ&R>`C?Rm$FM\MV[:o&/,4S/-M>*q;I>WW2K[r)='j^5u_,*/.;Cf_%N9)N:Eom!O,Ds"G\Wl"3(D
	:n;MpK"KVHLUqCFb8Lt.)0:cld/s(nr)#qQ$cRBaX[801YL^>3'1dM0qPjQGW=_A`T`qs9n!J/@7j@
	`77k;a3\&G\KtVT'&<'2-o>_2.LM7H1(sS^iQ+&hZREo;A?0<[8k'gdF7>O1BElb\iYIA!++Fn+1*?
	C9se*ZSL39T9Y;#6</UH@XrQ$!<A!CqFIh="Vur'8&33<3#UnK!!G(lHfrVM3EW%e*bSOSOr4Dr6@s
	naSaoF<]k)idJrB0^P?<-j4I=u_CaB0iFf@HJohQJC!$K7GrRrcT%`IF0"Mq-#\`Seu3)t3WF&H=4P
	QcC]QZrStM=A3Vho'cX-NB;W`T"OBH%Hh07*LP0;A_8Y(Y@JJ;d%NIjPsMJ):kK1N0TX((G;:X=W,I
	e.8ACqIXSG=pl54gqYT8MKNq9:PgV.Qeh-)6%2V$m9`!!YkBCh4l$h6MW$Tm.?BL!0@Ot\$hgAXFh]
	T]'bZGEFK'b(Oj;N_EQQg'DL.b4Q9$8[31UYT-!%t*?VYiJll-(d_POmbbKW13I9(bnEPH!6aK"(;H
	Vp&p=f.h:!_)lGP7(/!sZ`%Nu:"dd`VZ+:Am?qB!-GUAhA%->*20@RN9%VF_/YtP0ftHY$WlA1_^A#
	s/ii.",%DM`-?!gTM*^BY$e1c*?ER/8![Bkd?r(eP#?)2HL_#R`,i^TSRg%)pqpZYI;EPd;\#ROa)H
	L_>K[]o?W7>JNo-=/LKrgsL\c6iS[!6iB=X[n;REo"TDCV07)&!ILG!`DX'd=R8L7J,U^4o`g^FZu7
	n-p*`>1L,,$_fu(5Ra!G1CjU'iU)P9Nl[SO)Cf[e+f'_l&m-i/%Y^Z8"ZQh^2c3^2e,YWn3a]NDT>(
	'&O-lZdj!k$Y.0)nN4hN4+\`_WKLh"R&)]`Kt[K,#CZq"J*'M@LR9'<&PYT@ZE?@$*?cDHe_<T7;%1
	\aq8k-nB>"N0H=YgP]&WPthiG9Q3C=d*;h"HL7eFQe.&Al9HUurQJ3\@KWs,j<>s7s4jTr(Oe98k9=
	u5QNTX'$98:mag)7W];ElrFCHdJKQ6tc:G*a""BX=>$PK#ZA@4%F%o@r@<B%Yl6XYe+p[T?&:7Qh,j
	Wf3P3DbgYn5>a9mH1^Bo($a8CIu>!"mqNe(\N;a5GQWhMdAN8aMlB4%egM,l&o\pX^tM7Eb.VOkj(k
	KT9Rb*>_T[@4OW(e`Sg^lO-$6dHTj([*seJ1>aM,BWoAtQBVnF!R)q"+n+-*>I`,Rtkd$1eU7C3F!J
	6n;M6WFiln[QK.EPs/1kZJrj4G=6."qmjFi287+NnD9L&]\K$g$rEo8gY3ER4=ZHarnDgTWI[!_0nY
	7!"5XW$E5%G-dGd!gN0`[Ek2aF))isad[0c-HH<cTJ+;4`s),Z^D%CGUe+^kb?1'c&'F>!bA(8]%g4
	Le+TMMb(Tt(KKE2$3nKl#u&3bQQlX0\VfTlaYh0EqZl?*JiqR*$U_6)IAI.VrnF/pQfY`]EuGhGtcL
	*F1j"Z,/Lq;QJ!B6,629[9&)ZYXpC'2NM*>:*3%8H1rNjF[M0HD^G7h@!0ZWWpg-Hb!t!SAkZ"ki@@
	o&r#0@16]AbG8UCCiE?u:Nsl)f=0?Q/)acIlB$C`IR5K?'e&gPo*"27_AIAiJ@(:J_FMjQurS.&e4(
	rE8UoM8"1U#frhZ!+ZKeH7JTL3]"#&=&Q\>LCNURLNIK#h0''6i$g:[.h-b3/WY'"mL`Jk0K;JE\6m
	%*;MM<mR1<I;$scT09c&:4)WQRp.i.EpN(<rO^rJqp)J<3Z8/Y-<m1YZ6jkW9hU3Flt;r<4-aP5/Z6
	QHBU\tnnWRnW)C39mo0KE"3?h$$)HKIsA15`)6+s1CG<RGMQ1V^"R##A;Z\B<`Tnru4/BI*YA8^1-Z
	/aqEYAJK><tCluF<9ncj$$u?NJg#Che6s.Z*F9`*<F-9BZ90eGEe@o(4YN9pRFHJXUDh9dG8bGjQtQ
	plSl/3#&1WFes,..34I.Vqe[XMD\&K/$A(pm9,?^Z2nB^VR2Qh>ARW^nQi&:a?V/QK%KsR6]"5'>L)
	ZU\qR_NC*jY/j4u><<ip;M35C`$u=]/5*TW!#\%J@afoMG)Ag@];=B8.LVjQ1UBoLl1o'\Tg*e\`0!
	`H-qRQ[fr/;-lDabMenYg'%j#%ejL==<:*MoC_"No>/;IV!!.+>r+CTaD$+D%-^eFQd+S:,XF+@7`f
	<pflIb%NIKX(\O`/8CA#/O9m,^H*^4l?SUc8`WT?HqlbK)":H^n?aT+<gEea56%@cIWI^=@t[\Ma[a
	5JGK2.1a,h\1/$._gZ<s&m1V?V/T@LPa1hRF9;(TEIXs1'u@3_2SuikIUNQ0<MCU/0!g@e]C<l"3G4
	5;Hku!kj>)8mrhc6Kf7^c*K"0NiT95UF@L@ZM<te;<Wq$UBg6kmFhTpeS4^R$P,-(LG$mbkX\^DJQS
	MIjHYV_.%"9Kcf7;&WF:SNF-c-#(#*!BO"Z%iEqC<d:l,MlHq/c(:,4NV?PO5I[2f2aQfDSl8edlHA
	ip=pZQ3Do[htlK9RP/^M7tWa=da*"F'j$)[Q%4!+6q([XAsfbD4MYY('#r)+=+tc>!&hJ'-BdGS.q\
	hQc/rA)cS#YAXNKh&)qTM6GsP,"G.QAbm@1Pkc3V(sGPK+GHiE9u?XC/:L<k>BZa!VuD69`>4Td)3n
	XlE;\JSMYjHeIT_kY,KE1eZ.!%89VM#DY\_YI/Ye<Ti6&;Wl]dZ\1\Ki?sXJPlRSi*Q!^hu<hHVE1d
	iVS0\;8ltjqo;^^BdIJb@EV&b_pXB*S2qD=#RGcm0H0LjKP\0_84uf"W2'\,nN.PM,&h9^DBKBj<ZR
	HMYh*=h73*[/,`Q;Y2Cb0;^%&gDfb_7796=ptCb_eB0XWtZ$XM@q3._C:?!]ED3=T1Q4(li7WP`D(<
	KN2@S?0Sd3JZCrY_u!j'V46XCmFE8FEWn9'k6dilX$3*LPhprZpX9kY5r_](8Kf1*-*K;K4%YUM%._
	iqX+%>s;?/EcZQN_Gr`m6c!X?XtRGrhaC"Z?YB%/!p0rhkf3/.lS&q7W7gNI2]lA5rVY[Un:&d8mLW
	LT7mN-aT79Is<pG0.?RJgEc#dSZ7umM$I&_U;?"70#Wb0#bMfon&GA1`]/AU?S;]!l@r0MX+^:FJ!*
	e/?9a9['VhUM=/TV&<9X0or%iO5Ou-GJ`J-8"+Yc5i"]99kKbRj&RW653)"ef*?/Q6RQ*)4?p"bW"\
	6T$YN-Z__o-"h2\8Nr]-p!>gj?p=+Mj97.26(a7Gu;kA>Oqj=!Y(L;@#cAH'L9dqG`?+n@hOB>NBgJ
	!X=H611u`p5YP3X9#9tOoH?(!1C3PGQShT@2Uqrc1gC93W%bZ?9F<s(_EUfV.@O7%AW]^)(P80e*+h
	6l]k8J'Kq/B=BYFOXpe%OEM,`u0El-[d*7u,W"eQmR2r9p1B49t2"JGQ;SK,)EE,>;Dd$-U`Vr2OiL
	fZjZ[:!PW#``84H9"JBIc2e/dt211Qng7S-KnJ5%5g+nW,(-\087;0Au*mI^H\Z2PXqV$Y$Kl;3p3-
	Ms/h?0pjp#2$DH;a"#]Fik-\_D[Gd-'iEup"BLp2!T0;f7oB+;i^T>Ce(t5]`_`J*!msK9@D>2o8=?
	g<lD#!m#^.VuMcHb$cQ'IUe]OCfl8DHfudE8[XW*aJsEGBIti8Vu8BD:cG-\Yg:Elm)?9lL,a>fM&;
	f:b,5^9M/7%4g!^c/3.X&/uPDrS%7ETqP[Khc*rirI1c?GS1'1F6E'$05]UTjo-j.eR:H+]gJtFa6e
	>"TXM:4O'H%Of!p%V!#4#iQ`XU+%YmPE7j!3TiOeQm]<8:hSPIe\X;H"f(Il!q4NJq'5(/5\WUYnk-
	GrZW2kH$kb+<S=E['?Z5@88m\X3P;qC8C>\^B1e,?,AiEi&@("eS^R]==df9SV:"`f>.%]j\e_J#)(
	P=!`hQ7uqj7[>i\qji]/hM^K(EOWC_(ch+pl3>7e3d2Il&n'CD@mQ#N4YM\eE\RQ3$f0?kt6k,f*-a
	!Z#j6+i-/Z!F&SZqP`R!E4ajRF&cm@f:VWesij-^nfNb0.uObKBo3&rB"#dF?Z&F66/7n*fZ2F^94h
	cA:^n>1'l->Y4&r)B*@*C8Cdc$dF&_?[I.32j'5b&J"ogV0[V;=3O?+<E3%9D/Ft41UF7M,pai;%hB
	2*,9['0EKZ/H/se(@/tVcSKB\/Y>lDV$hU$pm<Ho\)jS)WiHe4WR2OdDfP7p?o[/6im!f2GG$8ZAE`
	-Vir+X5AlNugH1kg6#*/7t@5D7A>%;c=oofY2e2`JYPmn[K->l-cCK*?BlS>t'sKd-TPuPF5_.4aZm
	=3h<FTXPC=*@p)sf_1Mu"Iei(9J,$pnGOM+XA&bfcbC[Q<.[Bl+c[Xg,gt^<)ET+cgA&jT=%1VE>\Q
	Q7NX]Vj&[']IrGMY?.qR!Ek?!Ua$Q'I7C/NS1JjOpkP!<`IT7>hqh[^OnurSi_g2Dd5nK>F7TU!_98
	Vk/3LcC?onrV^k]Fj$(&,GL)40CI]1]=u".jiWi%#cCS"_hSaE5CVCn/>(8?daBn#rd;K<J)J+n_hS
	aq.5RC9\om>=Wi@BO.&F#KY7Ca;Vb`qV3HHML6c6foK7gS>[@3sAV(BgTlKUETn6dd_A*-<-Z?Yp!p
	@e3RTqN]$Nju6-=k:4R^8ku%S@Pa@DnZCj=F=rRrdC\>Sg#ANcaR`4de<BX:"'+/h7Imc[Va,sZFmj
	*,@`d*fsbo"\T?S`6p).jX^&DWmbG@UlZRDn^%0;rR7tWhpID"+FmIV4_r9dMHS1Z.4n?Z=Xf\_7DV
	B4)fWeqAO!N1GE\W'[r7.iK91(d`lK#3[a2=V?r\sQ,FRr4B=09;]b%<1?>ISM+YQ+I&S#6#2;bpu2
	fiTg!g2!lL2E!bkcpN$4EQ=Y6Hes)7/_e!/Q%'t@]"Vt30#qu"^%^A`X&cq2m^m,WSB9l5NoQqaC"I
	JX.k<8X\.F_A!=TAFUsnRkOqQNXp[-]_KXgEXg[;Z=Y0kYErVQ?0@PK(lm-Hiard7pS>=V3(WDf^@H
	[Aht?@DkPpXe!IG'.p:%hCJ&AQd]&[\9Cg\@B&GVWObFDHac%\^0I)n*a&K;?6RiqK-#8O96"gSN:o
	kq!mM/jt0fG/6o^SbaC8*^%I];kA+jKCMn$-Bk^_bI_DYl-bsl\E&_*+=unW&3'')m5_":`E%KSqg^
	J^h"pP8A+$Nq7>l;A>&);HnSYg,hgUGL5MBa>jLCYK0Xf[$0JHtK+l]3)Ndacm5:8a-m5'#ZX3u`+P
	jeMQ7:g[G9HhVCXR\i**PK@A']^sF\n%RPbm3eNRd^JPlVr'XbprNC/m@X0l-TX:L?@DLs;l<B%17>
	h&pBi&bHK_%sRl4iag!7l<T?ju]eLJHj2Jq/io?B4TNK1`[F_g$]`_V'CP8cI<HM#HlcYn44J<\d(K
	<Gdp&);6Xh6U_;bU\:Go9b=bb?D2^8Sr=HBptMMD]T`4aCI'0]^e[+A`]($9+8^OBP=?CW-J:6f/&h
	/YK<1R4C5J)[[*8H\$WMeqB2-J!Uq]XDJO%2j`9m9>Ue4Vfi_K^)Mpil*&oW-1=FV!;I3[9>?fk3e.
	dh[7Rot6;G*qNk2p6uQHbjUMhk91PiF`S5[`j)V9>/V.k3$c\5+.O">ijEq0\l48COq2+>>W/eCW;b
	=]S<oO&@GGNDAE"8u4R143Pdh<ifD#<E7SsdF$InFRIqpoB4GT6D6pq&e"t;8kPss[BAg6L/D5^D;0
	5PDm-Vq]^<p_*)G6==gDT6o&Z!)Unjf^]Y$?JO*>_h!H9%!kOWh<FAu4=Ggb0tgRC_Z/mc3Cg=eT3m
	bIC(o$sdBY@#'$>@s>$h/L7@jlPUSe^^e(XTJY-a^jt`OX#!kF`Z`k2,1EVWQFW'Dr8:"R<,p/pJt!
	_c0!9?4^&R:(DBYkH+=L'>8W870D>;AZY.UU4aZn*?+U)-.Js#>f<&8dE8e[fg0/E`f>po>V7`dRgP
	op9NoQp5WKE=*TqS/M*dL.&jn0Q&:NJJn'RQS$ISrf6Hp4`<,.cRV.4m+Td+-ZH;cD/qeQ#ULAX[3n
	*Zl7;fsYaehsVqeZ*CQ1.-1'#Bq!rJpG@/">?`WogTb8/^4#m9MMd]P?!:B6R7a<Q2)o3oSio1u*08
	-'%6%e:N8ii+N:5](<%=G6Q^3r+V?t'$o*#2H<%9a`2HF'fHmS+'1In1eBHRlMmHk@:6KcXbX/rDPF
	kn9V-ko9!&j(=*m-3c^1bG3A\un,7-b#>gqsUnF&DlbYf<oJM_Z<"J&nu9&[r'm.D'B=@63)ZML1*'
	%j1=[Jn8L"Hqsf_sm(GS:0VIaChsXpdI/3L'gE1n>iG^b]<`ZY;_Zgh-.a4DV-3j_Z*dd6.c`.p')f
	sj5V.6[oHBahJCIjLFG+iWibX)TYZ5OW"[VXW+gU7Y;R7o*,-KaHAY3T#rjZ&:@k0'mVbP>nAAo2C%
	:JXbf=-m>4F6:]'6m>7&80kKdoB*Wq3nJLq\X_usd:i1=fs?AqPa%EfFk9oZiuC71q!GQJIcd&22K%
	=6Xg9HT"&N$!k4AC<7n5A'N+naRp%="J-5\aoVal:E\Y%I4p3s3DW$j;P^Mr.`hsZn0Y$/6ufWepS,
	_YCJm!RcG(WsqE++3QDT?h`Rkg;P?p3:tr&gIb&e@+aT1?nQ1YN3"Q]&)5tI+(eK\ZY8?KP-:hRPh.
	V\N,kq4S@3&kKfcMr:.flrTR+)95XfCc^t*_O+,TBnl.+#D(3r&kMsRiRQfrObk_98Y!?V&!eE@Qk+
	pI?V,U;h;)fOZE8\No,=a<..X\_!TckJ<kAn+i;7jHPKb-%PbjbFUQW*)<dHAiJ:II^5*!l`L_-dg>
	AS%_$.%-qMM*rt&]QiMYOcbcg_MPh+]5QT@!s];aV/Es9`f1org:$D%4k&\f?nb\e>MIia\U4)=80h
	);>?facUnjffXK91Os5M"U!"t.,i8A!&*3QHI`cOOS831&.4XiU8i^?X@Od+::>u1"q#7%Tgm(.?*U
	=#oVgI"=qfkg@SC.p'f(kuanYuo6IZ+n'Rd75;Gm-G,`!ggCjqu'5`9uFld\unOI&Llf\DnL)^kg=K
	5]kuN4cHa^K2#?-_%k_2$q!d7[!'HEjWiiqEH>$st5WB`A:%S/Mj'0!1`>-rq?KaMaVj/F/lU'Ff]'
	bFj.ukZ6qWtQ7[^NW)NK'JkH#hB29tEM;i6^?;IdG^lVk8FLXf]k:pH+CVkg6$C`l@#tip1^WCMR_/
	b/t295()[u[sC*AXf\_?^]09PhXFe<2rB"hTqT<kpD:OiV$r-s#7hkL,SIMm[HGl.YH"UkfW)V2<Dl
	_8p?^HkhgBL]Jd&!IV%!kC-Vg1n;O3Q3@'V0odB$KWH?sm\mbBgLp?^YmhSI%ENfK.JdSeDc^Ckehn
	2Bp$OcaePep4rS#S\'kqg?,kHhTEV2TFeIrr2mGZ^:gQE4DmHBuc5SgU:rL.4I9&nmj-_C2%BBIf/u
	*6!`(O"9L/,/LO>cI.>/llg*ji?G+qHh0o1f[gO@TPZtV7*>o_,66&4=I-oXq!-DKW"9Q2Zmp<_Uq:
	rN%GO3uPo[?U^Rl>8!B^!g:6QI0f\87^\U*dYOeZTaK4Z#"&E8eY?@mVUZO2pG-R8['ajI)OU_o'aD
	c&kPmTqT;Fh1:-.JUrB[CY-k&4*QSSBUVt'=(b[ef[s:MO[pg_NK&oJ<ikf%b%*7qeC;uYR\it4R7p
	X_='&F'H:DIE;j0^qf6)4AT/U\[B?:>ZJ\&ER.:k%G)]K`c2/Ce&`J^M=W+B,7ldjV:Q'@L=+c;29K
	>Cq>OVerR#mQ#TQS+g`@g4`ee*40DZL[R,c\P>m;UK/7)N>BWR58LRIfI9=$U#e;#a%Y'&rC/*fo_C
	/dkj-I3guP-%Du"7fsVoX7&m;g$O'9SQ-88UU!SIB*Y*tgc_%E,H7kO/UAF`_lK[YR3#mjq&rB"R;,
	M[e]?fXj.Olo"/bRt;C2*fX=dJ)-p%A!CQ'K>-`MKE-!s8XsagGa*)UgN+K;k]D`AC<8&Q)0.[C(_+
	iL64(<%?GMf>l*.QS*,hBou:o<)a]hdF[!::8_lCCH$(^?l4X$lbQtJG^*=_g!J*mf[sllG#(n02Og
	6rDr.KoX/(uGAL.tG,tjPK>k[;AoiB@)1XQ"_`A!h1^_<]JkRt'nT`I.C3sm0k'A[t\DF.,oq/a^Eh
	WWhF_RNt3Uo*cBV9MD)FN9C^%1NcI<iqg6()(B>3^Sak:LVsC$_'ld5&Hc>dJSDHkXq@6_(IQq^m,,
	@jjNc#6[8Lq[gsNB(_2=f/R(-<_>O_D#C]ZW#fA@/jNNi2iNM1.n13=9`QdpSE)$+W!VB=:BgCPiaT
	);@!(fUS7'8jaJc
	ASCII85End
End

Function custSizeBinsButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Execute "custSizeBins()"
			break
	endswitch

	return 0
End

Function defSizeBinsButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			SVAR sizeBinsTextList = root:Panel:sizeBinsTextList
			sizeBinsTextList = wave2list(root:Panel:defSizeBins)
			duplicate /o root:Panel:defSizeBins, root:Panel:sizeBins
			break
	endswitch

	return 0
End

Function defFlBinsButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			SVAR flBinsTextList = root:Panel:flBinsTextList
			flBinsTextList = wave2list(root:Panel:defFlBins)
			duplicate /o root:Panel:defFlBins, root:Panel:flBins
			break
	endswitch

	return 0
End

Function defAFBinsButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			SVAR AFBinsTextList = root:Panel:AFBinsTextList
			AFBinsTextList = wave2list(root:Panel:defAFBins)
			duplicate /o root:Panel:defAFBins, root:Panel:AFBins
			break
	endswitch

	return 0
End

Function cancelButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			DoWindow /K kwTopWin
			break
	endswitch

	return 0
End

Function custSizeBinsOKButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			setdatafolder root:Panel
			SVAR sizeBinsTextList
			wave sizeBinsListSW
			make /o/t/n=(itemsinlist(sizeBinsTextList)) sizeBinsList = stringfromlist(p, sizeBinsTextList)
			Redimension /n=(numpnts(sizeBinsList)) sizeBinsListSW
			wave sizeBins
			redimension /n=(numpnts(sizeBinsList)) sizeBins
			wave temp = textWave2numWave(sizeBinsList)
			sizeBins = temp
			make /o/n=(numpnts(sizeBins)-1) dLogDp = log(sizeBins[p+1])-log(sizeBins[p])
			wave sizeBM = getLogBM(sizeBins, "Size")

			SVAR FlBinsTextList
			wave flBinsListSW
			make /o/t/n=(itemsinlist(flBinsTextList)) flBinsList = stringfromlist(p, flBinsTextList)
			Redimension /n=(numpnts(flBinsList)) flBinsListSW
			wave flBins
			redimension /n=(numpnts(flBinsList)) flBins
			wave temp = textWave2numWave(flBinsList)
			flBins = temp
			make /o/n=(numpnts(flBins)-1) dLogFl = log(flBins[p+1])-log(flBins[p])
			wave flBM = getLogBM(flBins, "Fluo")
			
			SVAR AFBinsTextList
			wave AFBinsListSW
			make /o/t/n=(itemsinlist(AFBinsTextList)) AFBinsList = stringfromlist(p, AFBinsTextList)
			Redimension /n=(numpnts(AFBinsList)) AFBinsListSW
			wave AFBins
			redimension /n=(numpnts(AFBinsList)) AFBins
			wave temp = textWave2numWave(AFBinsList)
			AFBins = temp
			make /o/n=(numpnts(AFBins)-1) dAF = AFBins[p+1]-AFBins[p]
			wave afBM = getLogBM(afBins, "AF")
			
			setdatafolder root:
			DoWindow /K kwTopWin
			break
	endswitch

	return 0
End

Function loadDataButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
		
			wave BLs = root:Baseline:BLs
		
			if(!waveexists(BLs))
				setdatafolder root:
				Abort "Please load the forced trigger data first"
			endif
		
			NVAR timeRes = root:panel:timeRes
			NVAR flowRate = root:panel:flowRate
			ControlInfo T0_minSize; variable minSizeThresh = V_value
			ControlInfo T0_loadFl1CheckBox; variable loadFl1flag = V_value
			ControlInfo T0_loadFl2CheckBox; variable loadFl2flag = V_value
			ControlInfo T0_loadFl3CheckBox; variable loadFl3flag = V_value
			ControlInfo T0_loadAFCheckBox; variable loadAFflag = V_value
			wave sizebins = root:Panel:sizeBins
			wave flbins = root:Panel:flBins
			wave afbins = root:Panel:afBins
			wave prototypes = root:Prototypes:prototypes
			wave prototypeNames = root:Prototypes:prototypeNames
			
			loadWIBSdata(timeRes, flowRate, minSizeThresh, sizeBins, flBins, AFBins, 1, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFFlag, 1,  prototypes=prototypes, prototypeNames=prototypeNames) // zero is so we don't load clusters
			refreshTypes(prototypeNames=prototypeNames)
			
			break
	endswitch

	return 0
End

Function addNewPrototype(threshWave, AndOr, Not, newName) // of trypto280, nadh280, nadh370, minsize, maxsize, string name
	wave threshWave
	variable AndOr
	variable Not
	string newName
	
	STRUCT prototype newPrototype
	
	NewPrototype.FL1Min = threshWave[0]
	NewPrototype.FL1Max = threshWave[1]
	NewPrototype.FL2Min = threshWave[2]
	NewPrototype.FL2Max = threshWave[3]
	NewPrototype.FL3Min = threshWave[4]
	NewPrototype.FL3Max = threshWave[5]
	NewPrototype.minSize = threshWave[6]
	NewPrototype.maxSize = threshWave[7]
	NewPrototype.AndOr = AndOr
	NewPrototype.Not = Not
	string newProtoName = newName
	
	wave prototypes = root:prototypes:prototypes
	wave /t prototypeNames = root:prototypes:prototypeNames
	//check if its a duplicate
	findvalue /TEXT=newProtoName prototypeNames
	variable writeIndex = V_value
	if(writeIndex != -1) // prototype of that name already exists
		DoAlert 2, "A prototype of that name already exists. OK to overwrite?"
	endif
			
	if(writeIndex == -1)
		//if not duplicate
		Redimension/N=(-1,dimsize(prototypes,1)+1) prototypes
		structput NewPrototype prototypes[dimsize(prototypes,1)-1]
		InsertPoints numpnts(prototypeNames), 1, prototypeNames
		prototypeNames[numpnts(prototypeNames)] = newProtoName
	elseif(V_flag == 1 || writeIndex != -1)
		// if duplicate and overwriting
		structput NewPrototype prototypes[writeIndex]
	endif
	
		/// update drop down list

End


Function waspTabProc(tca) : TabControl
	STRUCT WMTabControlAction &tca

	switch( tca.eventCode )
			case 2: // mouse up
				Variable tab = tca.tab
				break
	endswitch
	
	variable i, hideflag
	string controls = controlNameList("")
	string thiscontrol
	for(i = 0; i < itemsinlist(controls); i += 1)
		thiscontrol = stringfromlist(i, controls)
			strswitch(thiscontrol[0,2])
			case "T0_": // belongs to first tab
				hideflag = (tab != 0)
				break
			case "T1_": // belongs to second tab
				hideflag = (tab != 1)
				break
			case "T2_": // belongs to third tab
				hideflag = (tab != 2)
				break
			case "T3_": // belongs to fourth tab
				hideflag = (tab != 3)
				break
			case "T4_": // belongs to fifth tab
				hideflag = (tab != 4)
				break
			//case "T5_": // belongs to fifth tab
			//	hideflag = (tab != 5)
			//	break
			case "T14": // belongs to second and fifth tab
				hideflag = (tab != 1) && (tab != 4)
				break
			case "T23": // belongs to third and fourth tab
				hideflag = (tab != 2) && (tab != 3)
				break
			case "TPB": // progress bar
				hideflag = (tab != 0) && (tab != 4)
				break
			case "TVL": // variable list
				hideflag = (tab != 1) && (tab != 4) //&& (tab != 5)
				break
			default:
				hideflag = 0
				break
		endswitch
		
		if(cmpstr(thisControl, "T0_loadSizeCheckBox") == 0 && hideflag == 0)
			hideflag=2
		endif
		
		controlinfo /w=waspPanel $thiscontrol
		switch (abs(v_flag))
			case 1:
				button $thiscontrol disable=hideflag
				break
			case 2:
				checkbox  $thiscontrol disable=hideflag
				break
			case 3:
				popupmenu $thiscontrol disable=hideflag
				break
			case 4:
				valdisplay $thiscontrol disable=hideflag
				break
			case 5:
				setvariable $thiscontrol disable=hideflag
				break
			case 6:
				chart $thiscontrol disable=hideflag
				break
			case 7:
				slider $thiscontrol disable=hideflag
				break
			case 8:
				tabcontrol $thiscontrol disable=hideflag
				break
			case 9:
				groupbox $thiscontrol disable=hideflag
				break
			case 10:
				titlebox $thiscontrol disable=hideflag
				break
			case 11:
				listbox $thiscontrol disable=hideflag
				break
		endswitch
	endfor
	return 0
End


Function ProtoOrCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox T0_ProtoAnd value=0
			CheckBox T0_ProtoOr value=1
			break
	endswitch

	return 0
End

Function ProtoAndCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox T0_ProtoAnd value=1
			CheckBox T0_ProtoOr value=0
			break
	endswitch

	return 0
End

Function HighGainCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox dispHighGain value=1
			CheckBox dispLowGain value=0
			refreshSeriesDisp()
			break
	endswitch

	return 0
End

Function LowGainCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox dispHighGain value=0
			CheckBox dispLowGain value=1
			refreshSeriesDisp()
			break
	endswitch

	return 0
End

Function ViewSeriesButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			
			wave /t types = root:panel:types
			duplicate /o types, root:panel:seriesList
			wave seriesList = root:Panel:seriesList
			make /o/n=(numpnts(seriesList)) root:Panel:seriesSW
			wave seriesSW = root:Panel:seriesSW
			controlInfo T0_typeList
			seriesSW = 0
			seriesSW[V_value-1] = 1
						
			DoWindow /K/Z Series
			display /N=Series
			
			controlBar /L 100
			ListBox sizeBinList,pos={0,0},size={100,400},listWave=root:Panel:seriesList
			ListBox sizeBinList,selWave=root:Panel:seriesSW,mode= 4,proc=SeriesListBoxProc
			
			refreshSeriesDisp()
			break
	endswitch

	return 0
End

Function SeriesListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			refreshSeriesDisp()
			break
		case 3: // double click
			break
		case 4: // cell selection
			refreshSeriesDisp()
		case 5: // cell selection plus shift key
			refreshSeriesDisp()
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
	endswitch

	return 0
End

Function refreshSeriesDisp()
	variable i
	string tracesDisplayed = TraceNameList("series", ";", 1)
	
	ControlInfo T2_Number; variable NumberFlag = V_Value
	ControlInfo T2_Volume; variable VolumeFlag = V_Value
	ControlInfo T2_SA; variable SAFlag = V_Value
	
	SVAR dataFolder = root:Panel:dataFolder

	dataFolder = "root:Data:"
	
	for(i = 0; i < itemsInList(tracesDisplayed); i +=1)
		string thisTraceName = stringFromList(i, tracesDisplayed)
		RemoveFromGraph $thisTraceName
	endfor

	wave /t seriesList = root:Panel:seriesList
	wave seriesSW = root:Panel:seriesSW

	ColorTab2Wave rainbow
	wave M_colors
	variable tot = numpnts(seriesList)
	variable l = dimSize(M_colors,0)
	
	for(i = 0; i < numpnts(seriesList); i += 1)
		if(seriesSW[i] == 1)
			wave /z protoToDisp = $(dataFolder+seriesList[i])
			if(waveexists(protoToDisp))
				AppendToGraph /C=(M_colors[I*l/tot][0], M_colors[I*l/tot][1], M_colors[I*l/tot][2]) protoToDisp
			endif
		endif
	endfor

	killwaves M_colors
		
	SetAxis /Z left, 0, *
	Label /Z left "Conc (#/l\\S-1\\M)"
	Label /Z bottom "Time"
	Legend /C/N=text0/A=RT
End

Function loadSPDButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			NVAR pc = root:Panel:pcSPDtoLoad
			ControlInfo T0_minSize; variable minSizeThresh = V_value
			ControlInfo T1_raw; variable rawOrNot = V_value
			loadSPD(pc, rawOrNot, minSizeThresh)
			break
	endswitch

	return 0
End

Function PlotSelectedSPDwavesButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			wave /t xSPDwaves = root:Panel:xSPDwaves
			wave /t ySPDwaves = root:Panel:ySPDwaves
			wave xSPDwavesSW = root:Panel:xSPDwavesSW
			wave SPD = root:SP:SPD
		
			extract /t/o xSPDwaves, xWavesToPlot, xSPDwavesSW == 1
			wave /t xWavesToPlot
			
			controlInfo T1_ySPDwaves
			if(sum(xSPDwavesSW) == 0 || sum(ySPDwavesSW) == 0) // if no waves selected in either col
				break
			endif

			variable i, xwColNo, ywColNo
			string traceName
			ywColNo = FindDimLabel(SPD,1, ySPDwaves[V_value])
			display /N='SPD_scatter'
			for(i = 0; i < numpnts(xWavesToPlot); i += 1) // loops round the x wavs to plot
				xwColNo = FindDimLabel(SPD, 1, xWavesToPlot[i])
				traceName = GetDimLabel(SPD, 1, xwColNo) + " vs " + GetDimLabel(SPD, 1, ywColNo)
				
				appendtograph SPD[][xwColNo] /TN=$traceName vs SPD[][ywColNo]
			endfor
			KBColorizeTraces(0.4, 0.8, 0)
			modifyGraph mode=3
			legend

			killwaves xWavesToPlot
			break
	endswitch

	return 0
End

// this function takes a distribution consisting of 5 columns (mean, median 75th, 25th, 90th, 10th), size, and y axis label str
Function plotDistri(dist, bm, ylabel, xlabel, name)
	wave dist, bm
	string ylabel, xlabel, name
	
	NVAR minSizeThresh = root:Panel:minSizeThresh
	
	display /N=$name dist[][4] vs bm
	appendtograph dist[][5] vs bm
	appendtograph dist[][2] vs bm
	appendtograph dist[][3] vs bm
	appendtograph dist[][1] vs bm
	appendtograph dist[][0] vs bm
	
	ModifyGraph mode[0]=7,lsize[0]=0,hbFill[0]=5,toMode[0]=1
	ModifyGraph lsize[1]=0
	ModifyGraph mode[2]=7,lsize[2]=0,hbFill[2]=4,toMode[2]=1
	ModifyGraph lsize[3]=0
	ModifyGraph lsize[4]=2, lsize[5]=2, lstyle[4]=3

	ModifyGraph fStyle=1,axThick=2;DelayUpdate
	Label left ylabel;DelayUpdate
	Label bottom xlabel
	SetAxis bottom minSizeThresh, *
	ModifyGraph log(bottom)=1
End

Function NewToDoButtonProc(ba) : ButtonControl // ltd to size type todos currently
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
	
		SVAR name = root:Panel:newToDoName
		if(strlen(name) == 0)
			DoAlert 0, "Please enter a todo name"
		elseif(strsearch(name, " ", 0) != -1) // needs parsing
			parseToDoStr(name)
		else // needs creating
			NVAR startPt = root:Panel:toDoStartPt
			NVAR endPt = root:Panel:toDoEndPt
			wave varSW = root:Panel:SizeBinsListSW
			SVAR name = root:Panel:newToDoName
			createToDo(startPt, endPt, varSW, "SD", name)
		endif

	refreshToDoList()
			break
	endswitch

	return 0
End

Function DelToDoButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			ControlInfo ToDoList
			
			if(cmpstr(S_value,"All") == 0)
				DoAlert 0, "You cannot delete the \"All\" todo wave"
			else
				wave gonner = $("root:ToDoWaves:" + S_value)
				killwaves gonner
				refreshToDoList()
			endif
			break
	endswitch

	return 0
End

Function refreshToDoList()
	SVAR toDoList = root:Panel:ToDoList
	
	setdatafolder root:ToDoWaves
	toDoList = WaveList("*", ";", "")
	SVAR name = root:Panel:newToDoName
	PopupMenu ToDoList popmatch="*"
	setdatafolder root:
End

Function InterpBLsCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
		 	CheckBox T0_avgFlThresh value=0
			break
	endswitch

	return 0
End

Function AvgBLCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox T0_interpFlThresh value=0
			break
	endswitch

	return 0
End

Function clearSPDButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			wave /t xnames = root:Panel:xSPDwaves
			wave xsw = root:Panel:xSPDwavesSW
			wave SPD = root:SP:SPD
			
			extract /o/indx xnames, temp, xsw
			string selectedName = xnames[temp[0]]
			variable deleteCol = FindDimLabel(SPD, 1, selectedName) 
			
			DeletePoints /M=1 deleteCol, 1, SPD
			 
			refreshSPDlist()
			break
	endswitch

	return 0
End

Function LoadFTButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			loadFTdata()
			break
	endswitch

	return 0
End

Function TypeSizeCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox typeFl value=0
			CheckBox typeAF value=0
			break
	endswitch

	return 0
End

Function typeFlCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox typeSize value=0
			CheckBox typeAF value=0
			break
	endswitch

	return 0
End

Function typeAFCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox typeFl value=0
			CheckBox typeSize value=0
			break
	endswitch

	return 0
End


Function ImagePlotTab2ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			NVAR minSizeThresh = root:Panel:minSizeThresh
			ControlInfo T2_Number; variable NumberFlag = V_Value
			ControlInfo T2_Volume; variable VolumeFlag = V_Value
			ControlInfo T2_SA; variable SAFlag = V_Value

			ControlInfo toDoList
			wave thisToDo = $("root:ToDoWaves:"+S_value)
			
			SVAR dataFolder = root:Panel:dataFolder
			
			wave /t types = root:Panel:types
			wave typesSW = root:Panel:typesSW
			extract /o/free/t types, selectedTypes, typesSW
			SVAR dataFolder = root:Panel:dataFolder
			
			string plotName
			variable i
			for(i = 0; i < numpnts(selectedTypes); i += 1)
				if(NumberFlag)
					wave thisImage = $(dataFolder + selectedTypes[i] + "_SD")
					SetDataFolder root:DataProducts
					wave thisBins = root:Panel:SizeBins
					wave thisToDoSD = inThisToDo(thisToDo, thisImage)
					plotName = "NumberSizeImage"+selectedTypes[i]
					display /N=$plotName; appendimage thisToDoSD vs {*,thisBins}
					ModifyGraph log(left)=1
					ModifyImage '' ctab={0,*,Rainbow,1}
					killwaves /z thisToDoSD
					Label left "Dp (um)"
				elseif(VolumeFlag)
					wave thisImage = $(dataFolder +  selectedTypes[i] + "_SD")
					SetDataFolder root:DataProducts
					wave thisBins = root:Panel:SizeBins
					wave thisBM = root:Panel:SizeBM
					wave thisToDoSD = inThisToDo(thisToDo, thisImage)
					wave thisToDoVolSD = NumTimeDist2VolTimeDist(thisToDoSD, thisBM)
					killwaves /z thisToDoSD
					plotName = "VolSizeImage"+selectedTypes[i]
					display /N=$plotName; appendimage thisToDoVolSD vs {*,thisBins}
					ModifyGraph log(left)=1
					ModifyImage '' ctab={0,*,Rainbow,1}
					Label left "Dp (um)"
				elseif(SAFlag)
					wave thisImage = $(dataFolder + selectedTypes[i] + "_SD")
					SetDataFolder root:DataProducts
					wave thisBins = root:Panel:SizeBins
					wave thisBM = root:Panel:SizeBM
					wave thisToDoSD = inThisToDo(thisToDo, thisImage)
					wave thisToDoSASD = NumTimeDist2VolTimeDist(thisToDoSD, thisBM)
					killwaves /z thisToDoSD
					plotName = "SASSizeImage" + selectedTypes[i]
					display /N=$plotName; appendimage thisToDoSASD vs {*,thisBins}
					ModifyGraph log(left)=1
					ModifyImage '' ctab={0,*,Rainbow,1}
					Label left "Dp (um)"
				endif
				
				Label bottom "Time"
				setaxis left minsizethresh, *
			endfor // rount types
	
			setdatafolder root:
	
			break
	endswitch

	return 0
End

Function ImagePlotTab3ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			NVAR minSizeThresh = root:Panel:minSizeThresh
			ControlInfo T3_NumberSize; variable NumberSizeFlag = V_Value
			ControlInfo T3_VolumeSize; variable VolumeSizeFlag = V_Value
			ControlInfo T3_SASize; variable SASizeFlag = V_Value
			ControlInfo T3_NumberFl1; variable NumberFl1Flag = V_Value
			ControlInfo T3_NumberFl2; variable NumberFl2Flag = V_Value
			ControlInfo T3_NumberFl3; variable NumberFl3Flag = V_Value
			ControlInfo T3_NumberAF; variable NumberAFFlag = V_Value
			ControlInfo toDoList
			wave thisToDo = $("root:ToDoWaves:"+S_value)
			
			wave /t types = root:Panel:types
			wave typesSW = root:Panel:typesSW
			extract /o/free/t types, selectedTypes, typesSW
			SVAR dataFolder = root:Panel:dataFolder
			
			string plotName
			variable i
			for(i = 0; i < numpnts(selectedTypes); i += 1)
				if(NumberSizeFlag)
					wave thisImage = $(dataFolder + selectedTypes[i] + "_SD")
					SetDataFolder root:DataProducts
					wave thisBins = root:Panel:SizeBins
					wave thisToDoSD = inThisToDo(thisToDo, thisImage)
					plotName = "NumberSizeImage" + selectedTypes[i]
					display /N=$plotName; appendimage thisToDoSD vs {*,thisBins}
					ModifyGraph log(left)=1
					ModifyImage '' ctab={0,*,Rainbow,1}
					killwaves /z thisToDoSD
					Label left "Dp (um)"
				elseif(VolumeSizeFlag)
					wave thisImage = $(dataFolder + selectedTypes[i] + "_SD")
					SetDataFolder root:DataProducts
					wave thisBins = root:Panel:SizeBins
					wave thisBM = root:Panel:SizeBM
					wave thisToDoSD = inThisToDo(thisToDo, thisImage)
					wave thisToDoVolSD = NumTimeDist2VolTimeDist(thisToDoSD, thisBM)
					plotname = "VolSizeImage" + selectedTypes[i]
					display /N=$plotName; appendimage thisToDoVolSD vs {*,thisBins}
					ModifyGraph log(left)=1
					ModifyImage '' ctab={0,*,Rainbow,1}
					Label left "Dp (um)"
				elseif(SASizeFlag)
					wave thisImage = $(dataFolder + selectedTypes[i] + "_SD")
					SetDataFolder root:DataProducts
					wave thisBins = root:Panel:SizeBins
					wave thisBM = root:Panel:SizeBM
					wave thisToDoSD = inThisToDo(thisToDo, thisImage)
					wave thisToDoSASD = NumTimeDist2VolTimeDist(thisToDoSD, thisBM)
					plotName = "SASizeImage" + selectedTypes[i]
					display /N=$plotName; appendimage thisToDoSASD vs {*,thisBins}
					ModifyGraph log(left)=1
					ModifyImage '' ctab={0,*,Rainbow,1}
					Label left "Dp (um)"
				elseif(NumberFl1Flag)
					wave thisImage = $(dataFolder + selectedTypes[i] + "_Fl1D")
					SetDataFolder root:DataProducts
					wave thisBins = root:Panel:FlBins
					wave thisToDoFlD = inThisToDo(thisToDo, thisImage)
					plotName = "NumberFl1Image" + selectedTypes[i]
					display /N=$plotName; appendimage thisToDoFlD vs {*,thisBins}
					ModifyImage '' ctab={0,*,Rainbow,1}
					Label left "Fluo"
				elseif(NumberFl2Flag)
					wave thisImage = $(dataFolder + selectedTypes[i] + "_Fl2D")
					SetDataFolder root:DataProducts
					wave thisBins = root:Panel:FlBins
					wave thisToDoFlD = inThisToDo(thisToDo, thisImage)
					plotName = "NumberFl2Image" + selectedTypes[i]
					display /N=$plotName; appendimage thisToDoFlD vs {*,thisBins}
					ModifyImage '' ctab={0,*,Rainbow,1}
					Label left "Fluo"
				elseif(NumberFl3Flag)
					wave thisImage = $(dataFolder + selectedTypes[i] + "_Fl3D")
					SetDataFolder root:DataProducts
					wave thisBins = root:Panel:FlBins
					wave thisToDoFlD = inThisToDo(thisToDo, thisImage)
					plotName = "NumberFl3Image" + selectedTypes[i]
					display /N=$plotName; appendimage thisToDoFlD vs {*,thisBins}
					ModifyImage '' ctab={0,*,Rainbow,1}
					Label left "Fluo"
				elseif(NumberAFFlag)
					wave thisImage = $(dataFolder + selectedTypes[i] + "_AFD")
					SetDataFolder root:DataProducts
					wave thisBins = root:Panel:AFBins
					wave thisToDoAFD = inThisToDo(thisToDo, thisImage)
					plotName = "AsymmFacSizeImage" + selectedTypes[i]
					display /N=$plotName; appendimage thisToDoAFD vs {*,thisBins}
					ModifyImage '' ctab={0,*,Rainbow,1}
					ModifyGraph log(left)=1
					Label left "AF"
				endif
	
				Label bottom "Time"
				setaxis left minSizeThresh, *
			endfor // round different types to plot
			setdatafolder root:
			
			break
	endswitch

	return 0
End

Function DistriPlotButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			ControlInfo T3_NumberSize; variable NumberSizeFlag = V_Value
			ControlInfo T3_VolumeSize; variable VolumeSizeFlag = V_Value
			ControlInfo T3_SASize; variable SASizeFlag = V_Value
			ControlInfo T3_NumberFl1; variable NumberFl1Flag = V_Value
			ControlInfo T3_NumberFl2; variable NumberFl2Flag = V_Value
			ControlInfo T3_NumberFl3; variable NumberFl3Flag = V_Value
			ControlInfo T3_NumberAF; variable NumberAFFlag = V_Value
			
			ControlInfo toDoList
			wave thisToDo = $("root:ToDoWaves:"+S_value)
			
			wave /t types = root:Panel:types
			wave typesSW = root:Panel:typesSW
			extract /o/free/t types, selectedTypes, typesSW
			SVAR dataFolder = root:Panel:dataFolder
			
			variable i
			for(i = 0; i < numpnts(selectedTypes); i += 1)
				if(NumberSizeFlag)
					SetDataFolder root:DataProducts
					wave thisSD = $(dataFolder + selectedTypes[i] + "_SD")
					wave thisBM = root:Panel:SizeBM
					wave thisToDoSD = inThisToDo(thisToDo, thisSD)
					wave thisToDoAvgSD = calcAvgDistri(thisToDoSD)
					killwaves /z thisToDoSD
					plotDistri(thisToDoAvgSD, thisBM, "dN/dLogDp (#/l)", "Size (um)", "NumSizeDist"+selectedTypes[i])
				elseif(VolumeSizeFlag)
					SetDataFolder root:DataProducts
					wave thisSD = $(dataFolder + selectedTypes[i] + "_SD")
					wave thisBM = root:Panel:SizeBM
					wave thisToDoSD = inThisToDo(thisToDo, thisSD)
					wave thisToDoVolSD = NumTimeDist2VolTimeDist(thisToDoSD, thisBM)
					wave thisToDoAvgSD = calcAvgDistri(thisToDoVolSD)
					killwaves /z thisToDoSD, thisToDoVolSD
					plotDistri(thisToDoAvgSD, thisBM, "dV/dLogDp (um\S3\M/l)", "Size (um)", "VolSizeDist"+selectedTypes[i])
				elseif(SASizeFlag)
					SetDataFolder root:DataProducts
					wave thisSD = $(dataFolder + selectedTypes[i] + "_SD")
					wave thisBM = root:Panel:SizeBM				
					wave thisToDoSD = inThisToDo(thisToDo, thisSD)
					wave thisToDoSASD = NumTimeDist2SATimeDist(thisToDoSD, thisBM)
					wave thisToDoAvgSD = calcAvgDistri(thisToDoSASD)
					killwaves /z thisToDoSD, thisToDoSASD
					plotDistri(thisToDoAvgSD, thisBM, "dSA/dLogDp (um\S2\M/l)", "Size (um)", "SASizeDist"+selectedTypes[i])
				elseif(NumberFl1Flag)
					SetDataFolder root:DataProducts
					wave thisFlD = $(dataFolder + selectedTypes[i] + "_Fl1D")
					wave thisBM = root:Panel:flBM
					wave thisToDoFlD = inThisToDo(thisToDo, thisFlD)
					wave thisToDoAvgFlD = calcAvgDistri(thisToDoFlD)
					killwaves /z thisToDoFlD
					plotDistri(thisToDoAvgFlD, thisBM, "dN/dFl (#/l)", "Fluo", "NumFl1Dist"+selectedTypes[i])
					ModifyGraph log(bottom)=0
				elseif(NumberFl2Flag)
					SetDataFolder root:DataProducts
					wave thisFlD = $(dataFolder + selectedTypes[i] + "_Fl2D")
					wave thisBM = root:Panel:flBM
					wave thisToDoFlD = inThisToDo(thisToDo, thisFlD)
					wave thisToDoAvgFlD = calcAvgDistri(thisToDoFlD)
					killwaves /z thisToDoFlD
					plotDistri(thisToDoAvgFlD, thisBM, "dN/dFl (#/l)", "Fluo", "NumFl2Dist"+selectedTypes[i])
					ModifyGraph log(bottom)=0
				elseif(NumberFl3Flag)
					SetDataFolder root:DataProducts
					wave thisFlD = $(dataFolder + selectedTypes[i] + "_Fl3D")
					wave thisBM = root:Panel:flBM
					wave thisToDoFlD = inThisToDo(thisToDo, thisFlD)
					wave thisToDoAvgFlD = calcAvgDistri(thisToDoFlD)
					killwaves /z thisToDoFlD
					plotDistri(thisToDoAvgFlD, thisBM, "dN/dFl (#/l)", "Fluo", "NumFl3Dist"+selectedTypes[i])
					ModifyGraph log(bottom)=0
				elseif(NumberAFFlag)
					SetDataFolder root:DataProducts
					wave thisAFD = $(dataFolder + selectedTypes[i] + "_AFD")
					wave thisToDoAFD = inThisToDo(thisToDo, thisAFD)
					wave thisToDoAvgAFD = calcAvgDistri(thisToDoAFD)
					wave thisBM = root:Panel:AFBM
					killwaves /z thisToDoAFD
					plotDistri(thisToDoAvgAFD, thisBM, "dN/dLogDSA (#/l)", "Asymm. Fac", "NumAFDist"+selectedTypes[i])
				endif
			endfor // round types
	
			setdatafolder root:
			break
	endswitch

	return 0
End

Function importSeriesButtProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			if(!datafolderexists("root:SP"))
				setdatafolder root:
				Abort "Please load single particle data first"
			endif
			
			setdatafolder root:SP
			wave SPD = SPD
			duplicate /o/r=(*)(0) SPD, SPDtime
			redimension /n=(-1) SPDtime
			
			wave dataWave = $PopupWS_GetSelectionFullPath("waspPanel", "T1_DataWaveSelector")
			wave timeWave = $PopupWS_GetSelectionFullPath("waspPanel", "T1_TimeWaveSelector")
			
			if(numpnts(dataWave) != numpnts(timeWave))
				setdatafolder root:
				Abort "Data and time waves are different lengths"
			endif
			
			wavestats /q timeWave
			wave newData = changeTimeBases(SPDtime, SPDtime, timeWave, dataWave, 1.2*(V_max-V_min)/V_npnts, "temp") 
			
			redimension /n=(-1,dimsize(SPD,1)+1) SPD
			SPD[][dimsize(SPD,1)-1] = newData[p]
			SetDimLabel 1, dimsize(SPD,1)-1,$nameofwave(dataWave), SPD
			
			killwaves newData, SPDtime
			
			refreshSPDlist()
				
			setdatafolder root:
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function refreshSPDlist()
	setdatafolder root:SP
	wave SPD = SPD	
	make /o/t/n=(dimsize(SPD,1)) SPDwaves
	SPDwaves = GetDimLabel(SPD, 1, p)
	wave /t xSPDwaves = root:Panel:xSPDwaves
	wave /t ySPDwaves = root:Panel:ySPDwaves
	redimension /n=(numpnts(SPDwaves)) xSPDwaves
	redimension /n=(numpnts(SPDwaves)) ySPDwaves
	xSPDwaves = SPDwaves
	ySPDwaves = SPDwaves
	wave xSPDwavesSW = root:Panel:xSPDwavesSW
	wave ySPDwavesSW = root:Panel:ySPDwavesSW
	redimension /n=(numpnts(xSPDwaves)) xSPDwavesSW
	redimension /n=(numpnts(ySPDwaves)) ySPDwavesSW
End

Function doPCAbutt(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			doPCA()			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function NumberSizeCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox T3_VolumeSize value=0
			CheckBox T3_SASize value=0
			CheckBox T3_NumberAF value=0
			CheckBox T3_NumberFl1 value=0
			CheckBox T3_NumberFl2 value=0
			CheckBox T3_NumberFl3 value=0		
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function VolumeSizeCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox T3_NumberSize value=0
			CheckBox T3_SASize value=0
			CheckBox T3_NumberAF value=0
			CheckBox T3_NumberFl1 value=0
			CheckBox T3_NumberFl2 value=0
			CheckBox T3_NumberFl3 value=0
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SASizeCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox T3_VolumeSize value=0
			CheckBox T3_NumberSize value=0
			CheckBox T3_NumberAF value=0
			CheckBox T3_NumberFl1 value=0
			CheckBox T3_NumberFl2 value=0
			CheckBox T3_NumberFl3 value=0
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function NumberFl1CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			controlInfo T0_loadFl1CheckBox
			if(V_value)
				Variable checked = cba.checked
				CheckBox T3_VolumeSize value=0
				CheckBox T3_SASize value=0
				CheckBox T3_NumberSize value=0
				CheckBox T3_NumberAF value=0
				CheckBox T3_NumberFl2 value=0
				CheckBox T3_NumberFl3 value=0
			else
				CheckBox T3_NumberFl1 value=0
				setdatafolder root:
				Abort "FL1 data not loaded"
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function NumberFl2CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			controlInfo T0_loadFl2CheckBox
			if(V_value)
				Variable checked = cba.checked
				CheckBox T3_VolumeSize value=0
				CheckBox T3_SASize value=0
				CheckBox T3_NumberSize value=0
				CheckBox T3_NumberAF value=0
				CheckBox T3_NumberFl1 value=0
				CheckBox T3_NumberFl3 value=0
			else
				CheckBox T3_NumberFl2 value=0
				setdatafolder root:
				Abort "FL2 data not loaded"
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function NumberFl3CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			controlInfo T0_loadFl3CheckBox
			if(V_value)
				Variable checked = cba.checked
				CheckBox T3_VolumeSize value=0
				CheckBox T3_SASize value=0
				CheckBox T3_NumberSize value=0
				CheckBox T3_NumberAF value=0
				CheckBox T3_NumberFl1 value=0
				CheckBox T3_NumberFl2 value=0
			else
				CheckBox T3_NumberFluo value=0
				setdatafolder root:
				Abort "FL3 data not loaded"
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function NumberAFCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse u
			ControlInfo T0_loadAFCheckBox
			if(V_Value)
				Variable checked = cba.checked
				CheckBox T3_VolumeSize value=0
				CheckBox T3_SASize value=0
				CheckBox T3_NumberSize value=0
				CheckBox T3_NumberFl1 value=0
				CheckBox T3_NumberFl2 value=0
				CheckBox T3_NumberFl3 value=0
			else
				CheckBox T3_NumberAF value=0
				setdatafolder root:
				Abort "Asymmetry factor data not loaded"
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function TwoDBiPlot_ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			if(!datafolderexists("root:PCAdata"))
				setdatafolder root:
				Abort "Please perform PCA first"
			else
				setdatafolder root:PCAdata
			endif
			wave M_C, M_R, varNames
			
			display
			make /o/n=(dimsize(M_R, 0), 2) biplotData = M_R[p][q]
			duplicate /o/r=(*)(0) M_R, temp
			wavestats /q temp
			variable ymax = V_max
			duplicate /o/r=(*)(1) M_R, temp
			wavestats /q temp
			variable xmax = V_max
			variable scalingFac = 1/(max(ymax,xmax))
			biplotData *= scalingFac
			appendtograph biplotData[][0] vs biplotData[][1]
			ModifyGraph mode(biplotData)=2

			make /o/n=(DimSize(M_C, 1),2) biplot = M_C[q][p]
			appendtograph biplot[][0] vs biplot[][1]
			ModifyGraph rgb(biplot)=(0,0,52224)
			ModifyGraph mode(biplot)=3
			ModifyGraph textMarker(biplot)={varNames,"default",0,0,5,0.00,0.00}
			
			Label left "PC1"
			Label bottom "PC2"
			ModifyGraph zero=1
			
			setdatafolder root:
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ThreeDBiplot_ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			// click code here
			if(!datafolderexists("root:PCAdata"))
				setdatafolder root:
				Abort "Please perform PCA first"
			endif
			setdatafolder root:PCAdata
			wave M_C, M_R, varNames
			
			execute "newGizmo"
			make /o/n=(dimsize(M_R, 0), 3) biplotData = M_R[p][q]
			duplicate /o/r=(*)(0) M_R, temp
			wavestats /q temp
			variable ymax = V_max
			duplicate /o/r=(*)(1) M_R, temp
			wavestats /q temp
			variable xmax = V_max
			variable scalingFac = 1/(max(ymax,xmax))
			biplotData *= scalingFac
	//		execute "AppendToGizmo DefaultScatter=biplotData, name=biplotData"

			make /o/n=(DimSize(M_R, 1),3) biplot = M_C[q][p]
			execute "AppendToGizmo DefaultScatter=biplot, name=biplot"
			
			setdatafolder root:
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function /wave calcTseries(NVSA, thisToDo, type)
	string NVSA // number volume or surface aerea
	wave thistodo
	string type // the thing (All, FL1 etc) that we are caculating for 
	
	SVAR dataFolder = root:Panel:dataFolder
	wave dLogDp = root:Panel:dLogDp
	wave blackList = root:Panel:blackList
			
	NVAR startTime = root:panel:StartTime
	NVAR endTime = root:panel:maxT
	NVAR timeRes = root:Panel:timeRes
			
	wave thisBM = root:Panel:SizeBM
	wave thisImage = $(dataFolder + type + "_SD")
	duplicate /o/free thisImage, thisImageCounts
	thisImageCounts = thisImage*dLogDp[q]
	
	if(cmpstr(NVSA, "num") == 0)
		SetDataFolder root:DataProducts

		wave thisToDoSD = inThisToDo(thisToDo, thisImageCounts)
		wave  thisToDoTSeriesInit = initialiseDistribution(startTime+(timeRes*0.5), endTime, timeRes, 0,type + "_" +nameofwave(thisToDo)+NVSA) // this initialises an empty tsereis
		wave thisToDoTSeriesUnInit = sumRowsWithNaNs(thisToDoSD, type+ "_" +nameofwave(thisToDo) + "UnIn") // this calculates the t sereis in a different wave (so the function can be kept general)
		thisTodoTSeriesInit = blacklist[p] ? NaN : thisToDoTSeriesUnInit
		killwaves thisToDoTSeriesUnInit // loads the initialised t series (which is wave scaled)  and kills the uninitialised t series

		return thisToDoTseriesInit
		
		//////////////////////////
	elseif(cmpstr(NVSA, "vol")==0)
		wave thisImage = $(dataFolder +type + "_SD")
		SetDataFolder root:DataProducts
		
		wave thisToDoSD = inThisToDo(thisToDo, thisImage)
		wave thisToDoVolSD = NumTimeDist2VolTimeDist(thisToDoSD, thisBM)

		wave  thisToDoTSeriesInit = initialiseDistribution(startTime+(timeRes*0.5), endTime, timeRes, 0, type + "_" +nameofwave(thisToDo)+NVSA) // this initialises an empty tsereis
		wave thisToDoTSeriesUnInit = sumRowsWithNaNs(thisToDoVolSD, type + "_" +nameofwave(thisToDo) + "UnIn") // this calculates the t sereis in a different wave (so the function can be kept general)
		thisTodoTSeriesInit = blacklist[p] ? NaN : thisToDoTSeriesUnInit
		killwaves thisToDoTSeriesUnInit // loads the initialised t series (which is wave scaled)  and kills the uninitialised t series
		
		return thisToDoTSeriesInit

	/////////////////////
	elseif(cmpstr(NVSA,"SA")==0)
		wave thisImage = $(dataFolder +type + "_SD")
		SetDataFolder root:DataProducts
	
		wave thisToDoSD = inThisToDo(thisToDo, thisImage)
		wave thisToDoSASD = NumTimeDist2SATimeDist(thisToDoSD, thisBM)
		
		wave  thisToDoTSeriesInit = initialiseDistribution(startTime+(timeRes*0.5), endTime, timeRes, 0, type + "_" +nameofwave(thisToDo)+NVSA) // this initialises an empty tsereis
		wave thisToDoTSeriesUnInit = sumRowsWithNaNs(thisToDoSASD, type + "_" +nameofwave(thisToDo) + "UnIn") // this calculates the t sereis in a different wave (so the function can be kept general)
		thisTodoTSeriesInit = blacklist[p] ? NaN : thisToDoTSeriesUnInit
		killwaves thisToDoTSeriesUnInit // loads the initialised t series (which is wave scaled)  and kills the uninitialised t series

		return thisToDoTSeriesInit
	endif
End


Function ViewTimeSeries_ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
				// click code here
			ControlInfo T2_Number; variable NumberFlag = V_Value
			ControlInfo T2_Volume; variable VolumeFlag = V_Value
			ControlInfo T2_SA; variable SAFlag = V_Value

			ControlInfo toDoList
			wave thisToDo = $("root:ToDoWaves:"+S_value)
			
			wave /t types = root:Panel:types
			wave typesSW = root:Panel:typesSW
			
			extract /o/free/t types, selectedTypes, typesSW
			
			string NVSA // number vol or sufrace area
			if(NumberFlag)
				NVSA = "num"
				display /N=NumberSeries
			elseif(VolumeFlag)
				NVSA = "Vol"
				display /N=VolumeSeries
			elseif(SAFlag)
				NVSA = "SA"
				display /N=SASeries
			endif
			
			variable i
			for(i = 0; i < numpnts(selectedTypes); i += 1)
				wave thisToDoTSeriesInit = calcTseries(NVSA, thisToDo, selectedTypes[i])
				appendtograph thisToDoTSeriesInit /TN=$selectedTypes[i]
			endfor
			
			if(NumberFlag)
				Label left "Conc (#/l)"
			elseif(VolumeFlag)
				Label left "Conc (um\S3\M/l)"
			elseif(SAFlag)
				Label left "Conc (um\S2\M/l)"
			endif
			
			KBColorizeTraces(0.4, 0.8, 0)
			Label bottom "Time"
			Legend
		
			
			setdatafolder root:			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function DiurnalImage_ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			ControlInfo T2_Number; variable NumberFlag = V_Value
			ControlInfo T2_Volume; variable VolumeFlag = V_Value
			ControlInfo T2_SA; variable SAFlag = V_Value
			NVAR minSizeThresh = root:Panel:minSizeThresh
			
			ControlInfo toDoList
			wave thisToDo = $("root:ToDoWaves:"+S_value)
			
			wave /t types = root:Panel:types
			wave typesSW = root:Panel:typesSW
			extract /o/free/t types, selectedTypes, typesSW
			
			wave sizeBins = root:panel:sizeBins
			wave sizeBM = root:Panel:sizeBM
				
			SVAR dataFolder = root:panel:dataFolder
			setdatafolder root:DataProducts
									
			variable i
			for(i = 0; i < numpnts(selectedTypes); i += 1)
				wave thisImage = $(dataFolder +selectedTypes[i]+ "_SD")
			
				string NVSA
				if(NumberFlag)
					NVSA = "Num"
					wave thisToDoSD = inThisToDo(thisToDo, thisImage)
				elseif(VolumeFlag)
					NVSA = "Vol"
					wave thisToDoSDnum = inThisToDo(thisToDo, thisImage)
					wave thisToDoSD = NumTimeDist2VolTimeDist(thisToDoSDNum, sizeBM)
				elseif(SAFlag)
					NVSA = "SA"
					wave thisToDoSDnum = inThisToDo(thisToDo, thisImage)
					wave thisToDoSD = NumTimeDist2SATimeDist(thisToDoSDNum, sizeBM)
				endif
					
				wave diurnalMean = diurnalImagePlot(thisToDoSD)
				
				display /N=$("DiurnalImage" + selectedTypes[i]); appendimage diurnalMean vs {*,sizeBins}
				ModifyImage ''#0 ctab= {*,*,Rainbow,1}
				ModifyGraph log(left)=1
				ModifyGraph manTick(bottom)={0,6,0,0},manMinor(bottom)={0,0}
				Label left "Dp (um)"
				Label bottom "Time of day"
				SetAxis left minSizeThresh, *
			endfor // round types
			
			setdatafolder root:	
			break	
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function DiurnalImage_ButtonProcTab3(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here

			ControlInfo T3_NumberSize; variable NumberFlag = V_Value
			ControlInfo T3_VolumeSize; variable VolumeFlag = V_Value
			ControlInfo T3_SASize; variable SAFlag = V_Value
			ControlInfo T3_NumberFluo; variable NumberFluoFlag = V_Value
			ControlInfo T3_NumberAF; variable NumberAFFlag = V_Value

			ControlInfo toDoList
			wave thisToDo = $("root:ToDoWaves:"+S_value)
			
			ControlInfo T23_typeList
			wave /t types = root:Panel:types
			string type = types[V_value]
			SVAR dataFolder = root:panel:dataFolder
			
			if(NumberFlag || VolumeFlag || SAFlag)
				wave thisImage = $(dataFolder +type + "_SD")
			elseif(NumberFluoFlag)
				wave thisImage = $(dataFolder +type + "_FlD")
			elseif(NumberAFFlag)
				wave thisImage = $(dataFolder +type + "_AFD")
			endif
			
			wave sizeBins = root:panel:sizeBins
			wave sizeBM = root:Panel:sizeBM
			variable SDExistsFlag = 0
			
			string NVSA
			if(NumberFlag)
				NVSA = "Num"
				if(waveexists($type + "_SD_" +nameofwave(thisToDo)+NVSA))
					SDExistsFlag = 1
					wave thisToDoSD = $type + "_SD_" +nameofwave(thisToDo)+NVSA
				else
					wave thisToDoSD = inThisToDo(thisToDo, thisImage)
				endif
			elseif(VolumeFlag)
				NVSA = "Vol"
				if(waveexists($type + "_SD_" +nameofwave(thisToDo)+NVSA))
					SDExistsFlag = 1
					wave thisToDoSD = $type + "_" +nameofwave(thisToDo)+NVSA
				else
					wave thisToDoSDnum = inThisToDo(thisToDo, thisImage)
					wave thisToDoSD = NumTimeDist2VolTimeDist(thisToDoSDNum, sizeBM)
				endif
			elseif(SAFlag)
				type = "SA"
				if(waveexists($type + "_SD_" +nameofwave(thisToDo)+NVSA))
					SDExistsFlag = 1
					wave thisToDoSD = $type + "_" +nameofwave(thisToDo)+NVSA
				else
					wave thisToDoSDnum = inThisToDo(thisToDo, thisImage)
					wave thisToDoSD = NumTimeDist2SATimeDist(thisToDoSDNum, sizeBM)
				endif
			elseif(NumberFluoFlag)
				NVSA = "Num"
				if(waveexists($type + "_FlD_" +nameofwave(thisToDo)+NVSA))
					SDExistsFlag = 1
					wave thisToDoSD = $type + "_" +nameofwave(thisToDo)+NVSA
				else
					wave thisToDoSDnum = inThisToDo(thisToDo, thisImage)
				endif
			elseif(NumberAFFlag)
				NVSA = "Num"
				if(waveexists($type + "_AFD_" +nameofwave(thisToDo)+NVSA))
					SDExistsFlag = 1
					wave thisToDoSD = $type + "_" +nameofwave(thisToDo)+NVSA
				else
					wave thisToDoSDnum = inThisToDo(thisToDo, thisImage)
				endif
			endif
			
			setdatafolder root:DataProducts
			wave diurnalMean = diurnalImagePlot(thisToDoSD)
			
			if(NumberFlag || VolumeFlag || SAFlag)
				display; appendimage diurnalMean vs {*,sizeBins}
				Label left "Dp (um)"
				ModifyGraph log(left)=1
			elseif(NumberFluoFlag)
				wave FlBins = root:panel:flBins
				display; appendimage diurnalMean vs {*,flBins}
				Label left "Fl"
			elseif(NumberAFFlag)
				wave AFBins = root:panel:AFBins
				display; appendimage diurnalMean vs {*,AFBins}
				Label left "AF"
			endif
			
			ModifyImage ''#0 ctab= {*,*,Rainbow,1}
			ModifyGraph manTick(bottom)={0,6,0,0},manMinor(bottom)={0,0}
			Label bottom "Time of day"
				
			if(!SDExistsFlag)
				killwaves /z thisToDoSD
			endif
			
			setdatafolder root:	
			break	
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function DiurnalTSereis_ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here

			ControlInfo T2_Number; variable NumberFlag = V_Value
			ControlInfo T2_Volume; variable VolumeFlag = V_Value
			ControlInfo T2_SA; variable SAFlag = V_Value

			ControlInfo toDoList
			wave thisToDo = $("root:ToDoWaves:"+S_value)
			
			ControlInfo T23_typeList
			wave /t types = root:Panel:types
			wave typesSW = root:Panel:typesSW
			extract /o/free/t types, selectedTypes, typesSW
			
			variable i
			for(i = 0; i < numpnts(selectedTypes); i += 1)
				string NVSA
				if(NumberFlag)
					NVSA = "Num"
					wave thisToDoTSeries = calcTseries(NVSA, thisToDo, selectedTypes[i])
				elseif(VolumeFlag)
					NVSA = "Vol"
					wave thisToDoTSeries = calcTseries(NVSA, thisToDo, selectedTypes[i])
				elseif(SAFlag)
					NVSA = "SA"
					wave thisToDoTSeries = calcTseries(NVSA, thisToDo, selectedTypes[i])
				endif
			
				newdatafolder /O/S :$nameofwave(thistodotseries)+"_d"
				diurnalPlot(thisToDoTSeries)
			endfor
				
			setdatafolder root:	
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function NumberCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox T2_Volume value=0
			CheckBox T2_SA value=0
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function VolumeCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox T2_Number value=0
			CheckBox T2_SA value=0
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SACheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox T2_Number value=0
			CheckBox T2_Volume value=0
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function viewCAstats_ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			setdatafolder $getCAfolder()
			controlInfo T4_upToSol
			wave /z clusterNos
			if(!waveexists(clusterNos))
				setdatafolder root:
				Abort "Please perform cluster analysis first."
			endif
			variable n = dimsize(clusterNos,1)
			duplicate /o/r=(n-V_value,n)(*) clusterNos, clusterNosSub
			wave CAinput = CAinput
			calcCAstats(clusterNosSub, CAinput)
			setdatafolder root:
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function assignClusters_ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			if(!datafolderexists("root:CAdata"))
				setdatafolder root:
				Abort "Please perform cluster analysis first"
			endif
		
			NVAR timeRes = root:panel:timeRes
			NVAR flowRate = root:panel:flowRate
			ControlInfo T0_minSize; variable minSizeThresh = V_value
			ControlInfo T0_loadFl1CheckBox; variable loadFl1flag = V_value
			ControlInfo T0_loadFl2CheckBox; variable loadFl2flag = V_value
			ControlInfo T0_loadFl3CheckBox; variable loadFl3flag = V_value
			ControlInfo T0_loadAFCheckBox; variable loadAFflag = V_value
			wave sizebins = root:Panel:sizeBins
			wave flbins = root:Panel:flBins
			wave afbins = root:Panel:afBins
			wave BLs = root:Baseline:BLs
			wave flThresh = root:Baseline:flThresh
			
			ControlInfo T4_toClusters
			make /o/wave/n=(itemsInList(S_value)) clusters
			setdatafolder $getCAfolder()
			variable i
			for(i = 0; i < numpnts(clusters); i += 1)
				wave /z temp = $"cluster"+stringfromlist(i, S_value)
				if(!waveexists(temp))
					setdatafolder root:
					killwaves clusters
					Abort "Please view the solutions before assignment."
				endif
				clusters[i] = temp
			endfor
			
			loadWIBSdata(timeRes, flowRate, minSizeThresh, sizeBins, flBins, AFBins, 1, loadFl1Flag, loadFl2Flag, loadFl3Flag, loadAFflag, 2, clusters=clusters)
			
			wave prototypeNames = root:Prototypes:prototypeNames
			refreshTypes(prototypeNames = prototypeNames, clusters = clusters)
			
			killwaves /z clusters
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function /S getCAfolder()
	ControlInfo T4_centroid
	variable centroidFlag = V_value
	ControlInfo T4_grpAvg
	variable grpAvg = V_value
	ControlInfo T4_FP
	variable FPFlag = V_value
	
	if(centroidFlag)
		return "root:CAdata:centroid"
	elseif(grpAvg)
		return "root:CAdata:grpAvg"
	elseif(FPFlag)
		return "root:CAdata:FP"
	endif
End

Function ViewCASolution_ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			controlInfo T4_centroid
			variable centroidFlag = V_value
			controlInfo T4_grpavg
			variable grpavgFlag = V_value
			controlInfo T4_FP
			variable FPFlag = V_value
			
			if(centroidFlag)
				setdatafolder root:CAdata:centroid:
			elseif(grpavgFlag)
				setdatafolder root:CAdata:grpavg:
			elseif(FPFlag)
				setdatafolder root:CAdata:FP:
			else
				Abort
			endif
			
			wave /z rawCAinput, varNames, clusterNos
			if(!waveexists(clusterNos))
				setdatafolder root:
				Abort "Please perform cluster analysis first."
			endif
			
			controlinfo T4_clusterSolChooser
			viewClusters(clusterNos, rawCAinput, V_value, varNames)
			setdatafolder root:
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function RecalcSizes_CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			if(checked)
				DoAlert /T="Recalculate sizes" 0, "Please edit function CalcSizeFromScatter() accordingly. (press Ctrl+M)" 
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ViewInputStatsButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse ups
			// click code here
			
			if(!waveexists(root:SP:SPD))
				setdatafolder root:
				Abort "Please load single particle data in the SPD tab first."
			endif
			plotCAinput()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function doCA_ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
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
				centroidCA(CAinput)
			elseif(grpavgFlag)
				newdatafolder /o/s root:CAdata:GrpAvg
				wave CAinput = prepCAinput()
				 groupAvgCA(CAinput)
			elseif(FPFlag)
				newdatafolder /o/s root:CAdata:FP
				wave CAinput = prepCAinput()
				make /free/o/n=(dimsize(CAinput, 1)) extractTrue
				extractTrue = !mod(p,3)==0
				wave temp = extractFromMatrix(1, 1, CAinput, extractTrue) 
				redimension /n=(-1,dimsize(temp,1)) CAinput
				CAinput = temp
				FPCA(CAinput)
			else
				Abort
			endif
					
			if(dimsize(CAinput,1)^2 >= 2147000000)
				Abort "Input matrix is too large for Igor"
			endif
			
			break
			
			setdatafolder root:
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Centroid_CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			checkbox T4_grpavg, value=0
			checkbox T4_FP, value=0
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function GrpAvg_CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			checkbox T4_centroid, value=0
			checkbox T4_FP, value=0
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function FP_CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			checkbox T4_grpavg, value=0
			checkbox T4_centroid, value=0
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function DelSPDButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			wave /t xnames = root:Panel:xSPDwaves
			wave xsw = root:Panel:xSPDwavesSW
			wave SPD = root:SP:SPD
			
			extract /free/o/t xnames, temp, xsw
			string selectedName = temp[0]
			if(strlen(selectedName) > 0)
				variable deleteCol = FindDimLabel(SPD, 1, selectedName) 				
				DeletePoints /M=1 deleteCol, 1, SPD
			endif
			 
			refreshSPDlist()
			break
	endswitch

	return 0
End

Function refreshTypes([prototypeNames, clusters])
	wave /t prototypeNames
	wave /wave clusters
	
	wave /t types = root:panel:types
	wave typesSW = root:panel:typesSW
	
	redimension /n=0 types
	
	if(!paramisdefault(prototypeNames))
		redimension /n=(numpnts(prototypeNames)) types
		types = prototypeNames
	endif
	if(!paramisdefault(clusters))
		variable n = numpnts(types)
		redimension /n=(n+numpnts(clusters)) types
//		types[n] = "Unclassified"
		variable i
		for(i = 0; i < numpnts(clusters); i += 1)
			types[i+n] = nameofwave(clusters[i])
		endfor
	endif
	
	redimension /n=(numpnts(types)) typesSW
End

Function ButtonProc_1(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ManualBL_ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Execute "ManualBL()"
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ManualBLOK_ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here			
			
			newdatafolder /o/s root:Baseline
					
			make /o/d/n=(1,4) BLs
			BLs[0][0] = datetime
			controlInfo FL1BL; BLs[0][1] = V_value
			controlInfo FL2BL; BLs[0][2] = V_value
			controlInfo FL3BL; BLs[0][3] = V_value

			make /o/d/n=(1,4) flThresh
			flThresh[0][0] = datetime
			controlInfo FL1Thresh; flThresh[0][1] = V_value
			controlInfo FL2Thresh; flThresh[0][2] = V_value
			controlInfo FL3Thresh; flThresh[0][3] = V_value
			
			setdatafolder root:
			
			doWindow /K ManualBL
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ManualBLCancel_ButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			DoWindow /K ManualBL
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End



Function OKModeChoice_ButtonProc_2(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			controlInfo LowGain; variable LG = V_value
			controlInfo HighGain; variable HG = V_value
			if(HG)
				variable /G root:panel:gainMode = 1
			elseif(LG)
				variable /G root:panel:gainMode = 0
			endif
			doWindow /K modeChoice
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function cancelModeChoice_ButtonProc_2(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			doWindow /K modeChoice
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function LowGain_CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox T0_HighGain value = 0
			NVAR gainMode = root:panel:gainMode
			gainMode = 0
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function highGain_CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			CheckBox T0_LowGain value = 0
			NVAR gainMode = root:panel:gainMode
			gainMode = 1
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
