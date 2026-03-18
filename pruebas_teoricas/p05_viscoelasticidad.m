%%
% p05_viscoelasticidad.m
% =========================================================================
% PRUEBA TEÓRICA 05 — Viscoelasticidad lineal y amortiguamiento material
% =========================================================================
%
% OBJETIVO
%   Cerrar el Capítulo 2 de Foti construyendo intuición sobre la sección 2.5:
%   qué pasa cuando el suelo NO es perfectamente elástico — disipa energía.
%   Esta disipación afecta tanto la velocidad de propagación como la amplitud.
%
% CONCEPTOS CUBIERTOS
%   1. Ecuación de Boltzmann (Foti Ec. 2.96): el esfuerzo depende del
%      historial de deformaciones — el suelo tiene "memoria"
%   2. Módulo complejo G*(ω) = G₁(ω) + i·G₂(ω) (Foti Ec. 2.104)
%   3. Factor de amortiguamiento D_χ = G₂/(2G₁) (Foti Ec. 2.115)
%      D ≈ 0.01–0.05 para suelos (geotécnicos): casi siempre < 5%
%   4. Relaciones Kramers-Krönig (Foti Ecs. 2.99, 2.130): la causalidad
%      obliga a que V(ω) y D(ω) no sean independientes
%   5. Velocidad compleja V*_χ ≈ V_χ(1 + i·D_χ) (Foti Ec. 2.128)
%      (aproximación de disipación débil — válida para D ≤ 0.05)
%   6. Número de onda complejo k* = ω/V* = k_R + i·α_R (Foti Ec. 2.121)
%      — La parte imaginaria α_R [Np/m] es el coeficiente de atenuación
%   7. El problema inverso viscoelástico se desacopla (Foti Ec. 2.133):
%      invertir V_R primero (no lineal), luego α_R (lineal) para obtener D_R(z)
%
% NOTA TÉCNICA: SÍNTESIS DE SEÑAL EN EL DOMINIO DE LA FRECUENCIA
%   Para sintetizar una señal real de N muestras desde su espectro unilateral
%   se necesitan exactamente N/2+1 puntos (incluye DC y Nyquist):
%     Full spectrum = [X(1:N/2+1), conj(X(N/2:-1:2))]  → N puntos
%   ERRÓNEO usar N/2 puntos (da N-1 después de la simetría hermítica).
%
% CÓMO CORRER
%   >> init_project()
%   >> p05_viscoelasticidad
%
% REFERENCIA PRINCIPAL
%   Foti, S. — Cap. 2, Sección 2.5: "Viscoelastic Behaviour"
%   Ecuaciones clave: 2.96, 2.99, 2.104, 2.115, 2.118, 2.121, 2.128, 2.130, 2.133
%
% =========================================================================

close all; clear; clc;

fprintf('=================================================================\n');
fprintf(' PRUEBA TEÓRICA 05 — Viscoelasticidad y amortiguamiento material\n');
fprintf('=================================================================\n\n');

% =========================================================================
% PARÁMETROS BASE
% =========================================================================

% Propiedades elásticas del suelo (mismo suelo de p01)
Vs0   = 244.9;         % velocidad de corte elástica de referencia [m/s]
rho   = 1900;          % densidad [kg/m³]
mu0   = rho * Vs0^2;   % módulo de corte a frecuencia de referencia [Pa]

% Factor de amortiguamiento material típico para suelos
% D = G₂/(2G₁) — ver Foti Ec. 2.115
% Valores típicos:
%   Arcilla blanda:  D ≈ 0.03–0.10
%   Arena densa:     D ≈ 0.01–0.03
%   Roca:            D ≈ 0.001–0.01
D_valores = [0.01, 0.03, 0.05, 0.10];   % comparar 4 valores de D

% Frecuencia de referencia para el módulo (Foti: se usa f_ref = 1 Hz)
f_ref_visco  = 1.0;   % [Hz]
omega_ref    = 2*pi*f_ref_visco;

% Rango de frecuencias de análisis
f_vec   = logspace(-1, 2, 500);    % 0.1 Hz a 100 Hz (log)
omega_v = 2*pi*f_vec;

fprintf('--- PARÁMETROS DEL SUELO ---\n');
fprintf('  Vs0 = %.1f m/s (elástico, a f_ref = %.0f Hz)\n', Vs0, f_ref_visco);
fprintf('  ρ   = %.0f kg/m³\n', rho);
fprintf('  μ0  = %.2e Pa (= %.0f MPa)\n', mu0, mu0/1e6);
fprintf('  D valores analizados: ');
fprintf('%.2f  ', D_valores);
fprintf('\n\n');

% =========================================================================
% FIGURA 1: Módulo complejo G*(ω) — partes real e imaginaria
% =========================================================================
%
% En un suelo viscoelástico, el módulo de corte es COMPLEJO y depende de ω:
%
%   G*(ω) = G₁(ω) + i·G₂(ω)
%
% donde:
%   G₁(ω) = parte real  → "storage modulus" — energía almacenada elásticamente
%   G₂(ω) = parte imag. → "loss modulus"    — energía disipada por ciclo
%
% En el modelo de amortiguamiento histerético CAUSAL (que cumple Kramers-Krönig,
% Foti Ec. 2.130), G₁ y G₂ NO son independientes. Si D es constante:
%
%   V_S(ω) = V_S0 · [1 + (D/π)·ln(ω/ω_ref)]   ← dispersión intrínseca causal
%   G₁(ω)  = ρ · V_S(ω)²                        ← crece logarítmicamente con f
%   G₂(ω)  = 2·D·G₁(ω)                          ← también crece con f
%
% DIFERENCIA CON EL MODELO HISTERÉTICO NO-CAUSAL:
%   Si D = cte y G₁ = cte → violaría causalidad (Kramers-Krönig).
%   El modelo causal tiene V_S que AUMENTA suavemente con f.
%   En campo real, esta variación es pequeña pero medible.

D_plot = 0.05;   % usamos D=5% para visualización

% Módulo en modelo histerético causal (con corrección Kramers-Krönig)
% V_S(ω) = V_S0 · [1 + D/π · ln(ω/ω_ref)]
V_kk   = Vs0 * (1 + D_plot/pi * log(omega_v/omega_ref));
G1_kk  = rho * V_kk.^2;            % parte real del módulo
G2_kk  = 2 * D_plot * G1_kk;       % parte imaginaria (Ec. 2.115: D = G₂/2G₁)

G0_ref = rho * Vs0^2;   % módulo elástico de referencia

figure('Name', 'Fig 1 — Módulo complejo G*(ω) y corrección causal (Foti Ecs. 2.104–2.130)', ...
       'NumberTitle', 'off', 'Position', [50 550 1000 450]);

subplot(1, 2, 1);
hold on;
area(log10(f_vec), G2_kk/G0_ref, 'FaceColor', [1 0.9 0.9], 'EdgeColor', 'none', ...
    'HandleVisibility', 'off');
area(log10(f_vec), G1_kk/G0_ref, 'FaceColor', [0.9 0.9 1.0], 'EdgeColor', 'none', ...
    'HandleVisibility', 'off');
semilogx(f_vec, G1_kk/G0_ref, 'b-', 'LineWidth', 2.2, ...
    'DisplayName', 'G_1(ω)/G_0  (rigidez almacenada)');
semilogx(f_vec, G2_kk/G0_ref, 'r-', 'LineWidth', 2.2, ...
    'DisplayName', 'G_2(ω)/G_0  (rigidez disipada)');
yline(1.0, ':k', 'G_0 (elástico puro)', 'FontSize', 8);
xline(f_ref_visco, '--k', sprintf('f_{ref}=%.0fHz', f_ref_visco), ...
    'FontSize', 8, 'LabelVerticalAlignment', 'bottom');
xlabel('Frecuencia f  [Hz]', 'FontSize', 11);
ylabel('G / G_0  [-]', 'FontSize', 11);
title({'Módulo complejo G*(ω)/G_0', ...
       sprintf('Modelo histerético CAUSAL  (D=%.2f, Kramers-Krönig Ec. 2.130)', D_plot)}, ...
    'FontSize', 10);
legend('Location', 'northwest', 'FontSize', 9);
grid on; box on;

% Anotación: el ángulo entre G1 y G2 es el ángulo de pérdida δ
% tan(δ) = G2/G1 = 2D → δ ≈ 2D [rad] para D << 1
text(10, 1.05, sprintf('tan(δ) = G_2/G_1 = 2D = %.2f', 2*D_plot), ...
    'FontSize', 8, 'Color', [0.5 0 0]);

subplot(1, 2, 2);
hold on;
semilogx(f_vec, V_kk, 'b-', 'LineWidth', 2.5);
yline(Vs0, '--k', sprintf('V_{S0} = %.0f m/s (elástico)', Vs0), 'FontSize', 8);
xline(f_ref_visco, '--k', sprintf('f_{ref}=%.0f Hz', f_ref_visco), 'FontSize', 8, ...
    'LabelVerticalAlignment', 'bottom');
xlabel('Frecuencia f  [Hz]', 'FontSize', 11);
ylabel('V_S(ω)  [m/s]', 'FontSize', 11);
title({'Dispersión causal V_S(ω) — Kramers-Krönig (Foti Ec. 2.130)', ...
       sprintf('V(ω) = V_0·[1 + D/π·ln(ω/ω_{ref})]   D=%.2f', D_plot)}, 'FontSize', 10);
grid on; box on;
ylim([Vs0*0.88, Vs0*1.16]);

% Anotar variación total
dV = V_kk(end) - V_kk(1);
annotation('doublearrow', [0.72 0.87], [0.7 0.7]);   % solo cosmético

sgtitle({'Fig 1: Módulo complejo en suelo viscoelástico (D=5%)', ...
         'La causalidad (Kramers-Krönig) impone dispersión intrínseca en V_S(ω)'}, ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 1 generada: módulo complejo G*(ω).\n');
fprintf('  Variación de V_S en [0.1, 100] Hz: ΔV = %.1f m/s (%.1f%%)\n', dV, 100*dV/Vs0);
fprintf('  Esta dispersión CAUSAL es distinta de la dispersión geométrica\n');
fprintf('  que surge de las capas — ambas contribuyen a c_R(f) medida.\n\n');
drawnow;

% =========================================================================
% FIGURA 2: Factor de amortiguamiento D — su efecto en la atenuación espacial
% =========================================================================
%
% Número de onda complejo para onda S en medio viscoelástico (Foti Ec. 2.121):
%
%   k* = ω / V*_S = ω / [V_S(1 + i·D_S)]
%
% Para D << 1 (disipación débil, Foti Ec. 2.128):
%   k* ≈ (ω/V_S) - i·(ω·D_S/V_S) = k_R - i·α_S
%
% donde α_S = ω·D_S/V_S [Np/m] es el coeficiente de ATENUACIÓN espacial.
%
% La onda que se propaga:
%   u(x,t) = A·exp(i(k*x - ωt)) = A·exp(-α_S·x)·exp(i(k_R·x - ωt))
%                                     ↑                   ↑
%                              decaimiento           oscilación
%
% Conclusión práctica para MASW:
%   - α_S crece con f: las altas frecuencias se atenúan más rápido
%   - A mayor D, todo el espectro se atenúa más
%   - Si D > 0.10 en un suelo, el SNR de la imagen MASW puede degradarse
%     significativamente a los offsets típicos de campo (> 20 m)

f_atten = [5, 10, 20, 40];   % frecuencias de análisis [Hz]
x_vec   = linspace(0, 200, 600);   % distancia [m]

figure('Name', 'Fig 2 — Atenuación espacial por amortiguamiento (Foti Ecs. 2.121–2.128)', ...
       'NumberTitle', 'off', 'Position', [50 80 1050 490]);

colores_D = {[0.1 0.3 0.9], [0.1 0.7 0.2], [0.9 0.4 0.1], [0.7 0.1 0.7]};

% Panel izquierdo: amplitud vs distancia para D={0.01,0.03,0.05,0.10} @ f=10 Hz
subplot(1, 2, 1);
hold on;
f_ref_atten  = 10;   % [Hz]
omega_ref_at = 2*pi*f_ref_atten;

% Fondo: región típica de array MASW en campo
fill([5 30 30 5], [0 0 1.1 1.1], [0.93 0.97 0.93], 'EdgeColor', 'none', ...
    'HandleVisibility', 'off');
text(17.5, 1.07, 'Array típico', 'FontSize', 8, 'HorizontalAlignment', 'center', ...
    'Color', [0.3 0.6 0.3]);

for iD = 1:length(D_valores)
    D_k     = D_valores(iD);
    alpha_k = omega_ref_at * D_k / Vs0;     % [Np/m]
    amp_k   = exp(-alpha_k * x_vec);

    x_1e = 1/alpha_k;   % distancia donde la amplitud cae a 1/e ≈ 37%
    plot(x_vec, amp_k, 'Color', colores_D{iD}, 'LineWidth', 2.2, ...
        'DisplayName', sprintf('D=%.2f  (x_{1/e}=%.0fm)', D_k, x_1e));

    % Marcar x=1/e
    if x_1e < 200
        plot(x_1e, exp(-1), 'o', 'Color', colores_D{iD}, 'MarkerSize', 6, ...
            'HandleVisibility', 'off');
    end
end

yline(exp(-1), ':k', '1/e ≈ 0.37', 'FontSize', 8, 'LabelHorizontalAlignment', 'left');

xlabel('Distancia x  [m]', 'FontSize', 11);
ylabel('Amplitud norm.  A(x)/A_0  [-]', 'FontSize', 11);
title({sprintf('Decaimiento de amplitud por amortiguamiento a f=%.0f Hz', f_ref_atten), ...
       'u(x) = A_0·exp(-α_S·x),   α_S = ω·D/V_S  (Foti Ec. 2.128)'}, 'FontSize', 10);
legend('Location', 'northeast', 'FontSize', 9);
grid on; box on;
ylim([0, 1.12]);

% Panel derecho: α_S [Np/m] vs frecuencia para distintos D
subplot(1, 2, 2);
hold on;

% Sombrear rango típico MASW
fill(log10([5 50 50 5]), [0 0 0.5 0.5], [0.93 0.97 0.93], 'EdgeColor', 'none', ...
    'HandleVisibility', 'off');
text(log10(15), 0.47, 'Rango MASW', 'FontSize', 8, 'HorizontalAlignment', 'center', ...
    'Color', [0.3 0.6 0.3]);

for iD = 1:length(D_valores)
    D_k     = D_valores(iD);
    alpha_f = omega_v * D_k / Vs0;
    semilogx(f_vec, alpha_f, 'Color', colores_D{iD}, 'LineWidth', 2.2, ...
        'DisplayName', sprintf('D = %.2f', D_k));
end

xlabel('Frecuencia f  [Hz]', 'FontSize', 11);
ylabel('Coeficiente de atenuación α_S  [Np/m]', 'FontSize', 11);
title({'α_S(f) = ω·D/V_S — atenuación crece con frecuencia', ...
       'Alta f + D grande → la onda se atenúa antes de llegar al último geófono'}, ...
    'FontSize', 10);
legend('Location', 'northwest', 'FontSize', 9);
grid on; box on;
xlim([0.1, 100]);
ylim([0, 0.55]);

sgtitle({'Fig 2: Efecto del amortiguamiento D en la propagación de ondas S', ...
         'Ondas de alta frecuencia (y materiales con D alto) se atenúan en distancias más cortas'}, ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 2 generada: atenuación espacial por amortiguamiento.\n');
fprintf('  A f=10 Hz y D=0.05: α = %.4f Np/m → distancia 1/e = %.0f m\n', ...
    2*pi*10*0.05/Vs0, Vs0/(2*pi*10*0.05));
fprintf('  En MASW campo típico (offset 5–30 m y f=10–50 Hz):\n');
fprintf('  D=0.03–0.05 es aceptable, D>0.1 puede degradar el SNR a largo offset.\n\n');
drawnow;

% =========================================================================
% FIGURA 3: Pulso propagándose — elástico vs viscoelástico
%           Layout 2×2: wiggles (fila 1) + espectros de amplitud (fila 2)
% =========================================================================
%
% Lo que ve el geófono: el mismo pulso en un medio elástico llega sin
% cambio de forma (solo se demora). En un medio viscoelástico:
%   1. La AMPLITUD total disminuye con la distancia (absorción)
%   2. Las ALTAS FRECUENCIAS se atenúan más rápido que las bajas
%      → el pulso se "ensancha" y parece más suave a mayor distancia
%      → la señal llega MÁS TARDE en términos de frecuencia dominante
%
% Por eso el panel de espectros es tan informativo: se ve directamente
% cómo el "contenido frecuencial" del pulso cambia con la distancia.
%
% IMPLICACIONES PARA MASW:
%   - En suelos con D alto, las frecuencias > 40 Hz desaparecen rápidamente
%   - Esto LIMITA la resolución de la imagen c-f en alta frecuencia
%   - También limita la profundidad mínima que se puede investigar
%     (necesitamos alta frecuencia para sondear las capas superficiales)

% Parámetros del pulso
f0      = 20;     % frecuencia central [Hz]
sigma_f = 8;      % ancho espectral [Hz]

% Grilla de tiempo y frecuencia para la síntesis
N_syn  = 2048;
fs_syn = 200;          % frecuencia de muestreo [Hz]
dt_syn = 1/fs_syn;     % paso de tiempo [s]
t_syn  = (0:N_syn-1)*dt_syn;                 % tiempo total [s]
f_syn  = (0:N_syn-1)*fs_syn/N_syn;           % frecuencias [Hz]

% ESPECTRO UNILATERAL CORRECTO: N/2+1 puntos (incluye DC en f=0 y Nyquist)
% Para reconstruir N=2048 muestras se necesitan exactamente 1025 puntos:
%   Full spectrum = [X(1:1025), conj(X(1024:-1:2))] → 1025 + 1023 = 2048 ✓
nf_pos    = N_syn/2 + 1;          % = 1025 (incluye DC y Nyquist)
f_pos     = f_syn(1:nf_pos);      % [0, Δf, 2Δf, ..., fs/2]
omega_pos = 2*pi*f_pos;

% Espectro fuente: Gaussiano centrado en f0=20 Hz, ancho σ=8 Hz
S_gauss      = exp(-(f_pos - f0).^2 / (2*sigma_f^2));
S_gauss(1)   = 0;   % sin componente DC

% Distancias de los receptores (simulando el arreglo MASW)
x_geos = [5, 10, 20, 40, 60, 100];   % [m]

% Dos escenarios: elástico (D=0) y viscoelástico (D=0.05)
D_comparar = [0, 0.05];
col_main   = {'b', [0.85 0.15 0]};   % azul = elástico, rojo-naranja = visco
etiquetas  = {'Elástico (D=0)', 'Viscoelástico (D=0.05)'};

% Pre-sintetizar todas las trazas
all_traces = cell(1, 2);
for iD = 1:2
    D_k = D_comparar(iD);
    traces_k = zeros(N_syn, length(x_geos));

    for ig = 1:length(x_geos)
        x_g = x_geos(ig);

        % Velocidad dispersiva causal (Kramers-Krönig, Ec. 2.130)
        % Nota: para ω=0 usamos max(..., ε) para evitar log(0)
        V_kk_s = Vs0 * (1 + D_k/pi * log(max(omega_pos, 1e-9)/omega_ref));

        % Número de onda complejo: k* = k_R - i·α_S
        k_real = omega_pos ./ V_kk_s;           % parte real: propagación
        k_imag = omega_pos * D_k ./ V_kk_s;     % parte imag: atenuación

        % Campo espectral en posición x_g:
        % U(ω,x) = S(ω) · exp(-α_S·x) · exp(i·k_R·x)
        %           ↑ espectro     ↑ atenuación   ↑ desfase por propagación
        U_f = S_gauss .* exp(-k_imag*x_g) .* exp(1i*k_real*x_g);

        % Reconstruir espectro completo con simetría hermítica (señal real)
        % [U(0), U(1),...,U(N/2), conj(U(N/2-1)),...,conj(U(1))]
        % = [1025 puntos, 1023 puntos] = 2048 puntos ✓
        U_full = [U_f, conj(U_f(end-1:-1:2))];

        % Transformar a tiempo
        u_t = real(ifft(U_full));

        traces_k(:, ig) = u_t;
    end
    all_traces{iD} = traces_k;
end

figure('Name', 'Fig 3 — Pulso: elástico vs viscoelástico (Foti Ec. 2.128)', ...
       'NumberTitle', 'off', 'Position', [50 50 1200 680]);

% Normalización global: respecto al primer receptor en medio elástico
amp_global = max(abs(all_traces{1}(:, 1)));

t_ms = t_syn * 1000;   % tiempo en milisegundos

% --- FILA 1: wiggle plots ---
for iD = 1:2
    subplot(2, 2, iD);
    hold on;

    traces_k  = all_traces{iD};
    scale_wig = 7;   % escala de wiggle [m]

    for ig = 1:length(x_geos)
        offset   = x_geos(ig);
        tr_norm  = traces_k(:, ig) / amp_global;
        amp_rel  = max(abs(traces_k(:, ig))) / amp_global;

        % Traza wiggle
        plot(t_ms, tr_norm*scale_wig + offset, ...
            'Color', col_main{iD}, 'LineWidth', 0.9);

        % Relleno positivo (convención estándar de sísmica)
        pos_mask = tr_norm*scale_wig >= 0;
        if any(pos_mask)
            t_pos = t_ms(pos_mask);
            y_pos = tr_norm(pos_mask)*scale_wig + offset;
            fill([t_pos, t_pos(end), t_pos(1)], ...
                 [y_pos, offset, offset], ...
                 col_main{iD}, 'FaceAlpha', 0.35, 'EdgeColor', 'none', ...
                 'HandleVisibility', 'off');
        end

        % Anotación de amplitud relativa
        text(185, offset + 1.5, sprintf('A=%.2f', amp_rel), ...
            'FontSize', 7, 'Color', col_main{iD}, 'HorizontalAlignment', 'right');
    end

    xlabel('Tiempo  [ms]', 'FontSize', 10);
    ylabel('Offset  [m]', 'FontSize', 10);
    title({etiquetas{iD}, ...
           'Wiggle — trazas normalizadas al receptor más cercano'}, 'FontSize', 10);
    xlim([0, 200]);
    ylim([0, 120]);
    grid on; box on;
end

% --- FILA 2: espectros de amplitud por receptor ---
for iD = 1:2
    subplot(2, 2, iD + 2);
    hold on;

    traces_k = all_traces{iD};

    % Colormap de offsets: desde cercano (azul/rojo oscuro) a lejano (claro)
    n_geo  = length(x_geos);
    cmap_k = parula(n_geo + 2);
    cmap_k = cmap_k(2:end-1, :);   % recortar extremos

    for ig = 1:n_geo
        % Espectro de la traza
        U_tr  = abs(fft(traces_k(:, ig)));
        U_pos = U_tr(1:nf_pos) / max(U_tr(1:nf_pos));   % normalizar

        % Solo mostrar hasta 80 Hz (rango relevante)
        f_mask = f_pos <= 80;
        plot(f_pos(f_mask), U_pos(f_mask), ...
            'Color', cmap_k(ig, :), 'LineWidth', 1.8, ...
            'DisplayName', sprintf('x=%dm', x_geos(ig)));
    end

    % Espectro fuente normalizado (referencia)
    S_norm = S_gauss / max(S_gauss);
    plot(f_pos(f_pos<=80), S_norm(f_pos<=80), 'k--', 'LineWidth', 2.0, ...
        'DisplayName', 'Fuente (x=0)');

    % Línea vertical de frecuencia central
    xline(f0, ':k', sprintf('f_0=%dHz', f0), 'FontSize', 8, ...
        'LabelVerticalAlignment', 'bottom');

    xlabel('Frecuencia f  [Hz]', 'FontSize', 10);
    ylabel('Amplitud espectral norm.  [-]', 'FontSize', 10);

    if iD == 1
        title({'Espectros de amplitud — Elástico', ...
               'Todos los receptores conservan el mismo contenido frecuencial'}, ...
            'FontSize', 9);
    else
        title({'Espectros de amplitud — Viscoelástico', ...
               'Las altas frecuencias desaparecen con la distancia → pulso se "suaviza"'}, ...
            'FontSize', 9);
    end

    legend('Location', 'northeast', 'FontSize', 7);
    xlim([0, 80]);
    ylim([0, 1.15]);
    grid on; box on;
end

sgtitle({'Fig 3: Efecto de la viscoelasticidad sobre el pulso propagándose', ...
         'Fila superior: wiggles (forma del pulso)  |  Fila inferior: espectros (contenido frecuencial)', ...
         'D=0.05 → las altas frecuencias se atenúan → pulso se ensancha con la distancia'}, ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 3 generada: comparación elástico vs viscoelástico (2×2 layout).\n');
fprintf('  Panel de espectros muestra visualmente cómo el medio actúa\n');
fprintf('  como un filtro PASA-BAJOS que SE VUELVE MÁS AGRESIVO con la distancia.\n');
fprintf('  Esto explica por qué la imagen MASW se deteriora a alta f en suelos blandos.\n\n');
drawnow;

% =========================================================================
% FIGURA 4: Desacoplamiento del problema inverso (Foti Ec. 2.133)
% =========================================================================
%
% En el problema inverso viscoelástico de Rayleigh, Foti Ec. 2.133 muestra
% que en la aproximación de disipación débil (D << 1) el problema se DESACOPLA:
%
%   Fase 1: invertir la parte REAL de k*_R(ω) → perfil V_R(z)   [NO LINEAL]
%           (es exactamente la inversión elástica de p04)
%   Fase 2: invertir la parte IMAGINARIA α_R(ω) → perfil D_R(z) [LINEAL]
%           (mucho más simple: es un problema de kernel lineal)
%
% α_R(ω) ≈ Σ_j  [∂k_R/∂β_j · D_j · β_j]   (suma ponderada sobre capas)
%
% La PONDERACIÓN ∂k_R/∂β_j es la función de sensibilidad — depende de cuánta
% energía de la onda Rayleigh está concentrada en cada capa.
%
% Analogía con la sensibilidad de c_R(f) a Vs_j (vista en p04 Fig 1):
%   Alta f → λ_R corta → energía concentrada en capa superficial → sensible a D_1
%   Baja f → λ_R larga → energía en half-space → sensible a D_2

% Modelo base (del p04)
Vs1 = 120; Vs2 = 300; h1 = 10;
D1_vec = [0.01, 0.04, 0.08];   % variación del amortiguamiento de capa 1
D2     = 0.02;                  % amortiguamiento del half-space (fijo)

% Curva de dispersión elástica del modelo de 2 capas
lambda_v = linspace(1, 80, 60);
c_test_v = 60:1:320;

[c_visco, lam_visco] = MASWaves_theoretical_dispersion_curve( ...
    c_test_v, lambda_v, [h1], [250, 520], [Vs1, Vs2], [1700, 1950], 1);
c_visco   = c_visco(:)';
lam_visco = lam_visco(:)';
vv = c_visco>0; c_visco=c_visco(vv); lam_visco=lam_visco(vv);
f_visco = c_visco./lam_visco;
[f_visco, svis] = sort(f_visco); c_visco = c_visco(svis);

% Factor de participación de energía de capa 1 vs half-space
% Aproximación heurística basada en la profundidad de penetración de Rayleigh:
%   λ_R ~ 2h → la capa 1 contribuye cuando f > Vs1/(2h1) ≈ 6 Hz
%   Para f >> Vs1/(2h1): casi toda la energía está en la capa 1
%   Para f << Vs1/(2h1): casi toda la energía está en el half-space
%   P1(f) ≈ 1 - exp(-h1·f / (c_R(f)/2))  [fórmula aproximada]
P1 = 1 - exp(-h1 * f_visco ./ (c_visco/2));
P1 = min(max(P1, 0), 1);
P2 = 1 - P1;

f_transicion = Vs1 / (2*h1);   % [Hz] — frecuencia de transición

figure('Name', 'Fig 4 — Desacoplamiento inverso viscoelástico (Foti Ec. 2.133)', ...
       'NumberTitle', 'off', 'Position', [730 50 1050 490]);

% Panel izquierdo: α_R(f) para distintos D1 (D2 fijo)
subplot(1, 2, 1);
hold on;

% Fondo: zona donde α_R es sensible a D1 vs D2
f_mask_1 = f_visco >= f_transicion;
f_mask_2 = f_visco < f_transicion;
if any(f_mask_1)
    fill([f_visco(f_mask_1), fliplr(f_visco(f_mask_1))], ...
         [zeros(1,sum(f_mask_1)), ones(1,sum(f_mask_1))*0.025], ...
         [0.9 0.93 1.0], 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

colores_D1 = {[0.1 0.3 0.9], [0.9 0.5 0.1], [0.7 0.1 0.1]};
for iD = 1:length(D1_vec)
    D1_k    = D1_vec(iD);
    alpha1_k = 2*pi*f_visco * D1_k / Vs1;       % atenuación cuerpo capa 1
    alpha2   = 2*pi*f_visco * D2     / Vs2;       % atenuación cuerpo half-space
    alphaR_k = P1 .* alpha1_k + P2 .* alpha2;    % atenuación Rayleigh ponderada

    plot(f_visco, alphaR_k*1000, 'Color', colores_D1{iD}, 'LineWidth', 2.2, ...
        'DisplayName', sprintf('D_1=%.2f, D_2=%.2f', D1_k, D2));
end

xline(f_transicion, ':k', ...
    sprintf('f_{trans} = V_{S1}/(2h_1) = %.0f Hz', f_transicion), ...
    'FontSize', 8, 'LabelVerticalAlignment', 'bottom');

xlabel('Frecuencia f  [Hz]', 'FontSize', 11);
ylabel('α_R(f)  [mNp/m]', 'FontSize', 11);
title({'Coeficiente de atenuación Rayleigh α_R(f)', ...
       'Alta f → sensible a D_1 (capa 1)   Baja f → sensible a D_2 (half-space)'}, ...
    'FontSize', 10);
legend('Location', 'northwest', 'FontSize', 9);
grid on; box on;

% Panel derecho: factor de participación P1 y P2
subplot(1, 2, 2);
hold on;

% Sombrear zona de dominancia de cada capa
fill([f_visco, fliplr(f_visco)], [P1, zeros(1,length(f_visco))], ...
    [0.85 0.9 1.0], 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([f_visco, fliplr(f_visco)], [P1, ones(1,length(f_visco))], ...
    [1.0 0.9 0.85], 'EdgeColor', 'none', 'HandleVisibility', 'off');

plot(f_visco, P1, 'b-',  'LineWidth', 2.5, 'DisplayName', 'P_1: participación capa 1');
plot(f_visco, P2, 'r--', 'LineWidth', 2.5, 'DisplayName', 'P_2: participación half-space');

xline(f_transicion, ':k', ...
    sprintf('f ~ V_{S1}/(2h_1) = %.0fHz', f_transicion), ...
    'FontSize', 8, 'LabelVerticalAlignment', 'bottom');

% Línea de P1=P2=0.5 (reparto equitativo)
yline(0.5, '--k', 'P_1 = P_2 = 0.5', 'FontSize', 8, 'LabelHorizontalAlignment', 'left');

xlabel('Frecuencia f  [Hz]', 'FontSize', 11);
ylabel('Factor de participación  [-]', 'FontSize', 11);
title({'Factor de participación de energía P₁ y P₂', ...
       '(análogo a sensibilidad de c_R a Vs — ver p04 Fig 1)'}, 'FontSize', 10);
legend('Location', 'east', 'FontSize', 9);
ylim([-0.05, 1.15]);
grid on; box on;

% Caja de texto con la analogía explícita
text(max(f_visco)*0.55, 1.1, ...
    {'Analogía con Fig 1 de p04:', ...
     '  Alta f → "ve" capa 1 → α_R ∝ D_1', ...
     '  Baja f → "ve" half-space → α_R ∝ D_2', ...
     '  Invertir α_R(f) da perfil D(z)'}, ...
    'FontSize', 8, 'BackgroundColor', [1 1 0.88], 'EdgeColor', [0.7 0.7 0], ...
    'HorizontalAlignment', 'left', 'LineWidth', 1.0);

sgtitle({'Fig 4: Problema inverso viscoelástico desacoplado (Foti Ec. 2.133)', ...
         'Fase 1: V_R(z) de c_R(f)  [no lineal — igual que p04]', ...
         'Fase 2: D_R(z) de α_R(f)  [lineal — sistema de kernels ponderados]'}, ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 4 generada: atenuación de Rayleigh y desacoplamiento inverso.\n');
fprintf('  El desacoplamiento (Foti Ec. 2.133) es clave para la práctica MASW:\n');
fprintf('  1. Primero se invierte c_R(f) → V_R(z) con métodos estándar (p04)\n');
fprintf('  2. Luego se mide α_R(f) de la amplitud del shot gather\n');
fprintf('  3. Se resuelve un sistema lineal → D_R(z) por capas\n\n');
drawnow;

% =========================================================================
% RESUMEN FINAL — Cierre del Capítulo 2
% =========================================================================

fprintf('=================================================================\n');
fprintf(' RESUMEN — Viscoelasticidad (Foti Sec. 2.5)\n');
fprintf('=================================================================\n\n');
fprintf('CONCEPTOS CUBIERTOS EN ESTE SCRIPT:\n');
fprintf('  1. G*(ω) = G₁ + i·G₂ — módulo complejo viscoelástico\n');
fprintf('  2. D = G₂/(2G₁) — factor de amortiguamiento (típico 1–5%% en suelos)\n');
fprintf('  3. V*(ω) ≈ V(ω)(1 + iD) — velocidad compleja (disipación débil, Ec. 2.128)\n');
fprintf('  4. k* = k_R - iα: número de onda complejo → α atenúa la onda con x\n');
fprintf('  5. Kramers-Krönig: V(ω) y D(ω) no son independientes (causalidad)\n');
fprintf('  6. Desacoplamiento inverso: Fase 1 = V(z) no lineal, Fase 2 = D(z) lineal\n\n');
fprintf('IMPLICACIONES PRÁCTICAS PARA MASW:\n');
fprintf('  - D alto → altas frecuencias desaparecen → imagen c-f ruidosa en alta f\n');
fprintf('  - Kramers-Krönig → pequeña dispersión intrínseca en V(ω) (del material)\n');
fprintf('    Se superpone a la dispersión GEOMÉTRICA de las capas\n');
fprintf('  - D puede extraerse de α_R(f) medido (segunda parte del problema inverso)\n\n');
fprintf('=================================================================\n');
fprintf(' FIN DE LA SERIE PRUEBAS TEÓRICAS — CAPÍTULO 2\n');
fprintf('=================================================================\n');
fprintf('  p01: ondas de cuerpo (P y S) en medio homogéneo\n');
fprintf('  p02: ondas superficiales (Rayleigh y Love) — half-space y 2 capas\n');
fprintf('  p03: sismograma sintético + imagen de dispersión c-f (MASWaves)\n');
fprintf('  p04: inversión de c_R(f) → perfil Vs(z) — sensibilidad, no-unicidad\n');
fprintf('  p05: viscoelasticidad — amortiguamiento, Kramers-Krönig, α_R(f)\n');
fprintf('=================================================================\n');
