#include "rtw_capi.h"
#ifdef HOST_CAPI_BUILD
#include "SM24_model_capi_host.h"
#define sizeof(s) ((size_t)(0xFFFF))
#undef rt_offsetof
#define rt_offsetof(s,el) ((uint16_T)(0xFFFF))
#define TARGET_CONST
#define TARGET_STRING(s) (s)
#ifndef SS_UINT64
#define SS_UINT64 17
#endif
#ifndef SS_INT64
#define SS_INT64 18
#endif
#else
#include "builtin_typeid_types.h"
#include "SM24_model.h"
#include "SM24_model_capi.h"
#include "SM24_model_private.h"
#ifdef LIGHT_WEIGHT_CAPI
#define TARGET_CONST
#define TARGET_STRING(s)               ((NULL))
#else
#define TARGET_CONST                   const
#define TARGET_STRING(s)               (s)
#endif
#endif
static const rtwCAPI_Signals rtBlockSignals [ ] = { { 0 , 0 , TARGET_STRING (
"SM24_model/Step" ) , TARGET_STRING ( "" ) , 0 , 0 , 0 , 0 , 0 } , { 1 , 0 ,
TARGET_STRING ( "SM24_model/Bode Plot/Detect edge/RateConversion" ) ,
TARGET_STRING ( "" ) , 0 , 0 , 0 , 0 , 1 } , { 2 , 0 , TARGET_STRING (
"SM24_model/Bode Plot/Detect edge/Logical Operator3" ) , TARGET_STRING ( "" )
, 0 , 1 , 0 , 0 , 0 } , { 3 , 0 , TARGET_STRING (
"SM24_model/Bode Plot/Detect edge/D2" ) , TARGET_STRING ( "" ) , 0 , 2 , 0 ,
0 , 0 } , { 4 , 0 , TARGET_STRING (
"SM24_model/Solver Configuration/EVAL_KEY/INPUT_1_1_1" ) , TARGET_STRING ( ""
) , 0 , 0 , 1 , 0 , 1 } , { 5 , 0 , TARGET_STRING (
"SM24_model/Solver Configuration/EVAL_KEY/OUTPUT_1_0" ) , TARGET_STRING ( ""
) , 0 , 0 , 0 , 0 , 1 } , { 6 , 0 , TARGET_STRING (
"SM24_model/Solver Configuration/EVAL_KEY/STATE_1" ) , TARGET_STRING ( "" ) ,
0 , 0 , 2 , 0 , 1 } , { 7 , 0 , TARGET_STRING (
"SM24_model/Bode Plot/Detect edge/C2/Compare" ) , TARGET_STRING ( "" ) , 0 ,
2 , 0 , 0 , 0 } , { 8 , 0 , TARGET_STRING (
"SM24_model/Bode Plot/Detect edge/Zero/Compare" ) , TARGET_STRING ( "" ) , 0
, 2 , 0 , 0 , 0 } , { 0 , 0 , ( NULL ) , ( NULL ) , 0 , 0 , 0 , 0 , 0 } } ;
static const rtwCAPI_BlockParameters rtBlockParameters [ ] = { { 9 ,
TARGET_STRING ( "SM24_model/Step" ) , TARGET_STRING ( "Time" ) , 0 , 0 , 0 }
, { 10 , TARGET_STRING ( "SM24_model/Step" ) , TARGET_STRING ( "Before" ) , 0
, 0 , 0 } , { 11 , TARGET_STRING ( "SM24_model/Step" ) , TARGET_STRING (
"After" ) , 0 , 0 , 0 } , { 12 , TARGET_STRING (
"SM24_model/Bode Plot/Detect edge/RateConversion" ) , TARGET_STRING ( "Gain"
) , 0 , 0 , 0 } , { 13 , TARGET_STRING (
"SM24_model/Bode Plot/Detect edge/D1" ) , TARGET_STRING ( "InitialCondition"
) , 2 , 0 , 0 } , { 14 , TARGET_STRING (
"SM24_model/Bode Plot/Detect edge/D2" ) , TARGET_STRING ( "InitialCondition"
) , 2 , 0 , 0 } , { 15 , TARGET_STRING (
"SM24_model/Bode Plot/Detect edge/D3" ) , TARGET_STRING ( "InitialCondition"
) , 2 , 0 , 0 } , { 16 , TARGET_STRING (
"SM24_model/Bode Plot/Trigger signal/Snapshot times" ) , TARGET_STRING (
"Value" ) , 0 , 0 , 0 } , { 17 , TARGET_STRING (
"SM24_model/Bode Plot/Detect edge/C1/Constant" ) , TARGET_STRING ( "Value" )
, 0 , 0 , 0 } , { 18 , TARGET_STRING (
"SM24_model/Bode Plot/Detect edge/C2/Constant" ) , TARGET_STRING ( "Value" )
, 0 , 0 , 0 } , { 19 , TARGET_STRING (
"SM24_model/Bode Plot/Detect edge/C3/Constant" ) , TARGET_STRING ( "Value" )
, 0 , 0 , 0 } , { 20 , TARGET_STRING (
"SM24_model/Bode Plot/Detect edge/Zero/Constant" ) , TARGET_STRING ( "Value"
) , 0 , 0 , 0 } , { 0 , ( NULL ) , ( NULL ) , 0 , 0 , 0 } } ; static int_T
rt_LoggedStateIdxList [ ] = { - 1 } ; static const rtwCAPI_Signals
rtRootInputs [ ] = { { 0 , 0 , ( NULL ) , ( NULL ) , 0 , 0 , 0 , 0 , 0 } } ;
static const rtwCAPI_Signals rtRootOutputs [ ] = { { 0 , 0 , ( NULL ) , (
NULL ) , 0 , 0 , 0 , 0 , 0 } } ; static const rtwCAPI_ModelParameters
rtModelParameters [ ] = { { 0 , ( NULL ) , 0 , 0 , 0 } } ;
#ifndef HOST_CAPI_BUILD
static void * rtDataAddrMap [ ] = { & rtB . hptfqp3w4t , & rtB . ex54xq0c2t ,
& rtB . aaphbljg5e , & rtB . ojrpy5nefy , & rtB . ckzbdtbp2u [ 0 ] , & rtB .
d315qoqwkh , & rtB . dffdefsite [ 0 ] , & rtB . p3ejhqueew , & rtB .
exmape5dlp , & rtP . Step_Time , & rtP . Step_Y0 , & rtP . Step_YFinal , &
rtP . RateConversion_Gain , & rtP . D1_InitialCondition , & rtP .
D2_InitialCondition , & rtP . D3_InitialCondition , & rtP .
Snapshottimes_Value , & rtP . Constant_Value , & rtP .
Constant_Value_dv5dqkwtfv , & rtP . Constant_Value_n54scyttiz , & rtP .
Constant_Value_fnvw3cdvbn , } ; static int32_T * rtVarDimsAddrMap [ ] = { (
NULL ) } ;
#endif
static TARGET_CONST rtwCAPI_DataTypeMap rtDataTypeMap [ ] = { { "double" ,
"real_T" , 0 , 0 , sizeof ( real_T ) , ( uint8_T ) SS_DOUBLE , 0 , 0 , 0 } ,
{ "unsigned char" , "boolean_T" , 0 , 0 , sizeof ( boolean_T ) , ( uint8_T )
SS_BOOLEAN , 0 , 0 , 0 } , { "unsigned char" , "uint8_T" , 0 , 0 , sizeof (
uint8_T ) , ( uint8_T ) SS_UINT8 , 0 , 0 , 0 } } ;
#ifdef HOST_CAPI_BUILD
#undef sizeof
#endif
static TARGET_CONST rtwCAPI_ElementMap rtElementMap [ ] = { { ( NULL ) , 0 ,
0 , 0 , 0 } , } ; static const rtwCAPI_DimensionMap rtDimensionMap [ ] = { {
rtwCAPI_SCALAR , 0 , 2 , 0 } , { rtwCAPI_VECTOR , 2 , 2 , 0 } , {
rtwCAPI_VECTOR , 4 , 2 , 0 } } ; static const uint_T rtDimensionArray [ ] = {
1 , 1 , 4 , 1 , 28 , 1 } ; static const real_T rtcapiStoredFloats [ ] = { 0.0
, 1.0 } ; static const rtwCAPI_FixPtMap rtFixPtMap [ ] = { { ( NULL ) , (
NULL ) , rtwCAPI_FIX_RESERVED , 0 , 0 , ( boolean_T ) 0 } , } ; static const
rtwCAPI_SampleTimeMap rtSampleTimeMap [ ] = { { ( const void * ) &
rtcapiStoredFloats [ 0 ] , ( const void * ) & rtcapiStoredFloats [ 1 ] , (
int8_T ) 1 , ( uint8_T ) 0 } , { ( const void * ) & rtcapiStoredFloats [ 0 ]
, ( const void * ) & rtcapiStoredFloats [ 0 ] , ( int8_T ) 0 , ( uint8_T ) 0
} } ; static rtwCAPI_ModelMappingStaticInfo mmiStatic = { { rtBlockSignals ,
9 , rtRootInputs , 0 , rtRootOutputs , 0 } , { rtBlockParameters , 12 ,
rtModelParameters , 0 } , { ( NULL ) , 0 } , { rtDataTypeMap , rtDimensionMap
, rtFixPtMap , rtElementMap , rtSampleTimeMap , rtDimensionArray } , "float"
, { 3391073398U , 1272981956U , 1383899044U , 2805460587U } , ( NULL ) , 0 ,
( boolean_T ) 0 , rt_LoggedStateIdxList } ; const
rtwCAPI_ModelMappingStaticInfo * SM24_model_GetCAPIStaticMap ( void ) {
return & mmiStatic ; }
#ifndef HOST_CAPI_BUILD
void SM24_model_InitializeDataMapInfo ( void ) { rtwCAPI_SetVersion ( ( *
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
void SM24_model_host_InitializeDataMapInfo ( SM24_model_host_DataMapInfo_T *
dataMap , const char * path ) { rtwCAPI_SetVersion ( dataMap -> mmi , 1 ) ;
rtwCAPI_SetStaticMap ( dataMap -> mmi , & mmiStatic ) ;
rtwCAPI_SetDataAddressMap ( dataMap -> mmi , ( NULL ) ) ;
rtwCAPI_SetVarDimsAddressMap ( dataMap -> mmi , ( NULL ) ) ; rtwCAPI_SetPath
( dataMap -> mmi , path ) ; rtwCAPI_SetFullPath ( dataMap -> mmi , ( NULL ) )
; rtwCAPI_SetChildMMIArray ( dataMap -> mmi , ( NULL ) ) ;
rtwCAPI_SetChildMMIArrayLen ( dataMap -> mmi , 0 ) ; }
#ifdef __cplusplus
}
#endif
#endif
