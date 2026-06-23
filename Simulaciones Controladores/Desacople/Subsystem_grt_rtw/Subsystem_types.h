/*
 * Subsystem_types.h
 *
 * Code generation for model "Subsystem".
 *
 * Model version              : 1.39
 * Simulink Coder version : 25.2 (R2025b) 28-Jul-2025
 * C source code generated on : Tue Jun 23 16:23:21 2026
 *
 * Target selection: grt.tlc
 * Note: GRT includes extra infrastructure and instrumentation for prototyping
 * Embedded hardware selection: Intel->x86-64 (Windows64)
 * Code generation objectives: Unspecified
 * Validation result: Not run
 */

#ifndef Subsystem_types_h_
#define Subsystem_types_h_
#include "rtwtypes.h"
#ifndef struct_emxArray_real_T
#define struct_emxArray_real_T

struct emxArray_real_T
{
  real_T *data;
  int32_T *size;
  int32_T allocatedSize;
  int32_T numDimensions;
  boolean_T canFreeData;
};

#endif                                 /* struct_emxArray_real_T */

#ifndef typedef_emxArray_real_T_Subsystem_T
#define typedef_emxArray_real_T_Subsystem_T

typedef struct emxArray_real_T emxArray_real_T_Subsystem_T;

#endif                                 /* typedef_emxArray_real_T_Subsystem_T */

/* Parameters (default storage) */
typedef struct P_Subsystem_T_ P_Subsystem_T;

/* Forward declaration for rtModel */
typedef struct tag_RTM_Subsystem_T RT_MODEL_Subsystem_T;

#endif                                 /* Subsystem_types_h_ */
