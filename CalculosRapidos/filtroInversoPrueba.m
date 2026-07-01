%% filtroInversoPrueba.m
% Lee:
% C:\Users\elias\Downloads\captures\002_start_2\geo1\filt.csv
%
% Flujo:
%   1) Lee Geo1/filt.csv
%   2) Discretiza model con Tustin
%   3) Aplica inverso discreto 1/modeld con filter()
%   4) Aplica high-pass FIR final con filtfilt
%   5) Aplica low-pass FIR final con filtfilt
%
% Importante:
%   - El high-pass NO se invierte.
%   - El low-pass NO se invierte.
%   - Ambos son filtros finales de limpieza.
%   - Los gráficos se normalizan a pico 1.
%   - El eje de frecuencia se grafica en escala logarítmica.

clearvars -except model
clc
close all

%% ================== CONFIGURACIÓN ==================

archivoCsv = "C:\Users\elias\Downloads\captures\002_start_2\geo1\filt.csv";

quitarMedia = true;

% Si model no existe en el workspace, usar modelo simplificado
usarModeloSimplificadoSiNoExiste = true;

% High-pass final
aplicarHighpassFinal = true;

% Frecuencia de corte high-pass en Hz
fcHighpassHz = 0.1;

% Orden grande FIR high-pass
ordenHighpassFIR = 3000;

% Low-pass final
aplicarLowpassFinal = true;

% Frecuencia de corte low-pass en Hz
fcLowpassHz = 200;

% Orden FIR low-pass
ordenLowpassFIR = 1000;

% Para graficar espectro logarítmico
fMinPlot = 0.01;     % Hz, no usar 0 en escala log
fMaxPlot = 1500;     % Hz, aprox fs/2

%% ================== LEER CSV ==================

T = readtable(archivoCsv, "VariableNamingRule", "preserve");

nombres = string(T.Properties.VariableNames);
nombresLower = lower(nombres);

idxTime = find(nombresLower == "time_s" | nombresLower == "time" | nombresLower == "t", 1);
idxValue = find(nombresLower == "value_v" | nombresLower == "value" | nombresLower == "valor" | nombresLower == "v", 1);

if isempty(idxTime)
    error("No encontré columna de tiempo. Debe llamarse time_s, time o t.");
end

if isempty(idxValue)
    error("No encontré columna de señal. Debe llamarse value_v, value, valor o v.");
end

timeCol = nombres(idxTime);
valueCol = nombres(idxValue);

t = double(T.(timeCol));
x = double(T.(valueCol));

t = t(:);
x = x(:);

% Ordenar por tiempo
[t, idx] = sort(t);
x = x(idx);

% Frecuencia de muestreo
Ts = median(diff(t), "omitnan");
fs = 1 / Ts;

fprintf("Archivo leído correctamente.\n");
fprintf("Muestras: %d\n", numel(x));
fprintf("Ts = %.12f s\n", Ts);
fprintf("fs = %.6f Hz\n", fs);

if quitarMedia
    x = x - mean(x, "omitnan");
end

%% ================== MODELO CONTINUO ==================

s = tf('s');

if ~exist("model", "var")
    if usarModeloSimplificadoSiNoExiste
        model = (29.34*s) / (0.0002432*s^2 + 29.24*s + 1);
        disp("No había model en workspace. Se usó el modelo simplificado.");
    else
        error("La variable model no está cargada en el workspace.");
    end
end

disp("Modelo continuo usado:");
model

%% ================== DISCRETIZAR CON TUSTIN ==================

modeld = c2d(model, Ts, "tustin");

disp("Modelo discreto por Tustin:");
modeld

%% ================== FILTRO INVERSO DISCRETO ==================

filtroInversoD = 1 / modeld;

disp("Filtro inverso discreto 1/modeld:");
filtroInversoD

[bInv, aInv] = tfdata(filtroInversoD, "v");

% Normalizar coeficientes por seguridad
bInv = bInv / aInv(1);
aInv = aInv / aInv(1);

%% ================== APLICAR INVERSO TUSTIN ==================

% El inverso se aplica con filter().
% No se usa lsim.
% No se usa minreal.
y_inv_sin_filtros_finales = filter(bInv, aInv, x);
y_inv_sin_filtros_finales = y_inv_sin_filtros_finales(:);

disp("Filtro inverso aplicado con filter(bInv, aInv, x).");

%% ================== FILTROS FINALES: HIGH-PASS Y LOW-PASS ==================

% Los filtros finales NO se invierten.
% Solo limpian la salida luego del inverso.

y_final = y_inv_sin_filtros_finales;

%% -------- HIGH-PASS FINAL --------

if aplicarHighpassFinal

    if fcHighpassHz <= 0
        error("fcHighpassHz debe ser mayor que 0.");
    end

    if fcHighpassHz >= fs/2
        error("fcHighpassHz debe ser menor que fs/2.");
    end

    % FIR high-pass: usar orden par
    if mod(ordenHighpassFIR, 2) == 1
        ordenHighpassFIR = ordenHighpassFIR + 1;
    end

    WnHP = fcHighpassHz / (fs/2);

    bHP = fir1(ordenHighpassFIR, WnHP, "high", ...
        hamming(ordenHighpassFIR + 1), "scale");

    aHP = 1;

    y_final = aplicarFiltfiltConPadding(y_final, bHP, aHP, ordenHighpassFIR);

    fprintf("High-pass FIR final aplicado con filtfilt.\n");
    fprintf("fcHighpassHz = %.6f Hz\n", fcHighpassHz);
    fprintf("Orden FIR high-pass = %d\n", ordenHighpassFIR);

else

    bHP = 1;
    aHP = 1;

    disp("High-pass final desactivado.");

end

%% -------- LOW-PASS FINAL --------

if aplicarLowpassFinal

    if fcLowpassHz <= 0
        error("fcLowpassHz debe ser mayor que 0.");
    end

    if fcLowpassHz >= fs/2
        error("fcLowpassHz debe ser menor que fs/2.");
    end

    % FIR low-pass: usar orden par
    if mod(ordenLowpassFIR, 2) == 1
        ordenLowpassFIR = ordenLowpassFIR + 1;
    end

    WnLP = fcLowpassHz / (fs/2);

    bLP = fir1(ordenLowpassFIR, WnLP, "low", ...
        hamming(ordenLowpassFIR + 1), "scale");

    aLP = 1;

    y_final = aplicarFiltfiltConPadding(y_final, bLP, aLP, ordenLowpassFIR);

    fprintf("Low-pass FIR final aplicado con filtfilt.\n");
    fprintf("fcLowpassHz = %.6f Hz\n", fcLowpassHz);
    fprintf("Orden FIR low-pass = %d\n", ordenLowpassFIR);

else

    bLP = 1;
    aLP = 1;

    disp("Low-pass final desactivado.");

end

% Salida definitiva
y_inv = y_final(:);

%% ================== ARREGLAR DIMENSIONES ==================

t = t(:);
x = x(:);
y_inv_sin_filtros_finales = y_inv_sin_filtros_finales(:);
y_inv = y_inv(:);

Nmin = min([numel(t), numel(x), numel(y_inv_sin_filtros_finales), numel(y_inv)]);

t = t(1:Nmin);
x = x(1:Nmin);
y_inv_sin_filtros_finales = y_inv_sin_filtros_finales(1:Nmin);
y_inv = y_inv(1:Nmin);

%% ================== NORMALIZAR PARA GRÁFICOS ==================

x_norm = x / (max(abs(x)) + eps);

y_inv_sin_filtros_norm = ...
    y_inv_sin_filtros_finales / (max(abs(y_inv_sin_filtros_finales)) + eps);

y_inv_norm = y_inv / (max(abs(y_inv)) + eps);

%% ================== GUARDAR RESULTADOS ==================

resultado = table(t, x, y_inv_sin_filtros_finales, y_inv, ...
    x_norm, y_inv_sin_filtros_norm, y_inv_norm, ...
    'VariableNames', {'time_s', ...
                      'value_v_original', ...
                      'value_v_inversa_tustin_sin_filtros_finales', ...
                      'value_v_inversa_tustin_con_filtros_finales', ...
                      'value_original_normalizada', ...
                      'value_inversa_sin_filtros_finales_normalizada', ...
                      'value_inversa_con_filtros_finales_normalizada'});

carpetaSalida = fileparts(archivoCsv);

archivoSalidaCsv = fullfile(carpetaSalida, "filt_geo1_inverso_tustin_hp_lp.csv");
archivoSalidaMat = fullfile(carpetaSalida, "filt_geo1_inverso_tustin_hp_lp.mat");

writetable(resultado, archivoSalidaCsv);

save(archivoSalidaMat, ...
    "t", "x", "y_inv_sin_filtros_finales", "y_inv", ...
    "x_norm", "y_inv_sin_filtros_norm", "y_inv_norm", ...
    "fs", "Ts", "model", "modeld", "filtroInversoD", ...
    "bInv", "aInv", "bHP", "aHP", "bLP", "aLP", ...
    "fcHighpassHz", "ordenHighpassFIR", ...
    "fcLowpassHz", "ordenLowpassFIR", ...
    "resultado");

fprintf("\nResultado CSV guardado en:\n%s\n", archivoSalidaCsv);
fprintf("Resultado MAT guardado en:\n%s\n", archivoSalidaMat);

%% ================== GRÁFICO SEÑAL REAL ==================

figure;
plot(t, x, 'DisplayName', 'Entrada original');
hold on;
plot(t, y_inv_sin_filtros_finales, ...
    'DisplayName', 'Inverso Tustin sin filtros finales');
plot(t, y_inv, ...
    'DisplayName', 'Inverso Tustin + HP/LP finales');
grid on;
xlabel('Tiempo [s]');
ylabel('Amplitud real');
title('Geo1 - Entrada vs inverso Tustin con HP/LP finales');
legend('Location', 'best');

%% ================== GRÁFICO NORMALIZADO ==================

figure;
plot(t, x_norm, 'DisplayName', 'Entrada original normalizada');
hold on;
plot(t, y_inv_sin_filtros_norm, ...
    'DisplayName', 'Inverso sin filtros finales normalizado');
plot(t, y_inv_norm, ...
    'DisplayName', 'Inverso + HP/LP finales normalizado');
grid on;
xlabel('Tiempo [s]');
ylabel('Amplitud normalizada');
title('Geo1 - Entrada y salida normalizadas a pico 1');
legend('Location', 'best');
ylim([-1.1 1.1]);

%% ================== ZOOM NORMALIZADO ==================

figure;
plot(t, x_norm, 'DisplayName', 'Entrada original normalizada');
hold on;
plot(t, y_inv_sin_filtros_norm, 'DisplayName', 'Sin filtros finales');
plot(t, y_inv_norm, 'DisplayName', 'Con HP/LP finales');
grid on;
xlabel('Tiempo [s]');
ylabel('Amplitud normalizada');
title('Zoom - Entrada vs salida');
legend('Location', 'best');
xlim([0 0.5]);
ylim([-1.1 1.1]);

%% ================== ESPECTRO LOG NORMALIZADO ==================

Nesp = numel(x);

ventana = hann(Nesp);

xw = x .* ventana;
ywSinFiltros = y_inv_sin_filtros_finales .* ventana;
ywFinal = y_inv .* ventana;

Xesp = fft(xw);
YespSinFiltros = fft(ywSinFiltros);
YespFinal = fft(ywFinal);

fesp = (0:Nesp-1) * (fs / Nesp);
mitad = 1:floor(Nesp/2);

fpos = fesp(mitad);

Xmag = abs(Xesp(mitad));
YmagSinFiltros = abs(YespSinFiltros(mitad));
YmagFinal = abs(YespFinal(mitad));

Xmag_norm = Xmag / (max(Xmag) + eps);
YmagSinFiltros_norm = YmagSinFiltros / (max(YmagSinFiltros) + eps);
YmagFinal_norm = YmagFinal / (max(YmagFinal) + eps);

idxLog = fpos >= fMinPlot & fpos <= fMaxPlot;

figure;
semilogx(fpos(idxLog), Xmag_norm(idxLog), ...
    'DisplayName', 'Entrada original');
hold on;
semilogx(fpos(idxLog), YmagSinFiltros_norm(idxLog), ...
    'DisplayName', 'Salida sin filtros finales');
semilogx(fpos(idxLog), YmagFinal_norm(idxLog), ...
    'DisplayName', 'Salida con HP/LP finales');
grid on;
xlabel('Frecuencia [Hz]');
ylabel('Magnitud normalizada');
title('Espectro normalizado - Entrada vs salida');
legend('Location', 'best');
ylim([0 1.05]);

if aplicarHighpassFinal
    xline(fcHighpassHz, '--', 'fc HP');
end

if aplicarLowpassFinal
    xline(fcLowpassHz, '--', 'fc LP');
end

archivoEspectroPng = fullfile(carpetaSalida, "espectro_log_entrada_salida_hp_lp.png");
saveas(gcf, archivoEspectroPng);

fprintf("Imagen del espectro logarítmico guardada en:\n%s\n", archivoEspectroPng);

%% ================== ESPECTRO LOG EN dB ==================

Xmag_dB = 20*log10(Xmag_norm + eps);
YmagSinFiltros_dB = 20*log10(YmagSinFiltros_norm + eps);
YmagFinal_dB = 20*log10(YmagFinal_norm + eps);

figure;
semilogx(fpos(idxLog), Xmag_dB(idxLog), ...
    'DisplayName', 'Entrada original');
hold on;
semilogx(fpos(idxLog), YmagSinFiltros_dB(idxLog), ...
    'DisplayName', 'Salida sin filtros finales');
semilogx(fpos(idxLog), YmagFinal_dB(idxLog), ...
    'DisplayName', 'Salida con HP/LP finales');
grid on;
xlabel('Frecuencia [Hz]');
ylabel('Magnitud normalizada [dB]');
title('Espectro normalizado en dB - Entrada vs salida');
legend('Location', 'best');
ylim([-100 5]);

if aplicarHighpassFinal
    xline(fcHighpassHz, '--', 'fc HP');
end

if aplicarLowpassFinal
    xline(fcLowpassHz, '--', 'fc LP');
end

archivoEspectroDbPng = fullfile(carpetaSalida, "espectro_log_entrada_salida_hp_lp_dB.png");
saveas(gcf, archivoEspectroDbPng);

fprintf("Imagen del espectro logarítmico en dB guardada en:\n%s\n", archivoEspectroDbPng);

%% ================== RESPUESTA DEL INVERSO TUSTIN ==================

[Hinv, Fresp] = freqz(bInv, aInv, 4096, fs);

figure;
semilogx(Fresp, abs(Hinv));
grid on;
xlabel('Frecuencia [Hz]');
ylabel('|H_{inv}(f)|');
title('Magnitud del filtro inverso discreto Tustin');
xlim([fMinPlot fMaxPlot]);

figure;
semilogx(Fresp, 20*log10(abs(Hinv) + eps));
grid on;
xlabel('Frecuencia [Hz]');
ylabel('Magnitud [dB]');
title('Magnitud en dB del filtro inverso discreto Tustin');
xlim([fMinPlot fMaxPlot]);

%% ================== RESPUESTA DEL HIGH-PASS FINAL ==================

if aplicarHighpassFinal

    [Hhp, Fhp] = freqz(bHP, aHP, 8192, fs);

    figure;
    semilogx(Fhp, abs(Hhp));
    grid on;
    xlabel('Frecuencia [Hz]');
    ylabel('|H_{HP}(f)|');
    title('Magnitud del high-pass FIR final');
    xlim([fMinPlot fMaxPlot]);
    xline(fcHighpassHz, '--', 'fc HP');

    figure;
    semilogx(Fhp, 20*log10(abs(Hhp) + eps));
    grid on;
    xlabel('Frecuencia [Hz]');
    ylabel('Magnitud [dB]');
    title('Magnitud en dB del high-pass FIR final');
    xlim([fMinPlot fMaxPlot]);
    ylim([-100 5]);
    xline(fcHighpassHz, '--', 'fc HP');

end

%% ================== RESPUESTA DEL LOW-PASS FINAL ==================

if aplicarLowpassFinal

    [Hlp, Flp] = freqz(bLP, aLP, 8192, fs);

    figure;
    semilogx(Flp, abs(Hlp));
    grid on;
    xlabel('Frecuencia [Hz]');
    ylabel('|H_{LP}(f)|');
    title('Magnitud del low-pass FIR final');
    xlim([fMinPlot fMaxPlot]);
    xline(fcLowpassHz, '--', 'fc LP');

    figure;
    semilogx(Flp, 20*log10(abs(Hlp) + eps));
    grid on;
    xlabel('Frecuencia [Hz]');
    ylabel('Magnitud [dB]');
    title('Magnitud en dB del low-pass FIR final');
    xlim([fMinPlot fMaxPlot]);
    ylim([-100 5]);
    xline(fcLowpassHz, '--', 'fc LP');

end

%% ================== FUNCIÓN LOCAL ==================

function y_out = aplicarFiltfiltConPadding(y_in, b, a, ordenFIR)

    y_in = y_in(:);
    N = numel(y_in);

    if N < 20
        error("La señal es demasiado corta para aplicar filtfilt con padding.");
    end

    % Padding por reflexión.
    % Esto ayuda a reducir transitorios raros al inicio y final.
    padN = min(N - 2, max(3*ordenFIR, 1000));

    if padN < 10
        error("Padding insuficiente para filtfilt.");
    end

    prePad  = 2*y_in(1)   - flipud(y_in(2:padN+1));
    postPad = 2*y_in(end) - flipud(y_in(end-padN:end-1));

    y_pad = [prePad; y_in; postPad];

    y_pad_f = filtfilt(b, a, y_pad);

    y_out = y_pad_f(padN + 1 : padN + N);
    y_out = y_out(:);

end