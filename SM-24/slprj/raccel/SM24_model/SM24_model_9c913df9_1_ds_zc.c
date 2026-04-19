#include "ne_ds.h"
#include "SM24_model_9c913df9_1_ds_sys_struct.h"
#include "SM24_model_9c913df9_1_ds_zc.h"
#include "SM24_model_9c913df9_1_ds.h"
#include "SM24_model_9c913df9_1_ds_externals.h"
#include "SM24_model_9c913df9_1_ds_external_struct.h"
#include "ssc_ml_fun.h"
int32_T SM24_model_9c913df9_1_ds_zc ( const NeDynamicSystem * sys , const
NeDynamicSystemInput * t5 , NeDsMethodOutput * t6 ) { PmRealVector out ;
real_T X_idx_0 ; real_T X_idx_7 ; real_T intrm_sf_mf_2 ; real_T t0 ; int32_T
M_idx_0 ; int32_T M_idx_1 ; int32_T M_idx_2 ; boolean_T t2 ; boolean_T t3 ;
M_idx_0 = t5 -> mM . mX [ 0 ] ; M_idx_1 = t5 -> mM . mX [ 1 ] ; M_idx_2 = t5
-> mM . mX [ 2 ] ; X_idx_0 = t5 -> mX . mX [ 0 ] ; X_idx_7 = t5 -> mX . mX [
7 ] ; out = t6 -> mZC ; X_idx_7 = ( ( 2.5 - X_idx_7 ) * 1000.0 - X_idx_0 ) *
5.0265482457436688E+7 ; if ( X_idx_7 > 4300.0 ) { intrm_sf_mf_2 = 4300.0 ; }
else { intrm_sf_mf_2 = X_idx_7 < - 4300.0 ? - 4300.0 : X_idx_7 ; } if ( (
M_idx_0 == 0 ) && ( M_idx_1 == 0 ) ) { t0 = X_idx_7 - 4300.0 ; } else { t0 =
0.0 ; } if ( ( M_idx_0 == 0 ) && ( M_idx_1 == 0 ) && ( M_idx_2 == 0 ) ) {
X_idx_7 = - 4300.0 - X_idx_7 ; } else { X_idx_7 = 0.0 ; } if ( X_idx_0 >= 4.5
) { t2 = ( intrm_sf_mf_2 > 0.0 ) ; } else { t2 = false ; } if ( M_idx_0 == 0
) { if ( X_idx_0 <= 0.5 ) { t3 = ( intrm_sf_mf_2 < 0.0 ) ; } else { t3 =
false ; } } else { t3 = false ; } out . mX [ 0 ] = t0 ; out . mX [ 1 ] =
X_idx_7 ; out . mX [ 2 ] = ( real_T ) t2 ; out . mX [ 3 ] = ( real_T ) t3 ; (
void ) sys ; ( void ) t6 ; return 0 ; }
