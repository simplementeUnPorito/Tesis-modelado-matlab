#ifndef RTW_HEADER_FiltroDigital_h_
#define RTW_HEADER_FiltroDigital_h_
#ifndef FiltroDigital_COMMON_INCLUDES_
#define FiltroDigital_COMMON_INCLUDES_
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include "sl_fileio_rtw.h"
#include "simtarget/slSimTgtSlFileioRTW.h"
#include "rtwtypes.h"
#include "sigstream_rtw.h"
#include "simtarget/slSimTgtSigstreamRTW.h"
#include "simtarget/slSimTgtSlioCoreRTW.h"
#include "simtarget/slSimTgtSlioClientsRTW.h"
#include "simtarget/slSimTgtSlioSdiRTW.h"
#include "simstruc.h"
#include "fixedpoint.h"
#include "raccel.h"
#include "slsv_diagnostic_codegen_c_api.h"
#include "rt_logging_simtarget.h"
#include "dt_info.h"
#include "ext_work.h"
#endif
#include "FiltroDigital_types.h"
#include <float.h>
#include "mwmathutil.h"
#include "rtw_modelmap_simtarget.h"
#include "rt_defines.h"
#include <string.h>
#include "rtGetInf.h"
#include "rt_nonfinite.h"
#define MODEL_NAME FiltroDigital
#define NSAMPLE_TIMES (7) 
#define NINPUTS (0)       
#define NOUTPUTS (0)     
#define NBLOCKIO (11) 
#define NUM_ZC_EVENTS (0) 
#ifndef NCSTATES
#define NCSTATES (1)   
#elif NCSTATES != 1
#error Invalid specification of NCSTATES defined in compiler command
#endif
#ifndef rtmGetDataMapInfo
#define rtmGetDataMapInfo(rtm) (*rt_dataMapInfoPtr)
#endif
#ifndef rtmSetDataMapInfo
#define rtmSetDataMapInfo(rtm, val) (rt_dataMapInfoPtr = &val)
#endif
#ifndef IN_RACCEL_MAIN
#endif
typedef struct { real_T a5tnoiyu3h ; real_T nn1docam0d ; real_T nlibdwom40 ;
real_T kbcfzcgqyz ; real_T cuhgapmu0l ; real_T m4mpxizuz3 ; real_T gousoqy1pl
; real_T pvs4axzl4p ; real_T dowb0yskro ; real_T lfhnwo55cp ; real_T
gpy1qxhqhc ; } B ; typedef struct { real_T mj4dkemmao [ 32 ] ; real_T
bn1o5gqwpb [ 28 ] ; real_T p0upexwcsd ; real_T b0w5k5lope [ 32 ] ; real_T
h2xuphcqn2 [ 28 ] ; real_T ojrkdwj1wt ; real_T nqobrzgsxp [ 32 ] ; real_T
fiwlfo2bcx [ 28 ] ; real_T p2s40fywcf ; struct { real_T modelTStart ; }
klxyxcnixw ; struct { void * TUbufferPtrs [ 2 ] ; } muybj1k10g ; struct {
void * PrevTimePtr ; } on5ziqb2sn ; struct { void * LoggedData [ 4 ] ; }
faxszxpcwp ; int32_T eyj42yi00f ; int32_T hyv24f5d51 ; int32_T owb0zwuiuz ;
int32_T kjzvekaraj ; int32_T ooy1b32g4y ; int32_T i0ma42xyy5 ; int32_T
hdcl1gc5nw ; int32_T i5qv5clxbu ; int32_T gwh5ypvhka ; struct { int_T Tail ;
int_T Head ; int_T Last ; int_T CircularBufSize ; int_T MaxNewBufSize ; }
fc4nqsu01a ; int_T phwztcrhth ; } DW ; typedef struct { real_T l3yd0y2y2l ; }
X ; typedef struct { real_T l3yd0y2y2l ; } XDot ; typedef struct { boolean_T
l3yd0y2y2l ; } XDis ; typedef struct { real_T l3yd0y2y2l ; } CStateAbsTol ;
typedef struct { real_T l3yd0y2y2l ; } CXPtMin ; typedef struct { real_T
l3yd0y2y2l ; } CXPtMax ; typedef struct { real_T pk5byg4jab ; } ZCV ; typedef
struct { rtwCAPI_ModelMappingInfo mmi ; } DataMapInfo ; struct P_ { real_T
TransportDelay_Delay ; real_T TransportDelay_InitOutput ; real_T
Integrator_IC ; real_T FIRx4aDecimation_FILT [ 32 ] ; real_T
FIRx4bDecimation_FILT [ 32 ] ; real_T FIRx4cDecimation_FILT [ 32 ] ; real_T
Gain_Gain ; } ; extern const char_T * RT_MEMORY_ALLOCATION_ERROR ; extern B
rtB ; extern X rtX ; extern DW rtDW ; extern P rtP ; extern mxArray *
mr_FiltroDigital_GetDWork ( ) ; extern void mr_FiltroDigital_SetDWork ( const
mxArray * ssDW ) ; extern mxArray *
mr_FiltroDigital_GetSimStateDisallowedBlocks ( ) ; extern const
rtwCAPI_ModelMappingStaticInfo * FiltroDigital_GetCAPIStaticMap ( void ) ;
extern SimStruct * const rtS ; extern DataMapInfo * rt_dataMapInfoPtr ;
extern rtwCAPI_ModelMappingInfo * rt_modelMapInfoPtr ; void MdlOutputs (
int_T tid ) ; void MdlOutputsParameterSampleTime ( int_T tid ) ; void
MdlUpdate ( int_T tid ) ; void MdlTerminate ( void ) ; void
MdlInitializeSizes ( void ) ; void MdlInitializeSampleTimes ( void ) ;
SimStruct * raccel_register_model ( ssExecutionInfo * executionInfo ) ;
#endif
