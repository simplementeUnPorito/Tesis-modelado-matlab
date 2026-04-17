#include "ne_ds.h"
#include "SM24_model_9c913df9_1_ds_sys_struct.h"
#include "SM24_model_9c913df9_1_ds_a.h"
#include "SM24_model_9c913df9_1_ds.h"
#include "SM24_model_9c913df9_1_ds_externals.h"
#include "SM24_model_9c913df9_1_ds_external_struct.h"
#include "ssc_ml_fun.h"
int32_T SM24_model_9c913df9_1_ds_a ( const NeDynamicSystem * sys , const
NeDynamicSystemInput * t56 , NeDsMethodOutput * t57 ) { PmRealVector out ;
real_T t0 [ 48 ] ; real_T t9 [ 6 ] ; real_T t6 [ 5 ] ; real_T t8 [ 5 ] ;
real_T t11 [ 4 ] ; real_T t13 [ 4 ] ; real_T t7 [ 4 ] ; size_t t24 ; ( void )
t56 ; out = t57 -> mA ; t6 [ 0 ] = 0.0 ; t6 [ 1 ] = 1.0 ; t6 [ 2 ] = 1.0 ; t6
[ 3 ] = 1.0 ; t6 [ 4 ] = 1.0 ; t7 [ 0ULL ] = 0.0010378827192527244 ; t7 [
1ULL ] = - 0.0010378827192527244 ; t7 [ 2ULL ] = 0.0010378827192527244 ; t7 [
3ULL ] = 0.067704559385919391 ; t8 [ 0ULL ] = 0.0026666666666666666 ; t8 [
1ULL ] = - 0.0026666666666666666 ; t8 [ 2ULL ] = - 0.0026666666666666666 ; t8
[ 3ULL ] = - 0.01841469816272966 ; t8 [ 4ULL ] = 0.0026666666666666666 ; t9 [
0ULL ] = - 0.0026666666666666666 ; t9 [ 1ULL ] = 0.0026666666666666666 ; t9 [
2ULL ] = 0.0026666666666666666 ; t9 [ 3ULL ] = 0.0026666666666666666 ; t9 [
4ULL ] = - 1.0E-6 ; t9 [ 5ULL ] = - 0.0026666666666666666 ; t11 [ 0ULL ] = -
0.0010378827192527244 ; t11 [ 1ULL ] = 0.0010378827192527244 ; t11 [ 2ULL ] =
1.0E-6 ; t11 [ 3ULL ] = - 0.0010378827192527244 ; t13 [ 0ULL ] = - 1.0E-6 ;
t13 [ 1ULL ] = - 1.0E-6 ; t13 [ 2ULL ] = - 1.0E-6 ; t13 [ 3ULL ] = - 1.0E-6 ;
t0 [ 0ULL ] = - 0.066666666666666666 ; t0 [ 1ULL ] = - 0.0 ; t0 [ 2ULL ] =
0.0010378827192527244 ; t0 [ 3ULL ] = - 0.0 ; t0 [ 4ULL ] = 1.0E-6 ; t0 [
5ULL ] = - 1.0 ; t0 [ 6ULL ] = - 0.0 ; t0 [ 7ULL ] = - 0.0 ; t0 [ 8ULL ] = -
1.0E-6 ; t0 [ 9ULL ] = - 0.0 ; t0 [ 10ULL ] = - 1.0 ; t0 [ 11ULL ] = 1.0 ;
for ( t24 = 0ULL ; t24 < 5ULL ; t24 ++ ) { t0 [ t24 + 12ULL ] = t6 [ t24 ] ;
} for ( t24 = 0ULL ; t24 < 4ULL ; t24 ++ ) { t0 [ t24 + 17ULL ] = t7 [ t24 ]
; } for ( t24 = 0ULL ; t24 < 5ULL ; t24 ++ ) { t0 [ t24 + 21ULL ] = t8 [ t24
] ; } for ( t24 = 0ULL ; t24 < 6ULL ; t24 ++ ) { t0 [ t24 + 26ULL ] = t9 [
t24 ] ; } t0 [ 32ULL ] = - 0.0010378827192527244 ; t0 [ 33ULL ] =
0.015748031496062992 ; for ( t24 = 0ULL ; t24 < 4ULL ; t24 ++ ) { t0 [ t24 +
34ULL ] = t11 [ t24 ] ; } t0 [ 38ULL ] = - 1.0 ; t0 [ 39ULL ] =
3.4557519189487721E-7 ; for ( t24 = 0ULL ; t24 < 4ULL ; t24 ++ ) { t0 [ t24 +
40ULL ] = t13 [ t24 ] ; } out . mX [ 0 ] = t0 [ 0 ] ; out . mX [ 1 ] = t0 [ 1
] ; out . mX [ 2 ] = t0 [ 2 ] ; out . mX [ 3 ] = t0 [ 3 ] ; out . mX [ 4 ] =
t0 [ 4 ] ; out . mX [ 5 ] = t0 [ 5 ] ; out . mX [ 6 ] = t0 [ 6 ] ; out . mX [
7 ] = t0 [ 7 ] ; out . mX [ 8 ] = t0 [ 8 ] ; out . mX [ 9 ] = t0 [ 9 ] ; out
. mX [ 10 ] = t0 [ 10 ] ; out . mX [ 11 ] = t0 [ 11 ] ; out . mX [ 12 ] = t0
[ 12 ] ; out . mX [ 13 ] = t0 [ 13 ] ; out . mX [ 14 ] = t0 [ 14 ] ; out . mX
[ 15 ] = t0 [ 15 ] ; out . mX [ 16 ] = t0 [ 16 ] ; out . mX [ 17 ] = t0 [ 17
] ; out . mX [ 18 ] = t0 [ 18 ] ; out . mX [ 19 ] = t0 [ 19 ] ; out . mX [ 20
] = t0 [ 20 ] ; out . mX [ 21 ] = t0 [ 21 ] ; out . mX [ 22 ] = t0 [ 22 ] ;
out . mX [ 23 ] = t0 [ 23 ] ; out . mX [ 24 ] = t0 [ 24 ] ; out . mX [ 25 ] =
t0 [ 25 ] ; out . mX [ 26 ] = t0 [ 26 ] ; out . mX [ 27 ] = t0 [ 27 ] ; out .
mX [ 28 ] = t0 [ 28 ] ; out . mX [ 29 ] = t0 [ 29 ] ; out . mX [ 30 ] = t0 [
30 ] ; out . mX [ 31 ] = t0 [ 31 ] ; out . mX [ 32 ] = t0 [ 32 ] ; out . mX [
33 ] = t0 [ 33 ] ; out . mX [ 34 ] = t0 [ 34 ] ; out . mX [ 35 ] = t0 [ 35 ]
; out . mX [ 36 ] = t0 [ 36 ] ; out . mX [ 37 ] = t0 [ 37 ] ; out . mX [ 38 ]
= t0 [ 38 ] ; out . mX [ 39 ] = t0 [ 39 ] ; out . mX [ 40 ] = t0 [ 40 ] ; out
. mX [ 41 ] = t0 [ 41 ] ; out . mX [ 42 ] = t0 [ 42 ] ; out . mX [ 43 ] = t0
[ 43 ] ; out . mX [ 44 ] = - 1.0 ; out . mX [ 45 ] = 1.0E-6 ; out . mX [ 46 ]
= 1.0E-6 ; out . mX [ 47 ] = 2.8800000000000002E-5 ; ( void ) sys ; ( void )
t57 ; return 0 ; }
