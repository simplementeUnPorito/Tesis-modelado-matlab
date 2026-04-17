#include "SM24_model.h"
#include "rtwtypes.h"
#include <string.h>
#include "SM24_model_types.h"
#include <stddef.h>
#include "SM24_model_private.h"
#include "rt_logging_mmi.h"
#include "SM24_model_capi.h"
#include "SM24_model_dt.h"
extern void * CreateDiagnosticAsVoidPtr_wrapper ( const char * id , int nargs
, ... ) ; extern ssExecutionInfo gblExecutionInfo ; RTWExtModeInfo *
gblRTWExtModeInfo = NULL ; void raccelForceExtModeShutdown ( boolean_T
extModeStartPktReceived ) { if ( ! extModeStartPktReceived ) { boolean_T
stopRequested = false ; rtExtModeWaitForStartPkt ( gblRTWExtModeInfo , 2 , &
stopRequested ) ; } rtExtModeShutdown ( 2 ) ; }
#include "slsv_diagnostic_codegen_c_api.h"
#include "slsa_sim_engine.h"
#ifdef RSIM_WITH_SOLVER_MULTITASKING
boolean_T gbl_raccel_isMultitasking = 1 ;
#else
boolean_T gbl_raccel_isMultitasking = 0 ;
#endif
boolean_T gbl_raccel_tid01eq = 0 ; int_T gbl_raccel_NumST = 3 ; const char_T
* gbl_raccel_Version = "23.2 (R2023b) 01-Aug-2023" ; void
raccel_setup_MMIStateLog ( SimStruct * S ) {
#ifdef UseMMIDataLogging
rt_FillStateSigInfoFromMMI ( ssGetRTWLogInfo ( S ) , & ssGetErrorStatus ( S )
) ;
#else
UNUSED_PARAMETER ( S ) ;
#endif
} static DataMapInfo rt_dataMapInfo ; DataMapInfo * rt_dataMapInfoPtr = &
rt_dataMapInfo ; rtwCAPI_ModelMappingInfo * rt_modelMapInfoPtr = & (
rt_dataMapInfo . mmi ) ; int_T enableFcnCallFlag [ ] = { 1 , 1 , 1 } ; const
char * raccelLoadInputsAndAperiodicHitTimes ( SimStruct * S , const char *
inportFileName , int * matFileFormat ) { return rt_RAccelReadInportsMatFile (
S , inportFileName , matFileFormat ) ; }
#include "simstruc.h"
#include "fixedpoint.h"
#include "slsa_sim_engine.h"
#include "simtarget/slSimTgtSLExecSimBridge.h"
B rtB ; X rtX ; DW rtDW ; static SimStruct model_S ; SimStruct * const rtS =
& model_S ; void MdlInitialize ( void ) { rtDW . ipswhlfltx = rtP .
D1_InitialCondition ; rtDW . g2ubuwhrn0 = rtP . D3_InitialCondition ; rtDW .
pkz43umjxy = rtP . D2_InitialCondition ; } void MdlStart ( void ) { CXPtMax *
_rtXPerturbMax ; CXPtMin * _rtXPerturbMin ; NeModelParameters modelParameters
; NeModelParameters modelParameters_p ; NeslSimulationData * simulationData ;
NeslSimulator * tmp ; NeuDiagnosticManager * diagnosticManager ;
NeuDiagnosticTree * diagnosticTree ; NeuDiagnosticTree * diagnosticTree_e ;
NeuDiagnosticTree * diagnosticTree_p ; char * msg ; char * msg_e ; char *
msg_p ; real_T tmp_m [ 4 ] ; real_T time ; real_T tmp_e ; int32_T tmp_i ;
int_T tmp_g [ 2 ] ; boolean_T tmp_p ; boolean_T val ; { bool
externalInputIsInDatasetFormat = false ; void * pISigstreamManager =
rt_GetISigstreamManager ( rtS ) ;
rtwISigstreamManagerGetInputIsInDatasetFormat ( pISigstreamManager , &
externalInputIsInDatasetFormat ) ; if ( externalInputIsInDatasetFormat ) { }
} _rtXPerturbMax = ( ( CXPtMax * ) ssGetJacobianPerturbationBoundsMaxVec (
rtS ) ) ; _rtXPerturbMin = ( ( CXPtMin * )
ssGetJacobianPerturbationBoundsMinVec ( rtS ) ) ; tmp = nesl_lease_simulator
( "SM24_model/Solver Configuration_1" , 0 , 0 ) ; rtDW . kfdaeff2on = ( void
* ) tmp ; tmp_p = pointer_is_null ( rtDW . kfdaeff2on ) ; if ( tmp_p ) {
SM24_model_9c913df9_1_gateway ( ) ; tmp = nesl_lease_simulator (
"SM24_model/Solver Configuration_1" , 0 , 0 ) ; rtDW . kfdaeff2on = ( void *
) tmp ; } slsaSaveRawMemoryForSimTargetOP ( rtS ,
"SM24_model/Solver Configuration_100" , ( void * * ) ( & rtDW . kfdaeff2on )
, 0U * sizeof ( real_T ) , nesl_save_simdata , nesl_restore_simdata ) ;
simulationData = nesl_create_simulation_data ( ) ; rtDW . hzhks2wrhc = ( void
* ) simulationData ; diagnosticManager = rtw_create_diagnostics ( ) ; rtDW .
oxmoxmheof = ( void * ) diagnosticManager ; modelParameters . mSolverType =
NE_SOLVER_TYPE_DAE ; modelParameters . mSolverAbsTol = 0.001 ;
modelParameters . mSolverRelTol = 0.001 ; modelParameters .
mSolverModifyAbsTol = NE_MODIFY_ABS_TOL_MAYBE ; modelParameters . mStartTime
= 0.0 ; modelParameters . mLoadInitialState = false ; modelParameters .
mUseSimState = false ; modelParameters . mLinTrimCompile = false ;
modelParameters . mLoggingMode = SSC_LOGGING_OFF ; modelParameters .
mRTWModifiedTimeStamp = 6.98285383E+8 ; modelParameters . mZcDisabled = false
; modelParameters . mUseModelRefSolver = false ; modelParameters .
mTargetFPGAHIL = false ; tmp_e = 0.001 ; modelParameters . mSolverTolerance =
tmp_e ; tmp_e = 0.0 ; modelParameters . mFixedStepSize = tmp_e ; tmp_p = true
; modelParameters . mVariableStepSolver = tmp_p ; tmp_p = false ;
modelParameters . mIsUsingODEN = tmp_p ; tmp_p =
slIsRapidAcceleratorSimulating ( ) ; val = ssGetGlobalInitialStatesAvailable
( rtS ) ; if ( tmp_p ) { val = ( val && ssIsFirstInitCond ( rtS ) ) ; }
modelParameters . mLoadInitialState = val ; modelParameters . mZcDisabled =
false ; diagnosticManager = ( NeuDiagnosticManager * ) rtDW . oxmoxmheof ;
diagnosticTree = neu_diagnostic_manager_get_initial_tree ( diagnosticManager
) ; tmp_i = nesl_initialize_simulator ( ( NeslSimulator * ) rtDW . kfdaeff2on
, & modelParameters , diagnosticManager ) ; if ( tmp_i != 0 ) { tmp_p =
error_buffer_is_empty ( ssGetErrorStatus ( rtS ) ) ; if ( tmp_p ) { msg =
rtw_diagnostics_msg ( diagnosticTree ) ; ssSetErrorStatus ( rtS , msg ) ; } }
simulationData = ( NeslSimulationData * ) rtDW . hzhks2wrhc ; time = ssGetT (
rtS ) ; simulationData -> mData -> mTime . mN = 1 ; simulationData -> mData
-> mTime . mX = & time ; simulationData -> mData -> mContStates . mN = 7 ;
simulationData -> mData -> mContStates . mX = & rtX . d3yrpwytgj [ 0 ] ;
simulationData -> mData -> mDiscStates . mN = 17 ; simulationData -> mData ->
mDiscStates . mX = & rtDW . jokvmc1vow [ 0 ] ; simulationData -> mData ->
mModeVector . mN = 4 ; simulationData -> mData -> mModeVector . mX = & rtDW .
cs5gabfwq4 [ 0 ] ; tmp_p = ( ssIsMajorTimeStep ( rtS ) && ssGetRTWSolverInfo
( rtS ) -> foundContZcEvents ) ; simulationData -> mData -> mFoundZcEvents =
tmp_p ; simulationData -> mData -> mIsMajorTimeStep = ssIsMajorTimeStep ( rtS
) ; tmp_p = ( ssGetMdlInfoPtr ( rtS ) -> mdlFlags . solverAssertCheck == 1U )
; simulationData -> mData -> mIsSolverAssertCheck = tmp_p ; tmp_p =
ssIsSolverCheckingCIC ( rtS ) ; simulationData -> mData ->
mIsSolverCheckingCIC = tmp_p ; tmp_p = ssIsSolverComputingJacobian ( rtS ) ;
simulationData -> mData -> mIsComputingJacobian = tmp_p ; simulationData ->
mData -> mIsEvaluatingF0 = ( ssGetEvaluatingF0ForJacobian ( rtS ) != 0 ) ;
tmp_p = ssIsSolverRequestingReset ( rtS ) ; simulationData -> mData ->
mIsSolverRequestingReset = tmp_p ; simulationData -> mData ->
mIsModeUpdateTimeStep = ssIsModeUpdateTimeStep ( rtS ) ; tmp_g [ 0 ] = 0 ;
tmp_m [ 0 ] = rtB . ckzbdtbp2u [ 0 ] ; tmp_m [ 1 ] = rtB . ckzbdtbp2u [ 1 ] ;
tmp_m [ 2 ] = rtB . ckzbdtbp2u [ 2 ] ; tmp_m [ 3 ] = rtB . ckzbdtbp2u [ 3 ] ;
tmp_g [ 1 ] = 4 ; simulationData -> mData -> mInputValues . mN = 4 ;
simulationData -> mData -> mInputValues . mX = & tmp_m [ 0 ] ; simulationData
-> mData -> mInputOffsets . mN = 2 ; simulationData -> mData -> mInputOffsets
. mX = & tmp_g [ 0 ] ; simulationData -> mData -> mNumjacDxLo . mN = 7 ;
simulationData -> mData -> mNumjacDxLo . mX = & _rtXPerturbMin -> d3yrpwytgj
[ 0 ] ; simulationData -> mData -> mNumjacDxHi . mN = 7 ; simulationData ->
mData -> mNumjacDxHi . mX = & _rtXPerturbMax -> d3yrpwytgj [ 0 ] ;
diagnosticManager = ( NeuDiagnosticManager * ) rtDW . oxmoxmheof ;
diagnosticTree_p = neu_diagnostic_manager_get_initial_tree (
diagnosticManager ) ; tmp_i = ne_simulator_method ( ( NeslSimulator * ) rtDW
. kfdaeff2on , NESL_SIM_NUMJAC_DX_BOUNDS , simulationData , diagnosticManager
) ; if ( tmp_i != 0 ) { tmp_p = error_buffer_is_empty ( ssGetErrorStatus (
rtS ) ) ; if ( tmp_p ) { msg_p = rtw_diagnostics_msg ( diagnosticTree_p ) ;
ssSetErrorStatus ( rtS , msg_p ) ; } } tmp = nesl_lease_simulator (
"SM24_model/Solver Configuration_1" , 1 , 0 ) ; rtDW . p0uxtzqvso = ( void *
) tmp ; tmp_p = pointer_is_null ( rtDW . p0uxtzqvso ) ; if ( tmp_p ) {
SM24_model_9c913df9_1_gateway ( ) ; tmp = nesl_lease_simulator (
"SM24_model/Solver Configuration_1" , 1 , 0 ) ; rtDW . p0uxtzqvso = ( void *
) tmp ; } slsaSaveRawMemoryForSimTargetOP ( rtS ,
"SM24_model/Solver Configuration_110" , ( void * * ) ( & rtDW . p0uxtzqvso )
, 0U * sizeof ( real_T ) , nesl_save_simdata , nesl_restore_simdata ) ;
simulationData = nesl_create_simulation_data ( ) ; rtDW . k2bowqu4gq = ( void
* ) simulationData ; diagnosticManager = rtw_create_diagnostics ( ) ; rtDW .
hfgp5h0zt5 = ( void * ) diagnosticManager ; modelParameters_p . mSolverType =
NE_SOLVER_TYPE_DAE ; modelParameters_p . mSolverAbsTol = 0.001 ;
modelParameters_p . mSolverRelTol = 0.001 ; modelParameters_p .
mSolverModifyAbsTol = NE_MODIFY_ABS_TOL_MAYBE ; modelParameters_p .
mStartTime = 0.0 ; modelParameters_p . mLoadInitialState = false ;
modelParameters_p . mUseSimState = false ; modelParameters_p .
mLinTrimCompile = false ; modelParameters_p . mLoggingMode = SSC_LOGGING_OFF
; modelParameters_p . mRTWModifiedTimeStamp = 6.98285383E+8 ;
modelParameters_p . mZcDisabled = false ; modelParameters_p .
mUseModelRefSolver = false ; modelParameters_p . mTargetFPGAHIL = false ;
tmp_e = 0.001 ; modelParameters_p . mSolverTolerance = tmp_e ; tmp_e = 0.0 ;
modelParameters_p . mFixedStepSize = tmp_e ; tmp_p = true ; modelParameters_p
. mVariableStepSolver = tmp_p ; tmp_p = false ; modelParameters_p .
mIsUsingODEN = tmp_p ; tmp_p = slIsRapidAcceleratorSimulating ( ) ; val =
ssGetGlobalInitialStatesAvailable ( rtS ) ; if ( tmp_p ) { val = ( val &&
ssIsFirstInitCond ( rtS ) ) ; } modelParameters_p . mLoadInitialState = val ;
modelParameters_p . mZcDisabled = false ; diagnosticManager = (
NeuDiagnosticManager * ) rtDW . hfgp5h0zt5 ; diagnosticTree_e =
neu_diagnostic_manager_get_initial_tree ( diagnosticManager ) ; tmp_i =
nesl_initialize_simulator ( ( NeslSimulator * ) rtDW . p0uxtzqvso , &
modelParameters_p , diagnosticManager ) ; if ( tmp_i != 0 ) { tmp_p =
error_buffer_is_empty ( ssGetErrorStatus ( rtS ) ) ; if ( tmp_p ) { msg_e =
rtw_diagnostics_msg ( diagnosticTree_e ) ; ssSetErrorStatus ( rtS , msg_e ) ;
} } MdlInitialize ( ) ; } void MdlOutputs ( int_T tid ) { real_T hngwqa0smc ;
NeslSimulationData * simulationData ; NeuDiagnosticManager *
diagnosticManager ; NeuDiagnosticTree * diagnosticTree ; NeuDiagnosticTree *
diagnosticTree_p ; char * msg ; char * msg_p ; real_T tmp_m [ 32 ] ; real_T
tmp_p [ 4 ] ; real_T time ; real_T time_e ; real_T time_i ; real_T time_p ;
int32_T tmp_i ; int_T tmp_g [ 3 ] ; int_T tmp_e [ 2 ] ; boolean_T tmp ;
SimStruct * S ; void * diag ; if ( ssIsSampleHit ( rtS , 1 , 0 ) ) { rtDW .
ptcy4m1wr0 = ( ssGetTaskTime ( rtS , 1 ) >= rtP . Step_Time ) ; if ( rtDW .
ptcy4m1wr0 == 1 ) { rtB . hptfqp3w4t = rtP . Step_YFinal ; } else { rtB .
hptfqp3w4t = rtP . Step_Y0 ; } } rtB . ckzbdtbp2u [ 0 ] = rtB . hptfqp3w4t ;
rtB . ckzbdtbp2u [ 1 ] = 0.0 ; rtB . ckzbdtbp2u [ 2 ] = 0.0 ; if (
ssIsMajorTimeStep ( rtS ) ) { rtDW . celqvbnenk [ 0 ] = ! ( rtB . ckzbdtbp2u
[ 0 ] == rtDW . celqvbnenk [ 1 ] ) ; rtDW . celqvbnenk [ 1 ] = rtB .
ckzbdtbp2u [ 0 ] ; } rtB . ckzbdtbp2u [ 0 ] = rtDW . celqvbnenk [ 1 ] ; rtB .
ckzbdtbp2u [ 3 ] = rtDW . celqvbnenk [ 0 ] ; simulationData = (
NeslSimulationData * ) rtDW . hzhks2wrhc ; time = ssGetT ( rtS ) ;
simulationData -> mData -> mTime . mN = 1 ; simulationData -> mData -> mTime
. mX = & time ; simulationData -> mData -> mContStates . mN = 7 ;
simulationData -> mData -> mContStates . mX = & rtX . d3yrpwytgj [ 0 ] ;
simulationData -> mData -> mDiscStates . mN = 17 ; simulationData -> mData ->
mDiscStates . mX = & rtDW . jokvmc1vow [ 0 ] ; simulationData -> mData ->
mModeVector . mN = 4 ; simulationData -> mData -> mModeVector . mX = & rtDW .
cs5gabfwq4 [ 0 ] ; tmp = ( ssIsMajorTimeStep ( rtS ) && ssGetRTWSolverInfo (
rtS ) -> foundContZcEvents ) ; simulationData -> mData -> mFoundZcEvents =
tmp ; simulationData -> mData -> mIsMajorTimeStep = ssIsMajorTimeStep ( rtS )
; tmp = ( ssGetMdlInfoPtr ( rtS ) -> mdlFlags . solverAssertCheck == 1U ) ;
simulationData -> mData -> mIsSolverAssertCheck = tmp ; tmp =
ssIsSolverCheckingCIC ( rtS ) ; simulationData -> mData ->
mIsSolverCheckingCIC = tmp ; tmp = ssIsSolverComputingJacobian ( rtS ) ;
simulationData -> mData -> mIsComputingJacobian = tmp ; simulationData ->
mData -> mIsEvaluatingF0 = ( ssGetEvaluatingF0ForJacobian ( rtS ) != 0 ) ;
tmp = ssIsSolverRequestingReset ( rtS ) ; simulationData -> mData ->
mIsSolverRequestingReset = tmp ; simulationData -> mData ->
mIsModeUpdateTimeStep = ssIsModeUpdateTimeStep ( rtS ) ; tmp_e [ 0 ] = 0 ;
tmp_p [ 0 ] = rtB . ckzbdtbp2u [ 0 ] ; tmp_p [ 1 ] = rtB . ckzbdtbp2u [ 1 ] ;
tmp_p [ 2 ] = rtB . ckzbdtbp2u [ 2 ] ; tmp_p [ 3 ] = rtB . ckzbdtbp2u [ 3 ] ;
tmp_e [ 1 ] = 4 ; simulationData -> mData -> mInputValues . mN = 4 ;
simulationData -> mData -> mInputValues . mX = & tmp_p [ 0 ] ; simulationData
-> mData -> mInputOffsets . mN = 2 ; simulationData -> mData -> mInputOffsets
. mX = & tmp_e [ 0 ] ; simulationData -> mData -> mOutputs . mN = 28 ;
simulationData -> mData -> mOutputs . mX = & rtB . dffdefsite [ 0 ] ;
simulationData -> mData -> mTolerances . mN = 0 ; simulationData -> mData ->
mTolerances . mX = NULL ; simulationData -> mData -> mCstateHasChanged =
false ; time_p = ssGetTaskTime ( rtS , 0 ) ; simulationData -> mData -> mTime
. mN = 1 ; simulationData -> mData -> mTime . mX = & time_p ; simulationData
-> mData -> mSampleHits . mN = 0 ; simulationData -> mData -> mSampleHits .
mX = NULL ; simulationData -> mData -> mIsFundamentalSampleHit = false ;
diagnosticManager = ( NeuDiagnosticManager * ) rtDW . oxmoxmheof ;
diagnosticTree = neu_diagnostic_manager_get_initial_tree ( diagnosticManager
) ; tmp_i = ne_simulator_method ( ( NeslSimulator * ) rtDW . kfdaeff2on ,
NESL_SIM_OUTPUTS , simulationData , diagnosticManager ) ; if ( tmp_i != 0 ) {
tmp = error_buffer_is_empty ( ssGetErrorStatus ( rtS ) ) ; if ( tmp ) { msg =
rtw_diagnostics_msg ( diagnosticTree ) ; ssSetErrorStatus ( rtS , msg ) ; } }
if ( ssIsMajorTimeStep ( rtS ) && simulationData -> mData ->
mCstateHasChanged ) { ssSetBlockStateForSolverChangedAtMajorStep ( rtS ) ; }
simulationData = ( NeslSimulationData * ) rtDW . k2bowqu4gq ; time_e = ssGetT
( rtS ) ; simulationData -> mData -> mTime . mN = 1 ; simulationData -> mData
-> mTime . mX = & time_e ; simulationData -> mData -> mContStates . mN = 0 ;
simulationData -> mData -> mContStates . mX = NULL ; simulationData -> mData
-> mDiscStates . mN = 0 ; simulationData -> mData -> mDiscStates . mX = &
rtDW . d4s54ffcej ; simulationData -> mData -> mModeVector . mN = 0 ;
simulationData -> mData -> mModeVector . mX = & rtDW . olwuylhr2k ; tmp = (
ssIsMajorTimeStep ( rtS ) && ssGetRTWSolverInfo ( rtS ) -> foundContZcEvents
) ; simulationData -> mData -> mFoundZcEvents = tmp ; simulationData -> mData
-> mIsMajorTimeStep = ssIsMajorTimeStep ( rtS ) ; tmp = ( ssGetMdlInfoPtr (
rtS ) -> mdlFlags . solverAssertCheck == 1U ) ; simulationData -> mData ->
mIsSolverAssertCheck = tmp ; tmp = ssIsSolverCheckingCIC ( rtS ) ;
simulationData -> mData -> mIsSolverCheckingCIC = tmp ; simulationData ->
mData -> mIsComputingJacobian = false ; simulationData -> mData ->
mIsEvaluatingF0 = false ; tmp = ssIsSolverRequestingReset ( rtS ) ;
simulationData -> mData -> mIsSolverRequestingReset = tmp ; simulationData ->
mData -> mIsModeUpdateTimeStep = ssIsModeUpdateTimeStep ( rtS ) ; tmp_g [ 0 ]
= 0 ; tmp_m [ 0 ] = rtB . ckzbdtbp2u [ 0 ] ; tmp_m [ 1 ] = rtB . ckzbdtbp2u [
1 ] ; tmp_m [ 2 ] = rtB . ckzbdtbp2u [ 2 ] ; tmp_m [ 3 ] = rtB . ckzbdtbp2u [
3 ] ; tmp_g [ 1 ] = 4 ; memcpy ( & tmp_m [ 4 ] , & rtB . dffdefsite [ 0 ] ,
28U * sizeof ( real_T ) ) ; tmp_g [ 2 ] = 32 ; simulationData -> mData ->
mInputValues . mN = 32 ; simulationData -> mData -> mInputValues . mX = &
tmp_m [ 0 ] ; simulationData -> mData -> mInputOffsets . mN = 3 ;
simulationData -> mData -> mInputOffsets . mX = & tmp_g [ 0 ] ;
simulationData -> mData -> mOutputs . mN = 1 ; simulationData -> mData ->
mOutputs . mX = & rtB . d315qoqwkh ; simulationData -> mData -> mTolerances .
mN = 0 ; simulationData -> mData -> mTolerances . mX = NULL ; simulationData
-> mData -> mCstateHasChanged = false ; time_i = ssGetTaskTime ( rtS , 0 ) ;
simulationData -> mData -> mTime . mN = 1 ; simulationData -> mData -> mTime
. mX = & time_i ; simulationData -> mData -> mSampleHits . mN = 0 ;
simulationData -> mData -> mSampleHits . mX = NULL ; simulationData -> mData
-> mIsFundamentalSampleHit = false ; diagnosticManager = (
NeuDiagnosticManager * ) rtDW . hfgp5h0zt5 ; diagnosticTree_p =
neu_diagnostic_manager_get_initial_tree ( diagnosticManager ) ; tmp_i =
ne_simulator_method ( ( NeslSimulator * ) rtDW . p0uxtzqvso ,
NESL_SIM_OUTPUTS , simulationData , diagnosticManager ) ; if ( tmp_i != 0 ) {
tmp = error_buffer_is_empty ( ssGetErrorStatus ( rtS ) ) ; if ( tmp ) { msg_p
= rtw_diagnostics_msg ( diagnosticTree_p ) ; ssSetErrorStatus ( rtS , msg_p )
; } } if ( ssIsMajorTimeStep ( rtS ) && simulationData -> mData ->
mCstateHasChanged ) { ssSetBlockStateForSolverChangedAtMajorStep ( rtS ) ; }
rtB . ex54xq0c2t = ( ssGetT ( rtS ) - rtP . Snapshottimes_Value ) * rtP .
RateConversion_Gain ; if ( ssIsSampleHit ( rtS , 1 , 0 ) ) { if (
ssIsModeUpdateTimeStep ( rtS ) ) { rtDW . ehbyr4oova = ( rtB . ex54xq0c2t >=
rtP . Constant_Value ) ; rtDW . gsuxxg2o4n = ( rtB . ex54xq0c2t > rtP .
Constant_Value_n54scyttiz ) ; } rtB . ojrpy5nefy = rtDW . pkz43umjxy ; rtB .
aaphbljg5e = ( ( rtDW . ehbyr4oova && ( rtDW . ipswhlfltx != 0 ) ) || ( (
rtDW . g2ubuwhrn0 != 0 ) && ( rtB . ojrpy5nefy != 0 ) && rtDW . gsuxxg2o4n )
) ; hngwqa0smc = 1 ; if ( ! ( hngwqa0smc != 0.0 ) ) { S = rtS ; diag =
CreateDiagnosticAsVoidPtr ( "Simulink:blocks:AssertionAssert" , 2 , 5 ,
"SM24_model/Bode Plot/Assertion" , 2 , ssGetT ( rtS ) ) ;
rt_ssReportDiagnosticAsWarning ( S , diag ) ; } if ( ssIsModeUpdateTimeStep (
rtS ) ) { rtDW . bhhchkty0k = ( rtB . ex54xq0c2t < rtP .
Constant_Value_dv5dqkwtfv ) ; rtDW . drqqz0z3u2 = ( rtB . ex54xq0c2t == rtP .
Constant_Value_fnvw3cdvbn ) ; } rtB . p3ejhqueew = rtDW . bhhchkty0k ; rtB .
exmape5dlp = rtDW . drqqz0z3u2 ; } UNUSED_PARAMETER ( tid ) ; } void
MdlOutputsTID2 ( int_T tid ) { UNUSED_PARAMETER ( tid ) ; } void MdlUpdate (
int_T tid ) { NeslSimulationData * simulationData ; NeuDiagnosticManager *
diagnosticManager ; NeuDiagnosticTree * diagnosticTree ; char * msg ; real_T
tmp_p [ 4 ] ; real_T time ; int32_T tmp_i ; int_T tmp_e [ 2 ] ; boolean_T tmp
; simulationData = ( NeslSimulationData * ) rtDW . hzhks2wrhc ; time = ssGetT
( rtS ) ; simulationData -> mData -> mTime . mN = 1 ; simulationData -> mData
-> mTime . mX = & time ; simulationData -> mData -> mContStates . mN = 7 ;
simulationData -> mData -> mContStates . mX = & rtX . d3yrpwytgj [ 0 ] ;
simulationData -> mData -> mDiscStates . mN = 17 ; simulationData -> mData ->
mDiscStates . mX = & rtDW . jokvmc1vow [ 0 ] ; simulationData -> mData ->
mModeVector . mN = 4 ; simulationData -> mData -> mModeVector . mX = & rtDW .
cs5gabfwq4 [ 0 ] ; tmp = ( ssIsMajorTimeStep ( rtS ) && ssGetRTWSolverInfo (
rtS ) -> foundContZcEvents ) ; simulationData -> mData -> mFoundZcEvents =
tmp ; simulationData -> mData -> mIsMajorTimeStep = ssIsMajorTimeStep ( rtS )
; tmp = ( ssGetMdlInfoPtr ( rtS ) -> mdlFlags . solverAssertCheck == 1U ) ;
simulationData -> mData -> mIsSolverAssertCheck = tmp ; tmp =
ssIsSolverCheckingCIC ( rtS ) ; simulationData -> mData ->
mIsSolverCheckingCIC = tmp ; tmp = ssIsSolverComputingJacobian ( rtS ) ;
simulationData -> mData -> mIsComputingJacobian = tmp ; simulationData ->
mData -> mIsEvaluatingF0 = ( ssGetEvaluatingF0ForJacobian ( rtS ) != 0 ) ;
tmp = ssIsSolverRequestingReset ( rtS ) ; simulationData -> mData ->
mIsSolverRequestingReset = tmp ; simulationData -> mData ->
mIsModeUpdateTimeStep = ssIsModeUpdateTimeStep ( rtS ) ; tmp_e [ 0 ] = 0 ;
tmp_p [ 0 ] = rtB . ckzbdtbp2u [ 0 ] ; tmp_p [ 1 ] = rtB . ckzbdtbp2u [ 1 ] ;
tmp_p [ 2 ] = rtB . ckzbdtbp2u [ 2 ] ; tmp_p [ 3 ] = rtB . ckzbdtbp2u [ 3 ] ;
tmp_e [ 1 ] = 4 ; simulationData -> mData -> mInputValues . mN = 4 ;
simulationData -> mData -> mInputValues . mX = & tmp_p [ 0 ] ; simulationData
-> mData -> mInputOffsets . mN = 2 ; simulationData -> mData -> mInputOffsets
. mX = & tmp_e [ 0 ] ; diagnosticManager = ( NeuDiagnosticManager * ) rtDW .
oxmoxmheof ; diagnosticTree = neu_diagnostic_manager_get_initial_tree (
diagnosticManager ) ; tmp_i = ne_simulator_method ( ( NeslSimulator * ) rtDW
. kfdaeff2on , NESL_SIM_UPDATE , simulationData , diagnosticManager ) ; if (
tmp_i != 0 ) { tmp = error_buffer_is_empty ( ssGetErrorStatus ( rtS ) ) ; if
( tmp ) { msg = rtw_diagnostics_msg ( diagnosticTree ) ; ssSetErrorStatus (
rtS , msg ) ; } } if ( ssIsSampleHit ( rtS , 1 , 0 ) ) { rtDW . ipswhlfltx =
rtB . p3ejhqueew ; rtDW . g2ubuwhrn0 = rtB . ojrpy5nefy ; rtDW . pkz43umjxy =
rtB . exmape5dlp ; } UNUSED_PARAMETER ( tid ) ; } void MdlUpdateTID2 ( int_T
tid ) { UNUSED_PARAMETER ( tid ) ; } void MdlDerivatives ( void ) {
NeslSimulationData * simulationData ; NeuDiagnosticManager *
diagnosticManager ; NeuDiagnosticTree * diagnosticTree ; XDot * _rtXdot ;
char * msg ; real_T tmp_p [ 4 ] ; real_T time ; int32_T tmp_i ; int_T tmp_e [
2 ] ; boolean_T tmp ; _rtXdot = ( ( XDot * ) ssGetdX ( rtS ) ) ;
simulationData = ( NeslSimulationData * ) rtDW . hzhks2wrhc ; time = ssGetT (
rtS ) ; simulationData -> mData -> mTime . mN = 1 ; simulationData -> mData
-> mTime . mX = & time ; simulationData -> mData -> mContStates . mN = 7 ;
simulationData -> mData -> mContStates . mX = & rtX . d3yrpwytgj [ 0 ] ;
simulationData -> mData -> mDiscStates . mN = 17 ; simulationData -> mData ->
mDiscStates . mX = & rtDW . jokvmc1vow [ 0 ] ; simulationData -> mData ->
mModeVector . mN = 4 ; simulationData -> mData -> mModeVector . mX = & rtDW .
cs5gabfwq4 [ 0 ] ; tmp = ( ssIsMajorTimeStep ( rtS ) && ssGetRTWSolverInfo (
rtS ) -> foundContZcEvents ) ; simulationData -> mData -> mFoundZcEvents =
tmp ; simulationData -> mData -> mIsMajorTimeStep = ssIsMajorTimeStep ( rtS )
; tmp = ( ssGetMdlInfoPtr ( rtS ) -> mdlFlags . solverAssertCheck == 1U ) ;
simulationData -> mData -> mIsSolverAssertCheck = tmp ; tmp =
ssIsSolverCheckingCIC ( rtS ) ; simulationData -> mData ->
mIsSolverCheckingCIC = tmp ; tmp = ssIsSolverComputingJacobian ( rtS ) ;
simulationData -> mData -> mIsComputingJacobian = tmp ; simulationData ->
mData -> mIsEvaluatingF0 = ( ssGetEvaluatingF0ForJacobian ( rtS ) != 0 ) ;
tmp = ssIsSolverRequestingReset ( rtS ) ; simulationData -> mData ->
mIsSolverRequestingReset = tmp ; simulationData -> mData ->
mIsModeUpdateTimeStep = ssIsModeUpdateTimeStep ( rtS ) ; tmp_e [ 0 ] = 0 ;
tmp_p [ 0 ] = rtB . ckzbdtbp2u [ 0 ] ; tmp_p [ 1 ] = rtB . ckzbdtbp2u [ 1 ] ;
tmp_p [ 2 ] = rtB . ckzbdtbp2u [ 2 ] ; tmp_p [ 3 ] = rtB . ckzbdtbp2u [ 3 ] ;
tmp_e [ 1 ] = 4 ; simulationData -> mData -> mInputValues . mN = 4 ;
simulationData -> mData -> mInputValues . mX = & tmp_p [ 0 ] ; simulationData
-> mData -> mInputOffsets . mN = 2 ; simulationData -> mData -> mInputOffsets
. mX = & tmp_e [ 0 ] ; simulationData -> mData -> mDx . mN = 7 ;
simulationData -> mData -> mDx . mX = & _rtXdot -> d3yrpwytgj [ 0 ] ;
diagnosticManager = ( NeuDiagnosticManager * ) rtDW . oxmoxmheof ;
diagnosticTree = neu_diagnostic_manager_get_initial_tree ( diagnosticManager
) ; tmp_i = ne_simulator_method ( ( NeslSimulator * ) rtDW . kfdaeff2on ,
NESL_SIM_DERIVATIVES , simulationData , diagnosticManager ) ; if ( tmp_i != 0
) { tmp = error_buffer_is_empty ( ssGetErrorStatus ( rtS ) ) ; if ( tmp ) {
msg = rtw_diagnostics_msg ( diagnosticTree ) ; ssSetErrorStatus ( rtS , msg )
; } } } void MdlProjection ( void ) { } void MdlZeroCrossings ( void ) {
NeslSimulationData * simulationData ; NeuDiagnosticManager *
diagnosticManager ; NeuDiagnosticTree * diagnosticTree ; ZCV * _rtZCSV ; char
* msg ; real_T tmp_p [ 4 ] ; real_T time ; int32_T tmp_i ; int_T tmp_e [ 2 ]
; boolean_T tmp ; _rtZCSV = ( ( ZCV * ) ssGetSolverZcSignalVector ( rtS ) ) ;
_rtZCSV -> kucfedkei4 = ssGetT ( rtS ) - rtP . Step_Time ; simulationData = (
NeslSimulationData * ) rtDW . hzhks2wrhc ; time = ssGetT ( rtS ) ;
simulationData -> mData -> mTime . mN = 1 ; simulationData -> mData -> mTime
. mX = & time ; simulationData -> mData -> mContStates . mN = 7 ;
simulationData -> mData -> mContStates . mX = & rtX . d3yrpwytgj [ 0 ] ;
simulationData -> mData -> mDiscStates . mN = 17 ; simulationData -> mData ->
mDiscStates . mX = & rtDW . jokvmc1vow [ 0 ] ; simulationData -> mData ->
mModeVector . mN = 4 ; simulationData -> mData -> mModeVector . mX = & rtDW .
cs5gabfwq4 [ 0 ] ; tmp = ( ssIsMajorTimeStep ( rtS ) && ssGetRTWSolverInfo (
rtS ) -> foundContZcEvents ) ; simulationData -> mData -> mFoundZcEvents =
tmp ; simulationData -> mData -> mIsMajorTimeStep = ssIsMajorTimeStep ( rtS )
; tmp = ( ssGetMdlInfoPtr ( rtS ) -> mdlFlags . solverAssertCheck == 1U ) ;
simulationData -> mData -> mIsSolverAssertCheck = tmp ; tmp =
ssIsSolverCheckingCIC ( rtS ) ; simulationData -> mData ->
mIsSolverCheckingCIC = tmp ; tmp = ssIsSolverComputingJacobian ( rtS ) ;
simulationData -> mData -> mIsComputingJacobian = tmp ; simulationData ->
mData -> mIsEvaluatingF0 = ( ssGetEvaluatingF0ForJacobian ( rtS ) != 0 ) ;
tmp = ssIsSolverRequestingReset ( rtS ) ; simulationData -> mData ->
mIsSolverRequestingReset = tmp ; simulationData -> mData ->
mIsModeUpdateTimeStep = ssIsModeUpdateTimeStep ( rtS ) ; tmp_e [ 0 ] = 0 ;
tmp_p [ 0 ] = rtB . ckzbdtbp2u [ 0 ] ; tmp_p [ 1 ] = rtB . ckzbdtbp2u [ 1 ] ;
tmp_p [ 2 ] = rtB . ckzbdtbp2u [ 2 ] ; tmp_p [ 3 ] = rtB . ckzbdtbp2u [ 3 ] ;
tmp_e [ 1 ] = 4 ; simulationData -> mData -> mInputValues . mN = 4 ;
simulationData -> mData -> mInputValues . mX = & tmp_p [ 0 ] ; simulationData
-> mData -> mInputOffsets . mN = 2 ; simulationData -> mData -> mInputOffsets
. mX = & tmp_e [ 0 ] ; simulationData -> mData -> mNonSampledZCs . mN = 4 ;
simulationData -> mData -> mNonSampledZCs . mX = & _rtZCSV -> nlttom1j3y ;
diagnosticManager = ( NeuDiagnosticManager * ) rtDW . oxmoxmheof ;
diagnosticTree = neu_diagnostic_manager_get_initial_tree ( diagnosticManager
) ; tmp_i = ne_simulator_method ( ( NeslSimulator * ) rtDW . kfdaeff2on ,
NESL_SIM_ZEROCROSSINGS , simulationData , diagnosticManager ) ; if ( tmp_i !=
0 ) { tmp = error_buffer_is_empty ( ssGetErrorStatus ( rtS ) ) ; if ( tmp ) {
msg = rtw_diagnostics_msg ( diagnosticTree ) ; ssSetErrorStatus ( rtS , msg )
; } } _rtZCSV -> cflyaxs4fr = rtB . ex54xq0c2t - rtP . Constant_Value ;
_rtZCSV -> i11l1diodi = rtB . ex54xq0c2t - rtP . Constant_Value_n54scyttiz ;
_rtZCSV -> iriaqhcigt = rtB . ex54xq0c2t - rtP . Constant_Value_dv5dqkwtfv ;
_rtZCSV -> iim4yj0vlf = rtB . ex54xq0c2t - rtP . Constant_Value_fnvw3cdvbn ;
} void MdlTerminate ( void ) { neu_destroy_diagnostic_manager ( (
NeuDiagnosticManager * ) rtDW . oxmoxmheof ) ; nesl_destroy_simulation_data (
( NeslSimulationData * ) rtDW . hzhks2wrhc ) ; nesl_erase_simulator (
"SM24_model/Solver Configuration_1" ) ; nesl_destroy_registry ( ) ;
neu_destroy_diagnostic_manager ( ( NeuDiagnosticManager * ) rtDW . hfgp5h0zt5
) ; nesl_destroy_simulation_data ( ( NeslSimulationData * ) rtDW . k2bowqu4gq
) ; nesl_erase_simulator ( "SM24_model/Solver Configuration_1" ) ;
nesl_destroy_registry ( ) ; } static void mr_SM24_model_cacheDataAsMxArray (
mxArray * destArray , mwIndex i , int j , const void * srcData , size_t
numBytes ) ; static void mr_SM24_model_cacheDataAsMxArray ( mxArray *
destArray , mwIndex i , int j , const void * srcData , size_t numBytes ) {
mxArray * newArray = mxCreateUninitNumericMatrix ( ( size_t ) 1 , numBytes ,
mxUINT8_CLASS , mxREAL ) ; memcpy ( ( uint8_T * ) mxGetData ( newArray ) , (
const uint8_T * ) srcData , numBytes ) ; mxSetFieldByNumber ( destArray , i ,
j , newArray ) ; } static void mr_SM24_model_restoreDataFromMxArray ( void *
destData , const mxArray * srcArray , mwIndex i , int j , size_t numBytes ) ;
static void mr_SM24_model_restoreDataFromMxArray ( void * destData , const
mxArray * srcArray , mwIndex i , int j , size_t numBytes ) { memcpy ( (
uint8_T * ) destData , ( const uint8_T * ) mxGetData ( mxGetFieldByNumber (
srcArray , i , j ) ) , numBytes ) ; } static void
mr_SM24_model_cacheBitFieldToMxArray ( mxArray * destArray , mwIndex i , int
j , uint_T bitVal ) ; static void mr_SM24_model_cacheBitFieldToMxArray (
mxArray * destArray , mwIndex i , int j , uint_T bitVal ) {
mxSetFieldByNumber ( destArray , i , j , mxCreateDoubleScalar ( ( real_T )
bitVal ) ) ; } static uint_T mr_SM24_model_extractBitFieldFromMxArray ( const
mxArray * srcArray , mwIndex i , int j , uint_T numBits ) ; static uint_T
mr_SM24_model_extractBitFieldFromMxArray ( const mxArray * srcArray , mwIndex
i , int j , uint_T numBits ) { const uint_T varVal = ( uint_T ) mxGetScalar (
mxGetFieldByNumber ( srcArray , i , j ) ) ; return varVal & ( ( 1u << numBits
) - 1u ) ; } static void mr_SM24_model_cacheDataToMxArrayWithOffset ( mxArray
* destArray , mwIndex i , int j , mwIndex offset , const void * srcData ,
size_t numBytes ) ; static void mr_SM24_model_cacheDataToMxArrayWithOffset (
mxArray * destArray , mwIndex i , int j , mwIndex offset , const void *
srcData , size_t numBytes ) { uint8_T * varData = ( uint8_T * ) mxGetData (
mxGetFieldByNumber ( destArray , i , j ) ) ; memcpy ( ( uint8_T * ) & varData
[ offset * numBytes ] , ( const uint8_T * ) srcData , numBytes ) ; } static
void mr_SM24_model_restoreDataFromMxArrayWithOffset ( void * destData , const
mxArray * srcArray , mwIndex i , int j , mwIndex offset , size_t numBytes ) ;
static void mr_SM24_model_restoreDataFromMxArrayWithOffset ( void * destData
, const mxArray * srcArray , mwIndex i , int j , mwIndex offset , size_t
numBytes ) { const uint8_T * varData = ( const uint8_T * ) mxGetData (
mxGetFieldByNumber ( srcArray , i , j ) ) ; memcpy ( ( uint8_T * ) destData ,
( const uint8_T * ) & varData [ offset * numBytes ] , numBytes ) ; } static
void mr_SM24_model_cacheBitFieldToCellArrayWithOffset ( mxArray * destArray ,
mwIndex i , int j , mwIndex offset , uint_T fieldVal ) ; static void
mr_SM24_model_cacheBitFieldToCellArrayWithOffset ( mxArray * destArray ,
mwIndex i , int j , mwIndex offset , uint_T fieldVal ) { mxSetCell (
mxGetFieldByNumber ( destArray , i , j ) , offset , mxCreateDoubleScalar ( (
real_T ) fieldVal ) ) ; } static uint_T
mr_SM24_model_extractBitFieldFromCellArrayWithOffset ( const mxArray *
srcArray , mwIndex i , int j , mwIndex offset , uint_T numBits ) ; static
uint_T mr_SM24_model_extractBitFieldFromCellArrayWithOffset ( const mxArray *
srcArray , mwIndex i , int j , mwIndex offset , uint_T numBits ) { const
uint_T fieldVal = ( uint_T ) mxGetScalar ( mxGetCell ( mxGetFieldByNumber (
srcArray , i , j ) , offset ) ) ; return fieldVal & ( ( 1u << numBits ) - 1u
) ; } mxArray * mr_SM24_model_GetDWork ( ) { static const char_T *
ssDWFieldNames [ 3 ] = { "rtB" , "rtDW" , "NULL_PrevZCX" , } ; mxArray * ssDW
= mxCreateStructMatrix ( 1 , 1 , 3 , ssDWFieldNames ) ;
mr_SM24_model_cacheDataAsMxArray ( ssDW , 0 , 0 , ( const void * ) & ( rtB )
, sizeof ( rtB ) ) ; { static const char_T * rtdwDataFieldNames [ 15 ] = {
"rtDW.celqvbnenk" , "rtDW.jokvmc1vow" , "rtDW.d4s54ffcej" , "rtDW.cs5gabfwq4"
, "rtDW.olwuylhr2k" , "rtDW.ptcy4m1wr0" , "rtDW.ipswhlfltx" ,
"rtDW.g2ubuwhrn0" , "rtDW.pkz43umjxy" , "rtDW.e02zzncljy" , "rtDW.nqr2ask1kh"
, "rtDW.ehbyr4oova" , "rtDW.gsuxxg2o4n" , "rtDW.bhhchkty0k" ,
"rtDW.drqqz0z3u2" , } ; mxArray * rtdwData = mxCreateStructMatrix ( 1 , 1 ,
15 , rtdwDataFieldNames ) ; mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 ,
0 , ( const void * ) & ( rtDW . celqvbnenk ) , sizeof ( rtDW . celqvbnenk ) )
; mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 1 , ( const void * ) & (
rtDW . jokvmc1vow ) , sizeof ( rtDW . jokvmc1vow ) ) ;
mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 2 , ( const void * ) & (
rtDW . d4s54ffcej ) , sizeof ( rtDW . d4s54ffcej ) ) ;
mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 3 , ( const void * ) & (
rtDW . cs5gabfwq4 ) , sizeof ( rtDW . cs5gabfwq4 ) ) ;
mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 4 , ( const void * ) & (
rtDW . olwuylhr2k ) , sizeof ( rtDW . olwuylhr2k ) ) ;
mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 5 , ( const void * ) & (
rtDW . ptcy4m1wr0 ) , sizeof ( rtDW . ptcy4m1wr0 ) ) ;
mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 6 , ( const void * ) & (
rtDW . ipswhlfltx ) , sizeof ( rtDW . ipswhlfltx ) ) ;
mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 7 , ( const void * ) & (
rtDW . g2ubuwhrn0 ) , sizeof ( rtDW . g2ubuwhrn0 ) ) ;
mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 8 , ( const void * ) & (
rtDW . pkz43umjxy ) , sizeof ( rtDW . pkz43umjxy ) ) ;
mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 9 , ( const void * ) & (
rtDW . e02zzncljy ) , sizeof ( rtDW . e02zzncljy ) ) ;
mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 10 , ( const void * ) & (
rtDW . nqr2ask1kh ) , sizeof ( rtDW . nqr2ask1kh ) ) ;
mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 11 , ( const void * ) & (
rtDW . ehbyr4oova ) , sizeof ( rtDW . ehbyr4oova ) ) ;
mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 12 , ( const void * ) & (
rtDW . gsuxxg2o4n ) , sizeof ( rtDW . gsuxxg2o4n ) ) ;
mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 13 , ( const void * ) & (
rtDW . bhhchkty0k ) , sizeof ( rtDW . bhhchkty0k ) ) ;
mr_SM24_model_cacheDataAsMxArray ( rtdwData , 0 , 14 , ( const void * ) & (
rtDW . drqqz0z3u2 ) , sizeof ( rtDW . drqqz0z3u2 ) ) ; mxSetFieldByNumber (
ssDW , 0 , 1 , rtdwData ) ; } return ssDW ; } void mr_SM24_model_SetDWork (
const mxArray * ssDW ) { ( void ) ssDW ; mr_SM24_model_restoreDataFromMxArray
( ( void * ) & ( rtB ) , ssDW , 0 , 0 , sizeof ( rtB ) ) ; { const mxArray *
rtdwData = mxGetFieldByNumber ( ssDW , 0 , 1 ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . celqvbnenk ) ,
rtdwData , 0 , 0 , sizeof ( rtDW . celqvbnenk ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . jokvmc1vow ) ,
rtdwData , 0 , 1 , sizeof ( rtDW . jokvmc1vow ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . d4s54ffcej ) ,
rtdwData , 0 , 2 , sizeof ( rtDW . d4s54ffcej ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . cs5gabfwq4 ) ,
rtdwData , 0 , 3 , sizeof ( rtDW . cs5gabfwq4 ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . olwuylhr2k ) ,
rtdwData , 0 , 4 , sizeof ( rtDW . olwuylhr2k ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . ptcy4m1wr0 ) ,
rtdwData , 0 , 5 , sizeof ( rtDW . ptcy4m1wr0 ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . ipswhlfltx ) ,
rtdwData , 0 , 6 , sizeof ( rtDW . ipswhlfltx ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . g2ubuwhrn0 ) ,
rtdwData , 0 , 7 , sizeof ( rtDW . g2ubuwhrn0 ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . pkz43umjxy ) ,
rtdwData , 0 , 8 , sizeof ( rtDW . pkz43umjxy ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . e02zzncljy ) ,
rtdwData , 0 , 9 , sizeof ( rtDW . e02zzncljy ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . nqr2ask1kh ) ,
rtdwData , 0 , 10 , sizeof ( rtDW . nqr2ask1kh ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . ehbyr4oova ) ,
rtdwData , 0 , 11 , sizeof ( rtDW . ehbyr4oova ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . gsuxxg2o4n ) ,
rtdwData , 0 , 12 , sizeof ( rtDW . gsuxxg2o4n ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . bhhchkty0k ) ,
rtdwData , 0 , 13 , sizeof ( rtDW . bhhchkty0k ) ) ;
mr_SM24_model_restoreDataFromMxArray ( ( void * ) & ( rtDW . drqqz0z3u2 ) ,
rtdwData , 0 , 14 , sizeof ( rtDW . drqqz0z3u2 ) ) ; } } mxArray *
mr_SM24_model_GetSimStateDisallowedBlocks ( ) { mxArray * data =
mxCreateCellMatrix ( 3 , 3 ) ; mwIndex subs [ 2 ] , offset ; { static const
char_T * blockType [ 3 ] = { "SimscapeExecutionBlock" ,
"SimscapeExecutionBlock" , "Scope" , } ; static const char_T * blockPath [ 3
] = { "SM24_model/Solver Configuration/EVAL_KEY/STATE_1" ,
"SM24_model/Solver Configuration/EVAL_KEY/OUTPUT_1_0" , "SM24_model/Scope" ,
} ; static const int reason [ 3 ] = { 0 , 0 , 0 , } ; for ( subs [ 0 ] = 0 ;
subs [ 0 ] < 3 ; ++ ( subs [ 0 ] ) ) { subs [ 1 ] = 0 ; offset =
mxCalcSingleSubscript ( data , 2 , subs ) ; mxSetCell ( data , offset ,
mxCreateString ( blockType [ subs [ 0 ] ] ) ) ; subs [ 1 ] = 1 ; offset =
mxCalcSingleSubscript ( data , 2 , subs ) ; mxSetCell ( data , offset ,
mxCreateString ( blockPath [ subs [ 0 ] ] ) ) ; subs [ 1 ] = 2 ; offset =
mxCalcSingleSubscript ( data , 2 , subs ) ; mxSetCell ( data , offset ,
mxCreateDoubleScalar ( ( real_T ) reason [ subs [ 0 ] ] ) ) ; } } return data
; } void MdlInitializeSizes ( void ) { ssSetNumContStates ( rtS , 7 ) ;
ssSetNumPeriodicContStates ( rtS , 0 ) ; ssSetNumY ( rtS , 0 ) ; ssSetNumU (
rtS , 0 ) ; ssSetDirectFeedThrough ( rtS , 0 ) ; ssSetNumSampleTimes ( rtS ,
2 ) ; ssSetNumBlocks ( rtS , 45 ) ; ssSetNumBlockIO ( rtS , 9 ) ;
ssSetNumBlockParams ( rtS , 12 ) ; } void MdlInitializeSampleTimes ( void ) {
ssSetSampleTime ( rtS , 0 , 0.0 ) ; ssSetSampleTime ( rtS , 1 , 0.0 ) ;
ssSetOffsetTime ( rtS , 0 , 0.0 ) ; ssSetOffsetTime ( rtS , 1 , 1.0 ) ; }
void raccel_set_checksum ( ) { ssSetChecksumVal ( rtS , 0 , 3391073398U ) ;
ssSetChecksumVal ( rtS , 1 , 1272981956U ) ; ssSetChecksumVal ( rtS , 2 ,
1383899044U ) ; ssSetChecksumVal ( rtS , 3 , 2805460587U ) ; }
#if defined(_MSC_VER)
#pragma optimize( "", off )
#endif
SimStruct * raccel_register_model ( ssExecutionInfo * executionInfo ) {
static struct _ssMdlInfo mdlInfo ; static struct _ssBlkInfo2 blkInfo2 ;
static struct _ssBlkInfoSLSize blkInfoSLSize ; rt_modelMapInfoPtr = & (
rt_dataMapInfo . mmi ) ; executionInfo -> gblObjects_ . numToFiles = 0 ;
executionInfo -> gblObjects_ . numFrFiles = 0 ; executionInfo -> gblObjects_
. numFrWksBlocks = 0 ; executionInfo -> gblObjects_ . numModelInputs = 0 ;
executionInfo -> gblObjects_ . numRootInportBlks = 0 ; executionInfo ->
gblObjects_ . inportDataTypeIdx = NULL ; executionInfo -> gblObjects_ .
inportDims = NULL ; executionInfo -> gblObjects_ . inportComplex = NULL ;
executionInfo -> gblObjects_ . inportInterpoFlag = NULL ; executionInfo ->
gblObjects_ . inportContinuous = NULL ; ( void ) memset ( ( char_T * ) rtS ,
0 , sizeof ( SimStruct ) ) ; ( void ) memset ( ( char_T * ) & mdlInfo , 0 ,
sizeof ( struct _ssMdlInfo ) ) ; ( void ) memset ( ( char_T * ) & blkInfo2 ,
0 , sizeof ( struct _ssBlkInfo2 ) ) ; ( void ) memset ( ( char_T * ) &
blkInfoSLSize , 0 , sizeof ( struct _ssBlkInfoSLSize ) ) ; ssSetBlkInfo2Ptr (
rtS , & blkInfo2 ) ; ssSetBlkInfoSLSizePtr ( rtS , & blkInfoSLSize ) ;
ssSetMdlInfoPtr ( rtS , & mdlInfo ) ; ssSetExecutionInfo ( rtS ,
executionInfo ) ; slsaAllocOPModelData ( rtS ) ; { static time_T mdlPeriod [
NSAMPLE_TIMES ] ; static time_T mdlOffset [ NSAMPLE_TIMES ] ; static time_T
mdlTaskTimes [ NSAMPLE_TIMES ] ; static int_T mdlTsMap [ NSAMPLE_TIMES ] ;
static int_T mdlSampleHits [ NSAMPLE_TIMES ] ; static boolean_T
mdlTNextWasAdjustedPtr [ NSAMPLE_TIMES ] ; static int_T mdlPerTaskSampleHits
[ NSAMPLE_TIMES * NSAMPLE_TIMES ] ; static time_T mdlTimeOfNextSampleHit [
NSAMPLE_TIMES ] ; { int_T i ; for ( i = 0 ; i < NSAMPLE_TIMES ; i ++ ) {
mdlPeriod [ i ] = 0.0 ; mdlOffset [ i ] = 0.0 ; mdlTaskTimes [ i ] = 0.0 ;
mdlTsMap [ i ] = i ; mdlSampleHits [ i ] = 1 ; } } ssSetSampleTimePtr ( rtS ,
& mdlPeriod [ 0 ] ) ; ssSetOffsetTimePtr ( rtS , & mdlOffset [ 0 ] ) ;
ssSetSampleTimeTaskIDPtr ( rtS , & mdlTsMap [ 0 ] ) ; ssSetTPtr ( rtS , &
mdlTaskTimes [ 0 ] ) ; ssSetSampleHitPtr ( rtS , & mdlSampleHits [ 0 ] ) ;
ssSetTNextWasAdjustedPtr ( rtS , & mdlTNextWasAdjustedPtr [ 0 ] ) ;
ssSetPerTaskSampleHitsPtr ( rtS , & mdlPerTaskSampleHits [ 0 ] ) ;
ssSetTimeOfNextSampleHitPtr ( rtS , & mdlTimeOfNextSampleHit [ 0 ] ) ; }
ssSetSolverMode ( rtS , SOLVER_MODE_SINGLETASKING ) ; { ssSetBlockIO ( rtS ,
( ( void * ) & rtB ) ) ; ( void ) memset ( ( ( void * ) & rtB ) , 0 , sizeof
( B ) ) ; } { real_T * x = ( real_T * ) & rtX ; ssSetContStates ( rtS , x ) ;
( void ) memset ( ( void * ) x , 0 , sizeof ( X ) ) ; } { void * dwork = (
void * ) & rtDW ; ssSetRootDWork ( rtS , dwork ) ; ( void ) memset ( dwork ,
0 , sizeof ( DW ) ) ; } { static DataTypeTransInfo dtInfo ; ( void ) memset (
( char_T * ) & dtInfo , 0 , sizeof ( dtInfo ) ) ; ssSetModelMappingInfo ( rtS
, & dtInfo ) ; dtInfo . numDataTypes = 23 ; dtInfo . dataTypeSizes = &
rtDataTypeSizes [ 0 ] ; dtInfo . dataTypeNames = & rtDataTypeNames [ 0 ] ;
dtInfo . BTransTable = & rtBTransTable ; dtInfo . PTransTable = &
rtPTransTable ; dtInfo . dataTypeInfoTable = rtDataTypeInfoTable ; }
SM24_model_InitializeDataMapInfo ( ) ; ssSetIsRapidAcceleratorActive ( rtS ,
true ) ; ssSetRootSS ( rtS , rtS ) ; ssSetVersion ( rtS ,
SIMSTRUCT_VERSION_LEVEL2 ) ; ssSetModelName ( rtS , "SM24_model" ) ;
ssSetPath ( rtS , "SM24_model" ) ; ssSetTStart ( rtS , 0.0 ) ; ssSetTFinal (
rtS , 10.0 ) ; { static RTWLogInfo rt_DataLoggingInfo ; rt_DataLoggingInfo .
loggingInterval = ( NULL ) ; ssSetRTWLogInfo ( rtS , & rt_DataLoggingInfo ) ;
} { { static int_T rt_LoggedStateWidths [ ] = { 1 , 1 , 1 , 1 , 1 , 1 , 1 , 2
, 17 } ; static int_T rt_LoggedStateNumDimensions [ ] = { 1 , 1 , 1 , 1 , 1 ,
1 , 1 , 1 , 1 } ; static int_T rt_LoggedStateDimensions [ ] = { 1 , 1 , 1 , 1
, 1 , 1 , 1 , 2 , 17 } ; static boolean_T rt_LoggedStateIsVarDims [ ] = { 0 ,
0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 } ; static BuiltInDTypeId
rt_LoggedStateDataTypeIds [ ] = { SS_DOUBLE , SS_DOUBLE , SS_DOUBLE ,
SS_DOUBLE , SS_DOUBLE , SS_DOUBLE , SS_DOUBLE , SS_DOUBLE , SS_DOUBLE } ;
static int_T rt_LoggedStateComplexSignals [ ] = { 0 , 0 , 0 , 0 , 0 , 0 , 0 ,
0 , 0 } ; static RTWPreprocessingFcnPtr rt_LoggingStatePreprocessingFcnPtrs [
] = { ( NULL ) , ( NULL ) , ( NULL ) , ( NULL ) , ( NULL ) , ( NULL ) , (
NULL ) , ( NULL ) , ( NULL ) } ; static const char_T * rt_LoggedStateLabels [
] = { "CSTATE" , "CSTATE" , "CSTATE" , "CSTATE" , "CSTATE" , "CSTATE" ,
"CSTATE" , "Discrete" , "Discrete" } ; static const char_T *
rt_LoggedStateBlockNames [ ] = { "SM24_model/Band-Limited Op-Amp" ,
"SM24_model/Capacitor" , "SM24_model/Capacitor1" , "SM24_model/Inductor" ,
"SM24_model/Capacitor2" , "SM24_model/Floating Reference" ,
"SM24_model/Floating Reference1" ,
"SM24_model/Solver\nConfiguration/EVAL_KEY/INPUT_1_1_1" ,
"SM24_model/Solver\nConfiguration/EVAL_KEY/STATE_1" } ; static const char_T *
rt_LoggedStateNames [ ] = { "SM24_model.Band_Limited_Op_Amp.v_int" ,
"SM24_model.Capacitor.vc" , "SM24_model.Capacitor1.vc" ,
"SM24_model.Inductor.i_L" , "SM24_model.Capacitor2.vc" ,
"SM24_model.Floating_Reference.q" , "SM24_model.Floating_Reference1.q" ,
"Discrete" , "Discrete" } ; static boolean_T rt_LoggedStateCrossMdlRef [ ] =
{ 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 } ; static RTWLogDataTypeConvert
rt_RTWLogDataTypeConvert [ ] = { { 0 , SS_DOUBLE , SS_DOUBLE , 0 , 0 , 0 ,
1.0 , 0 , 0.0 } , { 0 , SS_DOUBLE , SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 , 0.0 } ,
{ 0 , SS_DOUBLE , SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 , 0.0 } , { 0 , SS_DOUBLE ,
SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 , 0.0 } , { 0 , SS_DOUBLE , SS_DOUBLE , 0 , 0
, 0 , 1.0 , 0 , 0.0 } , { 0 , SS_DOUBLE , SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 ,
0.0 } , { 0 , SS_DOUBLE , SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 , 0.0 } , { 0 ,
SS_DOUBLE , SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 , 0.0 } , { 0 , SS_DOUBLE ,
SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 , 0.0 } } ; static int_T
rt_LoggedStateIdxList [ ] = { 0 , 0 , 1 } ; static RTWLogSignalInfo
rt_LoggedStateSignalInfo = { 9 , rt_LoggedStateWidths ,
rt_LoggedStateNumDimensions , rt_LoggedStateDimensions ,
rt_LoggedStateIsVarDims , ( NULL ) , ( NULL ) , rt_LoggedStateDataTypeIds ,
rt_LoggedStateComplexSignals , ( NULL ) , rt_LoggingStatePreprocessingFcnPtrs
, { rt_LoggedStateLabels } , ( NULL ) , ( NULL ) , ( NULL ) , {
rt_LoggedStateBlockNames } , { rt_LoggedStateNames } ,
rt_LoggedStateCrossMdlRef , rt_RTWLogDataTypeConvert , rt_LoggedStateIdxList
} ; static void * rt_LoggedStateSignalPtrs [ 9 ] ; rtliSetLogXSignalPtrs (
ssGetRTWLogInfo ( rtS ) , ( LogSignalPtrsType ) rt_LoggedStateSignalPtrs ) ;
rtliSetLogXSignalInfo ( ssGetRTWLogInfo ( rtS ) , & rt_LoggedStateSignalInfo
) ; rt_LoggedStateSignalPtrs [ 0 ] = ( void * ) & rtX . d3yrpwytgj [ 0 ] ;
rt_LoggedStateSignalPtrs [ 1 ] = ( void * ) & rtX . d3yrpwytgj [ 1 ] ;
rt_LoggedStateSignalPtrs [ 2 ] = ( void * ) & rtX . d3yrpwytgj [ 2 ] ;
rt_LoggedStateSignalPtrs [ 3 ] = ( void * ) & rtX . d3yrpwytgj [ 3 ] ;
rt_LoggedStateSignalPtrs [ 4 ] = ( void * ) & rtX . d3yrpwytgj [ 4 ] ;
rt_LoggedStateSignalPtrs [ 5 ] = ( void * ) & rtX . d3yrpwytgj [ 5 ] ;
rt_LoggedStateSignalPtrs [ 6 ] = ( void * ) & rtX . d3yrpwytgj [ 6 ] ;
rt_LoggedStateSignalPtrs [ 7 ] = ( void * ) rtDW . celqvbnenk ;
rt_LoggedStateSignalPtrs [ 8 ] = ( void * ) rtDW . jokvmc1vow ; } rtliSetLogT
( ssGetRTWLogInfo ( rtS ) , "tout" ) ; rtliSetLogX ( ssGetRTWLogInfo ( rtS )
, "" ) ; rtliSetLogXFinal ( ssGetRTWLogInfo ( rtS ) , "xFinal" ) ;
rtliSetLogVarNameModifier ( ssGetRTWLogInfo ( rtS ) , "none" ) ;
rtliSetLogFormat ( ssGetRTWLogInfo ( rtS ) , 4 ) ; rtliSetLogMaxRows (
ssGetRTWLogInfo ( rtS ) , 0 ) ; rtliSetLogDecimation ( ssGetRTWLogInfo ( rtS
) , 1 ) ; rtliSetLogY ( ssGetRTWLogInfo ( rtS ) , "" ) ;
rtliSetLogYSignalInfo ( ssGetRTWLogInfo ( rtS ) , ( NULL ) ) ;
rtliSetLogYSignalPtrs ( ssGetRTWLogInfo ( rtS ) , ( NULL ) ) ; } { static
struct _ssStatesInfo2 statesInfo2 ; ssSetStatesInfo2 ( rtS , & statesInfo2 )
; } { static ssPeriodicStatesInfo periodicStatesInfo ;
ssSetPeriodicStatesInfo ( rtS , & periodicStatesInfo ) ; } { static
ssJacobianPerturbationBounds jacobianPerturbationBounds ;
ssSetJacobianPerturbationBounds ( rtS , & jacobianPerturbationBounds ) ; } {
static ssSolverInfo slvrInfo ; static boolean_T contStatesDisabled [ 7 ] ;
static real_T absTol [ 7 ] = { 1.0E-6 , 1.0E-6 , 1.0E-6 , 1.0E-6 , 1.0E-6 ,
1.0E-6 , 1.0E-6 } ; static uint8_T absTolControl [ 7 ] = { 0U , 0U , 0U , 0U
, 0U , 0U , 0U } ; static real_T contStateJacPerturbBoundMinVec [ 7 ] ;
static real_T contStateJacPerturbBoundMaxVec [ 7 ] ; static uint8_T
zcAttributes [ 9 ] = { ( ZC_EVENT_ALL_UP ) , ( ZC_EVENT_P2Z | ZC_EVENT_P2N |
ZC_EVENT_Z2P | ZC_EVENT_N2P ) , ( ZC_EVENT_P2Z | ZC_EVENT_P2N | ZC_EVENT_Z2P
| ZC_EVENT_N2P ) , ( ZC_EVENT_P2Z | ZC_EVENT_P2N | ZC_EVENT_Z2P |
ZC_EVENT_N2P ) , ( ZC_EVENT_P2Z | ZC_EVENT_P2N | ZC_EVENT_Z2P | ZC_EVENT_N2P
) , ( ZC_EVENT_ALL ) , ( ZC_EVENT_ALL ) , ( ZC_EVENT_ALL ) , ( ZC_EVENT_ALL )
} ; static ssNonContDerivSigInfo nonContDerivSigInfo [ 1 ] = { { 1 * sizeof (
real_T ) , ( char * ) ( & rtB . hptfqp3w4t ) , ( NULL ) } } ; { int i ; for (
i = 0 ; i < 7 ; ++ i ) { contStateJacPerturbBoundMinVec [ i ] = 0 ;
contStateJacPerturbBoundMaxVec [ i ] = rtGetInf ( ) ; } } ssSetSolverRelTol (
rtS , 0.001 ) ; ssSetStepSize ( rtS , 0.0 ) ; ssSetMinStepSize ( rtS , 0.0 )
; ssSetMaxNumMinSteps ( rtS , - 1 ) ; ssSetMinStepViolatedError ( rtS , 0 ) ;
ssSetMaxStepSize ( rtS , 0.2 ) ; ssSetSolverMaxOrder ( rtS , - 1 ) ;
ssSetSolverRefineFactor ( rtS , 1 ) ; ssSetOutputTimes ( rtS , ( NULL ) ) ;
ssSetNumOutputTimes ( rtS , 0 ) ; ssSetOutputTimesOnly ( rtS , 0 ) ;
ssSetOutputTimesIndex ( rtS , 0 ) ; ssSetZCCacheNeedsReset ( rtS , 1 ) ;
ssSetDerivCacheNeedsReset ( rtS , 0 ) ; ssSetNumNonContDerivSigInfos ( rtS ,
1 ) ; ssSetNonContDerivSigInfos ( rtS , nonContDerivSigInfo ) ;
ssSetSolverInfo ( rtS , & slvrInfo ) ; ssSetSolverName ( rtS ,
"VariableStepAuto" ) ; ssSetVariableStepSolver ( rtS , 1 ) ;
ssSetSolverConsistencyChecking ( rtS , 0 ) ; ssSetSolverAdaptiveZcDetection (
rtS , 0 ) ; ssSetSolverRobustResetMethod ( rtS , 0 ) ;
_ssSetSolverUpdateJacobianAtReset ( rtS , true ) ; ssSetAbsTolVector ( rtS ,
absTol ) ; ssSetAbsTolControlVector ( rtS , absTolControl ) ;
ssSetSolverAbsTol_Obsolete ( rtS , absTol ) ;
ssSetSolverAbsTolControl_Obsolete ( rtS , absTolControl ) ;
ssSetJacobianPerturbationBoundsMinVec ( rtS , contStateJacPerturbBoundMinVec
) ; ssSetJacobianPerturbationBoundsMaxVec ( rtS ,
contStateJacPerturbBoundMaxVec ) ; ssSetSolverStateProjection ( rtS , 0 ) ;
ssSetSolverMassMatrixType ( rtS , ( ssMatrixType ) 0 ) ;
ssSetSolverMassMatrixNzMax ( rtS , 0 ) ; ssSetModelOutputs ( rtS , MdlOutputs
) ; ssSetModelUpdate ( rtS , MdlUpdate ) ; ssSetModelDerivatives ( rtS ,
MdlDerivatives ) ; ssSetSolverZcSignalAttrib ( rtS , zcAttributes ) ;
ssSetSolverNumZcSignals ( rtS , 9 ) ; ssSetModelZeroCrossings ( rtS ,
MdlZeroCrossings ) ; ssSetSolverConsecutiveZCsStepRelTol ( rtS ,
2.8421709430404007E-13 ) ; ssSetSolverMaxConsecutiveZCs ( rtS , 1000 ) ;
ssSetSolverConsecutiveZCsError ( rtS , 2 ) ; ssSetSolverMaskedZcDiagnostic (
rtS , 1 ) ; ssSetSolverIgnoredZcDiagnostic ( rtS , 1 ) ;
ssSetSolverMaxConsecutiveMinStep ( rtS , 1 ) ;
ssSetSolverShapePreserveControl ( rtS , 2 ) ; ssSetTNextTid ( rtS , INT_MIN )
; ssSetTNext ( rtS , rtMinusInf ) ; ssSetSolverNeedsReset ( rtS ) ;
ssSetNumNonsampledZCs ( rtS , 9 ) ; ssSetContStateDisabled ( rtS ,
contStatesDisabled ) ; ssSetSolverMaxConsecutiveMinStep ( rtS , 1 ) ; }
ssSetChecksumVal ( rtS , 0 , 3391073398U ) ; ssSetChecksumVal ( rtS , 1 ,
1272981956U ) ; ssSetChecksumVal ( rtS , 2 , 1383899044U ) ; ssSetChecksumVal
( rtS , 3 , 2805460587U ) ; { static const sysRanDType rtAlwaysEnabled =
SUBSYS_RAN_BC_ENABLE ; static RTWExtModeInfo rt_ExtModeInfo ; static const
sysRanDType * systemRan [ 1 ] ; gblRTWExtModeInfo = & rt_ExtModeInfo ;
ssSetRTWExtModeInfo ( rtS , & rt_ExtModeInfo ) ;
rteiSetSubSystemActiveVectorAddresses ( & rt_ExtModeInfo , systemRan ) ;
systemRan [ 0 ] = & rtAlwaysEnabled ; rteiSetModelMappingInfoPtr (
ssGetRTWExtModeInfo ( rtS ) , & ssGetModelMappingInfo ( rtS ) ) ;
rteiSetChecksumsPtr ( ssGetRTWExtModeInfo ( rtS ) , ssGetChecksums ( rtS ) )
; rteiSetTPtr ( ssGetRTWExtModeInfo ( rtS ) , ssGetTPtr ( rtS ) ) ; }
slsaDisallowedBlocksForSimTargetOP ( rtS ,
mr_SM24_model_GetSimStateDisallowedBlocks ) ; slsaGetWorkFcnForSimTargetOP (
rtS , mr_SM24_model_GetDWork ) ; slsaSetWorkFcnForSimTargetOP ( rtS ,
mr_SM24_model_SetDWork ) ; rt_RapidReadMatFileAndUpdateParams ( rtS ) ; if (
ssGetErrorStatus ( rtS ) ) { return rtS ; } return rtS ; }
#if defined(_MSC_VER)
#pragma optimize( "", on )
#endif
void MdlOutputsParameterSampleTime ( int_T tid ) { MdlOutputsTID2 ( tid ) ; }
