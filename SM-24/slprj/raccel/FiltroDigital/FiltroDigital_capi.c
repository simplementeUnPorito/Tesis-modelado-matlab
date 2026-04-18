#include "rtw_capi.h"
#ifdef HOST_CAPI_BUILD
#include "FiltroDigital_capi_host.h"
#define sizeof(s) ((size_t)(0xFFFF))
#undef rt_offsetof
#define rt_offsetof(s,el) ((uint16_T)(0xFFFF))
#define TARGET_CONST
#define TARGET_STRING(s) (s)
#ifndef SS_UINT64
#define SS_UINT64 19
#endif
#ifndef SS_INT64
#define SS_INT64 20
#endif
#else
#include "builtin_typeid_types.h"
#include "FiltroDigital.h"
#include "FiltroDigital_capi.h"
#include "FiltroDigital_private.h"
#ifdef LIGHT_WEIGHT_CAPI
#define TARGET_CONST
#define TARGET_STRING(s)               ((NULL))
#else
#define TARGET_CONST                   const
#define TARGET_STRING(s)               (s)
#endif
#endif
static const rtwCAPI_Signals rtBlockSignals [ ] = { { 0 , 0 , TARGET_STRING (
"FiltroDigital/From File" ) , TARGET_STRING ( "" ) , 0 , 0 , 0 , 0 , 0 } , {
1 , 0 , TARGET_STRING ( "FiltroDigital/Gain" ) , TARGET_STRING (
"Analog Input" ) , 0 , 0 , 0 , 0 , 0 } , { 2 , 0 , TARGET_STRING (
"FiltroDigital/Integrator" ) , TARGET_STRING ( "" ) , 0 , 0 , 0 , 0 , 1 } , {
3 , 0 , TARGET_STRING ( "FiltroDigital/FIR x4(a) Decimation" ) ,
TARGET_STRING ( "" ) , 0 , 0 , 0 , 0 , 2 } , { 4 , 0 , TARGET_STRING (
"FiltroDigital/FIR x4(b) Decimation" ) , TARGET_STRING ( "" ) , 0 , 0 , 0 , 0
, 3 } , { 5 , 0 , TARGET_STRING ( "FiltroDigital/FIR x4(c) Decimation" ) ,
TARGET_STRING ( "Digitized\nApproximation" ) , 0 , 0 , 0 , 0 , 4 } , { 6 , 0
, TARGET_STRING ( "FiltroDigital/1-Bit quantizer" ) , TARGET_STRING ( "" ) ,
0 , 0 , 0 , 0 , 5 } , { 7 , 0 , TARGET_STRING ( "FiltroDigital/Sum" ) ,
TARGET_STRING ( "" ) , 0 , 0 , 0 , 0 , 5 } , { 8 , 0 , TARGET_STRING (
"FiltroDigital/Sum1" ) , TARGET_STRING ( "Error" ) , 0 , 0 , 0 , 0 , 1 } , {
9 , 0 , TARGET_STRING ( "FiltroDigital/Transport Delay" ) , TARGET_STRING (
"Analog Input(Delayed)" ) , 0 , 0 , 0 , 0 , 1 } , { 10 , 0 , TARGET_STRING (
"FiltroDigital/Zero-Order Hold" ) , TARGET_STRING ( "1-bit Error Signal" ) ,
0 , 0 , 0 , 0 , 6 } , { 0 , 0 , ( NULL ) , ( NULL ) , 0 , 0 , 0 , 0 , 0 } } ;
static const rtwCAPI_BlockParameters rtBlockParameters [ ] = { { 11 ,
TARGET_STRING ( "FiltroDigital/Gain" ) , TARGET_STRING ( "Gain" ) , 0 , 0 , 0
} , { 12 , TARGET_STRING ( "FiltroDigital/Integrator" ) , TARGET_STRING (
"InitialCondition" ) , 0 , 0 , 0 } , { 13 , TARGET_STRING (
"FiltroDigital/FIR x4(a) Decimation" ) , TARGET_STRING ( "FILT" ) , 0 , 1 , 0
} , { 14 , TARGET_STRING ( "FiltroDigital/FIR x4(b) Decimation" ) ,
TARGET_STRING ( "FILT" ) , 0 , 1 , 0 } , { 15 , TARGET_STRING (
"FiltroDigital/FIR x4(c) Decimation" ) , TARGET_STRING ( "FILT" ) , 0 , 1 , 0
} , { 16 , TARGET_STRING ( "FiltroDigital/Transport Delay" ) , TARGET_STRING
( "DelayTime" ) , 0 , 0 , 0 } , { 17 , TARGET_STRING (
"FiltroDigital/Transport Delay" ) , TARGET_STRING ( "InitialOutput" ) , 0 , 0
, 0 } , { 0 , ( NULL ) , ( NULL ) , 0 , 0 , 0 } } ; static int_T
rt_LoggedStateIdxList [ ] = { - 1 } ; static const rtwCAPI_Signals
rtRootInputs [ ] = { { 0 , 0 , ( NULL ) , ( NULL ) , 0 , 0 , 0 , 0 , 0 } } ;
static const rtwCAPI_Signals rtRootOutputs [ ] = { { 0 , 0 , ( NULL ) , (
NULL ) , 0 , 0 , 0 , 0 , 0 } } ; static const rtwCAPI_ModelParameters
rtModelParameters [ ] = { { 0 , ( NULL ) , 0 , 0 , 0 } } ;
#ifndef HOST_CAPI_BUILD
static void * rtDataAddrMap [ ] = { & rtB . dowb0yskro , & rtB . lfhnwo55cp ,
& rtB . nn1docam0d , & rtB . cuhgapmu0l , & rtB . m4mpxizuz3 , & rtB .
gousoqy1pl , & rtB . nlibdwom40 , & rtB . gpy1qxhqhc , & rtB . pvs4axzl4p , &
rtB . a5tnoiyu3h , & rtB . kbcfzcgqyz , & rtP . Gain_Gain , & rtP .
Integrator_IC , & rtP . FIRx4aDecimation_FILT [ 0 ] , & rtP .
FIRx4bDecimation_FILT [ 0 ] , & rtP . FIRx4cDecimation_FILT [ 0 ] , & rtP .
TransportDelay_Delay , & rtP . TransportDelay_InitOutput , } ; static int32_T
* rtVarDimsAddrMap [ ] = { ( NULL ) } ;
#endif
static TARGET_CONST rtwCAPI_DataTypeMap rtDataTypeMap [ ] = { { "double" ,
"real_T" , 0 , 0 , sizeof ( real_T ) , ( uint8_T ) SS_DOUBLE , 0 , 0 , 0 } }
;
#ifdef HOST_CAPI_BUILD
#undef sizeof
#endif
static TARGET_CONST rtwCAPI_ElementMap rtElementMap [ ] = { { ( NULL ) , 0 ,
0 , 0 , 0 } , } ; static const rtwCAPI_DimensionMap rtDimensionMap [ ] = { {
rtwCAPI_SCALAR , 0 , 2 , 0 } , { rtwCAPI_MATRIX_COL_MAJOR , 2 , 2 , 0 } } ;
static const uint_T rtDimensionArray [ ] = { 1 , 1 , 8 , 4 } ; static const
real_T rtcapiStoredFloats [ ] = { 1.8399189196062331E-8 , 0.0 ,
2.0833333333333333E-5 , 8.3333333333333331E-5 , 0.00033333333333333332 , 1.0
, 5.2083333333333332E-6 } ; static const rtwCAPI_FixPtMap rtFixPtMap [ ] = {
{ ( NULL ) , ( NULL ) , rtwCAPI_FIX_RESERVED , 0 , 0 , ( boolean_T ) 0 } , }
; static const rtwCAPI_SampleTimeMap rtSampleTimeMap [ ] = { { ( const void *
) & rtcapiStoredFloats [ 0 ] , ( const void * ) & rtcapiStoredFloats [ 1 ] ,
( int8_T ) 2 , ( uint8_T ) 0 } , { ( const void * ) & rtcapiStoredFloats [ 1
] , ( const void * ) & rtcapiStoredFloats [ 1 ] , ( int8_T ) 0 , ( uint8_T )
0 } , { ( const void * ) & rtcapiStoredFloats [ 2 ] , ( const void * ) &
rtcapiStoredFloats [ 1 ] , ( int8_T ) 4 , ( uint8_T ) 0 } , { ( const void *
) & rtcapiStoredFloats [ 3 ] , ( const void * ) & rtcapiStoredFloats [ 1 ] ,
( int8_T ) 5 , ( uint8_T ) 0 } , { ( const void * ) & rtcapiStoredFloats [ 4
] , ( const void * ) & rtcapiStoredFloats [ 1 ] , ( int8_T ) 6 , ( uint8_T )
0 } , { ( const void * ) & rtcapiStoredFloats [ 1 ] , ( const void * ) &
rtcapiStoredFloats [ 5 ] , ( int8_T ) 1 , ( uint8_T ) 0 } , { ( const void *
) & rtcapiStoredFloats [ 6 ] , ( const void * ) & rtcapiStoredFloats [ 1 ] ,
( int8_T ) 3 , ( uint8_T ) 0 } } ; static rtwCAPI_ModelMappingStaticInfo
mmiStatic = { { rtBlockSignals , 11 , rtRootInputs , 0 , rtRootOutputs , 0 }
, { rtBlockParameters , 7 , rtModelParameters , 0 } , { ( NULL ) , 0 } , {
rtDataTypeMap , rtDimensionMap , rtFixPtMap , rtElementMap , rtSampleTimeMap
, rtDimensionArray } , "float" , { 3816147868U , 1797692849U , 1650621602U ,
3954502009U } , ( NULL ) , 0 , ( boolean_T ) 0 , rt_LoggedStateIdxList } ;
const rtwCAPI_ModelMappingStaticInfo * FiltroDigital_GetCAPIStaticMap ( void
) { return & mmiStatic ; }
#ifndef HOST_CAPI_BUILD
void FiltroDigital_InitializeDataMapInfo ( void ) { rtwCAPI_SetVersion ( ( *
rt_dataMapInfoPtr ) . mmi , 1 ) ; rtwCAPI_SetStaticMap ( ( *
rt_dataMapInfoPtr ) . mmi , & mmiStatic ) ; rtwCAPI_SetLoggingStaticMap ( ( *
rt_dataMapInfoPtr ) . mmi , ( NULL ) ) ; rtwCAPI_SetDataAddressMap ( ( *
rt_dataMapInfoPtr ) . mmi , rtDataAddrMap ) ; rtwCAPI_SetVarDimsAddressMap (
( * rt_dataMapInfoPtr ) . mmi , rtVarDimsAddrMap ) ;
rtwCAPI_SetInstanceLoggingInfo ( ( * rt_dataMapInfoPtr ) . mmi , ( NULL ) ) ;
rtwCAPI_SetChildMMIArray ( ( * rt_dataMapInfoPtr ) . mmi , ( NULL ) ) ;
rtwCAPI_SetChildMMIArrayLen ( ( * rt_dataMapInfoPtr ) . mmi , 0 ) ; }
#else
#ifdef __cplusplus
extern "C" {
#endif
void FiltroDigital_host_InitializeDataMapInfo (
FiltroDigital_host_DataMapInfo_T * dataMap , const char * path ) {
rtwCAPI_SetVersion ( dataMap -> mmi , 1 ) ; rtwCAPI_SetStaticMap ( dataMap ->
mmi , & mmiStatic ) ; rtwCAPI_SetDataAddressMap ( dataMap -> mmi , ( NULL ) )
; rtwCAPI_SetVarDimsAddressMap ( dataMap -> mmi , ( NULL ) ) ;
rtwCAPI_SetPath ( dataMap -> mmi , path ) ; rtwCAPI_SetFullPath ( dataMap ->
mmi , ( NULL ) ) ; rtwCAPI_SetChildMMIArray ( dataMap -> mmi , ( NULL ) ) ;
rtwCAPI_SetChildMMIArrayLen ( dataMap -> mmi , 0 ) ; }
#ifdef __cplusplus
}
#endif
#endif
