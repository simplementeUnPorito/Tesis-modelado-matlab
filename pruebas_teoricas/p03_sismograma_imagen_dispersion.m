%%
% p03_sismograma_imagen_dispersion.m
% =========================================================================
% PRUEBA TEÓRICA 03 — Sismograma sintético + imagen de dispersión MASW
% =========================================================================
%
% OBJETIVO
%   Conectar la teoría de ondas superficiales (p02) con lo que un equipo
%   MASW hace en campo. El flujo completo es:
%
%     Modelo de suelo (Vs, Vp, ρ, h)
%           ↓
%     Sismograma sintético u(x, t)   ← simulamos aquí la propagación
%           ↓
%     Imagen de dispersión c-f       ← MASWaves_dispersion_imaging()
%           ↓
%     Curva de dispersión c(f)       ← picked del panel c-f
%           ↓
%     Inversión → perfil Vs(z)       ← (ese es el siguiente script)
%
% CONCEPTOS CUBIERTOS
%   1. Wavelet de Ricker: cómo se describe una fuente sísmica
%   2. Sumación modal: u(x,t) = IFFT[ S(ω)·exp(ik(ω)x) ] / √x
%      (Foti Ec. 2.75 — campo de desplazamiento superficial)
%   3. Dispersión visible en el sismograma: cada frecuencia llega a un tiempo
%      diferente porque k(ω) = ω/c(ω) y c(ω) NO es constante en medio estratificado
%   4. Decaimiento geométrico: body waves ~ 1/r, Rayleigh ~ 1/√r
%      (Foti Sec. 2.4.3 — función Y_l de spreading geométrico)
%   5. Fase shift method (Park et al. 1998) — cómo MASWaves extrae c-f
%      implementado en MASWaves_dispersion_imaging()
%   6. Velocidad aparente (efectiva) vs velocidad modal (Foti Ecs. 2.93–2.95)
%      En presencia de un solo modo dominante, la imagen c-f converge al modo.
%
% LIBRERÍA USADA
%   MASWaves_dispersion_imaging(u, N, x, fs, cT_min, cT_max, delta_cT)
%   MASWaves_theoretical_dispersion_curve(c_test, lambda, h, alpha, beta, rho, n)
%   Disponibles vía init_project() → genpath(third_party/MASW-Matlab-code/)
%
% CÓMO CORRER
%   >> init_project()
%   >> p03_sismograma_imagen_dispersion
%
% REFERENCIA PRINCIPAL
%   Foti, S. — Cap. 2, Secs. 2.4.1 (Lamb), 2.4.2 (spreading), 2.4.5 (aparente)
%   Park, C.B. et al. (1998) — Multichannel analysis of surface waves.
%   Geophysics 64(3): 800–808. (método de phase-shift)
%
% =========================================================================

close all; clear; clc;

fprintf('=================================================================\n');
fprintf(' PRUEBA TEÓRICA 03 — Sismograma sintético e imagen de dispersión\n');
fprintf('=================================================================\n\n');

% =========================================================================
% PARTE 0: MODELO DE SUELO Y CURVA DE DISPERSIÓN TEÓRICA
% =========================================================================
%
% Usamos el mismo modelo de 2 capas de p02 para que los números
% sean familiares. La curva de dispersión calculada aquí es la "verdad"
% que luego deberíamos recuperar de la imagen de dispersión.

% --- Modelo de 2 capas ---
h1   = 10;     % espesor capa 1 [m] — suelo blando
Vs1  = 120;    % Vs capa 1 [m/s]
Vp1  = 250;    % Vp capa 1 [m/s]
rho1 = 1700;   % densidad capa 1 [kg/m³]
Vs2  = 300;    % Vs half-space [m/s]
Vp2  = 520;    % Vp half-space [m/s]
rho2 = 1950;   % densidad half-space [kg/m³]

% Velocidad de Rayleigh asintótica (half-space, Foti Ec. 2.18 + 2.42)
cR_deep    = 0.9194 * Vs2;   % límite baja frecuencia
cR_shallow = 0.9194 * Vs1;   % límite alta frecuencia

% --- Configuración del arreglo de receptores (parámetros de campo típicos) ---
%
% En MASW: la fuente (martillo o peso) se ubica a un lado del arreglo.
% Los geófonos se ponen a una distancia mínima (near offset) del impacto.
% El near offset debe ser al menos λR/2 para evitar el near-field de Rayleigh
% (Foti Sec. 2.4.2). Para frecuencias de 5–50 Hz y cR ≈ 120 m/s:
%   λR = cR/f = 120/10 = 12 m → near offset mínimo ≈ 6 m

N_rec    = 24;          % número de receptores
dx       = 1.0;         % separación entre receptores [m]
x1       = 10.0;         % offset mínimo (near offset) [m]
x_rec    = x1 + (0:N_rec-1)*dx;   % posiciones de los receptores [m]
x_max    = max(x_rec);

fprintf('--- ARREGLO DE RECEPTORES ---\n');
fprintf('  N = %d receptores, dx = %.1f m\n', N_rec, dx);
fprintf('  Near offset: x1 = %.1f m\n', x1);
fprintf('  Far offset:  x_N = %.1f m\n', x_max);
fprintf('  Longitud total del arreglo: L = %.1f m\n', (N_rec-1)*dx);
fprintf('\n');

% --- Parámetros de muestreo temporal ---
fs     = 1000;          % frecuencia de muestreo [Hz] — típico para MASW
dt     = 1/fs;          % paso temporal [s]
T_total = 1.0;          % duración del registro [s]
t_vec  = 0:dt:T_total-dt;
N_t    = length(t_vec);

% =========================================================================
% PARTE 1: CURVA DE DISPERSIÓN TEÓRICA (usando MASWaves)
% =========================================================================
%
% Calculamos la curva de dispersión del modo fundamental de Rayleigh
% para el modelo de 2 capas. Esta es la "verdad de campo" — si todo
% funciona bien, la imagen de dispersión debería mostrar esta curva.

lambda_min = 1;
lambda_max = 120;
n_lam      = 100;
lambda_vec = linspace(lambda_min, lambda_max, n_lam);
c_test_vec = 50:1:350;

[c_t, lambda_t] = MASWaves_theoretical_dispersion_curve( ...
    c_test_vec, lambda_vec, [h1], [Vp1,Vp2], [Vs1,Vs2], [rho1,rho2], 1);

% MASWaves retorna c_t como columna (Nx1) y lambda_t como fila (1xN).
% Forzar ambos a vectores fila para que todas las operaciones sean consistentes.
c_t      = c_t(:)';
lambda_t = lambda_t(:)';

% Filtrar puntos donde no se encontró raíz (c_t == 0)
valid  = c_t > 0;
c_t    = c_t(valid);
lam_t  = lambda_t(valid);

% Ordenar por frecuencia creciente (MASWaves entrega orden por λ, no por f)
f_t    = c_t ./ lam_t;              % frecuencia [Hz] — vector fila
[f_t, isort] = sort(f_t);
c_t    = c_t(isort);
lam_t  = lam_t(isort);

fprintf('Curva de dispersión teórica: %d puntos en f = [%.1f, %.1f] Hz\n', ...
    sum(valid), min(f_t), max(f_t));

% Función de interpolación c_R(f) — usada en la síntesis del sismograma.
% Extrapolamos con los valores asintóticos de Rayleigh en los extremos.
f_interp = [0,       f_t,      500      ];
c_interp = [cR_deep, c_t,      cR_shallow];

c_of_f   = @(f_in) interp1(f_interp, c_interp, f_in, 'linear', 'extrap');

fprintf('  c_R a f=5 Hz:  %.0f m/s\n', c_of_f(5));
fprintf('  c_R a f=20 Hz: %.0f m/s\n', c_of_f(20));
fprintf('  c_R a f=50 Hz: %.0f m/s\n', c_of_f(50));
fprintf('\n');

% =========================================================================
% FIGURA 1: Wavelet de Ricker (fuente sísmica)
% =========================================================================
%
% Un martillo golpeando el suelo genera una señal impulsiva que se puede
% modelar como un wavelet de Ricker:
%
%   R(t) = (1 - 2π²·f0²·t²) · exp(-π²·f0²·t²)
%
% Parámetros:
%   f0 = frecuencia central (peak frequency) [Hz]
%
% En el dominio de frecuencias, el espectro de amplitud de Ricker es:
%   |R(f)| = (2/√π) · (f²/f0³) · exp(-f²/f0²)
%
% La frecuencia central f0 controla:
%   - La resolución temporal (más alto f0 → pulso más angosto → mejor resolución en t)
%   - El contenido de frecuencia (más alto f0 → más contribución de λ cortas → más superficial)
%   - En MASW se usa f0 entre 10 y 50 Hz típicamente.

f0       = 20;         % frecuencia central del wavelet [Hz]
t_ricker = (-0.15:dt:0.15);   % centrado en t=0
ricker   = (1 - 2*(pi*f0*t_ricker).^2) .* exp(-(pi*f0*t_ricker).^2);

% Espectro de amplitud del Ricker
N_r   = length(ricker);
f_ricker = (0:N_r-1)*(fs/N_r);
R_f   = abs(fft(ricker));
R_f   = R_f(1:floor(N_r/2));
f_ricker = f_ricker(1:floor(N_r/2));

figure('Name', 'Fig 1 — Wavelet de Ricker (fuente sísmica)', ...
       'NumberTitle', 'off', 'Position', [50 600 800 380]);

subplot(1, 2, 1);
plot(t_ricker*1000, ricker, 'b-', 'LineWidth', 2);
xlabel('Tiempo [ms]', 'FontSize', 11);
ylabel('Amplitud norm. [-]', 'FontSize', 11);
title({'Wavelet de Ricker — dominio temporal', ...
       sprintf('Frecuencia central f_0 = %d Hz', f0)}, 'FontSize', 10);
xline(0, ':k');
yline(0, ':k');
grid on;

subplot(1, 2, 2);
plot(f_ricker, R_f/max(R_f), 'r-', 'LineWidth', 2);
xline(f0, '--k', sprintf('f_0 = %d Hz', f0), 'FontSize', 9);
xlabel('Frecuencia [Hz]', 'FontSize', 11);
ylabel('Amplitud espectral norm. [-]', 'FontSize', 11);
title({'Espectro de amplitud del Ricker', ...
       'Energía concentrada alrededor de f_0'}, 'FontSize', 10);
xlim([0 min(fs/2, 4*f0)]);
grid on;

sgtitle('Fig 1: Wavelet de Ricker — modelo de fuente sísmica impulsiva', ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 1 generada: wavelet de Ricker f0=%.0f Hz.\n', f0);
fprintf('  La fuente emite energía principalmente entre %.0f y %.0f Hz.\n', f0*0.3, f0*2);
fprintf('  Esas frecuencias corresponden a λR = %.0f–%.0f m → profundidades %.0f–%.0f m\n\n', ...
    cR_shallow/f0/2, cR_shallow/(f0*0.3)/2, h1*0.3, h1*1.5);
drawnow;

% =========================================================================
% FIGURA 2: Sismograma sintético u(x, t) — "shot gather"
% =========================================================================

% Construir espectro de la fuente (Ricker padded al tamaño del registro)
ricker_padded = zeros(N_t, 1);
n_ricker      = length(ricker);

% Centrar el wavelet en t = 0.05 s
t0           = 0.05;                         % [s]
t_center_idx = round(t0 * fs) + 1;          % índice MATLAB (1-based)

idx_start = t_center_idx - floor(n_ricker/2);
idx_end   = idx_start + n_ricker - 1;

src_i1 = max(1, idx_start);
src_i2 = min(N_t, idx_end);

wav_i1 = 1 + (src_i1 - idx_start);
wav_i2 = wav_i1 + (src_i2 - src_i1);

ricker_padded(src_i1:src_i2) = ricker(wav_i1:wav_i2);

% FFT de la fuente
S_f = fft(ricker_padded);

% Vector de frecuencias del FFT
f_fft     = (0:N_t-1) * fs/N_t;
omega_fft = 2*pi*f_fft;
% Inicializar matriz de sismogramas
U_synth = zeros(N_t, N_rec);

fprintf('Sintetizando sismogramas para %d receptores...\n', N_rec);

for ir = 1:N_rec
    x_r = x_rec(ir);

    % --- Onda Rayleigh (dispersiva) ---
    U_R = zeros(N_t, 1);

    for iff = 2:floor(N_t/2)
        f_k = f_fft(iff);

        if f_k > 0.5 && f_k < fs/2
            c_k = c_of_f(f_k);

            if c_k > 0
                k_k = omega_fft(iff) / c_k;

                % signo corregido para retardo de propagación
                phase_factor = exp(-1i * k_k * x_r);

                U_R(iff) = S_f(iff) * phase_factor / sqrt(x_r);
                U_R(N_t - iff + 2) = conj(U_R(iff));
            end
        end
    end

    u_R = real(ifft(U_R));

    % Validación limpia: usar solo Rayleigh
    U_synth(:, ir) = u_R;
end
%%
% Normalización
U_max  = max(abs(U_synth(:)));
U_norm = U_synth / U_max;

fprintf('  Sismograma completado: %d muestras × %d trazas\n\n', N_t, N_rec);

% ---- Plot del shot gather ----
figure('Name', 'Fig 2 — Sismograma sintético "shot gather"', ...
       'NumberTitle', 'off', 'Position', [50 100 700 600]);

hold on;
wiggle_scale = dx * 0.7;

for ir = 1:N_rec
    x_r   = x_rec(ir);
    trace = U_norm(:, ir) * wiggle_scale;

    plot(x_r + zeros(N_t,1), t_vec, '-', ...
        'Color', [0.8 0.8 0.8], 'LineWidth', 0.3, ...
        'HandleVisibility', 'off');

    plot(x_r + trace, t_vec, 'k-', ...
        'LineWidth', 0.5, 'HandleVisibility', 'off');
end

% Referencias teóricas
x_plot = linspace(x1, x_max, 200);

t_P = t0 + x_plot / Vp1;
t_S = t0 + x_plot / Vs1;
t_R_low  = t0 + x_plot / cR_deep;
t_R_high = t0 + x_plot / cR_shallow;

plot(x_plot, t_P, 'b--', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Onda P (Vp=%.0f m/s)', Vp1));
plot(x_plot, t_S, 'r--', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Onda S (Vs=%.0f m/s)', Vs1));
plot(x_plot, t_R_low, 'g-', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Rayleigh baja f (≈%.0f m/s)', cR_deep));
plot(x_plot, t_R_high, 'm-', 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Rayleigh alta f (≈%.0f m/s)', cR_shallow));

xlabel('Offset x [m]', 'FontSize', 11);
ylabel('Tiempo t [s]', 'FontSize', 11);
title({'Fig 2: Shot gather sintético — u(x,t)', ...
       'Tiempo creciente hacia abajo (convención sísmica)'}, ...
       'FontSize', 10);

set(gca, 'YDir', 'reverse');
xlim([x1 - dx, x_max + dx]);
ylim([0, 0.5]);
legend('Location', 'southeast', 'FontSize', 8);
grid on;

fprintf('FIG 2 generada: shot gather sintético (wiggle plot).\n');
fprintf('  La dispersión es visible: la onda Rayleigh se ensancha con el offset.\n');
fprintf('  Alta frecuencia: más lenta (muestrea la capa superficial blanda).\n');
fprintf('  Baja frecuencia: más rápida (influencia del half-space rígido).\n\n');
drawnow;
% =========================================================================
% FIGURA 3: Decaimiento geométrico — body waves vs Rayleigh
% =========================================================================
%
% La diferencia en decaimiento geométrico es fundamental para entender
% por qué Rayleigh domina a distancias grandes:
%
%   Ondas de cuerpo (3D): amplitud ~ 1/r       (energy flux ~ 1/r²)
%   Ondas superficiales:  amplitud ~ 1/√r      (energy flux ~ 1/r)
%
% Consecuencia: a distancias mayores de ~1–2 longitudes de onda, la
% onda Rayleigh tiene mayor amplitud relativa → SNR mejor para MASW.
%
% Foti Sec. 2.4.2: "the geometric spreading function Y_l(r,x₂,ω)
% deviates from r^{-0.5} in layered media"

r_vec = linspace(1, 100, 500);

amp_body    = 1 ./ r_vec;
amp_surface = 1 ./ sqrt(r_vec);

% Normalizar ambas en r = x1
amp_body    = amp_body    / (1/x1);
amp_surface = amp_surface / (1/sqrt(x1));

figure('Name', 'Fig 3 — Decaimiento geométrico: body waves vs Rayleigh (Foti Sec. 2.4.2)', ...
       'NumberTitle', 'off', 'Position', [720 500 750 420]);

subplot(1, 2, 1);
hold on;
plot(r_vec, amp_body,    'r-', 'LineWidth', 2, 'DisplayName', 'Body wave  ~ 1/r');
plot(r_vec, amp_surface, 'b-', 'LineWidth', 2, 'DisplayName', 'Rayleigh  ~ 1/\surd r');
xline(x1, ':k', sprintf('x_{near}=%.0fm', x1), 'FontSize', 8);
xlabel('Distancia r  [m]', 'FontSize', 11);
ylabel('Amplitud norm.  [-]', 'FontSize', 11);
title('Decaimiento de amplitud — escala lineal', 'FontSize', 10);
legend('Location', 'northeast', 'FontSize', 9);
grid on;
ylim([0 1.05]);

subplot(1, 2, 2);
hold on;
plot(r_vec, amp_body,    'r-', 'LineWidth', 2, 'DisplayName', 'Body wave  ~ 1/r');
plot(r_vec, amp_surface, 'b-', 'LineWidth', 2, 'DisplayName', 'Rayleigh  ~ 1/\surd r');
set(gca, 'YScale', 'log', 'XScale', 'log');
xline(x1, ':k', 'x_{near}', 'FontSize', 8);

% Líneas de referencia de pendiente
x_ref = [5 50];
loglog(x_ref, 0.8*x1./x_ref,      '--r', 'LineWidth', 0.8, 'HandleVisibility', 'off');
loglog(x_ref, 0.8*sqrt(x1./x_ref),'--b', 'LineWidth', 0.8, 'HandleVisibility', 'off');
text(40, 0.8*x1/40*1.3,      'pendiente -1', 'FontSize', 8, 'Color', 'r');
text(40, 0.8*sqrt(x1/40)*1.3,'pendiente -½','FontSize', 8, 'Color', 'b');

xlabel('Distancia r  [m]', 'FontSize', 11);
ylabel('Amplitud norm.  [-]', 'FontSize', 11);
title('Decaimiento de amplitud — escala log-log', 'FontSize', 10);
legend('Location', 'northeast', 'FontSize', 9);
grid on;

sgtitle({'Fig 3: Decaimiento geométrico de ondas de cuerpo vs superficiales', ...
         'A distancias grandes, Rayleigh domina: mejor SNR para MASW'}, ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 3 generada: decaimiento geométrico.\n');
fprintf('  A r = 50 m:\n');
fprintf('    Body wave:  amplitud = %.3f\n', (x1/50));
fprintf('    Rayleigh:   amplitud = %.3f  (%.1f× mayor)\n', sqrt(x1/50), sqrt(x1/50)/(x1/50));
fprintf('  Por eso MASW usa offsets grandes: mejor SNR de Rayleigh.\n\n');
drawnow;

% =========================================================================
% FIGURA 4: Imagen de dispersión c-f (phase-shift method)
% =========================================================================

U_masw = U_synth;

cT_min   = 50;
cT_max   = 400;
delta_cT = 1;

fprintf('Ejecutando MASWaves_dispersion_imaging()...\n');

[f_img, c_img, A_img] = MASWaves_dispersion_imaging( ...
    U_masw, N_rec, x_rec, fs, cT_min, cT_max, delta_cT);

f_1d = f_img(:,1);
c_1d = c_img(1,:);

% Rango útil de frecuencias (acorde al Ricker)
f_min_plot = 4;
f_max_plot = 40;
f_mask = f_1d >= f_min_plot & f_1d <= f_max_plot;

A_plot = A_img(f_mask, :);
f_plot = f_1d(f_mask);

% Normalización global
A_norm = A_plot / max(A_plot(:));
A_norm(isnan(A_norm)) = 0;

% --- PEAK SIMPLE ---
[peak_amp, idx_peak] = max(A_plot, [], 2);
c_peak = c_1d(idx_peak);

% máscara de energía mínima
peak_mask = peak_amp > 0.20 * max(peak_amp);

figure('Name', 'Fig 4 — Imagen de dispersión c-f', ...
       'NumberTitle', 'off', 'Position', [720 50 800 550]);

imagesc(f_plot, c_1d, A_norm');
axis xy;
colormap(jet);
colorbar;
hold on;

% curva teórica
plot(f_t, c_t, 'w-', 'LineWidth', 2, ...
    'DisplayName', 'Curva teórica');

% PEAK DETECTADO
plot(f_plot(peak_mask), c_peak(peak_mask), 'k.', ...
    'MarkerSize', 10, 'DisplayName', 'Peak imagen');

xlabel('Frecuencia [Hz]');
ylabel('Velocidad [m/s]');
title('Imagen c-f + peak por frecuencia');
xlim([f_min_plot, f_max_plot]);
ylim([cT_min, cT_max]);
legend('Location', 'northeast');

fprintf('FIG 4 OK: peak por frecuencia graficado.\n\n');

% =========================================================================
% FIGURA 5: Picking simple + comparación con teórica
% =========================================================================

% suavizado simple
c_picked = c_peak;
c_picked_smooth = medfilt1(double(c_picked), 5);

% invalidar donde no hay energía
c_picked(~peak_mask) = NaN;
c_picked_smooth(~peak_mask) = NaN;

% interpolar teórica
c_teor_interp = c_of_f(f_plot(:));
error_abs = abs(c_picked_smooth(:) - c_teor_interp);

figure('Name', 'Fig 5 — Picking vs teórica', ...
       'NumberTitle', 'off', 'Position', [50 50 700 500]);

subplot(1,2,1); hold on;

imagesc(f_plot, c_1d, A_norm');
axis xy;
colormap(jet);

plot(f_t, c_t, 'w-', 'LineWidth', 2, 'DisplayName', 'Teórica');
plot(f_plot, c_picked, 'ko', 'MarkerSize', 3, 'DisplayName', 'Peak');
plot(f_plot, c_picked_smooth, 'r-', 'LineWidth', 1.5, ...
    'DisplayName', 'Suavizado');

xlabel('Frecuencia [Hz]');
ylabel('Velocidad [m/s]');
title('Picking simple');
xlim([f_min_plot, f_max_plot]);
ylim([cT_min, cT_max]);
legend('Location','northeast');

subplot(1,2,2); hold on;

plot(f_plot, error_abs, 'r-', 'LineWidth', 1.5);
yline(10, '--k', '10 m/s');
yline(20, ':k', '20 m/s');

xlabel('Frecuencia [Hz]');
ylabel('Error [m/s]');
title('Error vs teórica');
grid on;

fprintf('FIG 5 OK: picking simple funcionando.\n');
% =========================================================================
% RESUMEN FINAL
% =========================================================================

fprintf('=================================================================\n');
fprintf(' RESUMEN — Flujo completo MASW (síntesis)\n');
fprintf('=================================================================\n\n');
fprintf('FLUJO DEMOSTRADO:\n');
fprintf('  1. Modelo de suelo conocido (Vs1=%.0f, Vs2=%.0f, h1=%.0f m)\n', Vs1, Vs2, h1);
fprintf('  2. Curva teórica: MASWaves_theoretical_dispersion_curve()\n');
fprintf('  3. Síntesis del shot gather: sumación modal IFFT[S(ω)·e^{ik(ω)x}/√x]\n');
fprintf('  4. Imagen c-f: MASWaves_dispersion_imaging() — phase-shift method\n');
fprintf('  5. Picking automático del máximo de amplitud en cada frecuencia\n\n');
fprintf('CONCEPTOS CLAVE:\n');
fprintf('  - La dispersión es VISIBLE en el shot gather (apertura temporal de Rayleigh)\n');
fprintf('  - Rayleigh domina en amplitud a largo offset (decaimiento 1/√r vs 1/r)\n');
fprintf('  - La imagen c-f "abre" la dispersión para leerla directamente\n');
fprintf('  - Lo que se mide es la velocidad aparente ≈ c_modo_0 (si modo 0 domina)\n\n');
fprintf('PRÓXIMO SCRIPT:\n');
fprintf('  p04_inversion_perfil_vs.m — dado c(f), reconstruir Vs(z)\n');
fprintf('  La inversión es el paso final de MASW.\n');
fprintf('=================================================================\n');
