#include "ne_ds.h"
#include "SM24_model_9c913df9_1_ds_sys_struct.h"
#include "SM24_model_9c913df9_1_ds_f.h"
#include "SM24_model_9c913df9_1_ds.h"
#include "SM24_model_9c913df9_1_ds_externals.h"
#include "SM24_model_9c913df9_1_ds_external_struct.h"
#include "ssc_ml_fun.h"
int32_T SM24_model_9c913df9_1_ds_f ( const NeDynamicSystem * sys , const
NeDynamicSystemInput * t2 , NeDsMethodOutput * t3 ) { PmRealVector out ;
real_T X_idx_0 ; real_T X_idx_7 ; int32_T M_idx_0 ; int32_T M_idx_1 ; int32_T
M_idx_2 ; int32_T M_idx_3 ; M_idx_0 = t2 -> mM . mX [ 0 ] ; M_idx_1 = t2 ->
mM . mX [ 1 ] ; M_idx_2 = t2 -> mM . mX [ 2 ] ; M_idx_3 = t2 -> mM . mX [ 3 ]
; X_idx_0 = t2 -> mX . mX [ 0 ] ; X_idx_7 = t2 -> mX . mX [ 7 ] ; out = t3 ->
mF ; if ( M_idx_2 != 0 ) { X_idx_0 = 4300.0 ; } else { X_idx_0 = M_idx_3 != 0
? - 4300.0 : ( ( 2.5 - X_idx_7 ) * 1000.0 - X_idx_0 ) * 5.0265482457436688E+7
; } if ( M_idx_0 != 0 ) { X_idx_0 = - 0.0 ; } else { X_idx_0 = M_idx_1 != 0 ?
- 0.0 : - X_idx_0 ; } out . mX [ 0 ] = - X_idx_0 ; out . mX [ 1 ] = - 0.0 ;
out . mX [ 2 ] = - 0.0 ; out . mX [ 3 ] = - 0.0 ; out . mX [ 4 ] = - 0.0 ;
out . mX [ 5 ] = - 0.0 ; out . mX [ 6 ] = - 0.0 ; out . mX [ 7 ] = 0.0 ; out
. mX [ 8 ] = 0.0 ; out . mX [ 9 ] = 0.0 ; out . mX [ 10 ] = 0.0 ; out . mX [
11 ] = 0.0 ; out . mX [ 12 ] = 0.0 ; out . mX [ 13 ] = 0.0 ; out . mX [ 14 ]
= 0.0 ; out . mX [ 15 ] = - 2.5E-8 ; ( void ) sys ; ( void ) t3 ; return 0 ;
}
