clear; close all; clc;

%% Parámetros del Geófono SM-24 (10 Hz)
fn = 10;
wn = 2*pi*fn;
h0 = 0.25;
G = 28.8;

%% Objetivo compensación
fLow = 0.01;
wLow = 2*pi*fLow;
h1 = wn/(2*wLow);
K = h1/h0;

fprintf('h1 = %.2f\n', h1);

s = tf('s');

%% --- MODELO BASE (UNO SOLO) ---
Hv = (G*s^2) / (s^2 + 2*h0*wn*s + wn^2);   % salida vs velocidad
Ha = Hv / s;                             % misma salida vs aceleración

%% --- COMPENSADOR ---
Hcomp = 1 - (2*(h1-h0)*wn*s) / (s^2 + 2*h1*wn*s + wn^2);

%% --- SISTEMAS TOTALES ---
Hv_comp = K * Hv * Hcomp;
Ha_comp = Hv_comp / s;   % coherente: SIEMPRE desde Hv

%% Frecuencia
w = logspace(log10(wLow/10), log10(wn*10), 1000);

%% BODE MAGNITUD
[mag_v, ~] = bode(Hv, w);
[mag_vc, ~] = bode(Hv_comp, w);

[mag_a, ~] = bode(Ha, w);
[mag_ac, ~] = bode(Ha_comp, w);

f = w/(2*pi);

%% --- GRAFICOS ---
figure;

subplot(2,1,1);
loglog(f, squeeze(mag_v), 'r--', 'LineWidth',1.2); hold on;
loglog(f, squeeze(mag_vc), 'b', 'LineWidth',1.5);
title('Salida vs VELOCIDAD');
ylabel('V / (m/s)');
legend('Original','Compensado');
grid on;

subplot(2,1,2);
loglog(f, squeeze(mag_a), 'r--', 'LineWidth',1.2); hold on;
loglog(f, squeeze(mag_ac), 'g', 'LineWidth',1.5);
title('Salida vs ACELERACION');
ylabel('V / (m/s^2)');
xlabel('Frecuencia (Hz)');
legend('Original','Compensado');
grid on;

%% --- CHECK EN fLow ---
mag_flow = abs(freqresp(Hv_comp, wLow));
fprintf('Sensibilidad en %.2f Hz: %.2f V/(m/s)\n', fLow, mag_flow);