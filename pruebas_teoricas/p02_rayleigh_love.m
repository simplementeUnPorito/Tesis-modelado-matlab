%%
% p02_rayleigh_love.m
% =========================================================================
% PRUEBA TEÓRICA 02 — Ondas superficiales: Rayleigh y Love
% =========================================================================
%
% OBJETIVO
%   Construir intuición visual sobre las ondas superficiales Rayleigh y Love.
%   Partimos del caso más simple posible (half-space homogéneo) y luego
%   agregamos una capa — ese es el momento en que aparece la dispersión.
%
% CONCEPTOS CUBIERTOS
%   1. Por qué existe una onda Rayleigh: la ecuación secular (Foti Ec. 2.42)
%      como raíz del determinante de la matriz de rigidez dinámica
%   2. VR ≈ 0.92 Vs — la velocidad de Rayleigh en half-space homogéneo
%   3. Movimiento de partículas: elipse retrógrada, componentes Ux y Uz
%   4. Profundidad de penetración (skin depth) ≈ 0.94 λ_R
%   5. Dispersión: en half-space → curva plana. Con capas → curva dispersiva
%      Esto es lo que MASW mide y luego invierte.
%   6. Love: condición de existencia (VS1 < cL < VS2) y curva de dispersión
%
% LIBRERÍA USADA
%   MASWaves_theoretical_dispersion_curve() — dynamic stiffness matrix method
%   (Foti Ec. 2.74: Φ_R = 0, búsqueda de raíces por cambio de signo del det.)
%   Disponible en third_party/MASW-Matlab-code/, incluida por init_project().
%
% CÓMO CORRER
%   >> init_project()         % desde src/matlab/
%   >> p02_rayleigh_love      % funciona desde cualquier carpeta
%
% REFERENCIA PRINCIPAL
%   Foti, S. — "Surface Wave Methods for Near-Surface Site Characterization"
%   Cap. 2, Secciones 2.2 (Rayleigh en half-space), 2.3 (Love), 2.4 (capas)
%   Ecuaciones clave: 2.42, 2.43–2.48 (partículas), 2.54 (Love), 2.74 (disp.)
%
% =========================================================================

close all; clear; clc;

fprintf('=================================================================\n');
fprintf(' PRUEBA TEÓRICA 02 — Ondas superficiales: Rayleigh y Love\n');
fprintf('=================================================================\n\n');

% =========================================================================
% PARÁMETROS DEL MEDIO
% =========================================================================
%
% Usamos el mismo suelo de p01 para que los números sean familiares,
% pero ahora lo cortamos en dos: media-espacio simple (para Rayleigh puro)
% y luego un modelo de 2 capas (para ver la dispersión).

% --- Half-space homogéneo (base para Rayleigh sin dispersión) ---
Vs_hs  = 244.9;    % velocidad de corte del half-space [m/s]
Vp_hs  = 424.3;    % velocidad compresional del half-space [m/s]
rho_hs = 1900;     % densidad [kg/m³]

% --- Modelo de 2 capas (para mostrar dispersión) ---
%
% CAPA 1 (superficie): suelo blando
%   Vs1 = 120 m/s — arcilla blanda / relleno
%   h1  = 10 m    — espesor
%
% CAPA 2 (half-space): suelo rígido
%   Vs2 = 300 m/s — arena densa / grava
%
% Este contraste Vs1 < Vs2 es el caso NORMAL (perfil creciente con profundidad).
% La curva de dispersión tendrá pendiente negativa en f-c (velocidad baja a
% alta frecuencia → frecuencias altas son superficiales → ven capa blanda).

h1   = 10;     % espesor de la capa 1 [m]
Vs1  = 120;    % Vs capa 1 (suelo blando) [m/s]
Vp1  = 250;    % Vp capa 1 [m/s]  (ν ≈ 0.35, típico suelo blando)
rho1 = 1700;   % densidad capa 1 [kg/m³]

Vs2  = 300;    % Vs half-space (suelo rígido) [m/s]
Vp2  = 520;    % Vp half-space [m/s]
rho2 = 1950;   % densidad half-space [kg/m³]

fprintf('--- MODELOS DE SUELO ---\n');
fprintf('Half-space homogéneo: Vs = %.0f m/s, Vp = %.0f m/s\n', Vs_hs, Vp_hs);
fprintf('  → Rayleigh NO dispersivo (velocidad constante con frecuencia)\n\n');
fprintf('Modelo 2 capas:\n');
fprintf('  Capa 1: h = %.0f m,  Vs = %.0f m/s,  Vp = %.0f m/s  (suelo blando)\n', h1, Vs1, Vp1);
fprintf('  HS:              Vs = %.0f m/s,  Vp = %.0f m/s  (suelo rígido)\n', Vs2, Vp2);
fprintf('  → Rayleigh DISPERSIVO: baja f ve el HS (rígido), alta f ve la capa (blanda)\n\n');

% =========================================================================
% FIGURA 1: Ecuación secular de Rayleigh en half-space homogéneo
% =========================================================================
%
% La onda Rayleigh existe porque hay una velocidad cR tal que el determinante
% de la matriz de rigidez dinámica del half-space cambia de signo (Foti Ec. 2.74).
%
% Para un half-space homogéneo, la ecuación secular de Rayleigh es (Foti Ec. 2.42):
%
%   (2 - cR²/Vs²)² - 4·√(1 - cR²/Vp²)·√(1 - cR²/Vs²) = 0
%
% La única raíz real en (0, Vs) es cR ≈ 0.92·Vs para ν ≈ 0.25.
%
% Lo que graficamos: el lado izquierdo de la ecuación secular como función
% de c_test/Vs, para ver visualmente dónde cruza el cero.
% Esto es exactamente lo que hace MASWaves_stiffness_matrix internamente.

c_test_norm = linspace(0.01, 0.999, 5000);   % c/Vs normalizado (evitar singularidades)
c_test_abs  = c_test_norm * Vs_hs;            % velocidades de prueba [m/s]

% Evaluar la función secular F(c) = (2 - c²/Vs²)² - 4√(1-c²/Vp²)·√(1-c²/Vs²)
% Esta es la forma analítica para half-space (válida solo si c < Vp y c < Vs)
secular = (2 - c_test_norm.^2).^2 - ...
          4 * sqrt(abs(1 - (c_test_abs/Vp_hs).^2)) .* sqrt(abs(1 - c_test_norm.^2));

% Encontrar la raíz numéricamente (cambio de signo)
idx_root = find(diff(sign(secular)) ~= 0, 1);
cR_norm  = c_test_norm(idx_root);
cR       = cR_norm * Vs_hs;

fprintf('--- VELOCIDAD DE RAYLEIGH (half-space) ---\n');
fprintf('  cR = %.2f m/s\n', cR);
fprintf('  cR/Vs = %.4f   (teórico para ν=0.25: ~0.9194)\n', cR/Vs_hs);
fprintf('  Interpretación: la onda Rayleigh es siempre un poco más lenta que Vs\n\n');

figure('Name', 'Fig 1 — Ec. secular Rayleigh (Foti Ec. 2.42)', ...
       'NumberTitle', 'off', 'Position', [50 550 750 420]);

hold on;

% Graficar la función secular
plot(c_test_norm, secular, 'b-', 'LineWidth', 2);

% Marcar el cero
yline(0, 'k-', 'LineWidth', 1);

% Marcar la raíz
plot(cR_norm, 0, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
xline(cR_norm, '--r', sprintf('c_R/V_S = %.4f', cR_norm), ...
    'LabelVerticalAlignment', 'bottom', 'FontSize', 9);

% Zona donde no existe solución (c > Vs → raíces complejas)
fill([1.0 1.05 1.05 1.0], [-2.5 -2.5 2.5 2.5], [0.9 0.9 0.9], ...
    'FaceAlpha', 0.5, 'EdgeColor', 'none');
text(1.005, 1.5, {'c > V_S', '(no hay', 'sol. real)'}, 'FontSize', 8, 'Color', [0.5 0.5 0.5]);

xlabel('c_{test} / V_S  [-]', 'FontSize', 11);
ylabel('F(c) = (2 - c^2/V_S^2)^2 - 4\surd(...)\surd(...)  [-]', 'FontSize', 10);
title({'Ecuación secular de Rayleigh en half-space homogéneo', ...
       '(Foti Ec. 2.42): F(c_R) = 0  →  la raíz define la velocidad de Rayleigh'}, ...
      'FontSize', 10);
ylim([-2.5 2.5]);
xlim([0 1.05]);
grid on;
legend({'F(c) — función secular', 'Raíz: c_R = velocidad Rayleigh'}, ...
       'Location', 'southwest', 'FontSize', 9);

fprintf('FIG 1 generada: ecuación secular de Rayleigh.\n');
fprintf('  La onda Rayleigh "existe" porque hay exactamente UNA velocidad\n');
fprintf('  en (0, Vs) donde F(c) = 0. Sin esa raíz, no habría onda superficial.\n\n');
drawnow;

% =========================================================================
% FIGURA 2: Movimiento de partículas Rayleigh — elipse retrógrada
% =========================================================================
%
% En un half-space, la onda Rayleigh tiene dos componentes de desplazamiento
% (Foti Ecs. 2.43–2.48):
%
%   u_x(x,z,t) = A · [e^{-k·r·z} - (2rs/(1+s²)) · e^{-k·s·z}] · sin(kx - ωt)
%   u_z(x,z,t) = A · [-r·e^{-k·r·z} + (2s²/(1+s²)) · e^{-k·s·z}] · cos(kx - ωt)  (¡pero con decaimiento!)
%
% donde:  r = √(1 - cR²/Vp²),   s = √(1 - cR²/Vs²)
%
% Características clave:
%   - El movimiento es una ELIPSE en el plano vertical x-z
%   - La elipse es RETRÓGRADA cerca de la superficie: las partículas se
%     mueven en sentido antihorario cuando la onda avanza en +x.
%     (opuesto a las olas de agua, que son pródromas)
%   - Con la profundidad, las amplitudes decaen exponencialmente.
%   - A una cierta profundidad (z ≈ 0.2λ), Ux cambia de signo y la
%     elipse se vuelve prógrada (sentido horario) — pero con amplitud pequeña.
%
% Skin depth: la energía está concentrada en los primeros ~λR de profundidad.
% Regla práctica de Foti: 90% de la energía está en z < 0.94·λR.

% Usar una frecuencia de referencia para visualizar
f_ref   = 10;                % frecuencia [Hz]
omega_R = 2*pi*f_ref;
k_R     = omega_R / cR;      % número de onda Rayleigh
lambda_R = 2*pi / k_R;       % longitud de onda Rayleigh [m]

% Parámetros de decaimiento
r_R = sqrt(1 - (cR/Vp_hs)^2);   % decaimiento componente P
s_R = sqrt(1 - (cR/Vs_hs)^2);   % decaimiento componente S

fprintf('--- ONDA RAYLEIGH (f = %.0f Hz) ---\n', f_ref);
fprintf('  λ_R = %.1f m\n', lambda_R);
fprintf('  k_R = %.4f rad/m\n', k_R);
fprintf('  r   = %.4f (decaimiento compresional)\n', r_R);
fprintf('  s   = %.4f (decaimiento de corte)\n', s_R);
fprintf('  Skin depth (90%% energía): z ≈ 0.94·λ_R = %.1f m\n', 0.94*lambda_R);
fprintf('\n');

% Profundidades normalizadas z/λR en que evaluamos las elipses
z_norm_list = [0, 0.1, 0.2, 0.3, 0.5, 0.75, 1.0];
z_list      = z_norm_list * lambda_R;   % profundidades absolutas [m]

% Tiempo: un ciclo completo para trazar la elipse
t_ellipse = linspace(0, 2*pi/omega_R, 200);

% Amplitudes de las componentes a cada profundidad
% (Foti Ecs. 2.43–2.44, con A=1 normalizado)
coef_factor = 2*r_R*s_R / (1 + s_R^2);
amp_x = @(z) exp(-k_R*r_R*z) - coef_factor * exp(-k_R*s_R*z);
amp_z = @(z) -r_R*exp(-k_R*r_R*z) + (2*s_R^2/(1+s_R^2)) * exp(-k_R*s_R*z);

figure('Name', 'Fig 2 — Movimiento de partículas Rayleigh (Foti Ecs. 2.43–2.48)', ...
       'NumberTitle', 'off', 'Position', [820 550 950 500]);

% Panel izquierdo: elipses a distintas profundidades
subplot(1, 2, 1);
hold on;

colors_z = jet(length(z_list));

for iz = 1:length(z_list)
    z_k = z_list(iz);

    Ax = amp_x(z_k);   % amplitud horizontal (puede cambiar signo con z)
    Az = amp_z(z_k);   % amplitud vertical

    % Trayectoria de la partícula en el tiempo (x=0, fase temporal)
    ux_traj = Ax * sin(-omega_R * t_ellipse);     % componente x
    uz_traj = Az * cos(-omega_R * t_ellipse);     % componente z

    % Escalar para visualización centrada en su profundidad
    scale = lambda_R * 0.06;
    plot(ux_traj*scale, -z_k + uz_traj*scale, '-', ...
        'Color', colors_z(iz,:), 'LineWidth', 1.5);

    % Marcar el punto de inicio (t=0) con un círculo
    plot(ux_traj(1)*scale, -z_k + uz_traj(1)*scale, 'o', ...
        'MarkerSize', 5, 'MarkerFaceColor', colors_z(iz,:), 'MarkerEdgeColor', 'k');

    % Etiqueta de profundidad
    text(lambda_R*0.14, -z_k, sprintf('z/\\lambda_R = %.2f', z_norm_list(iz)), ...
        'FontSize', 8, 'Color', colors_z(iz,:));
end

% Línea de la superficie libre
yline(0, 'k-', 'Superficie libre', 'LineWidth', 1.5, 'FontSize', 9);

% Skin depth
yline(-0.94*lambda_R, '--k', 'Skin depth ≈ 0.94λ_R', 'FontSize', 8, ...
    'LabelHorizontalAlignment', 'left');

xlabel('Desplazamiento horizontal u_x  [norm.]', 'FontSize', 10);
ylabel('Profundidad z  [m]', 'FontSize', 10);
title({'Trayectorias de partículas Rayleigh', ...
       'Elipse retrógrada → prógrada con profundidad'}, 'FontSize', 10);
xlim([-lambda_R*0.12 lambda_R*0.22]);
ylim([-lambda_R*1.1 lambda_R*0.1]);
grid on;

% Panel derecho: amplitudes Ux y Uz vs profundidad
subplot(1, 2, 2);
hold on;

z_depth = linspace(0, 1.5*lambda_R, 300);
Ax_prof = arrayfun(amp_x, z_depth);
Az_prof = arrayfun(amp_z, z_depth);

plot(Ax_prof, -z_depth/lambda_R, 'b-', 'LineWidth', 2, 'DisplayName', 'u_x (horizontal)');
plot(Az_prof, -z_depth/lambda_R, 'r-', 'LineWidth', 2, 'DisplayName', 'u_z (vertical)');
xline(0, 'k-', 'LineWidth', 0.8);

% Skin depth
yline(-0.94, '--k', 'Skin depth 0.94λ_R', 'FontSize', 8, 'LabelHorizontalAlignment', 'left');

% Marcar donde Ux cambia de signo
[~, idx_zc] = min(abs(Ax_prof));   % aproximación de la profundidad donde Ux ≈ 0
z_zc = z_depth(idx_zc);
plot(0, -z_zc/lambda_R, 'bs', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
text(0.05, -z_zc/lambda_R, sprintf('u_x = 0 en z/\\lambda_R ≈ %.2f', z_zc/lambda_R), ...
    'FontSize', 8, 'Color', 'b');

xlabel('Amplitud normalizada  [-]', 'FontSize', 10);
ylabel('Profundidad  z / \lambda_R  [-]', 'FontSize', 10);
title({'Perfiles de amplitud vs profundidad', ...
       '(Foti Ecs. 2.43–2.48: decaimiento exponencial)'}, 'FontSize', 10);
legend('Location', 'southeast', 'FontSize', 9);
grid on;
ylim([-1.5 0.1]);
xlim([-1.1 1.1]);

sgtitle({'Fig 2: Movimiento de partículas de onda Rayleigh en half-space', ...
         'La elipse retrógrada y el decaimiento con profundidad son las firmas de esta onda'}, ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 2 generada: movimiento de partículas Rayleigh.\n');
fprintf('  Observar la elipse RETRÓGRADA en z/λR < ~0.2 (sentido antihorario).\n');
fprintf('  La amplitud decae con profundidad → onda superficial, no de cuerpo.\n');
fprintf('  El geófono vertical mide principalmente u_z.\n\n');
drawnow;

% =========================================================================
% FIGURA 3: Curva de dispersión — half-space vs. 2 capas
% =========================================================================
%
% ESTE ES EL CONCEPTO CENTRAL DE MASW:
%
%   Half-space homogéneo → cR = constante en todas las frecuencias (NO dispersivo)
%   Modelo con capas     → cR(f) cambia con la frecuencia (DISPERSIVO)
%
% Por qué:
%   - Frecuencia alta → longitud de onda corta → la onda "ve" sólo las capas superficiales
%   - Frecuencia baja → longitud de onda larga → la onda "ve" profundidades mayores
%   - Si Vs cambia con la profundidad, entonces cR cambia con f → DISPERSIÓN
%
% Lo que hacemos aquí:
%   1. Usar MASWaves_theoretical_dispersion_curve() para el modelo de 2 capas
%   2. Comparar con la línea horizontal cR ≈ 0.92·Vs del half-space
%
% MASWaves_theoretical_dispersion_curve usa el método de la matriz de rigidez
% dinámica (dynamic stiffness matrix), implementación de:
%   Kausel & Roesset (1981) / Foti Ec. 2.74 (Φ_R = 0)
%
% Firma de la función:
%   [c_t, lambda_t] = MASWaves_theoretical_dispersion_curve(c_test, lambda, h, alpha, beta, rho, n)

% Rango de longitudes de onda a calcular
lambda_min = 1;    % [m] — frecuencias altas (ven superficie)
lambda_max = 100;  % [m] — frecuencias bajas (ven profundidades > 10 m)
n_lambda   = 80;
lambda_vec = linspace(lambda_min, lambda_max, n_lambda);

% Velocidades de prueba (rango de búsqueda del determinante)
c_test_vec = 50:1:400;   % [m/s] — debe incluir la raíz esperada

% Parámetros del modelo de 2 capas para MASWaves:
%   h     = espesores de capas finitas [m] (vector longitud n)
%   alpha = Vp de cada capa + half-space [m/s] (vector longitud n+1)
%   beta  = Vs de cada capa + half-space [m/s] (vector longitud n+1)
%   rho   = densidad de cada capa + half-space [kg/m³] (vector longitud n+1)
%   n     = número de capas finitas (entero)

h_model     = [h1];                  % 1 capa finita de espesor h1
alpha_model = [Vp1, Vp2];            % Vp: [capa1, half-space]
beta_model  = [Vs1, Vs2];            % Vs: [capa1, half-space]
rho_model   = [rho1, rho2];          % ρ:  [capa1, half-space]
n_layers    = 1;                     % número de capas finitas

fprintf('Calculando curva de dispersión teórica con MASWaves...\n');

% Llamar a la función de la librería MASW
[c_t, lambda_t] = MASWaves_theoretical_dispersion_curve( ...
    c_test_vec, lambda_vec, h_model, alpha_model, beta_model, rho_model, n_layers);

% Filtrar puntos donde no se encontró raíz (c_t == 0)
valid = c_t > 0;
c_t      = c_t(valid);
lambda_t = lambda_t(valid);

% Convertir longitud de onda a frecuencia: f = c/λ
f_t = c_t ./ lambda_t;

fprintf('  Calculados %d puntos válidos en la curva de dispersión.\n', sum(valid));
fprintf('  Velocidad a λ pequeña (superficial): cR ≈ %.0f m/s (≈ 0.92·Vs1=%.0f)\n', ...
    min(c_t), 0.92*Vs1);
fprintf('  Velocidad a λ grande (profundo):     cR ≈ %.0f m/s (≈ 0.92·Vs2=%.0f)\n', ...
    max(c_t), 0.92*Vs2);
fprintf('\n');

% Velocidad Rayleigh del half-space 1 (límite alta frecuencia)
cR_hs1 = 0.9194 * Vs1;
% Velocidad Rayleigh del half-space 2 (límite baja frecuencia)
cR_hs2 = 0.9194 * Vs2;

figure('Name', 'Fig 3 — Dispersión Rayleigh: half-space vs 2 capas (MASWaves)', ...
       'NumberTitle', 'off', 'Position', [50 50 1100 500]);

% Panel izquierdo: curva c vs f
subplot(1, 2, 1);
hold on;

% Líneas de referencia del half-space
yline(cR_hs1, '--', sprintf('0.92·V_{S1} = %.0f m/s (límite alta f)', cR_hs1), ...
    'Color', [0.6 0.6 0.9], 'LineWidth', 1.2, 'FontSize', 8, 'LabelHorizontalAlignment', 'left');
yline(cR_hs2, '--', sprintf('0.92·V_{S2} = %.0f m/s (límite baja f)', cR_hs2), ...
    'Color', [0.9 0.4 0.4], 'LineWidth', 1.2, 'FontSize', 8, 'LabelHorizontalAlignment', 'left');

% Curva dispersiva del modelo 2 capas (calculada con MASWaves)
plot(f_t, c_t, 'k-o', 'MarkerSize', 4, 'LineWidth', 2, ...
    'DisplayName', 'Curva teórica — 2 capas (MASWaves)');

xlabel('Frecuencia f  [Hz]', 'FontSize', 11);
ylabel('Velocidad de fase c_R  [m/s]', 'FontSize', 11);
title({'Curva de dispersión de Rayleigh', ...
       'c_R(f): el corazón de MASW'}, 'FontSize', 11);
grid on;
legend('Location', 'southeast', 'FontSize', 9);
ylim([0 400]);
xlim([0 max(f_t)*1.1]);

% Anotar la física
text(max(f_t)*0.5, cR_hs1 - 15, ...
    {'Alta f → λ corta → ve capa 1 (blanda)'}, ...
    'FontSize', 8, 'HorizontalAlignment', 'center', 'Color', [0 0 0.6]);
text(max(f_t)*0.15, cR_hs2 + 15, ...
    {'Baja f → λ larga → ve half-space (rígido)'}, ...
    'FontSize', 8, 'HorizontalAlignment', 'center', 'Color', [0.7 0 0]);

% Panel derecho: curva c vs λ (forma más usada en la práctica MASW)
subplot(1, 2, 2);
hold on;

yline(cR_hs1, '--', 'Color', [0.6 0.6 0.9], 'LineWidth', 1.2);
yline(cR_hs2, '--', 'Color', [0.9 0.4 0.4], 'LineWidth', 1.2);
plot(lambda_t, c_t, 'k-o', 'MarkerSize', 4, 'LineWidth', 2);

% Marcar la profundidad de penetración aproximada: z_pen ≈ λ/3 a λ/2
xline(h1*3, ':b', sprintf('λ ≈ 3h_1 = %.0f m', h1*3), ...
    'FontSize', 8, 'LabelVerticalAlignment', 'bottom');

xlabel('Longitud de onda \lambda_R  [m]', 'FontSize', 11);
ylabel('Velocidad de fase c_R  [m/s]', 'FontSize', 11);
title({'Curva de dispersión vs longitud de onda', ...
       'λ proporcional a la profundidad de penetración'}, 'FontSize', 11);
grid on;
ylim([0 400]);
xlim([0 max(lambda_t)*1.05]);

% Sombrear el rango donde ocurre la transición (cerca de la interfaz)
fill([h1*1.5 h1*5 h1*5 h1*1.5], [0 0 400 400], [1 1 0.8], ...
    'FaceAlpha', 0.3, 'EdgeColor', 'none');
text(h1*2.5, 50, {'Transición', '(zona sensible', 'a la interfaz)'}, ...
    'FontSize', 8, 'HorizontalAlignment', 'center', 'Color', [0.6 0.5 0]);

sgtitle({'Fig 3: Dispersión de Rayleigh — MASWaves_theoretical_dispersion_curve()', ...
         sprintf('Modelo: capa h=%.0fm Vs=%.0fm/s  /  half-space Vs=%.0fm/s', h1, Vs1, Vs2)}, ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 3 generada: curva de dispersión de Rayleigh.\n');
fprintf('  ESTE es el dato que MASW mide en campo y luego invierte.\n');
fprintf('  Inversa: conocida c_R(f), encontrar el perfil Vs(z) que la explica.\n\n');
drawnow;

% =========================================================================
% FIGURA 4: Ondas Love — condición de existencia y dispersión
% =========================================================================
%
% Las ondas Love son ondas SH (horizontales transversales) atrapadas en la
% capa superficial por reflexión total en la interfaz.
%
% CONDICIÓN DE EXISTENCIA (Foti Sec. 2.3):
%   VS1 < cL < VS2
%   La onda Love SÓLO existe si hay una capa más blanda sobre un half-space rígido.
%   Si VS1 >= VS2, no hay reflexión total → no hay atrapamiento → no hay Love.
%
% ECUACIÓN DE DISPERSIÓN (Foti Ec. 2.54):
%   tan(k·h1·√(cL²/VS1² - 1)) = (ρ2/ρ1) · (√(1 - cL²/VS2²)) / (√(cL²/VS1² - 1))
%
% La diferencia clave con Rayleigh:
%   - Rayleigh: movimiento en el plano vertical (Ux, Uz) → geófono vertical
%   - Love:     movimiento horizontal transversal (Uy)   → geófono horizontal ⊥ propagación
%
% Modos: la ecuación de dispersión tiene múltiples raíces → múltiples modos.
%   Modo 0 (fundamental): existe para todas las f > 0
%   Modo n:               existe solo para f > fn (frecuencia de corte)
%   Frecuencia de corte modo n (Foti Ec. 2.55):
%     fn = n·VS1 / (2·h1·√(VS2²/VS1² - 1))  para n = 1, 2, 3...

% Velocidades de prueba para Love
c_L_vec = linspace(Vs1*1.001, Vs2*0.999, 3000);

% Frecuencias de análisis
f_love  = linspace(0.5, 100, 500);   % [Hz]
omega_L = 2*pi*f_love;               % [rad/s]

% Calcular la curva de dispersión de Love para los primeros 3 modos
% resolviendo la ecuación trascendental (Foti Ec. 2.54)

fprintf('Calculando curvas de dispersión de Love (modos 0, 1, 2)...\n');

% Para cada frecuencia y cada velocidad de prueba, evaluar el lado izquierdo
% menos el lado derecho de la ecuación de dispersión.
% F(cL, ω) = tan(k·h·√(cL²/VS1²-1)) - (ρ2/ρ1)·√(1-cL²/VS2²)/√(cL²/VS1²-1)

n_modes_love = 3;   % calcular los primeros n_modes_love

cL_curves = nan(n_modes_love, length(f_love));

for if_ = 1:length(f_love)
    omega_k = omega_L(if_);

    % Evaluar la función de dispersión para este ω
    F_love = zeros(size(c_L_vec));
    for ic = 1:length(c_L_vec)
        cL = c_L_vec(ic);
        k_L  = omega_k / cL;
        xi   = sqrt(cL^2/Vs1^2 - 1);    % raíz real > 0 si cL > VS1
        eta  = sqrt(1 - cL^2/Vs2^2);     % raíz real > 0 si cL < VS2
        F_love(ic) = tan(k_L * h1 * xi) - (rho2/rho1) * eta / xi;
    end

    % Buscar cambios de signo (raíces) en F_love
    % Cada cambio de signo corresponde a un modo
    sign_changes = find(diff(sign(F_love)) ~= 0);

    % Filtrar los saltos de tan() (discontinuidades) vs raíces reales
    % Una raíz real tiene F cambiando de - a + o de + a - de manera suave.
    % Una discontinuidad de tan() es un salto de -∞ a +∞.
    % Criterio: si |F(i)| < 100 y |F(i+1)| < 100, es una raíz real.
    roots_idx = [];
    for isc = 1:length(sign_changes)
        i1 = sign_changes(isc);
        i2 = i1 + 1;
        if abs(F_love(i1)) < 80 && abs(F_love(i2)) < 80
            roots_idx = [roots_idx, i1];
        end
    end

    % Asignar las raíces a los modos (de menor a mayor velocidad → modo 0, 1, 2...)
    for im = 1:min(n_modes_love, length(roots_idx))
        % Interpolación lineal para la raíz exacta
        i1 = roots_idx(im);
        i2 = i1 + 1;
        cL_root = c_L_vec(i1) - F_love(i1) * (c_L_vec(i2)-c_L_vec(i1)) / ...
                                               (F_love(i2)-F_love(i1));
        cL_curves(im, if_) = cL_root;
    end
end

% Frecuencias de corte de cada modo (Foti Ec. 2.55)
% f_n = n * Vs1 / (2 * h1 * sqrt(Vs2²/Vs1² - 1))   para n = 1, 2, ...
f_cutoff = zeros(1, n_modes_love);
for n = 1:n_modes_love
    if n == 1
        f_cutoff(n) = 0;   % el modo fundamental no tiene frecuencia de corte
    else
        f_cutoff(n) = (n-1) * Vs1 / (2 * h1 * sqrt(Vs2^2/Vs1^2 - 1));
    end
end

fprintf('  Frecuencias de corte Love (Foti Ec. 2.55):\n');
fprintf('    Modo 0 (fundamental): f_c = 0 Hz (existe para toda f)\n');
for n = 2:n_modes_love
    fprintf('    Modo %d: f_c = %.1f Hz\n', n-1, f_cutoff(n));
end
fprintf('\n');

figure('Name', 'Fig 4 — Dispersión de Love: condición + modos (Foti Ecs. 2.54–2.55)', ...
       'NumberTitle', 'off', 'Position', [820 50 950 500]);

subplot(1, 2, 1);
hold on;

% Colores para cada modo
colores_love = {'b', 'r', [0.1 0.6 0.1]};
nombres_modo = {'Modo 0 (fundamental)', 'Modo 1', 'Modo 2'};

for im = 1:n_modes_love
    c_m = cL_curves(im, :);
    validos = ~isnan(c_m);
    if any(validos)
        plot(f_love(validos), c_m(validos), '-', ...
            'Color', colores_love{im}, 'LineWidth', 2, ...
            'DisplayName', nombres_modo{im});
    end
    % Marcar frecuencia de corte
    if f_cutoff(im) > 0
        xline(f_cutoff(im), '--', sprintf('f_c%d=%.0fHz', im-1, f_cutoff(im)), ...
            'Color', colores_love{im}, 'FontSize', 8, 'LabelVerticalAlignment', 'bottom');
    end
end

% Límites de existencia
yline(Vs1, ':b', sprintf('V_{S1} = %.0f m/s (límite inferior)', Vs1), ...
    'FontSize', 8, 'LabelHorizontalAlignment', 'left');
yline(Vs2, ':r', sprintf('V_{S2} = %.0f m/s (límite superior)', Vs2), ...
    'FontSize', 8, 'LabelHorizontalAlignment', 'left');

xlabel('Frecuencia f  [Hz]', 'FontSize', 11);
ylabel('Velocidad de fase c_L  [m/s]', 'FontSize', 11);
title({'Curvas de dispersión de Love', ...
       sprintf('Condición: V_{S1}<c_L<V_{S2} (%.0f<c_L<%.0f m/s)', Vs1, Vs2)}, 'FontSize', 10);
legend('Location', 'southeast', 'FontSize', 9);
grid on;
ylim([Vs1*0.9, Vs2*1.05]);
xlim([0 max(f_love)]);

% Panel derecho: comparación Love vs Rayleigh (ambas curvas fundamentales)
subplot(1, 2, 2);
hold on;

% Rayleigh fundamental (de Fig 3)
plot(f_t, c_t, 'k-o', 'MarkerSize', 3, 'LineWidth', 1.5, 'DisplayName', 'Rayleigh — modo 0');

% Love fundamental
c_love0 = cL_curves(1, :);
validos0 = ~isnan(c_love0);
plot(f_love(validos0), c_love0(validos0), 'b-', 'LineWidth', 2, 'DisplayName', 'Love — modo 0');

% Referencias
yline(Vs1, ':b', 'V_{S1}', 'FontSize', 9);
yline(Vs2, ':r', 'V_{S2}', 'FontSize', 9);
yline(cR_hs1, '--k', sprintf('0.92 V_{S1}=%.0fm/s', cR_hs1), 'FontSize', 8, ...
    'LabelHorizontalAlignment', 'left');

xlabel('Frecuencia f  [Hz]', 'FontSize', 11);
ylabel('Velocidad de fase  [m/s]', 'FontSize', 11);
title({'Rayleigh vs Love — modo fundamental', ...
       'Love va de VS1 a VS2; Rayleigh va de 0.92VS1 a 0.92VS2'}, 'FontSize', 10);
legend('Location', 'southeast', 'FontSize', 9);
grid on;
ylim([0 Vs2*1.15]);
xlim([0 80]);

sgtitle({'Fig 4: Ondas Love — condición de existencia y curvas modales', ...
         sprintf('(Foti Ec. 2.54: trascendental, ρ2/ρ1=%.2f)', rho2/rho1)}, ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 4 generada: dispersión de Love.\n');
fprintf('  Diferencias clave Love vs Rayleigh:\n');
fprintf('    - Love está confinada ENTRE Vs1 y Vs2; Rayleigh debajo de Vs\n');
fprintf('    - Love: movimiento SH (geófono horizontal transversal)\n');
fprintf('    - Love: modos superiores aparecen a partir de una frecuencia de corte\n');
fprintf('    - Love NO existe sin la capa blanda (no hay Love en half-space homogéneo)\n\n');
drawnow;

% =========================================================================
% RESUMEN FINAL
% =========================================================================

fprintf('=================================================================\n');
fprintf(' RESUMEN — Rayleigh y Love\n');
fprintf('=================================================================\n\n');
fprintf('RAYLEIGH:\n');
fprintf('  cR ≈ 0.92 Vs (siempre algo más lento que Vs)\n');
fprintf('  Polarización elíptica en el plano vertical (Ux + Uz)\n');
fprintf('  Skin depth ≈ 0.94 λR → la frecuencia controla la profundidad de muestreo\n');
fprintf('  Dispersivo si hay capas → esa curva c(f) es lo que MASW mide\n\n');
fprintf('LOVE:\n');
fprintf('  Sólo existe si VS1 < VS2 (capa blanda sobre rígida)\n');
fprintf('  Velocidad entre VS1 y VS2\n');
fprintf('  Polarización SH (horizontal transversal)\n');
fprintf('  Modos superiores con frecuencias de corte f_n = (n·VS1)/(2h·√(VS2²/VS1²-1))\n\n');
fprintf('PRÓXIMOS SCRIPTS:\n');
fprintf('  p03_dispersion_inversion.m — inversión de la curva de dispersión → perfil Vs(z)\n');
fprintf('=================================================================\n');
