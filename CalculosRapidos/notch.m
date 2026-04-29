close all; clear; clc;
% Parámetros del Filtro
Fs = 1020;              
f_notch = 50;           
bw =10;                 
atenuacion_db = 30;     

% Definición de bandas
f1 = f_notch - bw;
f2 = f_notch - 0.5;
f3 = f_notch + 0.5;
f4 = f_notch + bw;

% Tolerancias (Rizado)
dev = [(10^(0.1/20)-1)/(10^(0.1/20)+1)  10^(-atenuacion_db/20)  (10^(0.1/20)-1)/(10^(0.1/20)+1)];

% Estimación de orden
[n, fo, ao, w] = firpmord([f1 f2 f3 f4], [1 0 1], dev, Fs);

% --- CORRECCIÓN CRÍTICA ---
% Si el orden es muy bajo o impar, firpm puede fallar en filtros Notch.
if n < 40
    n = 40; % Forzamos un mínimo para asegurar que la muesca exista
end
if mod(n,2) ~= 0
    n = n + 1; % Aseguramos que sea par para un filtro Simétrico Tipo I
end

% Generación de coeficientes
try
    % firls es mucho más estable para bandas de transición estrechas
    b = firls(n, fo, ao, w);
catch
    % Si falla con firpmord, usamos un diseño por ventana que es más robusto
    disp('firpm falló, usando diseño por ventana (fir1)...');
    b = fir1(n, [f2 f3]/(Fs/2), 'stop');
end

% --- Generación del archivo .h ---
fileID = fopen('coeficientes_notch.h', 'w');
fprintf(fileID, '/* Generado para Atenuacion: %d dB - Orden: %d */\n', atenuacion_db, n);
fprintf(fileID, '#ifndef COEFICIENTES_NOTCH_H\n#define COEFICIENTES_NOTCH_H\n\n');
fprintf(fileID, '#define FILTER_ORDER %d\n', n);
fprintf(fileID, 'double filter_coeffs[%d] = {\n', n + 1);
for i = 1:length(b)
    if i == length(b), fprintf(fileID, '    %.15f\n', b(i));
    else, fprintf(fileID, '    %.15f,\n', b(i)); end
end
fprintf(fileID, '};\n\n#endif\n');
fclose(fileID);

% --- Gráfico de Bode ---
[h, f] = freqz(b, 1, 1024*8, Fs);
figure('Color', 'w');
subplot(2,1,1);
plot(f, 20*log10(abs(h)), 'LineWidth', 1.5); hold on;
grid on; line([0 Fs/2], [-atenuacion_db -atenuacion_db], 'Color', 'r', 'LineStyle', '--');
title(['Filtro FIR Notch (Orden ', num2str(n), ')']);
ylabel('Magnitud (dB)'); axis([f_notch-20 f_notch+20 -atenuacion_db-10 5]);

subplot(2,1,2);
plot(f, unwrap(angle(h)) * 180/pi, 'LineWidth', 1.5, 'Color', [0.85 0.32 0.1]);
grid on; ylabel('Fase (grados)'); xlabel('Frecuencia (Hz)');
axis([f_notch-20 f_notch+20 -180*n/10 100]);