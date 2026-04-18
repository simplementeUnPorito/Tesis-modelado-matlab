#include "FiltroDigital.h"
#include <string.h>
#include "rtwtypes.h"
#include "FiltroDigital_private.h"
#include "rt_logging_mmi.h"
#include "FiltroDigital_capi.h"
#include "multiword_types.h"
#include "FiltroDigital_dt.h"
extern void * CreateDiagnosticAsVoidPtr_wrapper ( const char * id , int nargs
, ... ) ; extern ssExecutionInfo gblExecutionInfo ; RTWExtModeInfo *
gblRTWExtModeInfo = NULL ; void raccelForceExtModeShutdown ( boolean_T
extModeStartPktReceived ) { if ( ! extModeStartPktReceived ) { boolean_T
stopRequested = false ; rtExtModeWaitForStartPkt ( gblRTWExtModeInfo , 7 , &
stopRequested ) ; } rtExtModeShutdown ( 7 ) ; }
#include "slsv_diagnostic_codegen_c_api.h"
#include "slsa_sim_engine.h"
#ifdef RSIM_WITH_SOLVER_MULTITASKING
boolean_T gbl_raccel_isMultitasking = 1 ;
#else
boolean_T gbl_raccel_isMultitasking = 0 ;
#endif
boolean_T gbl_raccel_tid01eq = 0 ; int_T gbl_raccel_NumST = 7 ; const char_T
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
rt_dataMapInfo . mmi ) ; int_T enableFcnCallFlag [ ] = { 1 , 1 , 1 , 1 , 1 ,
1 , 1 } ; const char * raccelLoadInputsAndAperiodicHitTimes ( SimStruct * S ,
const char * inportFileName , int * matFileFormat ) { return
rt_RAccelReadInportsMatFile ( S , inportFileName , matFileFormat ) ; }
FrFInfo FiltroDigital_gblFrFInfo [ 1 ] ;
#include "simstruc.h"
#include "fixedpoint.h"
#include "slsa_sim_engine.h"
#include "simtarget/slSimTgtSLExecSimBridge.h"
B rtB ; X rtX ; DW rtDW ; static SimStruct model_S ; SimStruct * const rtS =
& model_S ;
#ifndef __RTW_UTFREE__  
extern void * utMalloc ( size_t ) ;
#endif
void * rt_TDelayCreateBuf ( int_T numBuffer , int_T bufSz , int_T elemSz ) {
return ( ( void * ) utMalloc ( numBuffer * bufSz * elemSz ) ) ; }
#ifndef __RTW_UTFREE__  
extern void * utMalloc ( size_t ) ; extern void utFree ( void * ) ;
#endif
boolean_T rt_TDelayUpdateTailOrGrowBuf ( int_T * bufSzPtr , int_T * tailPtr ,
int_T * headPtr , int_T * lastPtr , real_T tMinusDelay , real_T * * uBufPtr ,
boolean_T isfixedbuf , boolean_T istransportdelay , int_T * maxNewBufSzPtr )
{ int_T testIdx ; int_T tail = * tailPtr ; int_T bufSz = * bufSzPtr ; real_T
* tBuf = * uBufPtr + bufSz ; real_T * xBuf = ( NULL ) ; int_T numBuffer = 2 ;
if ( istransportdelay ) { numBuffer = 3 ; xBuf = * uBufPtr + 2 * bufSz ; }
testIdx = ( tail < ( bufSz - 1 ) ) ? ( tail + 1 ) : 0 ; if ( ( tMinusDelay <=
tBuf [ testIdx ] ) && ! isfixedbuf ) { int_T j ; real_T * tempT ; real_T *
tempU ; real_T * tempX = ( NULL ) ; real_T * uBuf = * uBufPtr ; int_T
newBufSz = bufSz + 1024 ; if ( newBufSz > * maxNewBufSzPtr ) { *
maxNewBufSzPtr = newBufSz ; } tempU = ( real_T * ) utMalloc ( numBuffer *
newBufSz * sizeof ( real_T ) ) ; if ( tempU == ( NULL ) ) { return ( false )
; } tempT = tempU + newBufSz ; if ( istransportdelay ) tempX = tempT +
newBufSz ; for ( j = tail ; j < bufSz ; j ++ ) { tempT [ j - tail ] = tBuf [
j ] ; tempU [ j - tail ] = uBuf [ j ] ; if ( istransportdelay ) tempX [ j -
tail ] = xBuf [ j ] ; } for ( j = 0 ; j < tail ; j ++ ) { tempT [ j + bufSz -
tail ] = tBuf [ j ] ; tempU [ j + bufSz - tail ] = uBuf [ j ] ; if (
istransportdelay ) tempX [ j + bufSz - tail ] = xBuf [ j ] ; } if ( * lastPtr
> tail ) { * lastPtr -= tail ; } else { * lastPtr += ( bufSz - tail ) ; } *
tailPtr = 0 ; * headPtr = bufSz ; utFree ( uBuf ) ; * bufSzPtr = newBufSz ; *
uBufPtr = tempU ; } else { * tailPtr = testIdx ; } return ( true ) ; } real_T
rt_TDelayInterpolate ( real_T tMinusDelay , real_T tStart , real_T * uBuf ,
int_T bufSz , int_T * lastIdx , int_T oldestIdx , int_T newIdx , real_T
initOutput , boolean_T discrete , boolean_T minorStepAndTAtLastMajorOutput )
{ int_T i ; real_T yout , t1 , t2 , u1 , u2 ; real_T * tBuf = uBuf + bufSz ;
if ( ( newIdx == 0 ) && ( oldestIdx == 0 ) && ( tMinusDelay > tStart ) )
return initOutput ; if ( tMinusDelay <= tStart ) return initOutput ; if ( (
tMinusDelay <= tBuf [ oldestIdx ] ) ) { if ( discrete ) { return ( uBuf [
oldestIdx ] ) ; } else { int_T tempIdx = oldestIdx + 1 ; if ( oldestIdx ==
bufSz - 1 ) tempIdx = 0 ; t1 = tBuf [ oldestIdx ] ; t2 = tBuf [ tempIdx ] ;
u1 = uBuf [ oldestIdx ] ; u2 = uBuf [ tempIdx ] ; if ( t2 == t1 ) { if (
tMinusDelay >= t2 ) { yout = u2 ; } else { yout = u1 ; } } else { real_T f1 =
( t2 - tMinusDelay ) / ( t2 - t1 ) ; real_T f2 = 1.0 - f1 ; yout = f1 * u1 +
f2 * u2 ; } return yout ; } } if ( minorStepAndTAtLastMajorOutput ) { if (
newIdx != 0 ) { if ( * lastIdx == newIdx ) { ( * lastIdx ) -- ; } newIdx -- ;
} else { if ( * lastIdx == newIdx ) { * lastIdx = bufSz - 1 ; } newIdx =
bufSz - 1 ; } } i = * lastIdx ; if ( tBuf [ i ] < tMinusDelay ) { while (
tBuf [ i ] < tMinusDelay ) { if ( i == newIdx ) break ; i = ( i < ( bufSz - 1
) ) ? ( i + 1 ) : 0 ; } } else { while ( tBuf [ i ] >= tMinusDelay ) { i = (
i > 0 ) ? i - 1 : ( bufSz - 1 ) ; } i = ( i < ( bufSz - 1 ) ) ? ( i + 1 ) : 0
; } * lastIdx = i ; if ( discrete ) { double tempEps = ( DBL_EPSILON ) *
128.0 ; double localEps = tempEps * muDoubleScalarAbs ( tBuf [ i ] ) ; if (
tempEps > localEps ) { localEps = tempEps ; } localEps = localEps / 2.0 ; if
( tMinusDelay >= ( tBuf [ i ] - localEps ) ) { yout = uBuf [ i ] ; } else {
if ( i == 0 ) { yout = uBuf [ bufSz - 1 ] ; } else { yout = uBuf [ i - 1 ] ;
} } } else { if ( i == 0 ) { t1 = tBuf [ bufSz - 1 ] ; u1 = uBuf [ bufSz - 1
] ; } else { t1 = tBuf [ i - 1 ] ; u1 = uBuf [ i - 1 ] ; } t2 = tBuf [ i ] ;
u2 = uBuf [ i ] ; if ( t2 == t1 ) { if ( tMinusDelay >= t2 ) { yout = u2 ; }
else { yout = u1 ; } } else { real_T f1 = ( t2 - tMinusDelay ) / ( t2 - t1 )
; real_T f2 = 1.0 - f1 ; yout = f1 * u1 + f2 * u2 ; } } return ( yout ) ; }
#ifndef __RTW_UTFREE__  
extern void utFree ( void * ) ;
#endif
void rt_TDelayFreeBuf ( void * buf ) { utFree ( buf ) ; } void MdlInitialize
( void ) { rtX . l3yd0y2y2l = rtP . Integrator_IC ; rtDW . hyv24f5d51 = 24 ;
rtDW . eyj42yi00f = 3 ; rtDW . owb0zwuiuz = 21 ; memset ( & rtDW . mj4dkemmao
[ 0 ] , 0 , sizeof ( real_T ) << 5U ) ; memset ( & rtDW . bn1o5gqwpb [ 0 ] ,
0 , 28U * sizeof ( real_T ) ) ; rtDW . ooy1b32g4y = 24 ; rtDW . kjzvekaraj =
3 ; rtDW . i0ma42xyy5 = 21 ; memset ( & rtDW . b0w5k5lope [ 0 ] , 0 , sizeof
( real_T ) << 5U ) ; memset ( & rtDW . h2xuphcqn2 [ 0 ] , 0 , 28U * sizeof (
real_T ) ) ; rtDW . i5qv5clxbu = 24 ; rtDW . hdcl1gc5nw = 3 ; rtDW .
gwh5ypvhka = 21 ; memset ( & rtDW . nqobrzgsxp [ 0 ] , 0 , sizeof ( real_T )
<< 5U ) ; memset ( & rtDW . fiwlfo2bcx [ 0 ] , 0 , 28U * sizeof ( real_T ) )
; } void MdlStart ( void ) { { bool externalInputIsInDatasetFormat = false ;
void * pISigstreamManager = rt_GetISigstreamManager ( rtS ) ;
rtwISigstreamManagerGetInputIsInDatasetFormat ( pISigstreamManager , &
externalInputIsInDatasetFormat ) ; if ( externalInputIsInDatasetFormat ) { }
} { char ptrKey [ 1024 ] ; { real_T * pBuffer = ( real_T * )
rt_TDelayCreateBuf ( 2 , 1024 , sizeof ( real_T ) ) ; if ( pBuffer == ( NULL
) ) { ssSetErrorStatus ( rtS , "tdelay memory allocation error" ) ; return ;
} rtDW . fc4nqsu01a . Tail = 0 ; rtDW . fc4nqsu01a . Head = 0 ; rtDW .
fc4nqsu01a . Last = 0 ; rtDW . fc4nqsu01a . CircularBufSize = 1024 ; pBuffer
[ 0 ] = ( rtP . TransportDelay_InitOutput ) ; pBuffer [ 1024 ] = ssGetT ( rtS
) ; rtDW . muybj1k10g . TUbufferPtrs [ 0 ] = ( void * ) & pBuffer [ 0 ] ;
sprintf ( ptrKey , "FiltroDigital/Transport\nDelay_TUbuffer%d" , 0 ) ;
slsaSaveRawMemoryForSimTargetOP ( rtS , ptrKey , ( void * * ) ( & rtDW .
muybj1k10g . TUbufferPtrs [ 0 ] ) , 2 * 1024 * sizeof ( real_T ) , ( NULL ) ,
( NULL ) ) ; } } { char fileName [ 509 ] =
"C:\\Github\\Tesis\\src\\matlab\\SM-24\\AnalogOut.mat" ; const char *
blockpath = "FiltroDigital/From File" ; if ( slIsRapidAcceleratorSimulating (
) ) { rt_RAccelReplaceFromFilename ( blockpath , fileName ) ; } { void * fp =
( NULL ) ; const char * errMsg = ( NULL ) ; errMsg =
rtwMatFileLoaderCollectionCreateInstance ( 1 , & fp ) ; if ( errMsg != ( NULL
) ) { ssSetErrorStatus ( rtS , errMsg ) ; return ; } rtDW . on5ziqb2sn .
PrevTimePtr = fp ; { unsigned char groundValue [ ] = { 0U , 0U , 0U , 0U , 0U
, 0U , 0U , 0U } ; const int enumNStrings = 0 ; const char * * enumStrings =
( NULL ) ; const int32_T * enumValues = ( NULL ) ; int_T dimensions [ 1 ] = {
1 } ; errMsg = rtwMatFileLoaderCollectionAddElement ( 1 , fp , fileName , ""
, 0 , 1 , 0 , 0 , groundValue , "double" , 0 , 1 , dimensions , 0 , 0 , 0 , 0
, 0 , 0 , 0 , 0 , enumNStrings , enumStrings , enumValues , 1 , 1 ,
"FiltroDigital/From File" ) ; if ( errMsg != ( NULL ) ) { ssSetErrorStatus (
rtS , errMsg ) ; return ; } } } } MdlInitialize ( ) ; } void MdlOutputs (
int_T tid ) { real_T accumulator ; int32_T cffIdx ; int32_T jIdx ; int32_T
maxWindow ; int32_T sumIndx ; { real_T * * uBuffer = ( real_T * * ) & rtDW .
muybj1k10g . TUbufferPtrs [ 0 ] ; real_T simTime = ssGetT ( rtS ) ; real_T
tMinusDelay = simTime - ( rtP . TransportDelay_Delay ) ; rtB . a5tnoiyu3h =
rt_TDelayInterpolate ( tMinusDelay , 0.0 , * uBuffer , rtDW . fc4nqsu01a .
CircularBufSize , & rtDW . fc4nqsu01a . Last , rtDW . fc4nqsu01a . Tail ,
rtDW . fc4nqsu01a . Head , ( rtP . TransportDelay_InitOutput ) , 1 , (
boolean_T ) ( ssIsMinorTimeStep ( rtS ) && ( ( * uBuffer + rtDW . fc4nqsu01a
. CircularBufSize ) [ rtDW . fc4nqsu01a . Head ] == ssGetT ( rtS ) ) ) ) ; }
rtB . nn1docam0d = rtX . l3yd0y2y2l ; if ( ssIsSampleHit ( rtS , 1 , 0 ) ) {
if ( rtB . nn1docam0d > 0.0 ) { rtDW . phwztcrhth = 1 ; } else if ( rtB .
nn1docam0d < 0.0 ) { rtDW . phwztcrhth = - 1 ; } else { rtDW . phwztcrhth = 0
; } rtB . nlibdwom40 = rtDW . phwztcrhth ; } if ( ssIsSampleHit ( rtS , 3 , 0
) ) { rtB . kbcfzcgqyz = rtB . nlibdwom40 ; maxWindow = ( rtDW . eyj42yi00f +
1 ) * 7 ; sumIndx = rtDW . eyj42yi00f << 3 ; rtDW . mj4dkemmao [ sumIndx ] =
rtB . kbcfzcgqyz * rtP . FIRx4aDecimation_FILT [ rtDW . hyv24f5d51 ] ; cffIdx
= rtDW . hyv24f5d51 + 1 ; sumIndx ++ ; for ( jIdx = rtDW . owb0zwuiuz + 1 ;
jIdx < maxWindow ; jIdx ++ ) { rtDW . mj4dkemmao [ sumIndx ] = rtDW .
bn1o5gqwpb [ jIdx ] * rtP . FIRx4aDecimation_FILT [ cffIdx ] ; cffIdx ++ ;
sumIndx ++ ; } for ( jIdx = maxWindow - 7 ; jIdx <= rtDW . owb0zwuiuz ; jIdx
++ ) { rtDW . mj4dkemmao [ sumIndx ] = rtDW . bn1o5gqwpb [ jIdx ] * rtP .
FIRx4aDecimation_FILT [ cffIdx ] ; cffIdx ++ ; sumIndx ++ ; } if ( rtDW .
eyj42yi00f + 1 >= 4 ) { accumulator = rtDW . mj4dkemmao [ 0 ] ; for ( jIdx =
0 ; jIdx < 31 ; jIdx ++ ) { accumulator += rtDW . mj4dkemmao [ jIdx + 1 ] ; }
rtDW . p0upexwcsd = accumulator ; } if ( ssIsSpecialSampleHit ( rtS , 4 , 3 ,
0 ) ) { rtB . cuhgapmu0l = rtDW . p0upexwcsd ; } } if ( ssIsSampleHit ( rtS ,
4 , 0 ) ) { maxWindow = ( rtDW . kjzvekaraj + 1 ) * 7 ; sumIndx = rtDW .
kjzvekaraj << 3 ; rtDW . b0w5k5lope [ sumIndx ] = rtB . cuhgapmu0l * rtP .
FIRx4bDecimation_FILT [ rtDW . ooy1b32g4y ] ; cffIdx = rtDW . ooy1b32g4y + 1
; sumIndx ++ ; for ( jIdx = rtDW . i0ma42xyy5 + 1 ; jIdx < maxWindow ; jIdx
++ ) { rtDW . b0w5k5lope [ sumIndx ] = rtDW . h2xuphcqn2 [ jIdx ] * rtP .
FIRx4bDecimation_FILT [ cffIdx ] ; cffIdx ++ ; sumIndx ++ ; } for ( jIdx =
maxWindow - 7 ; jIdx <= rtDW . i0ma42xyy5 ; jIdx ++ ) { rtDW . b0w5k5lope [
sumIndx ] = rtDW . h2xuphcqn2 [ jIdx ] * rtP . FIRx4bDecimation_FILT [ cffIdx
] ; cffIdx ++ ; sumIndx ++ ; } if ( rtDW . kjzvekaraj + 1 >= 4 ) {
accumulator = rtDW . b0w5k5lope [ 0 ] ; for ( jIdx = 0 ; jIdx < 31 ; jIdx ++
) { accumulator += rtDW . b0w5k5lope [ jIdx + 1 ] ; } rtDW . ojrkdwj1wt =
accumulator ; } if ( ssIsSpecialSampleHit ( rtS , 5 , 4 , 0 ) ) { rtB .
m4mpxizuz3 = rtDW . ojrkdwj1wt ; } } if ( ssIsSampleHit ( rtS , 5 , 0 ) ) {
maxWindow = ( rtDW . hdcl1gc5nw + 1 ) * 7 ; sumIndx = rtDW . hdcl1gc5nw << 3
; rtDW . nqobrzgsxp [ sumIndx ] = rtB . m4mpxizuz3 * rtP .
FIRx4cDecimation_FILT [ rtDW . i5qv5clxbu ] ; cffIdx = rtDW . i5qv5clxbu + 1
; sumIndx ++ ; for ( jIdx = rtDW . gwh5ypvhka + 1 ; jIdx < maxWindow ; jIdx
++ ) { rtDW . nqobrzgsxp [ sumIndx ] = rtDW . fiwlfo2bcx [ jIdx ] * rtP .
FIRx4cDecimation_FILT [ cffIdx ] ; cffIdx ++ ; sumIndx ++ ; } for ( jIdx =
maxWindow - 7 ; jIdx <= rtDW . gwh5ypvhka ; jIdx ++ ) { rtDW . nqobrzgsxp [
sumIndx ] = rtDW . fiwlfo2bcx [ jIdx ] * rtP . FIRx4cDecimation_FILT [ cffIdx
] ; cffIdx ++ ; sumIndx ++ ; } if ( rtDW . hdcl1gc5nw + 1 >= 4 ) {
accumulator = rtDW . nqobrzgsxp [ 0 ] ; for ( jIdx = 0 ; jIdx < 31 ; jIdx ++
) { accumulator += rtDW . nqobrzgsxp [ jIdx + 1 ] ; } rtDW . p2s40fywcf =
accumulator ; } if ( ssIsSpecialSampleHit ( rtS , 6 , 5 , 0 ) ) { rtB .
gousoqy1pl = rtDW . p2s40fywcf ; } } rtB . pvs4axzl4p = rtB . a5tnoiyu3h -
rtB . gousoqy1pl ; if ( ssIsSampleHit ( rtS , 2 , 0 ) ) { { void * fp = (
void * ) rtDW . on5ziqb2sn . PrevTimePtr ; const char * errMsg = ( NULL ) ;
if ( fp != ( NULL ) && ( ssIsMajorTimeStep ( rtS ) || ! 0 ) ) { real_T t =
ssGetTaskTime ( rtS , 2 ) ; { void * y = & rtB . dowb0yskro ; errMsg =
rtwMatFileLoaderCollectionGetOutput ( 1 , fp , 0 , t , ssIsMajorTimeStep (
rtS ) , & y ) ; if ( errMsg != ( NULL ) ) { ssSetErrorStatus ( rtS , errMsg )
; return ; } } } } } if ( ssIsSampleHit ( rtS , 2 , 0 ) ) { rtB . lfhnwo55cp
= rtP . Gain_Gain * rtB . dowb0yskro ; } if ( ssIsSampleHit ( rtS , 1 , 0 ) )
{ rtB . gpy1qxhqhc = rtB . lfhnwo55cp - rtB . kbcfzcgqyz ; } UNUSED_PARAMETER
( tid ) ; } void MdlUpdate ( int_T tid ) { int32_T kIdx ; int32_T phaseIdx ;
{ real_T * * uBuffer = ( real_T * * ) & rtDW . muybj1k10g . TUbufferPtrs [ 0
] ; real_T simTime = ssGetT ( rtS ) ; rtDW . fc4nqsu01a . Head = ( ( rtDW .
fc4nqsu01a . Head < ( rtDW . fc4nqsu01a . CircularBufSize - 1 ) ) ? ( rtDW .
fc4nqsu01a . Head + 1 ) : 0 ) ; if ( rtDW . fc4nqsu01a . Head == rtDW .
fc4nqsu01a . Tail ) { if ( ! rt_TDelayUpdateTailOrGrowBuf ( & rtDW .
fc4nqsu01a . CircularBufSize , & rtDW . fc4nqsu01a . Tail , & rtDW .
fc4nqsu01a . Head , & rtDW . fc4nqsu01a . Last , simTime - ( rtP .
TransportDelay_Delay ) , uBuffer , ( boolean_T ) 0 , false , & rtDW .
fc4nqsu01a . MaxNewBufSize ) ) { ssSetErrorStatus ( rtS ,
"tdelay memory allocation error" ) ; return ; }
slsaSaveRawMemoryForSimTargetOP ( rtS ,
"FiltroDigital/Transport\nDelay_TUbuffer0" , ( void * * ) ( & uBuffer [ 0 ] )
, 2 * rtDW . fc4nqsu01a . CircularBufSize * sizeof ( real_T ) , ( NULL ) , (
NULL ) ) ; } ( * uBuffer + rtDW . fc4nqsu01a . CircularBufSize ) [ rtDW .
fc4nqsu01a . Head ] = simTime ; ( * uBuffer ) [ rtDW . fc4nqsu01a . Head ] =
rtB . lfhnwo55cp ; } if ( ssIsSampleHit ( rtS , 3 , 0 ) ) { rtDW . bn1o5gqwpb
[ rtDW . owb0zwuiuz ] = rtB . kbcfzcgqyz ; kIdx = rtDW . owb0zwuiuz + 7 ; if
( rtDW . owb0zwuiuz + 7 >= 28 ) { kIdx = rtDW . owb0zwuiuz - 21 ; } phaseIdx
= rtDW . eyj42yi00f ; if ( rtDW . eyj42yi00f + 1 >= 4 ) { phaseIdx = - 1 ;
rtDW . hyv24f5d51 = 0 ; kIdx -- ; if ( kIdx < 0 ) { kIdx += 7 ; } } else {
rtDW . hyv24f5d51 += 8 ; } rtDW . owb0zwuiuz = kIdx ; rtDW . eyj42yi00f =
phaseIdx + 1 ; } if ( ssIsSampleHit ( rtS , 4 , 0 ) ) { rtDW . h2xuphcqn2 [
rtDW . i0ma42xyy5 ] = rtB . cuhgapmu0l ; kIdx = rtDW . i0ma42xyy5 + 7 ; if (
rtDW . i0ma42xyy5 + 7 >= 28 ) { kIdx = rtDW . i0ma42xyy5 - 21 ; } phaseIdx =
rtDW . kjzvekaraj ; if ( rtDW . kjzvekaraj + 1 >= 4 ) { phaseIdx = - 1 ; rtDW
. ooy1b32g4y = 0 ; kIdx -- ; if ( kIdx < 0 ) { kIdx += 7 ; } } else { rtDW .
ooy1b32g4y += 8 ; } rtDW . i0ma42xyy5 = kIdx ; rtDW . kjzvekaraj = phaseIdx +
1 ; } if ( ssIsSampleHit ( rtS , 5 , 0 ) ) { rtDW . fiwlfo2bcx [ rtDW .
gwh5ypvhka ] = rtB . m4mpxizuz3 ; kIdx = rtDW . gwh5ypvhka + 7 ; if ( rtDW .
gwh5ypvhka + 7 >= 28 ) { kIdx = rtDW . gwh5ypvhka - 21 ; } phaseIdx = rtDW .
hdcl1gc5nw ; if ( rtDW . hdcl1gc5nw + 1 >= 4 ) { phaseIdx = - 1 ; rtDW .
i5qv5clxbu = 0 ; kIdx -- ; if ( kIdx < 0 ) { kIdx += 7 ; } } else { rtDW .
i5qv5clxbu += 8 ; } rtDW . gwh5ypvhka = kIdx ; rtDW . hdcl1gc5nw = phaseIdx +
1 ; } UNUSED_PARAMETER ( tid ) ; } void MdlDerivatives ( void ) { XDot *
_rtXdot ; _rtXdot = ( ( XDot * ) ssGetdX ( rtS ) ) ; _rtXdot -> l3yd0y2y2l =
rtB . gpy1qxhqhc ; } void MdlProjection ( void ) { } void MdlZeroCrossings (
void ) { ZCV * _rtZCSV ; _rtZCSV = ( ( ZCV * ) ssGetSolverZcSignalVector (
rtS ) ) ; _rtZCSV -> pk5byg4jab = rtB . nn1docam0d ; } void MdlTerminate (
void ) { rt_TDelayFreeBuf ( rtDW . muybj1k10g . TUbufferPtrs [ 0 ] ) ; {
const char * errMsg = ( NULL ) ; void * fp = ( void * ) rtDW . on5ziqb2sn .
PrevTimePtr ; if ( fp != ( NULL ) ) { errMsg =
rtwMatFileLoaderCollectionDestroyInstance ( 1 , fp ) ; if ( errMsg != ( NULL
) ) { ssSetErrorStatus ( rtS , errMsg ) ; return ; } } } } static void
mr_FiltroDigital_cacheDataAsMxArray ( mxArray * destArray , mwIndex i , int j
, const void * srcData , size_t numBytes ) ; static void
mr_FiltroDigital_cacheDataAsMxArray ( mxArray * destArray , mwIndex i , int j
, const void * srcData , size_t numBytes ) { mxArray * newArray =
mxCreateUninitNumericMatrix ( ( size_t ) 1 , numBytes , mxUINT8_CLASS ,
mxREAL ) ; memcpy ( ( uint8_T * ) mxGetData ( newArray ) , ( const uint8_T *
) srcData , numBytes ) ; mxSetFieldByNumber ( destArray , i , j , newArray )
; } static void mr_FiltroDigital_restoreDataFromMxArray ( void * destData ,
const mxArray * srcArray , mwIndex i , int j , size_t numBytes ) ; static
void mr_FiltroDigital_restoreDataFromMxArray ( void * destData , const
mxArray * srcArray , mwIndex i , int j , size_t numBytes ) { memcpy ( (
uint8_T * ) destData , ( const uint8_T * ) mxGetData ( mxGetFieldByNumber (
srcArray , i , j ) ) , numBytes ) ; } static void
mr_FiltroDigital_cacheBitFieldToMxArray ( mxArray * destArray , mwIndex i ,
int j , uint_T bitVal ) ; static void mr_FiltroDigital_cacheBitFieldToMxArray
( mxArray * destArray , mwIndex i , int j , uint_T bitVal ) {
mxSetFieldByNumber ( destArray , i , j , mxCreateDoubleScalar ( ( real_T )
bitVal ) ) ; } static uint_T mr_FiltroDigital_extractBitFieldFromMxArray (
const mxArray * srcArray , mwIndex i , int j , uint_T numBits ) ; static
uint_T mr_FiltroDigital_extractBitFieldFromMxArray ( const mxArray * srcArray
, mwIndex i , int j , uint_T numBits ) { const uint_T varVal = ( uint_T )
mxGetScalar ( mxGetFieldByNumber ( srcArray , i , j ) ) ; return varVal & ( (
1u << numBits ) - 1u ) ; } static void
mr_FiltroDigital_cacheDataToMxArrayWithOffset ( mxArray * destArray , mwIndex
i , int j , mwIndex offset , const void * srcData , size_t numBytes ) ;
static void mr_FiltroDigital_cacheDataToMxArrayWithOffset ( mxArray *
destArray , mwIndex i , int j , mwIndex offset , const void * srcData ,
size_t numBytes ) { uint8_T * varData = ( uint8_T * ) mxGetData (
mxGetFieldByNumber ( destArray , i , j ) ) ; memcpy ( ( uint8_T * ) & varData
[ offset * numBytes ] , ( const uint8_T * ) srcData , numBytes ) ; } static
void mr_FiltroDigital_restoreDataFromMxArrayWithOffset ( void * destData ,
const mxArray * srcArray , mwIndex i , int j , mwIndex offset , size_t
numBytes ) ; static void mr_FiltroDigital_restoreDataFromMxArrayWithOffset (
void * destData , const mxArray * srcArray , mwIndex i , int j , mwIndex
offset , size_t numBytes ) { const uint8_T * varData = ( const uint8_T * )
mxGetData ( mxGetFieldByNumber ( srcArray , i , j ) ) ; memcpy ( ( uint8_T *
) destData , ( const uint8_T * ) & varData [ offset * numBytes ] , numBytes )
; } static void mr_FiltroDigital_cacheBitFieldToCellArrayWithOffset ( mxArray
* destArray , mwIndex i , int j , mwIndex offset , uint_T fieldVal ) ; static
void mr_FiltroDigital_cacheBitFieldToCellArrayWithOffset ( mxArray *
destArray , mwIndex i , int j , mwIndex offset , uint_T fieldVal ) {
mxSetCell ( mxGetFieldByNumber ( destArray , i , j ) , offset ,
mxCreateDoubleScalar ( ( real_T ) fieldVal ) ) ; } static uint_T
mr_FiltroDigital_extractBitFieldFromCellArrayWithOffset ( const mxArray *
srcArray , mwIndex i , int j , mwIndex offset , uint_T numBits ) ; static
uint_T mr_FiltroDigital_extractBitFieldFromCellArrayWithOffset ( const
mxArray * srcArray , mwIndex i , int j , mwIndex offset , uint_T numBits ) {
const uint_T fieldVal = ( uint_T ) mxGetScalar ( mxGetCell (
mxGetFieldByNumber ( srcArray , i , j ) , offset ) ) ; return fieldVal & ( (
1u << numBits ) - 1u ) ; } mxArray * mr_FiltroDigital_GetDWork ( ) { static
const char_T * ssDWFieldNames [ 3 ] = { "rtB" , "rtDW" , "NULL_PrevZCX" , } ;
mxArray * ssDW = mxCreateStructMatrix ( 1 , 1 , 3 , ssDWFieldNames ) ;
mr_FiltroDigital_cacheDataAsMxArray ( ssDW , 0 , 0 , ( const void * ) & ( rtB
) , sizeof ( rtB ) ) ; { static const char_T * rtdwDataFieldNames [ 21 ] = {
"rtDW.mj4dkemmao" , "rtDW.bn1o5gqwpb" , "rtDW.p0upexwcsd" , "rtDW.b0w5k5lope"
, "rtDW.h2xuphcqn2" , "rtDW.ojrkdwj1wt" , "rtDW.nqobrzgsxp" ,
"rtDW.fiwlfo2bcx" , "rtDW.p2s40fywcf" , "rtDW.klxyxcnixw" , "rtDW.eyj42yi00f"
, "rtDW.hyv24f5d51" , "rtDW.owb0zwuiuz" , "rtDW.kjzvekaraj" ,
"rtDW.ooy1b32g4y" , "rtDW.i0ma42xyy5" , "rtDW.hdcl1gc5nw" , "rtDW.i5qv5clxbu"
, "rtDW.gwh5ypvhka" , "rtDW.fc4nqsu01a" , "rtDW.phwztcrhth" , } ; mxArray *
rtdwData = mxCreateStructMatrix ( 1 , 1 , 21 , rtdwDataFieldNames ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 0 , ( const void * ) & (
rtDW . mj4dkemmao ) , sizeof ( rtDW . mj4dkemmao ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 1 , ( const void * ) & (
rtDW . bn1o5gqwpb ) , sizeof ( rtDW . bn1o5gqwpb ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 2 , ( const void * ) & (
rtDW . p0upexwcsd ) , sizeof ( rtDW . p0upexwcsd ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 3 , ( const void * ) & (
rtDW . b0w5k5lope ) , sizeof ( rtDW . b0w5k5lope ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 4 , ( const void * ) & (
rtDW . h2xuphcqn2 ) , sizeof ( rtDW . h2xuphcqn2 ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 5 , ( const void * ) & (
rtDW . ojrkdwj1wt ) , sizeof ( rtDW . ojrkdwj1wt ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 6 , ( const void * ) & (
rtDW . nqobrzgsxp ) , sizeof ( rtDW . nqobrzgsxp ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 7 , ( const void * ) & (
rtDW . fiwlfo2bcx ) , sizeof ( rtDW . fiwlfo2bcx ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 8 , ( const void * ) & (
rtDW . p2s40fywcf ) , sizeof ( rtDW . p2s40fywcf ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 9 , ( const void * ) & (
rtDW . klxyxcnixw ) , sizeof ( rtDW . klxyxcnixw ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 10 , ( const void * ) &
( rtDW . eyj42yi00f ) , sizeof ( rtDW . eyj42yi00f ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 11 , ( const void * ) &
( rtDW . hyv24f5d51 ) , sizeof ( rtDW . hyv24f5d51 ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 12 , ( const void * ) &
( rtDW . owb0zwuiuz ) , sizeof ( rtDW . owb0zwuiuz ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 13 , ( const void * ) &
( rtDW . kjzvekaraj ) , sizeof ( rtDW . kjzvekaraj ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 14 , ( const void * ) &
( rtDW . ooy1b32g4y ) , sizeof ( rtDW . ooy1b32g4y ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 15 , ( const void * ) &
( rtDW . i0ma42xyy5 ) , sizeof ( rtDW . i0ma42xyy5 ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 16 , ( const void * ) &
( rtDW . hdcl1gc5nw ) , sizeof ( rtDW . hdcl1gc5nw ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 17 , ( const void * ) &
( rtDW . i5qv5clxbu ) , sizeof ( rtDW . i5qv5clxbu ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 18 , ( const void * ) &
( rtDW . gwh5ypvhka ) , sizeof ( rtDW . gwh5ypvhka ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 19 , ( const void * ) &
( rtDW . fc4nqsu01a ) , sizeof ( rtDW . fc4nqsu01a ) ) ;
mr_FiltroDigital_cacheDataAsMxArray ( rtdwData , 0 , 20 , ( const void * ) &
( rtDW . phwztcrhth ) , sizeof ( rtDW . phwztcrhth ) ) ; mxSetFieldByNumber (
ssDW , 0 , 1 , rtdwData ) ; } return ssDW ; } void mr_FiltroDigital_SetDWork
( const mxArray * ssDW ) { ( void ) ssDW ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtB ) , ssDW , 0 , 0
, sizeof ( rtB ) ) ; { const mxArray * rtdwData = mxGetFieldByNumber ( ssDW ,
0 , 1 ) ; mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW .
mj4dkemmao ) , rtdwData , 0 , 0 , sizeof ( rtDW . mj4dkemmao ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . bn1o5gqwpb )
, rtdwData , 0 , 1 , sizeof ( rtDW . bn1o5gqwpb ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . p0upexwcsd )
, rtdwData , 0 , 2 , sizeof ( rtDW . p0upexwcsd ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . b0w5k5lope )
, rtdwData , 0 , 3 , sizeof ( rtDW . b0w5k5lope ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . h2xuphcqn2 )
, rtdwData , 0 , 4 , sizeof ( rtDW . h2xuphcqn2 ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . ojrkdwj1wt )
, rtdwData , 0 , 5 , sizeof ( rtDW . ojrkdwj1wt ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . nqobrzgsxp )
, rtdwData , 0 , 6 , sizeof ( rtDW . nqobrzgsxp ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . fiwlfo2bcx )
, rtdwData , 0 , 7 , sizeof ( rtDW . fiwlfo2bcx ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . p2s40fywcf )
, rtdwData , 0 , 8 , sizeof ( rtDW . p2s40fywcf ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . klxyxcnixw )
, rtdwData , 0 , 9 , sizeof ( rtDW . klxyxcnixw ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . eyj42yi00f )
, rtdwData , 0 , 10 , sizeof ( rtDW . eyj42yi00f ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . hyv24f5d51 )
, rtdwData , 0 , 11 , sizeof ( rtDW . hyv24f5d51 ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . owb0zwuiuz )
, rtdwData , 0 , 12 , sizeof ( rtDW . owb0zwuiuz ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . kjzvekaraj )
, rtdwData , 0 , 13 , sizeof ( rtDW . kjzvekaraj ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . ooy1b32g4y )
, rtdwData , 0 , 14 , sizeof ( rtDW . ooy1b32g4y ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . i0ma42xyy5 )
, rtdwData , 0 , 15 , sizeof ( rtDW . i0ma42xyy5 ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . hdcl1gc5nw )
, rtdwData , 0 , 16 , sizeof ( rtDW . hdcl1gc5nw ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . i5qv5clxbu )
, rtdwData , 0 , 17 , sizeof ( rtDW . i5qv5clxbu ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . gwh5ypvhka )
, rtdwData , 0 , 18 , sizeof ( rtDW . gwh5ypvhka ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . fc4nqsu01a )
, rtdwData , 0 , 19 , sizeof ( rtDW . fc4nqsu01a ) ) ;
mr_FiltroDigital_restoreDataFromMxArray ( ( void * ) & ( rtDW . phwztcrhth )
, rtdwData , 0 , 20 , sizeof ( rtDW . phwztcrhth ) ) ; } } mxArray *
mr_FiltroDigital_GetSimStateDisallowedBlocks ( ) { mxArray * data =
mxCreateCellMatrix ( 1 , 3 ) ; mwIndex subs [ 2 ] , offset ; { static const
char_T * blockType [ 1 ] = { "Scope" , } ; static const char_T * blockPath [
1 ] = { "FiltroDigital/Scope" , } ; static const int reason [ 1 ] = { 0 , } ;
for ( subs [ 0 ] = 0 ; subs [ 0 ] < 1 ; ++ ( subs [ 0 ] ) ) { subs [ 1 ] = 0
; offset = mxCalcSingleSubscript ( data , 2 , subs ) ; mxSetCell ( data ,
offset , mxCreateString ( blockType [ subs [ 0 ] ] ) ) ; subs [ 1 ] = 1 ;
offset = mxCalcSingleSubscript ( data , 2 , subs ) ; mxSetCell ( data ,
offset , mxCreateString ( blockPath [ subs [ 0 ] ] ) ) ; subs [ 1 ] = 2 ;
offset = mxCalcSingleSubscript ( data , 2 , subs ) ; mxSetCell ( data ,
offset , mxCreateDoubleScalar ( ( real_T ) reason [ subs [ 0 ] ] ) ) ; } }
return data ; } void MdlInitializeSizes ( void ) { ssSetNumContStates ( rtS ,
1 ) ; ssSetNumPeriodicContStates ( rtS , 0 ) ; ssSetNumY ( rtS , 0 ) ;
ssSetNumU ( rtS , 0 ) ; ssSetDirectFeedThrough ( rtS , 0 ) ;
ssSetNumSampleTimes ( rtS , 7 ) ; ssSetNumBlocks ( rtS , 12 ) ;
ssSetNumBlockIO ( rtS , 11 ) ; ssSetNumBlockParams ( rtS , 100 ) ; } void
MdlInitializeSampleTimes ( void ) { ssSetSampleTime ( rtS , 0 , 0.0 ) ;
ssSetSampleTime ( rtS , 1 , 0.0 ) ; ssSetSampleTime ( rtS , 2 ,
1.8399189196062331E-8 ) ; ssSetSampleTime ( rtS , 3 , 5.2083333333333332E-6 )
; ssSetSampleTime ( rtS , 4 , 2.0833333333333333E-5 ) ; ssSetSampleTime ( rtS
, 5 , 8.3333333333333331E-5 ) ; ssSetSampleTime ( rtS , 6 ,
0.00033333333333333332 ) ; ssSetOffsetTime ( rtS , 0 , 0.0 ) ;
ssSetOffsetTime ( rtS , 1 , 1.0 ) ; ssSetOffsetTime ( rtS , 2 , 0.0 ) ;
ssSetOffsetTime ( rtS , 3 , 0.0 ) ; ssSetOffsetTime ( rtS , 4 , 0.0 ) ;
ssSetOffsetTime ( rtS , 5 , 0.0 ) ; ssSetOffsetTime ( rtS , 6 , 0.0 ) ; }
void raccel_set_checksum ( ) { ssSetChecksumVal ( rtS , 0 , 3816147868U ) ;
ssSetChecksumVal ( rtS , 1 , 1797692849U ) ; ssSetChecksumVal ( rtS , 2 ,
1650621602U ) ; ssSetChecksumVal ( rtS , 3 , 3954502009U ) ; }
#if defined(_MSC_VER)
#pragma optimize( "", off )
#endif
SimStruct * raccel_register_model ( ssExecutionInfo * executionInfo ) {
static struct _ssMdlInfo mdlInfo ; static struct _ssBlkInfo2 blkInfo2 ;
static struct _ssBlkInfoSLSize blkInfoSLSize ; rt_modelMapInfoPtr = & (
rt_dataMapInfo . mmi ) ; executionInfo -> gblObjects_ . numToFiles = 0 ;
executionInfo -> gblObjects_ . numFrFiles = 1 ; executionInfo -> gblObjects_
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
, & dtInfo ) ; dtInfo . numDataTypes = 25 ; dtInfo . dataTypeSizes = &
rtDataTypeSizes [ 0 ] ; dtInfo . dataTypeNames = & rtDataTypeNames [ 0 ] ;
dtInfo . BTransTable = & rtBTransTable ; dtInfo . PTransTable = &
rtPTransTable ; dtInfo . dataTypeInfoTable = rtDataTypeInfoTable ; }
FiltroDigital_InitializeDataMapInfo ( ) ; ssSetIsRapidAcceleratorActive ( rtS
, true ) ; ssSetRootSS ( rtS , rtS ) ; ssSetVersion ( rtS ,
SIMSTRUCT_VERSION_LEVEL2 ) ; ssSetModelName ( rtS , "FiltroDigital" ) ;
ssSetPath ( rtS , "FiltroDigital" ) ; ssSetTStart ( rtS , 0.0 ) ; ssSetTFinal
( rtS , 1.04 ) ; { static RTWLogInfo rt_DataLoggingInfo ; rt_DataLoggingInfo
. loggingInterval = ( NULL ) ; ssSetRTWLogInfo ( rtS , & rt_DataLoggingInfo )
; } { { static int_T rt_LoggedStateWidths [ ] = { 1 , 32 , 28 , 1 , 32 , 28 ,
1 , 32 , 28 , 1 , 1 , 1 , 1 , 1 , 1 , 1 , 1 , 1 , 1 } ; static int_T
rt_LoggedStateNumDimensions [ ] = { 1 , 1 , 1 , 1 , 1 , 1 , 1 , 1 , 1 , 1 , 1
, 1 , 1 , 1 , 1 , 1 , 1 , 1 , 1 } ; static int_T rt_LoggedStateDimensions [ ]
= { 1 , 32 , 28 , 1 , 32 , 28 , 1 , 32 , 28 , 1 , 1 , 1 , 1 , 1 , 1 , 1 , 1 ,
1 , 1 } ; static boolean_T rt_LoggedStateIsVarDims [ ] = { 0 , 0 , 0 , 0 , 0
, 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 } ; static
BuiltInDTypeId rt_LoggedStateDataTypeIds [ ] = { SS_DOUBLE , SS_DOUBLE ,
SS_DOUBLE , SS_DOUBLE , SS_DOUBLE , SS_DOUBLE , SS_DOUBLE , SS_DOUBLE ,
SS_DOUBLE , SS_DOUBLE , SS_INT32 , SS_INT32 , SS_INT32 , SS_INT32 , SS_INT32
, SS_INT32 , SS_INT32 , SS_INT32 , SS_INT32 } ; static int_T
rt_LoggedStateComplexSignals [ ] = { 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 ,
0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 } ; static RTWPreprocessingFcnPtr
rt_LoggingStatePreprocessingFcnPtrs [ ] = { ( NULL ) , ( NULL ) , ( NULL ) ,
( NULL ) , ( NULL ) , ( NULL ) , ( NULL ) , ( NULL ) , ( NULL ) , ( NULL ) ,
( NULL ) , ( NULL ) , ( NULL ) , ( NULL ) , ( NULL ) , ( NULL ) , ( NULL ) ,
( NULL ) , ( NULL ) } ; static const char_T * rt_LoggedStateLabels [ ] = {
"CSTATE" , "Sums" , "StatesBuff" , "OutBuff" , "Sums" , "StatesBuff" ,
"OutBuff" , "Sums" , "StatesBuff" , "OutBuff" , "PhaseIdx" , "CoeffIdx" ,
"TapDelayIndex" , "PhaseIdx" , "CoeffIdx" , "TapDelayIndex" , "PhaseIdx" ,
"CoeffIdx" , "TapDelayIndex" } ; static const char_T *
rt_LoggedStateBlockNames [ ] = { "FiltroDigital/Integrator" ,
"FiltroDigital/FIR x4(a)\nDecimation" , "FiltroDigital/FIR x4(a)\nDecimation"
, "FiltroDigital/FIR x4(a)\nDecimation" ,
"FiltroDigital/FIR x4(b)\nDecimation" , "FiltroDigital/FIR x4(b)\nDecimation"
, "FiltroDigital/FIR x4(b)\nDecimation" ,
"FiltroDigital/FIR x4(c)\nDecimation" , "FiltroDigital/FIR x4(c)\nDecimation"
, "FiltroDigital/FIR x4(c)\nDecimation" ,
"FiltroDigital/FIR x4(a)\nDecimation" , "FiltroDigital/FIR x4(a)\nDecimation"
, "FiltroDigital/FIR x4(a)\nDecimation" ,
"FiltroDigital/FIR x4(b)\nDecimation" , "FiltroDigital/FIR x4(b)\nDecimation"
, "FiltroDigital/FIR x4(b)\nDecimation" ,
"FiltroDigital/FIR x4(c)\nDecimation" , "FiltroDigital/FIR x4(c)\nDecimation"
, "FiltroDigital/FIR x4(c)\nDecimation" } ; static const char_T *
rt_LoggedStateNames [ ] = { "" , "Sums" , "StatesBuff" , "OutBuff" , "Sums" ,
"StatesBuff" , "OutBuff" , "Sums" , "StatesBuff" , "OutBuff" , "PhaseIdx" ,
"CoeffIdx" , "TapDelayIndex" , "PhaseIdx" , "CoeffIdx" , "TapDelayIndex" ,
"PhaseIdx" , "CoeffIdx" , "TapDelayIndex" } ; static boolean_T
rt_LoggedStateCrossMdlRef [ ] = { 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 ,
0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 } ; static RTWLogDataTypeConvert
rt_RTWLogDataTypeConvert [ ] = { { 0 , SS_DOUBLE , SS_DOUBLE , 0 , 0 , 0 ,
1.0 , 0 , 0.0 } , { 0 , SS_DOUBLE , SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 , 0.0 } ,
{ 0 , SS_DOUBLE , SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 , 0.0 } , { 0 , SS_DOUBLE ,
SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 , 0.0 } , { 0 , SS_DOUBLE , SS_DOUBLE , 0 , 0
, 0 , 1.0 , 0 , 0.0 } , { 0 , SS_DOUBLE , SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 ,
0.0 } , { 0 , SS_DOUBLE , SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 , 0.0 } , { 0 ,
SS_DOUBLE , SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 , 0.0 } , { 0 , SS_DOUBLE ,
SS_DOUBLE , 0 , 0 , 0 , 1.0 , 0 , 0.0 } , { 0 , SS_DOUBLE , SS_DOUBLE , 0 , 0
, 0 , 1.0 , 0 , 0.0 } , { 0 , SS_INT32 , SS_INT32 , 0 , 0 , 0 , 1.0 , 0 , 0.0
} , { 0 , SS_INT32 , SS_INT32 , 0 , 0 , 0 , 1.0 , 0 , 0.0 } , { 0 , SS_INT32
, SS_INT32 , 0 , 0 , 0 , 1.0 , 0 , 0.0 } , { 0 , SS_INT32 , SS_INT32 , 0 , 0
, 0 , 1.0 , 0 , 0.0 } , { 0 , SS_INT32 , SS_INT32 , 0 , 0 , 0 , 1.0 , 0 , 0.0
} , { 0 , SS_INT32 , SS_INT32 , 0 , 0 , 0 , 1.0 , 0 , 0.0 } , { 0 , SS_INT32
, SS_INT32 , 0 , 0 , 0 , 1.0 , 0 , 0.0 } , { 0 , SS_INT32 , SS_INT32 , 0 , 0
, 0 , 1.0 , 0 , 0.0 } , { 0 , SS_INT32 , SS_INT32 , 0 , 0 , 0 , 1.0 , 0 , 0.0
} } ; static int_T rt_LoggedStateIdxList [ ] = { 0 , 13 , 0 , 14 , 16 , 3 ,
17 , 19 , 6 , 20 , 1 , 15 , 2 , 4 , 18 , 5 , 7 , 21 , 8 } ; static
RTWLogSignalInfo rt_LoggedStateSignalInfo = { 19 , rt_LoggedStateWidths ,
rt_LoggedStateNumDimensions , rt_LoggedStateDimensions ,
rt_LoggedStateIsVarDims , ( NULL ) , ( NULL ) , rt_LoggedStateDataTypeIds ,
rt_LoggedStateComplexSignals , ( NULL ) , rt_LoggingStatePreprocessingFcnPtrs
, { rt_LoggedStateLabels } , ( NULL ) , ( NULL ) , ( NULL ) , {
rt_LoggedStateBlockNames } , { rt_LoggedStateNames } ,
rt_LoggedStateCrossMdlRef , rt_RTWLogDataTypeConvert , rt_LoggedStateIdxList
} ; static void * rt_LoggedStateSignalPtrs [ 19 ] ; rtliSetLogXSignalPtrs (
ssGetRTWLogInfo ( rtS ) , ( LogSignalPtrsType ) rt_LoggedStateSignalPtrs ) ;
rtliSetLogXSignalInfo ( ssGetRTWLogInfo ( rtS ) , & rt_LoggedStateSignalInfo
) ; rt_LoggedStateSignalPtrs [ 0 ] = ( void * ) & rtX . l3yd0y2y2l ;
rt_LoggedStateSignalPtrs [ 1 ] = ( void * ) rtDW . mj4dkemmao ;
rt_LoggedStateSignalPtrs [ 2 ] = ( void * ) rtDW . bn1o5gqwpb ;
rt_LoggedStateSignalPtrs [ 3 ] = ( void * ) & rtDW . p0upexwcsd ;
rt_LoggedStateSignalPtrs [ 4 ] = ( void * ) rtDW . b0w5k5lope ;
rt_LoggedStateSignalPtrs [ 5 ] = ( void * ) rtDW . h2xuphcqn2 ;
rt_LoggedStateSignalPtrs [ 6 ] = ( void * ) & rtDW . ojrkdwj1wt ;
rt_LoggedStateSignalPtrs [ 7 ] = ( void * ) rtDW . nqobrzgsxp ;
rt_LoggedStateSignalPtrs [ 8 ] = ( void * ) rtDW . fiwlfo2bcx ;
rt_LoggedStateSignalPtrs [ 9 ] = ( void * ) & rtDW . p2s40fywcf ;
rt_LoggedStateSignalPtrs [ 10 ] = ( void * ) & rtDW . eyj42yi00f ;
rt_LoggedStateSignalPtrs [ 11 ] = ( void * ) & rtDW . hyv24f5d51 ;
rt_LoggedStateSignalPtrs [ 12 ] = ( void * ) & rtDW . owb0zwuiuz ;
rt_LoggedStateSignalPtrs [ 13 ] = ( void * ) & rtDW . kjzvekaraj ;
rt_LoggedStateSignalPtrs [ 14 ] = ( void * ) & rtDW . ooy1b32g4y ;
rt_LoggedStateSignalPtrs [ 15 ] = ( void * ) & rtDW . i0ma42xyy5 ;
rt_LoggedStateSignalPtrs [ 16 ] = ( void * ) & rtDW . hdcl1gc5nw ;
rt_LoggedStateSignalPtrs [ 17 ] = ( void * ) & rtDW . i5qv5clxbu ;
rt_LoggedStateSignalPtrs [ 18 ] = ( void * ) & rtDW . gwh5ypvhka ; }
rtliSetLogT ( ssGetRTWLogInfo ( rtS ) , "tout" ) ; rtliSetLogX (
ssGetRTWLogInfo ( rtS ) , "" ) ; rtliSetLogXFinal ( ssGetRTWLogInfo ( rtS ) ,
"xFinal" ) ; rtliSetLogVarNameModifier ( ssGetRTWLogInfo ( rtS ) , "none" ) ;
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
static ssSolverInfo slvrInfo ; static boolean_T contStatesDisabled [ 1 ] ;
static real_T absTol [ 1 ] = { 1.0E-6 } ; static uint8_T absTolControl [ 1 ]
= { 0U } ; static real_T contStateJacPerturbBoundMinVec [ 1 ] ; static real_T
contStateJacPerturbBoundMaxVec [ 1 ] ; static uint8_T zcAttributes [ 1 ] = {
( ZC_EVENT_ALL ) } ; static ssNonContDerivSigInfo nonContDerivSigInfo [ 1 ] =
{ { 1 * sizeof ( real_T ) , ( char * ) ( & rtB . gpy1qxhqhc ) , ( NULL ) } }
; { int i ; for ( i = 0 ; i < 1 ; ++ i ) { contStateJacPerturbBoundMinVec [ i
] = 0 ; contStateJacPerturbBoundMaxVec [ i ] = rtGetInf ( ) ; } }
ssSetSolverRelTol ( rtS , 0.001 ) ; ssSetStepSize ( rtS , 0.0 ) ;
ssSetMinStepSize ( rtS , 0.0 ) ; ssSetMaxNumMinSteps ( rtS , - 1 ) ;
ssSetMinStepViolatedError ( rtS , 0 ) ; ssSetMaxStepSize ( rtS ,
1.8399189196062331E-8 ) ; ssSetSolverMaxOrder ( rtS , - 1 ) ;
ssSetSolverRefineFactor ( rtS , 1 ) ; ssSetOutputTimes ( rtS , ( NULL ) ) ;
ssSetNumOutputTimes ( rtS , 0 ) ; ssSetOutputTimesOnly ( rtS , 0 ) ;
ssSetOutputTimesIndex ( rtS , 0 ) ; ssSetZCCacheNeedsReset ( rtS , 0 ) ;
ssSetDerivCacheNeedsReset ( rtS , 0 ) ; ssSetNumNonContDerivSigInfos ( rtS ,
1 ) ; ssSetNonContDerivSigInfos ( rtS , nonContDerivSigInfo ) ;
ssSetSolverInfo ( rtS , & slvrInfo ) ; ssSetSolverName ( rtS ,
"VariableStepAuto" ) ; ssSetVariableStepSolver ( rtS , 1 ) ;
ssSetSolverConsistencyChecking ( rtS , 0 ) ; ssSetSolverAdaptiveZcDetection (
rtS , 0 ) ; ssSetSolverRobustResetMethod ( rtS , 0 ) ; ssSetAbsTolVector (
rtS , absTol ) ; ssSetAbsTolControlVector ( rtS , absTolControl ) ;
ssSetSolverAbsTol_Obsolete ( rtS , absTol ) ;
ssSetSolverAbsTolControl_Obsolete ( rtS , absTolControl ) ;
ssSetJacobianPerturbationBoundsMinVec ( rtS , contStateJacPerturbBoundMinVec
) ; ssSetJacobianPerturbationBoundsMaxVec ( rtS ,
contStateJacPerturbBoundMaxVec ) ; ssSetSolverStateProjection ( rtS , 0 ) ;
ssSetSolverMassMatrixType ( rtS , ( ssMatrixType ) 0 ) ;
ssSetSolverMassMatrixNzMax ( rtS , 0 ) ; ssSetModelOutputs ( rtS , MdlOutputs
) ; ssSetModelUpdate ( rtS , MdlUpdate ) ; ssSetModelDerivatives ( rtS ,
MdlDerivatives ) ; ssSetSolverZcSignalAttrib ( rtS , zcAttributes ) ;
ssSetSolverNumZcSignals ( rtS , 1 ) ; ssSetModelZeroCrossings ( rtS ,
MdlZeroCrossings ) ; ssSetSolverConsecutiveZCsStepRelTol ( rtS ,
2.8421709430404007E-13 ) ; ssSetSolverMaxConsecutiveZCs ( rtS , 1000 ) ;
ssSetSolverConsecutiveZCsError ( rtS , 2 ) ; ssSetSolverMaskedZcDiagnostic (
rtS , 1 ) ; ssSetSolverIgnoredZcDiagnostic ( rtS , 1 ) ;
ssSetSolverMaxConsecutiveMinStep ( rtS , 1 ) ;
ssSetSolverShapePreserveControl ( rtS , 2 ) ; ssSetTNextTid ( rtS , INT_MIN )
; ssSetTNext ( rtS , rtMinusInf ) ; ssSetSolverNeedsReset ( rtS ) ;
ssSetNumNonsampledZCs ( rtS , 1 ) ; ssSetContStateDisabled ( rtS ,
contStatesDisabled ) ; ssSetSolverMaxConsecutiveMinStep ( rtS , 1 ) ; }
ssSetChecksumVal ( rtS , 0 , 3816147868U ) ; ssSetChecksumVal ( rtS , 1 ,
1797692849U ) ; ssSetChecksumVal ( rtS , 2 , 1650621602U ) ; ssSetChecksumVal
( rtS , 3 , 3954502009U ) ; { static const sysRanDType rtAlwaysEnabled =
SUBSYS_RAN_BC_ENABLE ; static RTWExtModeInfo rt_ExtModeInfo ; static const
sysRanDType * systemRan [ 1 ] ; gblRTWExtModeInfo = & rt_ExtModeInfo ;
ssSetRTWExtModeInfo ( rtS , & rt_ExtModeInfo ) ;
rteiSetSubSystemActiveVectorAddresses ( & rt_ExtModeInfo , systemRan ) ;
systemRan [ 0 ] = & rtAlwaysEnabled ; rteiSetModelMappingInfoPtr (
ssGetRTWExtModeInfo ( rtS ) , & ssGetModelMappingInfo ( rtS ) ) ;
rteiSetChecksumsPtr ( ssGetRTWExtModeInfo ( rtS ) , ssGetChecksums ( rtS ) )
; rteiSetTPtr ( ssGetRTWExtModeInfo ( rtS ) , ssGetTPtr ( rtS ) ) ; }
slsaDisallowedBlocksForSimTargetOP ( rtS ,
mr_FiltroDigital_GetSimStateDisallowedBlocks ) ; slsaGetWorkFcnForSimTargetOP
( rtS , mr_FiltroDigital_GetDWork ) ; slsaSetWorkFcnForSimTargetOP ( rtS ,
mr_FiltroDigital_SetDWork ) ; rt_RapidReadMatFileAndUpdateParams ( rtS ) ; if
( ssGetErrorStatus ( rtS ) ) { return rtS ; } return rtS ; }
#if defined(_MSC_VER)
#pragma optimize( "", on )
#endif
void MdlOutputsParameterSampleTime ( int_T tid ) { UNUSED_PARAMETER ( tid ) ;
}
