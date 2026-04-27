% Análisis de filtro Pasa-Bandas VCVS
% clear all
% close all
% clc

% 1. Definir parámetros del componente (Ajustar a tus valores reales)
R1 = 150e3; Ra = 10e3; Rb = 150e3; % Ejemplos
C1 = 4.7e-6; C2 = 0.22e-6; 
Rf = 47e3; R2 = 6.8e3; 


% 3. Construir la función de transferencia H(s)
s = tf('s');

% Numerador
num = ((1 + (Rb/Ra)) / (R1 * C1)) * s;

% Denominador: s^2 + (2*zeta*w0)*s + w0^2
% El término lineal (2*zeta*w0) es: (1/R1C1 + 1/R2C1 + 1/R2C2 - (Rb*R1)/(Ra*Rf*C1))
den = s^2 + ((1/(R1*C1)) + (1/(R2*C1)) + (1/(R2*C2)) - (Rb)/(Ra*Rf*C1))*s + (R1 + Rf) / (R1 * Rf * R2 * C1 * C2);

A = 1.2;
sys = (A-(91/3)*num/den)/A;

f0 = 10;
wn = 2*pi*f0;
flow = 1;
wlow = 2*pi*flow;
zeta_des = wn/(2*wlow);


H = 1- 2*(zeta_des - 0.25)*wn*s/(s^2+2*zeta_des*wn*s+wn^2);


% 4. Graficar Bode
figure;
bode(sys);
hold on;
bode(H);
grid on;
title('Respuesta en Frecuencia: Filtro Pasa-Bandas VCVS');

