/*
 * Subsystem.h
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

#ifndef Subsystem_h_
#define Subsystem_h_
#ifndef Subsystem_COMMON_INCLUDES_
#define Subsystem_COMMON_INCLUDES_
#include "rtwtypes.h"
#include "rtw_continuous.h"
#include "rtw_solver.h"
#include "rt_logging.h"
#include "rt_nonfinite.h"
#include "math.h"
#endif                                 /* Subsystem_COMMON_INCLUDES_ */

#include "Subsystem_types.h"
#include <float.h>
#include <string.h>
#include <stddef.h>

/* Macros for accessing real-time model data structure */
#ifndef rtmGetFinalTime
#define rtmGetFinalTime(rtm)           ((rtm)->Timing.tFinal)
#endif

#ifndef rtmGetRTWLogInfo
#define rtmGetRTWLogInfo(rtm)          ((rtm)->rtwLogInfo)
#endif

#ifndef rtmGetErrorStatus
#define rtmGetErrorStatus(rtm)         ((rtm)->errorStatus)
#endif

#ifndef rtmSetErrorStatus
#define rtmSetErrorStatus(rtm, val)    ((rtm)->errorStatus = (val))
#endif

#ifndef rtmGetStopRequested
#define rtmGetStopRequested(rtm)       ((rtm)->Timing.stopRequestedFlag)
#endif

#ifndef rtmSetStopRequested
#define rtmSetStopRequested(rtm, val)  ((rtm)->Timing.stopRequestedFlag = (val))
#endif

#ifndef rtmGetStopRequestedPtr
#define rtmGetStopRequestedPtr(rtm)    (&((rtm)->Timing.stopRequestedFlag))
#endif

#ifndef rtmGetT
#define rtmGetT(rtm)                   ((rtm)->Timing.taskTime0)
#endif

#ifndef rtmGetTFinal
#define rtmGetTFinal(rtm)              ((rtm)->Timing.tFinal)
#endif

#ifndef rtmGetTPtr
#define rtmGetTPtr(rtm)                (&(rtm)->Timing.taskTime0)
#endif

/* Block signals (default storage) */
typedef struct {
  real_T Gain;                         /* '<S1>/Gain' */
} B_Subsystem_T;

/* Block states (default storage) for system '<Root>' */
typedef struct {
  real_T UnitDelay_DSTATE;             /* '<S1>/Unit Delay' */
  real_T DiscreteFIRFilter_states[127];/* '<S1>/Discrete FIR Filter' */
  real_T Integrator_DSTATE;            /* '<S41>/Integrator' */
  real_T DiscreteFIRFilter_simContextBuf[254];/* '<S1>/Discrete FIR Filter' */
  real_T DiscreteFIRFilter_simRevCoeff[128];/* '<S1>/Discrete FIR Filter' */
  real_T idx;                          /* '<S1>/MATLAB Function1' */
  real_T count;                        /* '<S1>/MATLAB Function1' */
  emxArray_real_T_Subsystem_T* buf;    /* '<S1>/MATLAB Function1' */
  int32_T DiscreteFIRFilter_circBuf;   /* '<S1>/Discrete FIR Filter' */
  boolean_T buf_not_empty;             /* '<S1>/MATLAB Function1' */
  boolean_T locked;                    /* '<S1>/MATLAB Function1' */
} DW_Subsystem_T;

/* External inputs (root inport signals with default storage) */
typedef struct {
  real_T Vref;                         /* '<Root>/Vref' */
  boolean_T start;                     /* '<Root>/start' */
  real_T y;                            /* '<Root>/y' */
} ExtU_Subsystem_T;

/* External outputs (root outports fed by signals with default storage) */
typedef struct {
  real_T u;                            /* '<Root>/u' */
  real_T error;                        /* '<Root>/error' */
  boolean_T lock;                      /* '<Root>/lock' */
  real_T yf;                           /* '<Root>/yf' */
} ExtY_Subsystem_T;

/* Parameters (default storage) */
struct P_Subsystem_T_ {
  real_T Kinversa;                     /* Variable: Kinversa
                                        * Referenced by:
                                        *   '<S1>/Constant'
                                        *   '<S1>/Gain'
                                        */
  real_T PIDController_I;              /* Mask Parameter: PIDController_I
                                        * Referenced by: '<S38>/Integral Gain'
                                        */
  real_T PIDController_InitialConditionF;
                              /* Mask Parameter: PIDController_InitialConditionF
                               * Referenced by: '<S41>/Integrator'
                               */
  real_T PIDController_LowerIntegratorSa;
                              /* Mask Parameter: PIDController_LowerIntegratorSa
                               * Referenced by: '<S41>/Integrator'
                               */
  real_T PIDController_LowerSaturationLi;
                              /* Mask Parameter: PIDController_LowerSaturationLi
                               * Referenced by:
                               *   '<S48>/Saturation'
                               *   '<S33>/DeadZone'
                               */
  real_T PIDController_P;              /* Mask Parameter: PIDController_P
                                        * Referenced by: '<S46>/Proportional Gain'
                                        */
  real_T PIDController_UpperIntegratorSa;
                              /* Mask Parameter: PIDController_UpperIntegratorSa
                               * Referenced by: '<S41>/Integrator'
                               */
  real_T PIDController_UpperSaturationLi;
                              /* Mask Parameter: PIDController_UpperSaturationLi
                               * Referenced by:
                               *   '<S48>/Saturation'
                               *   '<S33>/DeadZone'
                               */
  real_T Constant1_Value;              /* Expression: 0
                                        * Referenced by: '<S31>/Constant1'
                                        */
  real_T UnitDelay_InitialCondition;   /* Expression: 0
                                        * Referenced by: '<S1>/Unit Delay'
                                        */
  real_T DiscreteFIRFilter_InitialStates;/* Expression: 0
                                          * Referenced by: '<S1>/Discrete FIR Filter'
                                          */
  real_T DiscreteFIRFilter_Coefficients[128];
                              /* Expression: fir1(127, 0.1/1500, hamming(127+1))
                               * Referenced by: '<S1>/Discrete FIR Filter'
                               */
  real_T Constant1_Value_a;            /* Expression: 128
                                        * Referenced by: '<S1>/Constant1'
                                        */
  real_T Integrator_gainval;           /* Computed Parameter: Integrator_gainval
                                        * Referenced by: '<S41>/Integrator'
                                        */
  real_T Quantizer_Interval;           /* Expression: 16e-3
                                        * Referenced by: '<S1>/Quantizer'
                                        */
  real_T Saturation_UpperSat;          /* Expression: 2.5
                                        * Referenced by: '<S1>/Saturation'
                                        */
  real_T Saturation_LowerSat;          /* Expression: -2.5
                                        * Referenced by: '<S1>/Saturation'
                                        */
  real_T Clamping_zero_Value;          /* Expression: 0
                                        * Referenced by: '<S31>/Clamping_zero'
                                        */
  int8_T Constant_Value;               /* Computed Parameter: Constant_Value
                                        * Referenced by: '<S31>/Constant'
                                        */
  int8_T Constant2_Value;              /* Computed Parameter: Constant2_Value
                                        * Referenced by: '<S31>/Constant2'
                                        */
  int8_T Constant3_Value;              /* Computed Parameter: Constant3_Value
                                        * Referenced by: '<S31>/Constant3'
                                        */
  int8_T Constant4_Value;              /* Computed Parameter: Constant4_Value
                                        * Referenced by: '<S31>/Constant4'
                                        */
};

/* Real-time Model Data Structure */
struct tag_RTM_Subsystem_T {
  const char_T *errorStatus;
  RTWLogInfo *rtwLogInfo;

  /*
   * Timing:
   * The following substructure contains information regarding
   * the timing information for the model.
   */
  struct {
    time_T taskTime0;
    uint32_T clockTick0;
    uint32_T clockTickH0;
    time_T stepSize0;
    struct {
      uint8_T TID[2];
    } TaskCounters;

    time_T tFinal;
    boolean_T stopRequestedFlag;
  } Timing;
};

/* Block parameters (default storage) */
extern P_Subsystem_T Subsystem_P;

/* Block signals (default storage) */
extern B_Subsystem_T Subsystem_B;

/* Block states (default storage) */
extern DW_Subsystem_T Subsystem_DW;

/* External inputs (root inport signals with default storage) */
extern ExtU_Subsystem_T Subsystem_U;

/* External outputs (root outports fed by signals with default storage) */
extern ExtY_Subsystem_T Subsystem_Y;

/* Model entry point functions */
extern void Subsystem_initialize(void);
extern void Subsystem_step(void);
extern void Subsystem_terminate(void);

/* Real-time Model object */
extern RT_MODEL_Subsystem_T *const Subsystem_M;

/*-
 * The generated code includes comments that allow you to trace directly
 * back to the appropriate location in the model.  The basic format
 * is <system>/block_name, where system is the system number (uniquely
 * assigned by Simulink) and block_name is the name of the block.
 *
 * Note that this particular code originates from a subsystem build,
 * and has its own system numbers different from the parent model.
 * Refer to the system hierarchy for this subsystem below, and use the
 * MATLAB hilite_system command to trace the generated code back
 * to the parent model.  For example,
 *
 * hilite_system('PID/Subsystem')    - opens subsystem PID/Subsystem
 * hilite_system('PID/Subsystem/Kp') - opens and selects block Kp
 *
 * Here is the system hierarchy for this model
 *
 * '<Root>' : 'PID'
 * '<S1>'   : 'PID/Subsystem'
 * '<S2>'   : 'PID/Subsystem/MATLAB Function'
 * '<S3>'   : 'PID/Subsystem/MATLAB Function1'
 * '<S4>'   : 'PID/Subsystem/PID Controller'
 * '<S5>'   : 'PID/Subsystem/PID Controller/Anti-windup'
 * '<S6>'   : 'PID/Subsystem/PID Controller/D Gain'
 * '<S7>'   : 'PID/Subsystem/PID Controller/External Derivative'
 * '<S8>'   : 'PID/Subsystem/PID Controller/Filter'
 * '<S9>'   : 'PID/Subsystem/PID Controller/Filter ICs'
 * '<S10>'  : 'PID/Subsystem/PID Controller/I Gain'
 * '<S11>'  : 'PID/Subsystem/PID Controller/Ideal P Gain'
 * '<S12>'  : 'PID/Subsystem/PID Controller/Ideal P Gain Fdbk'
 * '<S13>'  : 'PID/Subsystem/PID Controller/Integrator'
 * '<S14>'  : 'PID/Subsystem/PID Controller/Integrator ICs'
 * '<S15>'  : 'PID/Subsystem/PID Controller/N Copy'
 * '<S16>'  : 'PID/Subsystem/PID Controller/N Gain'
 * '<S17>'  : 'PID/Subsystem/PID Controller/P Copy'
 * '<S18>'  : 'PID/Subsystem/PID Controller/Parallel P Gain'
 * '<S19>'  : 'PID/Subsystem/PID Controller/Reset Signal'
 * '<S20>'  : 'PID/Subsystem/PID Controller/Saturation'
 * '<S21>'  : 'PID/Subsystem/PID Controller/Saturation Fdbk'
 * '<S22>'  : 'PID/Subsystem/PID Controller/Sum'
 * '<S23>'  : 'PID/Subsystem/PID Controller/Sum Fdbk'
 * '<S24>'  : 'PID/Subsystem/PID Controller/Tracking Mode'
 * '<S25>'  : 'PID/Subsystem/PID Controller/Tracking Mode Sum'
 * '<S26>'  : 'PID/Subsystem/PID Controller/Tsamp - Integral'
 * '<S27>'  : 'PID/Subsystem/PID Controller/Tsamp - Ngain'
 * '<S28>'  : 'PID/Subsystem/PID Controller/postSat Signal'
 * '<S29>'  : 'PID/Subsystem/PID Controller/preInt Signal'
 * '<S30>'  : 'PID/Subsystem/PID Controller/preSat Signal'
 * '<S31>'  : 'PID/Subsystem/PID Controller/Anti-windup/Disc. Clamping Parallel'
 * '<S32>'  : 'PID/Subsystem/PID Controller/Anti-windup/Disc. Clamping Parallel/Dead Zone'
 * '<S33>'  : 'PID/Subsystem/PID Controller/Anti-windup/Disc. Clamping Parallel/Dead Zone/Enabled'
 * '<S34>'  : 'PID/Subsystem/PID Controller/D Gain/Disabled'
 * '<S35>'  : 'PID/Subsystem/PID Controller/External Derivative/Disabled'
 * '<S36>'  : 'PID/Subsystem/PID Controller/Filter/Disabled'
 * '<S37>'  : 'PID/Subsystem/PID Controller/Filter ICs/Disabled'
 * '<S38>'  : 'PID/Subsystem/PID Controller/I Gain/Internal Parameters'
 * '<S39>'  : 'PID/Subsystem/PID Controller/Ideal P Gain/Passthrough'
 * '<S40>'  : 'PID/Subsystem/PID Controller/Ideal P Gain Fdbk/Disabled'
 * '<S41>'  : 'PID/Subsystem/PID Controller/Integrator/Discrete'
 * '<S42>'  : 'PID/Subsystem/PID Controller/Integrator ICs/Internal IC'
 * '<S43>'  : 'PID/Subsystem/PID Controller/N Copy/Disabled wSignal Specification'
 * '<S44>'  : 'PID/Subsystem/PID Controller/N Gain/Disabled'
 * '<S45>'  : 'PID/Subsystem/PID Controller/P Copy/Disabled'
 * '<S46>'  : 'PID/Subsystem/PID Controller/Parallel P Gain/Internal Parameters'
 * '<S47>'  : 'PID/Subsystem/PID Controller/Reset Signal/Disabled'
 * '<S48>'  : 'PID/Subsystem/PID Controller/Saturation/Enabled'
 * '<S49>'  : 'PID/Subsystem/PID Controller/Saturation Fdbk/Disabled'
 * '<S50>'  : 'PID/Subsystem/PID Controller/Sum/Sum_PI'
 * '<S51>'  : 'PID/Subsystem/PID Controller/Sum Fdbk/Disabled'
 * '<S52>'  : 'PID/Subsystem/PID Controller/Tracking Mode/Disabled'
 * '<S53>'  : 'PID/Subsystem/PID Controller/Tracking Mode Sum/Passthrough'
 * '<S54>'  : 'PID/Subsystem/PID Controller/Tsamp - Integral/TsSignalSpecification'
 * '<S55>'  : 'PID/Subsystem/PID Controller/Tsamp - Ngain/Passthrough'
 * '<S56>'  : 'PID/Subsystem/PID Controller/postSat Signal/Forward_Path'
 * '<S57>'  : 'PID/Subsystem/PID Controller/preInt Signal/Internal PreInt'
 * '<S58>'  : 'PID/Subsystem/PID Controller/preSat Signal/Forward_Path'
 */
#endif                                 /* Subsystem_h_ */
