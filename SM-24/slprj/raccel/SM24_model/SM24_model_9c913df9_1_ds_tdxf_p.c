#include "ne_ds.h"
#include "SM24_model_9c913df9_1_ds_sys_struct.h"
#include "SM24_model_9c913df9_1_ds_tdxf_p.h"
#include "SM24_model_9c913df9_1_ds.h"
#include "SM24_model_9c913df9_1_ds_externals.h"
#include "SM24_model_9c913df9_1_ds_external_struct.h"
#include "ssc_ml_fun.h"
int32_T SM24_model_9c913df9_1_ds_tdxf_p ( const NeDynamicSystem * sys , const
NeDynamicSystemInput * t1 , NeDsMethodOutput * t2 ) { PmSparsityPattern out ;
( void ) t1 ; out = t2 -> mTDXF_P ; out . mNumCol = 16ULL ; out . mNumRow =
16ULL ; out . mJc [ 0 ] = 0 ; out . mJc [ 1 ] = 2 ; out . mJc [ 2 ] = 4 ; out
. mJc [ 3 ] = 6 ; out . mJc [ 4 ] = 8 ; out . mJc [ 5 ] = 10 ; out . mJc [ 6
] = 13 ; out . mJc [ 7 ] = 18 ; out . mJc [ 8 ] = 23 ; out . mJc [ 9 ] = 28 ;
out . mJc [ 10 ] = 34 ; out . mJc [ 11 ] = 36 ; out . mJc [ 12 ] = 40 ; out .
mJc [ 13 ] = 42 ; out . mJc [ 14 ] = 46 ; out . mJc [ 15 ] = 48 ; out . mJc [
16 ] = 50 ; out . mIr [ 0 ] = 0 ; out . mIr [ 1 ] = 15 ; out . mIr [ 2 ] = 1
; out . mIr [ 3 ] = 10 ; out . mIr [ 4 ] = 2 ; out . mIr [ 5 ] = 7 ; out .
mIr [ 6 ] = 3 ; out . mIr [ 7 ] = 6 ; out . mIr [ 8 ] = 3 ; out . mIr [ 9 ] =
8 ; out . mIr [ 10 ] = 4 ; out . mIr [ 11 ] = 7 ; out . mIr [ 12 ] = 14 ; out
. mIr [ 13 ] = 5 ; out . mIr [ 14 ] = 8 ; out . mIr [ 15 ] = 9 ; out . mIr [
16 ] = 11 ; out . mIr [ 17 ] = 13 ; out . mIr [ 18 ] = 0 ; out . mIr [ 19 ] =
2 ; out . mIr [ 20 ] = 4 ; out . mIr [ 21 ] = 10 ; out . mIr [ 22 ] = 15 ;
out . mIr [ 23 ] = 1 ; out . mIr [ 24 ] = 4 ; out . mIr [ 25 ] = 10 ; out .
mIr [ 26 ] = 12 ; out . mIr [ 27 ] = 15 ; out . mIr [ 28 ] = 1 ; out . mIr [
29 ] = 4 ; out . mIr [ 30 ] = 10 ; out . mIr [ 31 ] = 12 ; out . mIr [ 32 ] =
14 ; out . mIr [ 33 ] = 15 ; out . mIr [ 34 ] = 10 ; out . mIr [ 35 ] = 12 ;
out . mIr [ 36 ] = 2 ; out . mIr [ 37 ] = 4 ; out . mIr [ 38 ] = 7 ; out .
mIr [ 39 ] = 15 ; out . mIr [ 40 ] = 3 ; out . mIr [ 41 ] = 11 ; out . mIr [
42 ] = 8 ; out . mIr [ 43 ] = 9 ; out . mIr [ 44 ] = 11 ; out . mIr [ 45 ] =
13 ; out . mIr [ 46 ] = 6 ; out . mIr [ 47 ] = 9 ; out . mIr [ 48 ] = 13 ;
out . mIr [ 49 ] = 14 ; ( void ) sys ; ( void ) t2 ; return 0 ; }
