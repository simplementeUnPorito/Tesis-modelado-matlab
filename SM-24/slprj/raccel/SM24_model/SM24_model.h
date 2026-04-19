#ifndef RTW_HEADER_SM24_model_h_
#define RTW_HEADER_SM24_model_h_
#ifndef SM24_model_COMMON_INCLUDES_
#define SM24_model_COMMON_INCLUDES_
#include <stdlib.h>
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
#include "nesl_rtw.h"
#include "SM24_model_9c913df9_1_gateway.h"
#endif
#include "SM24_model_types.h"
#include <stddef.h>
#include "rtw_modelmap_simtarget.h"
#include "rt_defines.h"
#include <string.h>
#include "rtGetInf.h"
#include "rt_nonfinite.h"
#define MODEL_NAME SM24_model
#define NSAMPLE_TIMES (3) 
#define NINPUTS (0)       
#define NOUTPUTS (0)     
#define NBLOCKIO (9) 
#define NUM_ZC_EVENTS (0) 
#ifndef NCSTATES
#define NCSTATES (7)   
#elif NCSTATES != 7
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
typedef struct { real_T hptfqp3w4t ; real_T ckzbdtbp2u [ 4 ] ; real_T
dffdefsite [ 28 ] ; real_T d315qoqwkh ; real_T ex54xq0c2t ; uint8_T
ojrpy5nefy ; uint8_T p3ejhqueew ; uint8_T exmape5dlp ; boolean_T aaphbljg5e ;
} B ; typedef struct { real_T celqvbnenk [ 2 ] ; real_T jokvmc1vow [ 17 ] ;
real_T d4s54ffcej ; void * kfdaeff2on ; void * hzhks2wrhc ; void * oxmoxmheof
; void * nsbdxrdfgk ; void * a0mgwxgmy2 ; void * p0uxtzqvso ; void *
k2bowqu4gq ; void * hfgp5h0zt5 ; void * nqnu05xhgo ; void * eik241o4qv ;
struct { void * LoggedData [ 2 ] ; } n3hbagh5re ; int_T cs5gabfwq4 [ 4 ] ;
int_T olwuylhr2k ; int_T ptcy4m1wr0 ; uint8_T ipswhlfltx ; uint8_T g2ubuwhrn0
; uint8_T pkz43umjxy ; boolean_T e02zzncljy ; boolean_T nqr2ask1kh ;
boolean_T ehbyr4oova ; boolean_T gsuxxg2o4n ; boolean_T bhhchkty0k ;
boolean_T drqqz0z3u2 ; } DW ; typedef struct { real_T d3yrpwytgj [ 7 ] ; } X
; typedef struct { real_T d3yrpwytgj [ 7 ] ; } XDot ; typedef struct {
boolean_T d3yrpwytgj [ 7 ] ; } XDis ; typedef struct { real_T d3yrpwytgj [ 7
] ; } CStateAbsTol ; typedef struct { real_T d3yrpwytgj [ 7 ] ; } CXPtMin ;
typedef struct { real_T d3yrpwytgj [ 7 ] ; } CXPtMax ; typedef struct {
real_T kucfedkei4 ; real_T nlttom1j3y ; real_T fvvles4kgx ; real_T mwv1ha0zcm
; real_T kdcu4arcnm ; real_T cflyaxs4fr ; real_T i11l1diodi ; real_T
iriaqhcigt ; real_T iim4yj0vlf ; } ZCV ; typedef struct {
rtwCAPI_ModelMappingInfo mmi ; } DataMapInfo ; struct P_ { real_T
Constant_Value ; real_T Constant_Value_dv5dqkwtfv ; real_T
Constant_Value_n54scyttiz ; real_T Constant_Value_fnvw3cdvbn ; real_T
Step_Time ; real_T Step_Y0 ; real_T Step_YFinal ; real_T RateConversion_Gain
; real_T Snapshottimes_Value ; uint8_T D1_InitialCondition ; uint8_T
D3_InitialCondition ; uint8_T D2_InitialCondition ; } ; extern const char_T *
RT_MEMORY_ALLOCATION_ERROR ; extern B rtB ; extern X rtX ; extern DW rtDW ;
extern P rtP ; extern mxArray * mr_SM24_model_GetDWork ( ) ; extern void
mr_SM24_model_SetDWork ( const mxArray * ssDW ) ; extern mxArray *
mr_SM24_model_GetSimStateDisallowedBlocks ( ) ; extern const
rtwCAPI_ModelMappingStaticInfo * SM24_model_GetCAPIStaticMap ( void ) ;
extern SimStruct * const rtS ; extern DataMapInfo * rt_dataMapInfoPtr ;
extern rtwCAPI_ModelMappingInfo * rt_modelMapInfoPtr ; void MdlOutputs (
int_T tid ) ; void MdlOutputsParameterSampleTime ( int_T tid ) ; void
MdlUpdate ( int_T tid ) ; void MdlTerminate ( void ) ; void
MdlInitializeSizes ( void ) ; void MdlInitializeSampleTimes ( void ) ;
SimStruct * raccel_register_model ( ssExecutionInfo * executionInfo ) ;
#endif
