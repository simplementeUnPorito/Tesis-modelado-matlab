% =========================================================
% SCRIPT PARA GRAFICAR FUNCIONES DE TRANSFERENCIA (CORREGIDO)
% =========================================================
clear all; clc; close all;

%% 1. CARGA DE VALORES (Modificá estos parámetros con los tuyos)

% --- Valores para la Ecuación 1 (Figura 2) ---
R1_1 = 82e3;  
R2_1 = 750e3;
R5_1 = 80e3;
C3_1 = 44e-6; 
C4_1 = 1e-9;

% --- Valores para la Ecuación 2 (Segunda imagen) ---
R1_2 = 330e3;
R2_2 = 91e3;
Rf_2 = 2e6;
Ra_2 = 40e3;
Rb_2 = 120e3;
C1_2 = 1e-9;
C2_2 = 10e-6;

% --- Valores para la Ecuación 3 (Texto) ---
gamma1 = 100;
gamma0 = 0.25;
w0     = 2*pi*10; % Frecuencia natural en rad/s

%% 2. DEFINICIÓN DE LAS FUNCIONES DE TRANSFERENCIA

% Definimos 's' como la variable de Laplace
s = tf('s');

% --- Ecuación 1 ---
Num1 = -s * (1 / (R1_1 * C4_1));
Den1 = s^2 + s * ((C3_1 + C4_1) / (C3_1 * C4_1 * R5_1)) + (1 / (R5_1 * C3_1 * C4_1)) * (1/R1_1 + 1/R2_1);
H1 = Num1 / Den1;

% --- Ecuación 2 ---
Num2 = (1 + Rb_2/Ra_2) * (s / (R1_2 * C1_2));
Den2 = s^2 + s * (1/(R1_2*C1_2) + 1/(R2_2*C1_2) + 1/(R2_2*C2_2) - Rb_2/(Ra_2*Rf_2*C1_2)) + (R1_2 + Rf_2) / (R1_2 * Rf_2 * R2_2 * C1_2 * C2_2);
H2 = Num2 / Den2;

% --- Ecuación 3 ---
Num3 = 2 * (gamma1*w0 - gamma0*w0) * s;
Den3 = s^2 + 2*gamma1*w0*s + w0^2;
H3 = Num3 / Den3;

%% 3. GRÁFICAS (Diagrama de Bode)

figure('Name', 'Respuesta en Frecuencia de los Filtros', 'NumberTitle', 'off');

% Opciones corregidas para el Diagrama de Bode
opts = bodeoptions('cstprefs');
opts.MagUnits = 'dB'; 
opts.MagScale = 'linear'; % <--- ¡ESTA LÍNEA ESTÁ CORREGIDA!
opts.FreqUnits = 'rad/s'; % Podés cambiar a 'Hz' si lo preferís

bodeplot(H1, 'b', H2, 'r', H3, 'g', opts);
grid on;

% Añadimos la leyenda para identificar cada curva
legend('Ecuación 1 (Figura 2)', 'Ecuación 2', 'Ecuación 3 (Texto)', 'Location', 'best');
title('Diagrama de Bode de las 3 Funciones de Transferencia');