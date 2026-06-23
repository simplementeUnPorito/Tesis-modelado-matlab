/*
 * Subsystem.c
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

#include "Subsystem.h"
#include "Subsystem_types.h"
#include "rtwtypes.h"
#include <string.h>
#include "rt_nonfinite.h"
#include <math.h>
#include "Subsystem_private.h"
#include <stdlib.h>
#include <stddef.h>

/* Block signals (default storage) */
B_Subsystem_T Subsystem_B;

/* Block states (default storage) */
DW_Subsystem_T Subsystem_DW;

/* External inputs (root inport signals with default storage) */
ExtU_Subsystem_T Subsystem_U;

/* External outputs (root outports fed by signals with default storage) */
ExtY_Subsystem_T Subsystem_Y;

/* Real-time model */
static RT_MODEL_Subsystem_T Subsystem_M_;
RT_MODEL_Subsystem_T *const Subsystem_M = &Subsystem_M_;

/* Forward declaration for local functions */
static void Subsystem_emxInit_real_T(emxArray_real_T_Subsystem_T **pEmxArray,
  int32_T numDimensions);
static void Subsys_emxEnsureCapacity_real_T(emxArray_real_T_Subsystem_T
  *emxArray, int32_T oldNumel);
static void Subsystem_emxFree_real_T(emxArray_real_T_Subsystem_T **pEmxArray);
static void rate_scheduler(void);

/*
 *         This function updates active task flag for each subrate.
 *         The function is called at model base rate, hence the
 *         generated code self-manages all its subrates.
 */
static void rate_scheduler(void)
{
  /* Compute which subrates run during the next base time step.  Subrates
   * are an integer multiple of the base rate counter.  Therefore, the subtask
   * counter is reset when it reaches its limit (zero means run).
   */
  (Subsystem_M->Timing.TaskCounters.TID[1])++;
  if ((Subsystem_M->Timing.TaskCounters.TID[1]) > 9) {/* Sample time: [0.00333333s, 0.0s] */
    Subsystem_M->Timing.TaskCounters.TID[1] = 0;
  }
}

static void Subsystem_emxInit_real_T(emxArray_real_T_Subsystem_T **pEmxArray,
  int32_T numDimensions)
{
  emxArray_real_T_Subsystem_T *emxArray;
  int32_T i;
  *pEmxArray = (emxArray_real_T_Subsystem_T *)malloc(sizeof
    (emxArray_real_T_Subsystem_T));
  emxArray = *pEmxArray;
  emxArray->data = (real_T *)NULL;
  emxArray->numDimensions = numDimensions;
  emxArray->size = (int32_T *)malloc(sizeof(int32_T) * (uint32_T)numDimensions);
  emxArray->allocatedSize = 0;
  emxArray->canFreeData = true;
  for (i = 0; i < numDimensions; i++) {
    emxArray->size[i] = 0;
  }
}

static void Subsys_emxEnsureCapacity_real_T(emxArray_real_T_Subsystem_T
  *emxArray, int32_T oldNumel)
{
  int32_T i;
  int32_T newNumel;
  void *newData;
  if (oldNumel < 0) {
    oldNumel = 0;
  }

  newNumel = 1;
  for (i = 0; i < emxArray->numDimensions; i++) {
    newNumel *= emxArray->size[i];
  }

  if (newNumel > emxArray->allocatedSize) {
    i = emxArray->allocatedSize;
    if (i < 16) {
      i = 16;
    }

    while (i < newNumel) {
      if (i > 1073741823) {
        i = MAX_int32_T;
      } else {
        i <<= 1;
      }
    }

    newData = malloc((uint32_T)i * sizeof(real_T));
    if (emxArray->data != NULL) {
      memcpy(newData, emxArray->data, sizeof(real_T) * (uint32_T)oldNumel);
      if (emxArray->canFreeData) {
        free(emxArray->data);
      }
    }

    emxArray->data = (real_T *)newData;
    emxArray->allocatedSize = i;
    emxArray->canFreeData = true;
  }
}

real_T rt_roundd_snf(real_T u)
{
  real_T y;
  if (fabs(u) < 4.503599627370496E+15) {
    if (u >= 0.5) {
      y = floor(u + 0.5);
    } else if (u > -0.5) {
      y = u * 0.0;
    } else {
      y = ceil(u - 0.5);
    }
  } else {
    y = u;
  }

  return y;
}

static void Subsystem_emxFree_real_T(emxArray_real_T_Subsystem_T **pEmxArray)
{
  if (*pEmxArray != (emxArray_real_T_Subsystem_T *)NULL) {
    if (((*pEmxArray)->data != (real_T *)NULL) && (*pEmxArray)->canFreeData) {
      free((*pEmxArray)->data);
    }

    free((*pEmxArray)->size);
    free(*pEmxArray);
    *pEmxArray = (emxArray_real_T_Subsystem_T *)NULL;
  }
}

/* Model step function */
void Subsystem_step(void)
{
  real_T buf;
  real_T err_span;
  real_T rtb_DeadZone;
  int32_T b_last;
  int32_T idx;
  int32_T last;
  int8_T tmp;
  int8_T tmp_0;
  boolean_T exitg1;
  boolean_T rtb_lock;

  /* Outport: '<Root>/u' incorporates:
   *  UnitDelay: '<S1>/Unit Delay'
   */
  Subsystem_Y.u = Subsystem_DW.UnitDelay_DSTATE;

  /* DiscreteFir: '<S1>/Discrete FIR Filter' incorporates:
   *  Inport: '<Root>/y'
   */
  err_span = Subsystem_U.y * Subsystem_P.DiscreteFIRFilter_Coefficients[0];
  idx = 1;
  for (last = Subsystem_DW.DiscreteFIRFilter_circBuf; last < 127; last++) {
    err_span += Subsystem_DW.DiscreteFIRFilter_states[last] *
      Subsystem_P.DiscreteFIRFilter_Coefficients[idx];
    idx++;
  }

  for (last = 0; last < Subsystem_DW.DiscreteFIRFilter_circBuf; last++) {
    err_span += Subsystem_DW.DiscreteFIRFilter_states[last] *
      Subsystem_P.DiscreteFIRFilter_Coefficients[idx];
    idx++;
  }

  /* Outport: '<Root>/yf' incorporates:
   *  DiscreteFir: '<S1>/Discrete FIR Filter'
   */
  Subsystem_Y.yf = err_span;

  /* MATLAB Function: '<S1>/MATLAB Function1' incorporates:
   *  Constant: '<S1>/Constant'
   *  Constant: '<S1>/Constant1'
   *  Inport: '<Root>/start'
   *  Outport: '<Root>/yf'
   */
  if (!Subsystem_DW.buf_not_empty) {
    idx = Subsystem_DW.buf->size[0] * Subsystem_DW.buf->size[1];
    Subsystem_DW.buf->size[0] = 1;
    last = (int32_T)Subsystem_P.Constant1_Value_a;
    Subsystem_DW.buf->size[1] = (int32_T)Subsystem_P.Constant1_Value_a;
    Subsys_emxEnsureCapacity_real_T(Subsystem_DW.buf, idx);
    if (last - 1 >= 0) {
      memset(&Subsystem_DW.buf->data[0], 0, (uint32_T)last * sizeof(real_T));
    }

    Subsystem_DW.buf_not_empty = (Subsystem_DW.buf->size[1] != 0);
    Subsystem_DW.idx = 1.0;
    Subsystem_DW.count = 0.0;
    Subsystem_DW.locked = false;
  }

  if (Subsystem_U.start) {
    last = Subsystem_DW.buf->size[1];
    idx = Subsystem_DW.buf->size[0] * Subsystem_DW.buf->size[1];
    Subsystem_DW.buf->size[0] = 1;
    Subsystem_DW.buf->size[1] = last;
    Subsys_emxEnsureCapacity_real_T(Subsystem_DW.buf, idx);
    if (last - 1 >= 0) {
      memset(&Subsystem_DW.buf->data[0], 0, (uint32_T)last * sizeof(real_T));
    }

    Subsystem_DW.idx = 1.0;
    Subsystem_DW.count = 0.0;
    Subsystem_DW.locked = false;
    rtb_lock = false;
  } else {
    Subsystem_DW.buf->data[(int32_T)Subsystem_DW.idx - 1] = Subsystem_Y.yf;
    Subsystem_DW.idx++;
    if (Subsystem_DW.idx > Subsystem_P.Constant1_Value_a) {
      Subsystem_DW.idx = 1.0;
    }

    if (Subsystem_DW.count < Subsystem_P.Constant1_Value_a) {
      Subsystem_DW.count++;
    }

    if (Subsystem_DW.count < Subsystem_P.Constant1_Value_a) {
      rtb_lock = false;
    } else {
      last = Subsystem_DW.buf->size[1];
      if (Subsystem_DW.buf->size[1] <= 2) {
        if (Subsystem_DW.buf->size[1] == 1) {
          err_span = Subsystem_DW.buf->data[0];
        } else {
          err_span = Subsystem_DW.buf->data[Subsystem_DW.buf->size[1] - 1];
          if ((Subsystem_DW.buf->data[0] < err_span) || (rtIsNaN
               (Subsystem_DW.buf->data[0]) && (!rtIsNaN(err_span)))) {
          } else {
            err_span = Subsystem_DW.buf->data[0];
          }
        }
      } else {
        if (!rtIsNaN(Subsystem_DW.buf->data[0])) {
          idx = 1;
        } else {
          idx = 0;
          b_last = 2;
          exitg1 = false;
          while ((!exitg1) && (b_last <= last)) {
            if (!rtIsNaN(Subsystem_DW.buf->data[b_last - 1])) {
              idx = b_last;
              exitg1 = true;
            } else {
              b_last++;
            }
          }
        }

        if (idx == 0) {
          err_span = Subsystem_DW.buf->data[0];
        } else {
          err_span = Subsystem_DW.buf->data[idx - 1];
          for (b_last = idx + 1; b_last <= last; b_last++) {
            buf = Subsystem_DW.buf->data[b_last - 1];
            if (err_span < buf) {
              err_span = buf;
            }
          }
        }
      }

      b_last = Subsystem_DW.buf->size[1];
      if (Subsystem_DW.buf->size[1] <= 2) {
        if (Subsystem_DW.buf->size[1] == 1) {
          rtb_DeadZone = Subsystem_DW.buf->data[0];
        } else {
          rtb_DeadZone = Subsystem_DW.buf->data[Subsystem_DW.buf->size[1] - 1];
          if ((Subsystem_DW.buf->data[0] > rtb_DeadZone) || (rtIsNaN
               (Subsystem_DW.buf->data[0]) && (!rtIsNaN(rtb_DeadZone)))) {
          } else {
            rtb_DeadZone = Subsystem_DW.buf->data[0];
          }
        }
      } else {
        if (!rtIsNaN(Subsystem_DW.buf->data[0])) {
          last = 1;
        } else {
          last = 0;
          idx = 2;
          exitg1 = false;
          while ((!exitg1) && (idx <= b_last)) {
            if (!rtIsNaN(Subsystem_DW.buf->data[idx - 1])) {
              last = idx;
              exitg1 = true;
            } else {
              idx++;
            }
          }
        }

        if (last == 0) {
          rtb_DeadZone = Subsystem_DW.buf->data[0];
        } else {
          rtb_DeadZone = Subsystem_DW.buf->data[last - 1];
          for (idx = last + 1; idx <= b_last; idx++) {
            buf = Subsystem_DW.buf->data[idx - 1];
            if (rtb_DeadZone > buf) {
              rtb_DeadZone = buf;
            }
          }
        }
      }

      err_span -= rtb_DeadZone;
      if (!Subsystem_DW.locked) {
        Subsystem_DW.locked = (err_span <= fabs(0.016 * Subsystem_P.Kinversa) *
          1.1);
      } else {
        Subsystem_DW.locked = !(err_span > fabs(0.016 * Subsystem_P.Kinversa) *
          1.1 * 2.0);
      }

      rtb_lock = Subsystem_DW.locked;
    }
  }

  /* End of MATLAB Function: '<S1>/MATLAB Function1' */

  /* Sum: '<S1>/Sum' incorporates:
   *  Inport: '<Root>/Vref'
   *  Outport: '<Root>/yf'
   */
  err_span = Subsystem_U.Vref - Subsystem_Y.yf;

  /* Outport: '<Root>/error' */
  Subsystem_Y.error = err_span;

  /* Outport: '<Root>/lock' */
  Subsystem_Y.lock = rtb_lock;
  if (Subsystem_M->Timing.TaskCounters.TID[1] == 0) {
    /* Gain: '<S1>/Gain' incorporates:
     *  Inport: '<Root>/Vref'
     */
    Subsystem_B.Gain = 0.6 / Subsystem_P.Kinversa * Subsystem_U.Vref;
  }

  /* Sum: '<S50>/Sum' incorporates:
   *  DiscreteIntegrator: '<S41>/Integrator'
   *  Gain: '<S46>/Proportional Gain'
   */
  rtb_DeadZone = Subsystem_P.PIDController_P * err_span +
    Subsystem_DW.Integrator_DSTATE;

  /* Saturate: '<S48>/Saturation' incorporates:
   *  DeadZone: '<S33>/DeadZone'
   */
  if (rtb_DeadZone > Subsystem_P.PIDController_UpperSaturationLi) {
    buf = Subsystem_P.PIDController_UpperSaturationLi;
    rtb_DeadZone -= Subsystem_P.PIDController_UpperSaturationLi;
  } else {
    if (rtb_DeadZone < Subsystem_P.PIDController_LowerSaturationLi) {
      buf = Subsystem_P.PIDController_LowerSaturationLi;
    } else {
      buf = rtb_DeadZone;
    }

    if (rtb_DeadZone >= Subsystem_P.PIDController_LowerSaturationLi) {
      rtb_DeadZone = 0.0;
    } else {
      rtb_DeadZone -= Subsystem_P.PIDController_LowerSaturationLi;
    }
  }

  /* End of Saturate: '<S48>/Saturation' */

  /* Gain: '<S38>/Integral Gain' */
  err_span *= Subsystem_P.PIDController_I;

  /* MATLAB Function: '<S1>/MATLAB Function' */
  if (!rtb_lock) {
    /* Quantizer: '<S1>/Quantizer' incorporates:
     *  Sum: '<S1>/Sum1'
     */
    buf = rt_roundd_snf((Subsystem_B.Gain - buf) /
                        Subsystem_P.Quantizer_Interval) *
      Subsystem_P.Quantizer_Interval;

    /* Saturate: '<S1>/Saturation' */
    if (buf > Subsystem_P.Saturation_UpperSat) {
      /* Update for UnitDelay: '<S1>/Unit Delay' */
      Subsystem_DW.UnitDelay_DSTATE = Subsystem_P.Saturation_UpperSat;
    } else if (buf < Subsystem_P.Saturation_LowerSat) {
      /* Update for UnitDelay: '<S1>/Unit Delay' */
      Subsystem_DW.UnitDelay_DSTATE = Subsystem_P.Saturation_LowerSat;
    } else {
      /* Update for UnitDelay: '<S1>/Unit Delay' */
      Subsystem_DW.UnitDelay_DSTATE = buf;
    }

    /* End of Saturate: '<S1>/Saturation' */
  }

  /* End of MATLAB Function: '<S1>/MATLAB Function' */

  /* Update for DiscreteFir: '<S1>/Discrete FIR Filter' incorporates:
   *  Inport: '<Root>/y'
   */
  /* Update circular buffer index */
  Subsystem_DW.DiscreteFIRFilter_circBuf--;
  if (Subsystem_DW.DiscreteFIRFilter_circBuf < 0) {
    Subsystem_DW.DiscreteFIRFilter_circBuf = 126;
  }

  /* Update circular buffer */
  Subsystem_DW.DiscreteFIRFilter_states[Subsystem_DW.DiscreteFIRFilter_circBuf] =
    Subsystem_U.y;

  /* End of Update for DiscreteFir: '<S1>/Discrete FIR Filter' */

  /* Switch: '<S31>/Switch1' incorporates:
   *  Constant: '<S31>/Clamping_zero'
   *  Constant: '<S31>/Constant'
   *  Constant: '<S31>/Constant2'
   *  RelationalOperator: '<S31>/fix for DT propagation issue'
   */
  if (rtb_DeadZone > Subsystem_P.Clamping_zero_Value) {
    tmp = Subsystem_P.Constant_Value;
  } else {
    tmp = Subsystem_P.Constant2_Value;
  }

  /* Switch: '<S31>/Switch2' incorporates:
   *  Constant: '<S31>/Clamping_zero'
   *  Constant: '<S31>/Constant3'
   *  Constant: '<S31>/Constant4'
   *  RelationalOperator: '<S31>/fix for DT propagation issue1'
   */
  if (err_span > Subsystem_P.Clamping_zero_Value) {
    tmp_0 = Subsystem_P.Constant3_Value;
  } else {
    tmp_0 = Subsystem_P.Constant4_Value;
  }

  /* Switch: '<S31>/Switch' incorporates:
   *  Constant: '<S31>/Clamping_zero'
   *  Constant: '<S31>/Constant1'
   *  Logic: '<S31>/AND3'
   *  RelationalOperator: '<S31>/Equal1'
   *  RelationalOperator: '<S31>/Relational Operator'
   *  Switch: '<S31>/Switch1'
   *  Switch: '<S31>/Switch2'
   */
  if ((Subsystem_P.Clamping_zero_Value != rtb_DeadZone) && (tmp == tmp_0)) {
    err_span = Subsystem_P.Constant1_Value;
  }

  /* Update for DiscreteIntegrator: '<S41>/Integrator' incorporates:
   *  Switch: '<S31>/Switch'
   */
  Subsystem_DW.Integrator_DSTATE += Subsystem_P.Integrator_gainval * err_span;
  if (Subsystem_DW.Integrator_DSTATE >
      Subsystem_P.PIDController_UpperIntegratorSa) {
    Subsystem_DW.Integrator_DSTATE = Subsystem_P.PIDController_UpperIntegratorSa;
  } else if (Subsystem_DW.Integrator_DSTATE <
             Subsystem_P.PIDController_LowerIntegratorSa) {
    Subsystem_DW.Integrator_DSTATE = Subsystem_P.PIDController_LowerIntegratorSa;
  }

  /* End of Update for DiscreteIntegrator: '<S41>/Integrator' */

  /* Matfile logging */
  rt_UpdateTXYLogVars(Subsystem_M->rtwLogInfo, (&Subsystem_M->Timing.taskTime0));

  /* signal main to stop simulation */
  {                                    /* Sample time: [0.000333333s, 0.0s] */
    if ((rtmGetTFinal(Subsystem_M)!=-1) &&
        !((rtmGetTFinal(Subsystem_M)-Subsystem_M->Timing.taskTime0) >
          Subsystem_M->Timing.taskTime0 * (DBL_EPSILON))) {
      rtmSetErrorStatus(Subsystem_M, "Simulation finished");
    }
  }

  /* Update absolute time for base rate */
  /* The "clockTick0" counts the number of times the code of this task has
   * been executed. The absolute time is the multiplication of "clockTick0"
   * and "Timing.stepSize0". Size of "clockTick0" ensures timer will not
   * overflow during the application lifespan selected.
   * Timer of this task consists of two 32 bit unsigned integers.
   * The two integers represent the low bits Timing.clockTick0 and the high bits
   * Timing.clockTickH0. When the low bit overflows to 0, the high bits increment.
   */
  if (!(++Subsystem_M->Timing.clockTick0)) {
    ++Subsystem_M->Timing.clockTickH0;
  }

  Subsystem_M->Timing.taskTime0 = Subsystem_M->Timing.clockTick0 *
    Subsystem_M->Timing.stepSize0 + Subsystem_M->Timing.clockTickH0 *
    Subsystem_M->Timing.stepSize0 * 4294967296.0;
  rate_scheduler();
}

/* Model initialize function */
void Subsystem_initialize(void)
{
  /* Registration code */

  /* initialize real-time model */
  (void) memset((void *)Subsystem_M, 0,
                sizeof(RT_MODEL_Subsystem_T));
  rtmSetTFinal(Subsystem_M, 1.0);
  Subsystem_M->Timing.stepSize0 = 0.00033333333333333332;

  /* Setup for data logging */
  {
    static RTWLogInfo rt_DataLoggingInfo;
    rt_DataLoggingInfo.loggingInterval = (NULL);
    Subsystem_M->rtwLogInfo = &rt_DataLoggingInfo;
  }

  /* Setup for data logging */
  {
    rtliSetLogXSignalInfo(Subsystem_M->rtwLogInfo, (NULL));
    rtliSetLogXSignalPtrs(Subsystem_M->rtwLogInfo, (NULL));
    rtliSetLogT(Subsystem_M->rtwLogInfo, "tout");
    rtliSetLogX(Subsystem_M->rtwLogInfo, "");
    rtliSetLogXFinal(Subsystem_M->rtwLogInfo, "");
    rtliSetLogVarNameModifier(Subsystem_M->rtwLogInfo, "rt_");
    rtliSetLogFormat(Subsystem_M->rtwLogInfo, 4);
    rtliSetLogMaxRows(Subsystem_M->rtwLogInfo, 0);
    rtliSetLogDecimation(Subsystem_M->rtwLogInfo, 1);
    rtliSetLogY(Subsystem_M->rtwLogInfo, "");
    rtliSetLogYSignalInfo(Subsystem_M->rtwLogInfo, (NULL));
    rtliSetLogYSignalPtrs(Subsystem_M->rtwLogInfo, (NULL));
  }

  /* block I/O */
  (void) memset(((void *) &Subsystem_B), 0,
                sizeof(B_Subsystem_T));

  /* states (dwork) */
  (void) memset((void *)&Subsystem_DW, 0,
                sizeof(DW_Subsystem_T));

  /* external inputs */
  (void)memset(&Subsystem_U, 0, sizeof(ExtU_Subsystem_T));

  /* external outputs */
  (void)memset(&Subsystem_Y, 0, sizeof(ExtY_Subsystem_T));

  /* Matfile logging */
  rt_StartDataLoggingWithStartTime(Subsystem_M->rtwLogInfo, 0.0, rtmGetTFinal
    (Subsystem_M), Subsystem_M->Timing.stepSize0, (&rtmGetErrorStatus
    (Subsystem_M)));

  {
    int32_T i;

    /* InitializeConditions for UnitDelay: '<S1>/Unit Delay' */
    Subsystem_DW.UnitDelay_DSTATE = Subsystem_P.UnitDelay_InitialCondition;

    /* InitializeConditions for DiscreteFir: '<S1>/Discrete FIR Filter' */
    Subsystem_DW.DiscreteFIRFilter_circBuf = 0;
    for (i = 0; i < 127; i++) {
      Subsystem_DW.DiscreteFIRFilter_states[i] =
        Subsystem_P.DiscreteFIRFilter_InitialStates;
    }

    /* End of InitializeConditions for DiscreteFir: '<S1>/Discrete FIR Filter' */

    /* InitializeConditions for DiscreteIntegrator: '<S41>/Integrator' */
    Subsystem_DW.Integrator_DSTATE = Subsystem_P.PIDController_InitialConditionF;
    Subsystem_emxInit_real_T(&Subsystem_DW.buf, 2);

    /* SystemInitialize for MATLAB Function: '<S1>/MATLAB Function1' */
    Subsystem_DW.buf_not_empty = false;
  }
}

/* Model terminate function */
void Subsystem_terminate(void)
{
  Subsystem_emxFree_real_T(&Subsystem_DW.buf);
}
