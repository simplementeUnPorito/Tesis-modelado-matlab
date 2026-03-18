%%
% p04_inversion_perfil_vs.m
% =========================================================================
% PRUEBA TEÓRICA 04 — Inversión de la curva de dispersión → perfil Vs(z)
% =========================================================================
%
% OBJETIVO
%   Entender qué significa "invertir" una curva de dispersión y cuáles son
%   los problemas fundamentales del proceso. Este script NO pretende hacer
%   una inversión de producción — pretende construir intuición sobre:
%
%     1. Sensibilidad: qué parámetro del suelo controla qué parte de c(f)
%     2. No-unicidad:  distintos perfiles Vs(z) pueden ajustar la misma curva
%     3. Grid search:  la forma más simple de inversión — buscar el mínimo
%        del misfit en un espacio de parámetros discretizado
%     4. El perfil Vs(z) como producto final de MASW
%
% FLUJO
%   Partimos de la CURVA DE DISPERSIÓN TEÓRICA del modelo de 2 capas de p02/p03
%   (que actúa como la "curva medida en campo"). Luego:
%     a) Perturbar los parámetros y ver cómo cambia la curva (sensibilidad)
%     b) Grid search sobre Vs1 y h1 — visualizar la superficie de misfit
%     c) Comparar perfil verdadero vs perfil invertido
%
% FUNCIÓN CLAVE
%   MASWaves_theoretical_dispersion_curve(c_test, lambda, h, alpha, beta, rho, n)
%   MASWaves_misfit(c_t, c_curve0)
%   — ambas disponibles vía init_project() → genpath(third_party/MASW-Matlab-code/)
%
% NOTA TÉCNICA: DIMENSIONES DE MASWaves
%   MASWaves_theoretical_dispersion_curve retorna:
%     c_t      = vector COLUMNA (N×1)   [inicializado con zeros(N,1)]
%     lambda_t = vector FILA   (1×N)   [crece sin pre-alocar en el loop]
%   Esto provoca broadcasting no deseado si se mezclan ambos en operaciones
%   aritméticas. SOLUCIÓN: forzar fila con (:)' inmediatamente después de
%   cada llamada. Esto asegura que c ./ lam sea siempre 1×M y no M×M.
%
% CÓMO CORRER
%   >> init_project()
%   >> p04_inversion_perfil_vs
%
% REFERENCIA PRINCIPAL
%   Foti, S. — Cap. 2, Sec. 2.4 (eigenproblema, dispersión en capas)
%   Foti, S. — Cap. 4 (inversión MASW — ver cuando lleguemos ahí)
%   Concepto de misfit: MASWaves_misfit (Ecs. implementadas en la librería)
%
% =========================================================================

close all; clear; clc;

fprintf('=================================================================\n');
fprintf(' PRUEBA TEÓRICA 04 — Inversión de curva de dispersión → Vs(z)\n');
fprintf('=================================================================\n\n');

% =========================================================================
% PARTE 0: MODELO VERDADERO Y CURVA DE DISPERSIÓN DE REFERENCIA
% =========================================================================
%
% Este es el modelo que MASW debería recuperar. En un ensayo real, no se
% conoce — este script simula el caso en que SÍ lo conocemos para poder
% evaluar qué tan bien funciona la inversión.

% --- Modelo verdadero (2 capas) ---
h_true   = [10];           % espesor capa 1 [m]
Vs_true  = [120, 300];     % Vs: [capa 1, half-space] [m/s]
Vp_true  = [250, 520];     % Vp: [capa 1, half-space] [m/s]
rho_true = [1700, 1950];   % densidad: [capa 1, half-space] [kg/m³]
n_true   = 1;              % número de capas finitas

% --- Calcular la curva de dispersión del modelo verdadero ---
% Esta es nuestra "medición de campo" sintética.
lambda_ref = linspace(1, 120, 80);   % longitudes de onda [m]
c_test_ref = 50:1:350;               % velocidades de prueba [m/s]

[c_ref, lam_ref] = MASWaves_theoretical_dispersion_curve( ...
    c_test_ref, lambda_ref, h_true, Vp_true, Vs_true, rho_true, n_true);

% CRÍTICO: forzar vectores fila para evitar broadcasting MxM
% MASWaves devuelve c_t columna (Nx1) y lambda_t fila (1xN) — si no se
% normaliza, c./lam produce una matriz NxN en vez de un vector Nx1.
c_ref   = c_ref(:)';
lam_ref = lam_ref(:)';

% Filtrar puntos sin solución (MASWaves deja 0 donde no convergió)
valid   = c_ref > 0;
c_ref   = c_ref(valid);
lam_ref = lam_ref(valid);
f_ref   = c_ref ./ lam_ref;           % frecuencia [Hz]

% Ordenar por frecuencia creciente
[f_ref, isort] = sort(f_ref);
c_ref   = c_ref(isort);
lam_ref = lam_ref(isort);

fprintf('Curva de referencia (modelo verdadero): %d puntos, f=[%.1f, %.1f] Hz\n\n', ...
    length(f_ref), min(f_ref), max(f_ref));

% =========================================================================
% FIGURA 1: Sensibilidad — cómo cambia c(f) al cambiar cada parámetro
% =========================================================================
%
% La sensibilidad responde a la pregunta: ¿qué parámetros del suelo podemos
% recuperar bien y cuáles son difíciles de determinar?
%
% Regla empírica (Foti Cap. 4):
%   - Vs1 (capa superficial) controla c_R a ALTA frecuencia (λ corta)
%   - Vs2 (half-space)       controla c_R a BAJA  frecuencia (λ larga)
%   - h1  (espesor de capa)  controla la FRECUENCIA de TRANSICIÓN entre los dos
%
% Esta figura muestra esas 3 perturbaciones: +20% en cada parámetro.
% La diferencia con la curva verdadera es la "sensibilidad local".

pert = 0.20;   % perturbación del 20% en cada parámetro

% Perturbar Vs1 (+20%) — debería mover la parte derecha de la curva
Vs_pert_1 = [Vs_true(1)*(1+pert), Vs_true(2)];
[c_p1, lam_p1] = MASWaves_theoretical_dispersion_curve( ...
    c_test_ref, lambda_ref, h_true, Vp_true, Vs_pert_1, rho_true, n_true);
c_p1 = c_p1(:)'; lam_p1 = lam_p1(:)';
v1 = c_p1>0; c_p1=c_p1(v1); lam_p1=lam_p1(v1);
f_p1=c_p1./lam_p1; [f_p1,s]=sort(f_p1); c_p1=c_p1(s);

% Perturbar Vs2 (+20%) — debería mover la parte izquierda de la curva
Vs_pert_2 = [Vs_true(1), Vs_true(2)*(1+pert)];
[c_p2, lam_p2] = MASWaves_theoretical_dispersion_curve( ...
    c_test_ref, lambda_ref, h_true, Vp_true, Vs_pert_2, rho_true, n_true);
c_p2 = c_p2(:)'; lam_p2 = lam_p2(:)';
v2 = c_p2>0; c_p2=c_p2(v2); lam_p2=lam_p2(v2);
f_p2=c_p2./lam_p2; [f_p2,s]=sort(f_p2); c_p2=c_p2(s);

% Perturbar h1 (+20%) — debería desplazar la zona de transición en frecuencia
h_pert = [h_true(1)*(1+pert)];
[c_p3, lam_p3] = MASWaves_theoretical_dispersion_curve( ...
    c_test_ref, lambda_ref, h_pert, Vp_true, Vs_true, rho_true, n_true);
c_p3 = c_p3(:)'; lam_p3 = lam_p3(:)';
v3 = c_p3>0; c_p3=c_p3(v3); lam_p3=lam_p3(v3);
f_p3=c_p3./lam_p3; [f_p3,s]=sort(f_p3); c_p3=c_p3(s);

figure('Name', 'Fig 1 — Sensibilidad de c(f) a los parámetros del suelo', ...
       'NumberTitle', 'off', 'Position', [50 550 1100 450]);

% --- Panel izquierdo: c vs f ---
subplot(1, 2, 1);
hold on;

% Zona de influencia como bandas de fondo
f_mid = max(f_ref) * 0.4;   % frecuencia de transición aproximada
fill([f_mid max(f_ref)*1.1 max(f_ref)*1.1 f_mid], [70 70 330 330], ...
    [0.9 0.93 1.0], 'EdgeColor', 'none', 'HandleVisibility', 'off');    % azul claro = zona Vs1
fill([0 f_mid f_mid 0], [70 70 330 330], ...
    [1.0 0.93 0.9], 'EdgeColor', 'none', 'HandleVisibility', 'off');    % naranja claro = zona Vs2

plot(f_ref, c_ref, 'k-',  'LineWidth', 3.0, 'DisplayName', 'Modelo verdadero');
plot(f_p1,  c_p1,  'b--', 'LineWidth', 1.8, 'DisplayName', sprintf('V_{S1} +%.0f%%', pert*100));
plot(f_p2,  c_p2,  'r--', 'LineWidth', 1.8, 'DisplayName', sprintf('V_{S2} +%.0f%%', pert*100));
plot(f_p3,  c_p3,  '--', 'LineWidth', 1.8, 'Color', [0 0.55 0], ...
    'DisplayName', sprintf('h_1 +%.0f%%',    pert*100));

xlabel('Frecuencia f  [Hz]', 'FontSize', 11);
ylabel('c_R  [m/s]', 'FontSize', 11);
title({'Efecto de +20% en cada parámetro sobre c_R(f)', ...
       'Cada parámetro controla una región distinta de la curva'}, 'FontSize', 10);
legend('Location', 'southeast', 'FontSize', 9);
grid on; box on;

xlim([0, max(f_ref)*1.1]);
ylim([80, 330]);

% Anotaciones de zonas
text(max(f_ref)*0.72, 100, {'Alta f:', 'V_{S1} domina'}, ...
    'FontSize', 8, 'Color', [0.1 0.1 0.8], 'HorizontalAlignment', 'center', ...
    'BackgroundColor', [0.95 0.97 1.0]);
text(max(f_ref)*0.15, 310, {'Baja f:', 'V_{S2} domina'}, ...
    'FontSize', 8, 'Color', [0.8 0.1 0.1], 'HorizontalAlignment', 'center', ...
    'BackgroundColor', [1.0 0.97 0.95]);
xline(f_mid, ':k', 'Transición', 'FontSize', 8, 'LabelVerticalAlignment', 'bottom');

% --- Panel derecho: sensibilidad absoluta |Δc| ---
subplot(1, 2, 2);
hold on;

% Interpolar las curvas perturbadas en las frecuencias de referencia
c_p1_interp = interp1(f_p1, c_p1, f_ref, 'linear', NaN);
c_p2_interp = interp1(f_p2, c_p2, f_ref, 'linear', NaN);
c_p3_interp = interp1(f_p3, c_p3, f_ref, 'linear', NaN);

dc1 = abs(c_p1_interp - c_ref);
dc2 = abs(c_p2_interp - c_ref);
dc3 = abs(c_p3_interp - c_ref);

% Área bajo la curva para cuantificar sensibilidad total
sens_Vs1 = nansum(dc1) * (f_ref(2)-f_ref(1));
sens_Vs2 = nansum(dc2) * (f_ref(2)-f_ref(1));
sens_h1  = nansum(dc3) * (f_ref(2)-f_ref(1));

area(f_ref, dc1, 'FaceColor', [0.8 0.85 1.0], 'EdgeColor', 'none', 'HandleVisibility', 'off');
area(f_ref, dc2, 'FaceColor', [1.0 0.85 0.8], 'EdgeColor', 'none', 'HandleVisibility', 'off');

plot(f_ref, dc1, 'b-', 'LineWidth', 2.2, ...
    'DisplayName', sprintf('|Δc_R| si V_{S1} +%.0f%%  (Σ=%.0f m/s·Hz)', pert*100, sens_Vs1));
plot(f_ref, dc2, 'r-', 'LineWidth', 2.2, ...
    'DisplayName', sprintf('|Δc_R| si V_{S2} +%.0f%%  (Σ=%.0f m/s·Hz)', pert*100, sens_Vs2));
plot(f_ref, dc3, '-', 'LineWidth', 2.2, 'Color', [0 0.55 0], ...
    'DisplayName', sprintf('|Δc_R| si h_1 +%.0f%%      (Σ=%.0f m/s·Hz)', pert*100, sens_h1));

xlabel('Frecuencia f  [Hz]', 'FontSize', 11);
ylabel('|Δc_R|  [m/s]', 'FontSize', 11);
title({'Sensibilidad absoluta |c_{perturbado} - c_{verdadero}|', ...
       'Área sombreada ∝ influencia total del parámetro'}, 'FontSize', 10);
legend('Location', 'northeast', 'FontSize', 8);
grid on; box on;
xlim([0, max(f_ref)*1.1]);
ylim([0, 50]);

sgtitle({'Fig 1: Sensibilidad de la curva de dispersión a los parámetros del modelo', ...
         '(Modelo: V_{S1}=120 m/s, V_{S2}=300 m/s, h_1=10 m  |  +20% de perturbación)'}, ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 1 generada: análisis de sensibilidad.\n');
fprintf('  Vs1 afecta principalmente las frecuencias altas (> %.0f Hz).\n', f_mid);
fprintf('  Vs2 afecta principalmente las frecuencias bajas  (< %.0f Hz).\n', f_mid);
fprintf('  h1  desplaza la zona de transición entre los dos regímenes.\n');
fprintf('  Sensibilidad integrada: Vs1=%.0f, Vs2=%.0f, h1=%.0f [m/s·Hz]\n\n', ...
    sens_Vs1, sens_Vs2, sens_h1);
drawnow;

% =========================================================================
% FIGURA 2: No-unicidad — distintos modelos, misma curva
% =========================================================================
%
% Este es el problema más serio de la inversión MASW (y de cualquier
% inversión geofísica):
%
%   El problema inverso es UNDERDETERMINED e ILL-POSED:
%     - Hay infinitos modelos Vs(z) que ajustan c_R(f) dentro del error.
%     - La solución no es única.
%     - Pequeños cambios en c(f) pueden dar grandes cambios en Vs(z).
%
% Aquí mostramos dos modelos distintos que tienen un misfit muy similar:
%   - Modelo A: escalón abrupto (contraste fuerte en la interfaz) — verdadero
%   - Modelo B: gradiente suave (5 capas simulando incremento gradual)
%
% Ambos ajustan la misma curva de dispersión razonablemente bien.
% Esto ilustra por qué la inversión MASW debe complementarse con
% información a priori (perfiles de referencia, ensayos CPT, etc.)

% Modelo B: gradiente suave (4 capas + half-space simulando gradiente)
n_B   = 4;
h_B   = [3, 3, 3, 3];                      % capas de 3 m cada una
Vs_B  = [100, 150, 210, 270, 300];          % gradiente suave hasta Vs2
Vp_B  = [210, 310, 430, 530, 520];
rho_B = [1650, 1750, 1850, 1900, 1950];

[c_B, lam_B] = MASWaves_theoretical_dispersion_curve( ...
    c_test_ref, lambda_ref, h_B, Vp_B, Vs_B, rho_B, n_B);
c_B = c_B(:)'; lam_B = lam_B(:)';
vB = c_B>0; c_B=c_B(vB); lam_B=lam_B(vB);
f_B=c_B./lam_B; [f_B,s]=sort(f_B); c_B=c_B(s);

% Misfit modelo verdadero consigo mismo (debería ser ≈ 0)
[c_A_chk, ~] = MASWaves_theoretical_dispersion_curve( ...
    c_test_ref, lam_ref, h_true, Vp_true, Vs_true, rho_true, n_true);
c_A_chk = c_A_chk(:)';
vA = c_A_chk > 0;
c_A_chk_v = c_A_chk(vA);
n_chk_A = min(length(c_A_chk_v), length(c_ref));
misfit_A = MASWaves_misfit(c_A_chk_v(1:n_chk_A), c_ref(1:n_chk_A));

% Misfit modelo B
[c_B_chk, ~] = MASWaves_theoretical_dispersion_curve( ...
    c_test_ref, lam_ref, h_B, Vp_B, Vs_B, rho_B, n_B);
c_B_chk = c_B_chk(:)';
vB2 = c_B_chk > 0;
c_B_chk_v = c_B_chk(vB2);
n_chk_B = min(length(c_B_chk_v), length(c_ref));
misfit_B = MASWaves_misfit(c_B_chk_v(1:n_chk_B), c_ref(1:n_chk_B));

figure('Name', 'Fig 2 — No-unicidad: distintos Vs(z), curvas similares', ...
       'NumberTitle', 'off', 'Position', [50 80 1100 480]);

% Panel izquierdo: perfiles Vs(z)
subplot(1, 2, 1);
hold on;

% Sombrear la zona de investigación (profundidad efectiva ≈ λmax/3)
z_invest = max(lam_ref)/3;
fill([50 360 360 50], [-z_invest -z_invest 0 0], ...
    [0.85 1.0 0.85], 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([50 360 360 50], [-50 -50 -z_invest -z_invest], ...
    [0.95 0.95 0.95], 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Perfil verdadero (escalón)
z_A = [0, h_true(1), h_true(1), 50];
Vs_A_plot = [Vs_true(1), Vs_true(1), Vs_true(2), Vs_true(2)];
plot(Vs_A_plot, -z_A, 'k-', 'LineWidth', 3.5, 'DisplayName', ...
    sprintf('Modelo A: escalón  ε=%.1f%%', misfit_A));

% Perfil B (gradiente)
z_B_plot = [0];
Vs_B_plot = [];
for i = 1:n_B
    z_B_plot = [z_B_plot, sum(h_B(1:i-1)), sum(h_B(1:i))];
    Vs_B_plot = [Vs_B_plot, Vs_B(i), Vs_B(i)];
end
z_B_plot = [z_B_plot, sum(h_B)+20];
Vs_B_plot = [Vs_B_plot, Vs_B(end), Vs_B(end)];
plot(Vs_B_plot, -z_B_plot, 'b--', 'LineWidth', 2.2, 'DisplayName', ...
    sprintf('Modelo B: gradiente  ε=%.1f%%', misfit_B));

% Línea de interfaz del modelo verdadero
yline(-h_true(1), ':k', sprintf('Interfaz real z=%.0fm', h_true(1)), ...
    'FontSize', 8, 'LabelHorizontalAlignment', 'left');
yline(-z_invest, '--', sprintf('Profundidad efectiva λ_{max}/3=%.0fm', z_invest), ...
    'FontSize', 8, 'Color', [0.5 0.5 0.5], 'LabelHorizontalAlignment', 'left');

% Texto de zona ciega
text(120, -42, {'Zona de poca', 'sensibilidad'}, ...
    'FontSize', 8, 'Color', [0.5 0.5 0.5], 'HorizontalAlignment', 'center');

xlabel('V_S  [m/s]', 'FontSize', 11);
ylabel('Profundidad z  [m]', 'FontSize', 11);
title({'Perfiles Vs(z): escalón (verdadero) vs gradiente suave', ...
       'Dos modelos geológicamente muy distintos'}, 'FontSize', 10);
legend('Location', 'southeast', 'FontSize', 9);
xlim([50, 360]);
ylim([-50, 2]);
grid on; box on;

% Panel derecho: curvas de dispersión — ¿se puede distinguir?
subplot(1, 2, 2);
hold on;

% Banda de error de medición típico en MASW (±5 m/s)
fill([f_ref, fliplr(f_ref)], [c_ref+5, fliplr(c_ref-5)], ...
    [0.85 0.85 0.85], 'EdgeColor', 'none', 'DisplayName', '±5 m/s (error típico MASW)');

plot(f_ref, c_ref, 'k-',  'LineWidth', 3,   'DisplayName', 'Curva ref. (medición)');
plot(f_B,   c_B,   'b--', 'LineWidth', 2.0,  'DisplayName', sprintf('Modelo B  ε=%.1f%%', misfit_B));

% Flechas anotando qué frecuencia "ve" cada profundidad
f_interface = mean(c_ref(c_ref < (Vs_true(1)*0.95 + Vs_true(2)*0.05))) / h_true(1);
text(20, 150, {'A alta f: Rayleigh ve', 'solo capa superficial'}, ...
    'FontSize', 8, 'Color', [0 0 0.7], 'HorizontalAlignment', 'center');
text(5, 280, {'A baja f: Rayleigh ve', 'el half-space'}, ...
    'FontSize', 8, 'Color', [0 0 0.7], 'HorizontalAlignment', 'center');

xlabel('Frecuencia f  [Hz]', 'FontSize', 11);
ylabel('c_R  [m/s]', 'FontSize', 11);
title({'Curvas de dispersión — misfit similar en ambos modelos', ...
       sprintf('Si el error de medición > %.1f%%, no se puede distinguir', ...
       max(misfit_A, misfit_B)*1.2)}, 'FontSize', 10);
legend('Location', 'southeast', 'FontSize', 9);
xlim([0, max(f_ref)*1.1]);
ylim([80, 330]);
grid on; box on;

sgtitle({'Fig 2: No-unicidad de la inversión MASW', ...
         'Distintos Vs(z) pueden producir la misma c_R(f) dentro del error de medición', ...
         '→  sin información a priori no se puede elegir entre ellos'}, ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 2 generada: no-unicidad del problema inverso.\n');
fprintf('  Misfit modelo A (verdadero):   ε = %.2f%%\n', misfit_A);
fprintf('  Misfit modelo B (gradiente):   ε = %.2f%%\n', misfit_B);
fprintf('  Si el error de picking es > %.1f%%, no se puede distinguir entre A y B.\n', ...
    max(misfit_A, misfit_B));
fprintf('  IMPLICACIÓN: siempre reportar la no-unicidad en estudios MASW reales.\n\n');
drawnow;

% =========================================================================
% FIGURA 3: Grid search — superficie de misfit en espacio Vs1 × h1
% =========================================================================
%
% La inversión por grid search es la forma más directa (y más lenta) de
% resolver el problema inverso:
%
%   Para cada combinación (Vs1_i, h1_j) en una grilla discreta:
%     1. Calcular la curva de dispersión teórica con MASWaves
%     2. Calcular el misfit ε = MASWaves_misfit(c_teor, c_ref)
%   Tomar el modelo con menor misfit como la solución.
%
% Visualizamos la SUPERFICIE de misfit en 2D: es el "paisaje de error"
% que un algoritmo de inversión tiene que explorar para encontrar el mínimo.
%
% Conceptos clave visibles en esta figura:
%   a) El mínimo global: la solución óptima
%   b) La FORMA del mínimo: si es estrecho → alta resolución en ese parámetro
%                           si es elongado → trade-off entre 2 parámetros
%   c) La existencia de mínimos secundarios (no-unicidad de nuevo)

Vs1_grid = 80:5:180;        % rango de búsqueda para Vs1 [m/s]
h1_grid  = 5:1:20;          % rango de búsqueda para h1 [m]

n_Vs1 = length(Vs1_grid);
n_h1  = length(h1_grid);

misfit_grid = nan(n_h1, n_Vs1);   % filas = h1, columnas = Vs1

fprintf('Ejecutando grid search (%d × %d = %d evaluaciones)...\n', ...
    n_h1, n_Vs1, n_h1*n_Vs1);

for i_h = 1:n_h1
    for i_v = 1:n_Vs1
        h_try  = [h1_grid(i_h)];
        Vs_try = [Vs1_grid(i_v), Vs_true(2)];   % Vs2 fija = verdadera

        [c_try, ~] = MASWaves_theoretical_dispersion_curve( ...
            c_test_ref, lam_ref, h_try, Vp_true, Vs_try, rho_true, 1);
        c_try = c_try(:)';   % forzar fila

        vt = c_try > 0;
        if sum(vt) >= 3
            c_try_v = c_try(vt);
            n_min   = min(length(c_try_v), length(c_ref));
            if n_min >= 2
                misfit_grid(i_h, i_v) = MASWaves_misfit(c_try_v(1:n_min), c_ref(1:n_min));
            end
        end
    end
end

% Encontrar el mínimo global
[row_min, col_min] = find(misfit_grid == min(misfit_grid(:)));
Vs1_opt = Vs1_grid(col_min(1));
h1_opt  = h1_grid(row_min(1));

fprintf('  Mínimo encontrado: Vs1 = %d m/s, h1 = %.0f m, ε = %.2f%%\n', ...
    Vs1_opt, h1_opt, misfit_grid(row_min(1), col_min(1)));
fprintf('  Modelo verdadero:  Vs1 = %d m/s, h1 = %.0f m\n\n', Vs_true(1), h_true(1));

figure('Name', 'Fig 3 — Grid search: superficie de misfit Vs1 × h1', ...
       'NumberTitle', 'off', 'Position', [730 550 950 490]);

subplot(1, 2, 1);

% Mapa de misfit con colormap perceptualmente uniforme
imagesc(Vs1_grid, h1_grid, misfit_grid);
axis xy;
colormap(parula);   % parula: progresivo azul→amarillo, buen contraste
cb = colorbar;
cb.Label.String = 'Misfit ε  [%]';
cb.FontSize = 9;
hold on;

% Contornos sobre el heatmap: revelan la "topografía" del espacio de parámetros
% Los contornos elongados indican trade-offs (no se puede determinar solo
% Vs1 sin conocer h1 y viceversa)
[C_lev, h_cont] = contour(Vs1_grid, h1_grid, misfit_grid, ...
    [1 2 3 5 8 12 20], 'w-', 'LineWidth', 0.8);
clabel(C_lev, h_cont, 'FontSize', 7, 'Color', 'w', 'LabelSpacing', 120);

% Marcar el mínimo encontrado por grid search
plot(Vs1_opt, h1_opt, 'co', 'MarkerSize', 13, 'LineWidth', 2.5, ...
    'DisplayName', sprintf('Grid min: Vs1=%d, h1=%.0f', Vs1_opt, h1_opt));

% Marcar la solución verdadera
plot(Vs_true(1), h_true(1), 'r^', 'MarkerSize', 13, 'LineWidth', 2.5, ...
    'MarkerFaceColor', 'r', 'DisplayName', sprintf('Verdadero: Vs1=%d, h1=%.0f', Vs_true(1), h_true(1)));

xlabel('V_{S1}  [m/s]', 'FontSize', 11);
ylabel('h_1  [m]', 'FontSize', 11);
title({'Superficie de misfit ε(V_{S1}, h_1)', ...
       'Curvas de nivel blancas = iso-misfit (trade-off Vs1↔h1)'}, 'FontSize', 10);
legend('Location', 'northeast', 'FontSize', 8, 'TextColor', 'w', 'Color', [0.2 0.2 0.2]);

% Panel derecho: dos cortes de la superficie — Vs1 fijo y h1 fijo
subplot(1, 2, 2);
hold on;

[~, ih_true] = min(abs(h1_grid - h_true(1)));     % fila más cercana a h1=10
[~, iv_true] = min(abs(Vs1_grid - Vs_true(1)));   % columna más cercana a Vs1=120

% Corte horizontal: ε vs Vs1 con h1=h1_verdadero
yyaxis left;
plot(Vs1_grid, misfit_grid(ih_true, :), 'b-', 'LineWidth', 2.2, ...
    'DisplayName', sprintf('ε vs V_{S1}  (h_1 = %.0f m)', h1_grid(ih_true)));
xline(Vs_true(1), '--b', sprintf('V_{S1}=%.0f', Vs_true(1)), ...
    'FontSize', 8, 'LabelVerticalAlignment', 'bottom');
ylabel('Misfit ε  [%]  —  corte h_1 cte.', 'FontSize', 10, 'Color', 'b');
set(gca, 'YColor', 'b');

% Corte vertical: ε vs h1 con Vs1=Vs1_verdadero (eje Y derecho)
yyaxis right;
plot(Vs1_grid(1) + (h1_grid - h1_grid(1)) * ...
    (Vs1_grid(end)-Vs1_grid(1))/(h1_grid(end)-h1_grid(1)), ...
    misfit_grid(:, iv_true)', 'r-', 'LineWidth', 2.2, ...
    'DisplayName', sprintf('ε vs h_1  (V_{S1} = %.0f m/s)', Vs1_grid(iv_true)));
ylabel('Misfit ε  [%]  —  corte V_{S1} cte.', 'FontSize', 10, 'Color', 'r');
set(gca, 'YColor', 'r');

xlabel('V_{S1}  [m/s]  (eje normalizado para superponer cortes)', 'FontSize', 10);
title({'Cortes de la superficie de misfit', ...
       'Azul: ε vs V_{S1}  |  Rojo: ε vs h_1'}, 'FontSize', 10);
grid on; box on;

sgtitle({'Fig 3: Grid search — espacio de parámetros Vs1 × h1 (Vs2 fijo = verdadero)', ...
         'Contornos blancos = iso-misfit  |  Valle elongado = trade-off entre parámetros'}, ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 3 generada: grid search en 2D.\n');
fprintf('  El mínimo no siempre coincide exactamente con la verdad porque:\n');
fprintf('  (1) resolución discreta de la grilla, (2) no-unicidad,\n');
fprintf('  (3) si el valle es elongado → trade-off Vs1-h1 → múltiples buenos modelos.\n\n');
drawnow;

% =========================================================================
% FIGURA 4: Perfil Vs(z) final — verdadero vs invertido
% =========================================================================
%
% Comparación entre el modelo verdadero y el modelo recuperado por
% grid search. También se muestra la curva de dispersión del modelo
% invertido superpuesta a la curva de referencia para ver el ajuste.

% Modelo invertido (óptimo del grid search)
h_inv   = [h1_opt];
Vs_inv  = [Vs1_opt, Vs_true(2)];
Vp_inv  = Vp_true;
rho_inv = rho_true;

[c_inv, lam_inv] = MASWaves_theoretical_dispersion_curve( ...
    c_test_ref, lambda_ref, h_inv, Vp_inv, Vs_inv, rho_inv, 1);
c_inv = c_inv(:)'; lam_inv = lam_inv(:)';
vi = c_inv>0; c_inv=c_inv(vi); lam_inv=lam_inv(vi);
f_inv = c_inv./lam_inv; [f_inv,si]=sort(f_inv); c_inv=c_inv(si);

% Misfit del modelo invertido
[c_inv_chk, ~] = MASWaves_theoretical_dispersion_curve( ...
    c_test_ref, lam_ref, h_inv, Vp_inv, Vs_inv, rho_inv, 1);
c_inv_chk = c_inv_chk(:)';
vi2 = c_inv_chk>0; c_inv_chk_v = c_inv_chk(vi2);
n_c = min(length(c_inv_chk_v), length(c_ref));
misfit_inv = MASWaves_misfit(c_inv_chk_v(1:n_c), c_ref(1:n_c));

figure('Name', 'Fig 4 — Resultado final: Vs(z) verdadero vs invertido', ...
       'NumberTitle', 'off', 'Position', [730 50 1000 520]);

% Panel izquierdo: perfil Vs(z)
subplot(1, 2, 1);
hold on;

z_max_plot = 40;

% Sombrear zona investigada vs zona ciega
z_inv_max = max(lam_ref)/3;
fill([50 360 360 50], [0 0 -z_inv_max -z_inv_max], ...
    [0.85 1.0 0.85], 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([50 360 360 50], [-z_inv_max -z_inv_max -z_max_plot -z_max_plot], ...
    [0.95 0.95 0.95], 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Perfil verdadero
zv = [0, h_true(1), h_true(1), z_max_plot];
cv_plot = [Vs_true(1), Vs_true(1), Vs_true(2), Vs_true(2)];
plot(cv_plot, -zv, 'k-', 'LineWidth', 3.5, ...
    'DisplayName', sprintf('Verdadero  V_{S1}=%dm/s, h_1=%.0fm', Vs_true(1), h_true(1)));

% Perfil invertido
zi_p = [0, h_inv(1), h_inv(1), z_max_plot];
ci_plot = [Vs_inv(1), Vs_inv(1), Vs_inv(2), Vs_inv(2)];
plot(ci_plot, -zi_p, 'r--', 'LineWidth', 2.5, ...
    'DisplayName', sprintf('Invertido  V_{S1}=%dm/s, h_1=%.0fm', Vs_inv(1), h_inv(1)));

% Líneas de asíntota de Rayleigh
yline(-z_inv_max, '--', sprintf('λ_{max}/3 = %.0f m (profundidad efectiva)', z_inv_max), ...
    'FontSize', 8, 'Color', [0.4 0.7 0.4], 'LabelHorizontalAlignment', 'left');

% Caja de resultados
err_Vs1 = abs(Vs1_opt - Vs_true(1));
err_h1  = abs(h1_opt  - h_true(1));
text(195, -32, {sprintf('ΔV_{S1} = %d m/s (%.0f%%)', err_Vs1, 100*err_Vs1/Vs_true(1)), ...
                sprintf('Δh_1    = %.0f m  (%.0f%%)', err_h1, 100*err_h1/h_true(1)), ...
                sprintf('ε final = %.2f%%', misfit_inv)}, ...
    'FontSize', 9, 'BackgroundColor', [1 1 0.88], 'EdgeColor', [0.7 0.7 0], ...
    'LineWidth', 1.2);

% Etiquetas de zona
text(100, -z_inv_max/2, 'Zona investigada', ...
    'FontSize', 8, 'Color', [0.2 0.5 0.2], 'HorizontalAlignment', 'center');
text(100, -(z_inv_max + (z_max_plot-z_inv_max)/2), 'Zona ciega (poca sensibilidad)', ...
    'FontSize', 8, 'Color', [0.5 0.5 0.5], 'HorizontalAlignment', 'center');

xlabel('V_S  [m/s]', 'FontSize', 12);
ylabel('Profundidad z  [m]', 'FontSize', 12);
title({'Perfil Vs(z): modelo verdadero vs. invertido', ...
       'Grid search en espacio Vs1 × h1 (Vs2 fijo)'}, 'FontSize', 10);
legend('Location', 'southeast', 'FontSize', 9);
xlim([50, 360]);
ylim([-z_max_plot, 2]);
grid on; box on;

% Panel derecho: ajuste de la curva de dispersión
subplot(1, 2, 2);
hold on;

% Banda de incertidumbre
fill([f_ref, fliplr(f_ref)], [c_ref+3, fliplr(c_ref-3)], ...
    [0.85 0.85 0.85], 'EdgeColor', 'none', 'DisplayName', '±3 m/s incertidumbre');

plot(f_ref, c_ref, 'k-',  'LineWidth', 3.2, 'DisplayName', 'Curva medida (referencia)');
plot(f_inv, c_inv, 'r--', 'LineWidth', 2.2, ...
    'DisplayName', sprintf('Modelo invertido  ε=%.2f%%', misfit_inv));

% Líneas de asíntota (valores de Rayleigh en homogéneo)
yline(0.9194*Vs_true(1), ':b', sprintf('0.92V_{S1}=%.0fm/s (límite alta f)', 0.9194*Vs_true(1)), ...
    'FontSize', 8, 'LabelHorizontalAlignment', 'left');
yline(0.9194*Vs_true(2), ':r', sprintf('0.92V_{S2}=%.0fm/s (límite baja f)', 0.9194*Vs_true(2)), ...
    'FontSize', 8, 'LabelHorizontalAlignment', 'left');

xlabel('Frecuencia f  [Hz]', 'FontSize', 12);
ylabel('c_R  [m/s]', 'FontSize', 12);
title({'Ajuste de la curva de dispersión', ...
       'El modelo invertido debe reproducir la curva medida'}, 'FontSize', 10);
legend('Location', 'southeast', 'FontSize', 9);
xlim([0, max(f_ref)*1.1]);
ylim([80, 310]);
grid on; box on;

sgtitle(sprintf('Fig 4: Resultado de la inversión — ε final = %.2f%%  |  Modelo: V_{S1}=%d m/s, h_1=%.0f m', ...
    misfit_inv, Vs1_opt, h1_opt), 'FontSize', 11, 'FontWeight', 'bold');

fprintf('FIG 4 generada: perfil Vs(z) invertido.\n');
fprintf('  Modelo verdadero:  Vs1 = %d m/s, h1 = %.0f m\n', Vs_true(1), h_true(1));
fprintf('  Modelo invertido:  Vs1 = %d m/s, h1 = %.0f m\n', Vs1_opt, h1_opt);
fprintf('  Error en Vs1: %d m/s (%.0f%%)\n', err_Vs1, 100*err_Vs1/Vs_true(1));
fprintf('  Error en h1:  %.0f m (%.0f%%)\n', err_h1, 100*err_h1/h_true(1));
fprintf('  Misfit final: %.2f%%\n\n', misfit_inv);
drawnow;

% =========================================================================
% RESUMEN FINAL
% =========================================================================

fprintf('=================================================================\n');
fprintf(' RESUMEN — Inversión MASW\n');
fprintf('=================================================================\n\n');
fprintf('CONCEPTO CENTRAL:\n');
fprintf('  La inversión de c_R(f) es un problema INVERSO INDIRECTO:\n');
fprintf('  No hay fórmula que dé Vs(z) directamente de c_R(f).\n');
fprintf('  Hay que resolver el problema FORWARD repetidamente.\n\n');
fprintf('PROBLEMAS FUNDAMENTALES:\n');
fprintf('  1. NO-UNICIDAD: distintos perfiles Vs(z) ajustan la misma curva.\n');
fprintf('  2. ILL-POSEDNESS: pequeños errores en c_R(f) → grandes errores en Vs(z).\n');
fprintf('  3. PROFUNDIDAD MÁXIMA: ≈ λ_max/3 a λ_max/2 (donde λ_max=max longitud de onda).\n');
fprintf('  4. INFORMACIÓN A PRIORI: siempre necesaria para desambiguar la solución.\n\n');
fprintf('SENSIBILIDADES (resumen de Fig 1):\n');
fprintf('  Alta f → Vs de las capas superficiales (λ corta)\n');
fprintf('  Baja f → Vs del half-space            (λ larga)\n');
fprintf('  h1     → frecuencia de transición entre los dos regímenes\n\n');
fprintf('PRÓXIMO SCRIPT:\n');
fprintf('  p05_viscoelasticidad.m — efecto del amortiguamiento en la propagación\n');
fprintf('  (Foti Cap. 2, Sec. 2.5: viscoelasticidad lineal, Kramers-Krönig)\n');
fprintf('=================================================================\n');
