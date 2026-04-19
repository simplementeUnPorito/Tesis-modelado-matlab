#include "ne_ds.h"
#include "SM24_model_9c913df9_1_ds_sys_struct.h"
#include "SM24_model_9c913df9_1_ds_a_p.h"
#include "SM24_model_9c913df9_1_ds.h"
#include "SM24_model_9c913df9_1_ds_externals.h"
#include "SM24_model_9c913df9_1_ds_external_struct.h"
#include "ssc_ml_fun.h"
int32_T SM24_model_9c913df9_1_ds_a_p ( const NeDynamicSystem * sys , const
NeDynamicSystemInput * t1 , NeDsMethodOutput * t2 ) { PmSparsityPattern out ;
( void ) t1 ; out = t2 -> mA_P ; out . mNumCol = 16ULL ; out . mNumRow =
16ULL ; out . mJc [ 0 ] = 0 ; out . mJc [ 1 ] = 1 ; out . mJc [ 2 ] = 3 ; out
. mJc [ 3 ] = 5 ; out . mJc [ 4 ] = 7 ; out . mJc [ 5 ] = 9 ; out . mJc [ 6 ]
= 12 ; out . mJc [ 7 ] = 17 ; out . mJc [ 8 ] = 21 ; out . mJc [ 9 ] = 26 ;
out . mJc [ 10 ] = 32 ; out . mJc [ 11 ] = 34 ; out . mJc [ 12 ] = 38 ; out .
mJc [ 13 ] = 40 ; out . mJc [ 14 ] = 44 ; out . mJc [ 15 ] = 46 ; out . mJc [
16 ] = 48 ; out . mIr [ 0 ] = 15 ; out . mIr [ 1 ] = 1 ; out . mIr [ 2 ] = 10
; out . mIr [ 3 ] = 2 ; out . mIr [ 4 ] = 7 ; out . mIr [ 5 ] = 3 ; out . mIr
[ 6 ] = 6 ; out . mIr [ 7 ] = 3 ; out . mIr [ 8 ] = 8 ; out . mIr [ 9 ] = 4 ;
out . mIr [ 10 ] = 7 ; out . mIr [ 11 ] = 14 ; out . mIr [ 12 ] = 5 ; out .
mIr [ 13 ] = 8 ; out . mIr [ 14 ] = 9 ; out . mIr [ 15 ] = 11 ; out . mIr [
16 ] = 13 ; out . mIr [ 17 ] = 2 ; out . mIr [ 18 ] = 4 ; out . mIr [ 19 ] =
10 ; out . mIr [ 20 ] = 15 ; out . mIr [ 21 ] = 1 ; out . mIr [ 22 ] = 4 ;
out . mIr [ 23 ] = 10 ; out . mIr [ 24 ] = 12 ; out . mIr [ 25 ] = 15 ; out .
mIr [ 26 ] = 1 ; out . mIr [ 27 ] = 4 ; out . mIr [ 28 ] = 10 ; out . mIr [
29 ] = 12 ; out . mIr [ 30 ] = 14 ; out . mIr [ 31 ] = 15 ; out . mIr [ 32 ]
= 10 ; out . mIr [ 33 ] = 12 ; out . mIr [ 34 ] = 2 ; out . mIr [ 35 ] = 4 ;
out . mIr [ 36 ] = 7 ; out . mIr [ 37 ] = 15 ; out . mIr [ 38 ] = 3 ; out .
mIr [ 39 ] = 11 ; out . mIr [ 40 ] = 8 ; out . mIr [ 41 ] = 9 ; out . mIr [
42 ] = 11 ; out . mIr [ 43 ] = 13 ; out . mIr [ 44 ] = 6 ; out . mIr [ 45 ] =
9 ; out . mIr [ 46 ] = 13 ; out . mIr [ 47 ] = 14 ; ( void ) sys ; ( void )
t2 ; return 0 ; }
