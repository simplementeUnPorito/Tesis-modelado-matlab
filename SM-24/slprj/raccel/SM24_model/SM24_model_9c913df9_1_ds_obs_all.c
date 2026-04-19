#include "ne_ds.h"
#include "SM24_model_9c913df9_1_ds_sys_struct.h"
#include "SM24_model_9c913df9_1_ds_obs_all.h"
#include "SM24_model_9c913df9_1_ds.h"
#include "SM24_model_9c913df9_1_ds_externals.h"
#include "SM24_model_9c913df9_1_ds_external_struct.h"
#include "ssc_ml_fun.h"
int32_T SM24_model_9c913df9_1_ds_obs_all ( const NeDynamicSystem * sys ,
const NeDynamicSystemInput * t2 , NeDsMethodOutput * t3 ) { PmRealVector out
; real_T Capacitor1_i ; real_T Capacitor2_i ; real_T Capacitor2_p_v ; real_T
Capacitor_i ; real_T Capacitor_n_v ; real_T U_idx_0 ; real_T Voltage_Sensor_V
; real_T X_idx_0 ; real_T X_idx_1 ; real_T X_idx_10 ; real_T X_idx_11 ;
real_T X_idx_12 ; real_T X_idx_13 ; real_T X_idx_14 ; real_T X_idx_15 ;
real_T X_idx_2 ; real_T X_idx_3 ; real_T X_idx_4 ; real_T X_idx_5 ; real_T
X_idx_6 ; real_T X_idx_7 ; real_T X_idx_8 ; real_T X_idx_9 ; real_T piece1 ;
U_idx_0 = t2 -> mU . mX [ 0 ] ; X_idx_0 = t2 -> mX . mX [ 0 ] ; X_idx_1 = t2
-> mX . mX [ 1 ] ; X_idx_2 = t2 -> mX . mX [ 2 ] ; X_idx_3 = t2 -> mX . mX [
3 ] ; X_idx_4 = t2 -> mX . mX [ 4 ] ; X_idx_5 = t2 -> mX . mX [ 5 ] ; X_idx_6
= t2 -> mX . mX [ 6 ] ; X_idx_7 = t2 -> mX . mX [ 7 ] ; X_idx_8 = t2 -> mX .
mX [ 8 ] ; X_idx_9 = t2 -> mX . mX [ 9 ] ; X_idx_10 = t2 -> mX . mX [ 10 ] ;
X_idx_11 = t2 -> mX . mX [ 11 ] ; X_idx_12 = t2 -> mX . mX [ 12 ] ; X_idx_13
= t2 -> mX . mX [ 13 ] ; X_idx_14 = t2 -> mX . mX [ 14 ] ; X_idx_15 = t2 ->
mX . mX [ 15 ] ; out = t3 -> mOBS_ALL ; Capacitor_i = X_idx_8 * -
0.0026666666666666666 + X_idx_9 * 0.0026666666666666666 ; Capacitor_n_v = -
X_idx_1 + X_idx_10 ; Capacitor1_i = X_idx_7 * - 0.0010378827192527244 +
X_idx_11 * 0.0010378827192527244 ; Capacitor2_i = X_idx_3 + X_idx_12 ;
Capacitor2_p_v = X_idx_4 + X_idx_13 ; Voltage_Sensor_V = Capacitor_n_v -
X_idx_5 * 1.0E+6 ; piece1 = X_idx_7 * - 1.0E-8 ; out . mX [ 0 ] = 2.5E-8 +
piece1 ; out . mX [ 1 ] = X_idx_0 * - 0.066666666666666666 + X_idx_7 *
0.066666666666666666 ; out . mX [ 2 ] = X_idx_7 ; out . mX [ 3 ] = X_idx_7 ;
out . mX [ 4 ] = 2.5 ; out . mX [ 5 ] = X_idx_0 ; out . mX [ 6 ] =
Capacitor_i ; out . mX [ 7 ] = Capacitor_n_v ; out . mX [ 8 ] = X_idx_10 ;
out . mX [ 9 ] = X_idx_1 ; out . mX [ 10 ] = X_idx_1 ; out . mX [ 11 ] =
Capacitor1_i ; out . mX [ 12 ] = X_idx_11 ; out . mX [ 13 ] = X_idx_5 *
1.0E+6 ; out . mX [ 14 ] = X_idx_2 ; out . mX [ 15 ] = X_idx_2 ; out . mX [
16 ] = Capacitor2_i ; out . mX [ 17 ] = X_idx_13 ; out . mX [ 18 ] =
Capacitor2_p_v ; out . mX [ 19 ] = X_idx_4 ; out . mX [ 20 ] = X_idx_4 ; out
. mX [ 21 ] = - Capacitor2_i ; out . mX [ 22 ] = X_idx_6 * 1.0E+6 ; out . mX
[ 23 ] = Capacitor2_p_v ; out . mX [ 24 ] = U_idx_0 ; out . mX [ 25 ] =
U_idx_0 ; out . mX [ 26 ] = 0.0 ; out . mX [ 27 ] = ( ( X_idx_7 *
0.0010378827192527244 + X_idx_11 * - 0.0010378827192527244 ) + X_idx_8 *
0.0026666666666666666 ) + X_idx_9 * - 0.0026666666666666666 ; out . mX [ 28 ]
= X_idx_5 * 1.0E+6 ; out . mX [ 29 ] = X_idx_5 ; out . mX [ 30 ] = X_idx_5 *
1.0E+6 ; out . mX [ 31 ] = 0.0 ; out . mX [ 32 ] = X_idx_6 * 1.0E+6 ; out .
mX [ 33 ] = X_idx_6 ; out . mX [ 34 ] = X_idx_6 * 1.0E+6 ; out . mX [ 35 ] =
X_idx_3 ; out . mX [ 36 ] = X_idx_6 * 1.0E+6 ; out . mX [ 37 ] = X_idx_13 ;
out . mX [ 38 ] = X_idx_14 ; out . mX [ 39 ] = X_idx_3 ; out . mX [ 40 ] =
Capacitor_i ; out . mX [ 41 ] = X_idx_7 ; out . mX [ 42 ] = Capacitor_n_v ;
out . mX [ 43 ] = Capacitor_i * 963.5 ; out . mX [ 44 ] = - Capacitor1_i ;
out . mX [ 45 ] = X_idx_11 ; out . mX [ 46 ] = X_idx_7 ; out . mX [ 47 ] =
Capacitor1_i * - 963.5 ; out . mX [ 48 ] = X_idx_12 ; out . mX [ 49 ] =
X_idx_6 * 1.0E+6 ; out . mX [ 50 ] = X_idx_13 ; out . mX [ 51 ] = X_idx_12 *
0.34557519189487723 ; out . mX [ 52 ] = Capacitor_i ; out . mX [ 53 ] =
X_idx_8 ; out . mX [ 54 ] = X_idx_9 ; out . mX [ 55 ] = Capacitor_i * 375.0 ;
out . mX [ 56 ] = Capacitor_i ; out . mX [ 57 ] = X_idx_10 ; out . mX [ 58 ]
= X_idx_8 ; out . mX [ 59 ] = Capacitor_i * 63.5 ; out . mX [ 60 ] = U_idx_0
; out . mX [ 61 ] = 0.0 ; out . mX [ 62 ] = - Capacitor_i ; out . mX [ 63 ] =
X_idx_6 * 1.0E+6 ; out . mX [ 64 ] = X_idx_5 * 1.0E+6 ; out . mX [ 65 ] =
X_idx_13 ; out . mX [ 66 ] = X_idx_9 ; out . mX [ 67 ] = X_idx_15 ; out . mX
[ 68 ] = X_idx_15 * 28.8 ; out . mX [ 69 ] = Voltage_Sensor_V ; out . mX [ 70
] = X_idx_5 * 1.0E+6 ; out . mX [ 71 ] = Capacitor_n_v ; out . mX [ 72 ] =
Voltage_Sensor_V ; out . mX [ 73 ] = - 2.5E-8 - piece1 ; out . mX [ 74 ] =
0.0 ; out . mX [ 75 ] = 2.5 ; out . mX [ 76 ] = 2.5 ; ( void ) sys ; ( void )
t3 ; return 0 ; }
