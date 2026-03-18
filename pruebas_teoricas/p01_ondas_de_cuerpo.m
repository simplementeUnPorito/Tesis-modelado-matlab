%% 
% p01_ondas_de_cuerpo.m
% =========================================================================
% PRUEBA TEÓRICA 01 — Ondas de cuerpo en un medio elástico homogéneo
% =========================================================================
%
% OBJETIVO
%   Desarrollar intuición visual sobre las ondas P y S propagándose en un
%   medio elástico infinito, homogéneo e isotrópico.
%   Las ecuaciones son las del modelo más simple posible — sin fronteras,
%   sin capas, sin disipación. Es el punto de partida obligatorio antes
%   de agregar cualquier complejidad.
%
% CONCEPTOS CUBIERTOS
%   1. Del material al movimiento: constantes de Lamé → velocidades Vp, Vs
%   2. Ondas P (compresión) vs ondas S (corte): distintas velocidades
%   3. Propagación de un pulso: qué tan rápido viaja cada tipo de onda
%   4. Carácter NO dispersivo: todas las frecuencias viajan a la misma
%      velocidad (esto cambiará TOTALMENTE cuando veamos medios estratificados)
%   5. Polarización: la dirección del movimiento de las partículas
%      - P: el suelo se mueve PARALELO a la dirección de propagación
%      - S: el suelo se mueve PERPENDICULAR a la dirección de propagación
%   6. Por qué Vp > Vs siempre
%   7. Por qué los métodos de ondas superficiales usan Vs y no Vp
%      (insensibilidad de Vp en suelos saturados)
%
% REFERENCIA PRINCIPAL
%   Foti, S. — "Surface Wave Methods for Near-Surface Site Characterization"
%   Capítulo 2, Sección 2.1.3
%   "Body waves in unbounded, homogeneous, linear elastic, isotropic continua"
%   Ecuaciones clave: 2.11 (Navier), 2.15 (Navier explícita), 2.17 (Vp, Vs),
%                     2.18 (Vp/Vs vs nu), 2.19–2.22 (onda armónica)
%
% CÓMO CORRER
%   Desde la raíz del proyecto (Tesis/) en MATLAB:
%     >> cd src/matlab
%     >> init_project()
%     >> cd pruebas_teoricas
%     >> p01_ondas_de_cuerpo
%
%   O directamente si ya corriste init_project:
%     >> p01_ondas_de_cuerpo
%
% =========================================================================
% Autor: generado como herramienta de aprendizaje para la tesis
% Fecha: 2026
% =========================================================================

close all;   % cerrar todas las figuras abiertas
clear;       % limpiar el workspace
clc;         % limpiar la consola

fprintf('=================================================================\n');
fprintf(' PRUEBA TEÓRICA 01 — Ondas de cuerpo en medio elástico homogéneo\n');
fprintf('=================================================================\n\n');

% =========================================================================
% PARTE 0: DEFINIR EL MEDIO ELÁSTICO
% =========================================================================
%
% Un medio elástico isotrópico queda completamente definido por tres
% parámetros: densidad ρ y dos constantes de Lamé (λ, μ).
%
% Interpretación física de cada parámetro:
%   ρ   = densidad de masa [kg/m³]
%         cuánta masa hay por unidad de volumen
%
%   μ   = módulo de corte (shear modulus) [Pa]
%         resistencia del material a la deformación de corte (cizalla)
%         μ = 0 para fluidos perfectos (no resisten el corte)
%         es el parámetro que más importa para la caracterización geotécnica
%
%   λ   = primer parámetro de Lamé [Pa]
%         relacionado con la rigidez volumétrica
%         λ = K - (2/3)μ  donde K es el módulo volumétrico (bulk modulus)
%
% Parámetros típicos para un suelo medio (arena densa, no saturada):
%   Vp  ≈ 400–800 m/s
%   Vs  ≈ 200–400 m/s
%   ν   ≈ 0.25–0.30

rho = 1900;       % densidad [kg/m³] — típico para arenas densas
mu  = 1.14e8;     % módulo de corte [Pa] = 114 MPa — suelo relativamente rígido
nu  = 0.25;       % coeficiente de Poisson [-] — valor clásico para muchos materiales

% Calcular λ a partir de ν y μ
% Relación: ν = λ / (2(λ + μ))  →  λ = 2μν / (1 - 2ν)
lambda = 2 * mu * nu / (1 - 2*nu);

% =========================================================================
% VELOCIDADES DE ONDA (Foti Ec. 2.17)
% =========================================================================
%
% Las velocidades emergen directamente de la ecuación de movimiento de Navier
% (Foti Ec. 2.15). Al aplicar los operadores divergencia y curl, el sistema
% se desacopla en dos ecuaciones de onda independientes:
%
%   Vp = sqrt((λ + 2μ) / ρ)   → velocidad de onda P (compresional)
%   Vs = sqrt(μ / ρ)           → velocidad de onda S (corte)
%
% Notación en Foti: χ = P para longitudinal, χ = S para transversal

Vp = sqrt((lambda + 2*mu) / rho);   % velocidad onda P [m/s]
Vs = sqrt(mu / rho);                 % velocidad onda S [m/s]

fprintf('--- PROPIEDADES DEL MEDIO ---\n');
fprintf('Densidad:              ρ  = %.0f kg/m³\n', rho);
fprintf('Módulo de corte:       μ  = %.2e Pa  (%.0f MPa)\n', mu, mu/1e6);
fprintf('Primer param. Lamé:    λ  = %.2e Pa  (%.0f MPa)\n', lambda, lambda/1e6);
fprintf('Coeficiente de Poisson ν  = %.2f\n', nu);
fprintf('\n');
fprintf('--- VELOCIDADES DE ONDA (Foti Ec. 2.17) ---\n');
fprintf('Velocidad onda P:  Vp = sqrt((λ+2μ)/ρ) = %.1f m/s\n', Vp);
fprintf('Velocidad onda S:  Vs = sqrt(μ/ρ)       = %.1f m/s\n', Vs);
fprintf('Relación Vp/Vs:    Vp/Vs = %.3f\n', Vp/Vs);
fprintf('Verificación:      sqrt(2(1-ν)/(1-2ν))  = %.3f (Foti Ec. 2.18)\n', ...
    sqrt(2*(1-nu)/(1-2*nu)));
fprintf('\n');
fprintf('OBSERVACIÓN: Vp > Vs siempre.\n');
fprintf('  Vp depende de la rigidez volumétrica (λ+2μ) Y de la rigidez de corte (μ).\n');
fprintf('  Vs depende SOLO de la rigidez de corte (μ).\n');
fprintf('  Como λ > 0, siempre se cumple (λ+2μ) > μ, entonces Vp > Vs.\n\n');

% =========================================================================
% FIGURA 1: Vp/Vs en función del coeficiente de Poisson
% =========================================================================
%
% Esta figura muestra una relación fundamental: cómo el cociente Vp/Vs
% depende del coeficiente de Poisson ν (Foti Ec. 2.18):
%
%   (Vp/Vs)² = (λ+2μ)/μ = 2(1-ν)/(1-2ν)
%
% Observaciones importantes:
%   - Para ν típicos de geomateriales secos (0.15–0.35): Vp/Vs ≈ 1.5–2.0
%   - Para ν → 0.5 (suelos saturados, incompresibles): Vp/Vs → ∞
%     Esto NO significa que el suelo sea infinitamente rígido en corte.
%     Significa que Vp queda controlado por la compresibilidad del agua,
%     que es mucho más alta que la del esqueleto sólido.
%   - Por eso: en suelos saturados, Vp es inútil para caracterizar el suelo
%     y los métodos de ondas superficiales (Vs) son mucho más informativos.

nu_vec = linspace(0, 0.499, 1000);   % vector de Poisson (evitar singularidad en 0.5)
ratio_vec = sqrt(2*(1-nu_vec) ./ (1-2*nu_vec));

figure('Name', 'Fig 1 — Vp/Vs vs Poisson (Foti Ec. 2.18)', ...
       'NumberTitle', 'off', 'Position', [50 600 700 420]);

plot(nu_vec, ratio_vec, 'b-', 'LineWidth', 2);
hold on;

% Marcar el valor actual del medio definido
plot(nu, Vp/Vs, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
text(nu + 0.01, Vp/Vs + 0.1, sprintf('  ν=%.2f, Vp/Vs=%.2f\n  (este medio)', nu, Vp/Vs), ...
    'FontSize', 9, 'Color', 'r');

% Sombrear zona típica de geomateriales secos (ν = 0.15 a 0.35)
x_geo = [0.15 0.35 0.35 0.15];
y_geo_min = sqrt(2*(1-[0.15 0.35]) ./ (1-2*[0.15 0.35]));
y_geo = [y_geo_min(1) y_geo_min(2) 5 5];
fill(x_geo, y_geo, [0.85 0.95 0.85], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
text(0.18, 1.7, {'Zona típica', 'geomateriales secos'}, 'FontSize', 8, 'Color', [0.2 0.5 0.2]);

% Marcar zona saturada (ν → 0.5)
xline(0.5, '--r', 'ν → 0.5 (suelo saturado)', 'LabelVerticalAlignment', 'bottom', ...
    'FontSize', 8, 'Color', [0.8 0 0]);

% Marcar Vp/Vs = 1 (imposible físicamente)
yline(1, ':k', 'Vp/Vs = 1 (mínimo teórico, ν=0)', 'FontSize', 8, 'LabelHorizontalAlignment', 'left');

xlabel('Coeficiente de Poisson ν  [-]', 'FontSize', 11);
ylabel('Cociente V_P / V_S  [-]', 'FontSize', 11);
title({'Relación V_P/V_S en función del coeficiente de Poisson', ...
       '(Foti Ec. 2.18):  (V_P/V_S)^2 = 2(1-\nu)/(1-2\nu)'}, 'FontSize', 11);
ylim([0.9 5]);
xlim([0 0.5]);
grid on;
legend('V_P/V_S teórico', 'Este medio', 'Zona típica geomateriales secos', ...
       'Location', 'northwest', 'FontSize', 9);

fprintf('FIG 1 generada: Vp/Vs vs coeficiente de Poisson\n');
fprintf('  Observar cómo Vp/Vs → ∞ cuando ν → 0.5 (suelo saturado).\n');
fprintf('  Esto hace que Vp sea un pésimo indicador de rigidez en suelos saturados.\n\n');
drawnow;

% =========================================================================
% FIGURA 2: Propagación de pulsos P y S — INTERACTIVO con slider de tiempo
% =========================================================================
%
% Vamos a simular la propagación de un pulso gaussiano en 1D.
% Esto corresponde a la solución de la ecuación de onda 1D (Foti Ec. 2.1):
%
%   ∂²u/∂x² = (1/V²) ∂²u/∂t²
%
% La solución general es la fórmula de d'Alembert (Foti Ec. 2.2):
%   u(x,t) = f(x - V·t) + g(x + V·t)
%
% Lo que graficamos: u(x, t) = A·exp(-(x-V·t)²/σ²)
% Un paquete gaussiano que se mueve hacia la derecha con velocidad V.
%
% INTERACTIVIDAD: un slider permite controlar el tiempo t en [0, t_max].
%   Al mover el slider, ambos pulsos (P y S) se mueven simultáneamente.
%   La diferencia de posición entre P y S se acumula con el tiempo —
%   eso es exactamente lo que se observa en un sismograma de campo.

% Configuración del dominio espacial
x_max = 1500;                    % longitud del dominio [m]
dx    = 0.5;                     % resolución espacial [m]
x     = 0 : dx : x_max;         % vector de posiciones [m]

% Parámetros del pulso gaussiano
x0    = 50;                      % posición inicial del pulso [m] (cerca del origen)
sigma = 30;                      % anchura del pulso gaussiano [m]

% Rango de tiempo para el slider
t_min = 0;
t_max = 3.0;    % [s] — tiempo suficiente para que P recorra casi todo el dominio
t_ini = 0;      % tiempo inicial al abrir la figura

% ---- Construir la figura con dos subplots y el slider debajo ----

fig2 = figure('Name', 'Fig 2 — Propagación de pulsos P y S (Foti Ec. 2.1–2.2)', ...
              'NumberTitle', 'off', 'Position', [50 100 1100 600]);

% Reservar espacio: subplots en la parte superior, slider abajo
% Los subplots ocupan [izq, abajo, ancho, alto] en coordenadas normalizadas

ax_P = subplot(2, 1, 1);
ax_S = subplot(2, 1, 2);

% Mover los subplots hacia arriba para dejar espacio al slider
set(ax_P, 'Position', [0.08 0.55 0.88 0.37]);
set(ax_S, 'Position', [0.08 0.12 0.88 0.37]);

% ---- Dibujar el estado inicial (t = t_ini) ----

% Panel onda P
axes(ax_P);
hold(ax_P, 'on');
u_P_ini = exp(-((x - x0 - Vp*t_ini).^2) / sigma^2);
line_P = plot(ax_P, x, u_P_ini, 'b-', 'LineWidth', 2.5);
% Marcador de posición del pico
xpico_P_ini = x0 + Vp*t_ini;
marker_P = plot(ax_P, xpico_P_ini, 1.02, 'bv', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
xlabel(ax_P, 'Posición x [m]', 'FontSize', 10);
ylabel(ax_P, 'Amplitud norm. [-]', 'FontSize', 10);
title(ax_P, {'ONDA P (compresional) — u(x,t) = exp(-(x - V_P·t)²/σ²)', ...
             '(Foti Ec. 2.1–2.2: solución de d''Alembert)'}, 'FontSize', 10);
ylim(ax_P, [-0.1 1.25]);
xlim(ax_P, [0 x_max]);
grid(ax_P, 'on');
% Texto fijo con Vp
text(ax_P, x_max*0.72, 0.9, sprintf('V_P = %.0f m/s →', Vp), ...
    'FontSize', 10, 'Color', [0 0 0.7], 'FontWeight', 'bold');
% Etiqueta del pico (se actualizará con el slider)
lbl_P = text(ax_P, xpico_P_ini, 1.13, sprintf('t = %.2f s', t_ini), ...
    'FontSize', 8, 'HorizontalAlignment', 'center', 'Color', 'b');

% Panel onda S
axes(ax_S);
hold(ax_S, 'on');
u_S_ini = exp(-((x - x0 - Vs*t_ini).^2) / sigma^2);
line_S = plot(ax_S, x, u_S_ini, 'r-', 'LineWidth', 2.5);
xpico_S_ini = x0 + Vs*t_ini;
marker_S = plot(ax_S, xpico_S_ini, 1.02, 'rv', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
xlabel(ax_S, 'Posición x [m]', 'FontSize', 10);
ylabel(ax_S, 'Amplitud norm. [-]', 'FontSize', 10);
title(ax_S, {'ONDA S (corte) — mismo pulso inicial, pero V_S < V_P', ...
             sprintf('V_S = %.0f m/s  vs  V_P = %.0f m/s  →  diferencia acumulada visible', Vs, Vp)}, ...
    'FontSize', 10);
ylim(ax_S, [-0.1 1.25]);
xlim(ax_S, [0 x_max]);
grid(ax_S, 'on');
text(ax_S, x_max*0.72, 0.9, sprintf('V_S = %.0f m/s →', Vs), ...
    'FontSize', 10, 'Color', [0.7 0 0], 'FontWeight', 'bold');
lbl_S = text(ax_S, xpico_S_ini, 1.13, sprintf('t = %.2f s', t_ini), ...
    'FontSize', 8, 'HorizontalAlignment', 'center', 'Color', 'r');

% Título global
sgtitle(fig2, sprintf(['Fig 2: Pulsos P y S — usá el slider para mover el tiempo\n' ...
    'Vp = %.0f m/s,  Vs = %.0f m/s,  Vp/Vs = %.2f  — mismo pulso, distintas velocidades'], ...
    Vp, Vs, Vp/Vs), 'FontSize', 11, 'FontWeight', 'bold');

% ---- Crear el slider de tiempo ----
%
% uicontrol('Style','slider') crea un widget interactivo.
% 'Min', 'Max', 'Value' definen el rango y valor inicial.
% 'Callback' es la función que se ejecuta cada vez que el usuario mueve el slider.
%
% Usamos una función anónima que captura las variables del workspace actual
% (x, x0, Vp, Vs, sigma, line_P, line_S, marker_P, marker_S, lbl_P, lbl_S)
% y actualiza las líneas sin redibujar toda la figura.

slider_t = uicontrol(fig2, ...
    'Style',    'slider', ...
    'Min',      t_min, ...
    'Max',      t_max, ...
    'Value',    t_ini, ...
    'Units',    'normalized', ...
    'Position', [0.08 0.03 0.78 0.04], ...   % [izq, abajo, ancho, alto]
    'SliderStep', [0.01 0.05], ...            % paso fino / paso grande (flecha / zona lateral)
    'Callback', @(src, ~) actualizar_pulsos(src, x, x0, Vp, Vs, sigma, ...
                    line_P, line_S, marker_P, marker_S, lbl_P, lbl_S));

% Etiqueta del slider
uicontrol(fig2, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.87 0.025 0.10 0.04], ...
    'String', 'Tiempo →', ...
    'FontSize', 9, ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', get(fig2, 'Color'));

uicontrol(fig2, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.0 0.025 0.07 0.04], ...
    'String', sprintf('t = 0 s'), ...
    'FontSize', 9, ...
    'HorizontalAlignment', 'right', ...
    'BackgroundColor', get(fig2, 'Color'));

uicontrol(fig2, 'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.87 0.065 0.12 0.03], ...
    'String', sprintf('t_{max} = %.1f s', t_max), ...
    'FontSize', 8, ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', get(fig2, 'Color'));

fprintf('FIG 2 generada: slider interactivo de tiempo.\n');
fprintf('  Mové el slider para ver los pulsos P y S moverse.\n');
fprintf('  Observar: al mismo tiempo t, el pulso P está siempre más adelante.\n');
fprintf('  La diferencia de posición crece con el tiempo:\n');
fprintf('    Δx(t) = (Vp - Vs) · t = %.0f · t  [m]\n', Vp - Vs);
fprintf('  Eso es exactamente lo que separa las llegadas P y S en un sismograma.\n\n');
drawnow;

% =========================================================================
% FUNCIÓN LOCAL: actualizar_pulsos
% =========================================================================
% Esta función es llamada por el slider cada vez que el usuario lo mueve.
% Recibe el handle del slider (src) y los handles de todos los objetos
% gráficos que necesita actualizar.
%
% En lugar de redibujar la figura (lento), solo actualiza los datos YData/XData
% de las líneas ya existentes. Esto es mucho más rápido y fluido.

function actualizar_pulsos(src, x, x0, Vp, Vs, sigma, ...
                           line_P, line_S, marker_P, marker_S, lbl_P, lbl_S)
    % Leer el tiempo del slider
    t = src.Value;

    % Calcular las posiciones del pico
    xpico_P = x0 + Vp * t;
    xpico_S = x0 + Vs * t;

    % Recalcular los pulsos gaussianos
    u_P = exp(-((x - xpico_P).^2) / sigma^2);
    u_S = exp(-((x - xpico_S).^2) / sigma^2);

    % Actualizar los datos de las líneas (sin redibujar los ejes)
    line_P.YData = u_P;
    line_S.YData = u_S;

    % Actualizar los marcadores de posición del pico
    marker_P.XData = xpico_P;
    marker_S.XData = xpico_S;

    % Actualizar las etiquetas de tiempo
    lbl_P.Position(1) = xpico_P;
    lbl_P.String = sprintf('t = %.2f s', t);
    lbl_S.Position(1) = xpico_S;
    lbl_S.String = sprintf('t = %.2f s', t);

    % Forzar actualización visual inmediata
    drawnow limitrate;
end

% =========================================================================
% FIGURA 3: Carácter NO dispersivo — todas las frecuencias van igual
% =========================================================================
%
% Este es un concepto CLAVE que diferencia a las ondas de cuerpo en medio
% homogéneo de las ondas superficiales en medios estratificados.
%
% Onda NO dispersiva: la relación de dispersión es lineal ω = V·k
%   → la velocidad de fase c = ω/k = V = constante, no depende de ω
%   → todos los componentes espectrales viajan al mismo ritmo
%   → una señal con múltiples frecuencias llega SIN distorsión
%
% Lo que vamos a mostrar: un pulso compuesto por dos frecuencias distintas.
%   - En medio elástico homogéneo: llega sin distorsión (no hay dispersión)
%   - Esto cambiará cuando agreguemos capas (Fig en scripts futuros)
%
% Solución armónica (Foti Ec. 2.3 y 2.20):
%   u(x,t) = A · exp(i[kx - ω(k)t])
%   con k = ω/Vs para ondas S
%
% Relación de dispersión lineal para ondas S:
%   ω = Vs · k    →    c = ω/k = Vs = constante

% Dos frecuencias distintas
f1 = 10;   % Hz — frecuencia baja (longitud de onda larga)
f2 = 40;   % Hz — frecuencia alta (longitud de onda corta)

omega1 = 2*pi*f1;
omega2 = 2*pi*f2;

% Números de onda para ondas S (relación de dispersión: k = ω/Vs)
k1 = omega1 / Vs;
k2 = omega2 / Vs;

% Longitudes de onda correspondientes: λ = 2π/k = Vs/f
lambda1 = Vs / f1;   % longitud de onda a f1 [m]
lambda2 = Vs / f2;   % longitud de onda a f2 [m]

fprintf('--- CARÁCTER NO DISPERSIVO (onda S) ---\n');
fprintf('  Frecuencia f1 = %2.0f Hz  →  λ1 = %.1f m,  k1 = %.4f rad/m\n', f1, lambda1, k1);
fprintf('  Frecuencia f2 = %2.0f Hz  →  λ2 = %.1f m,  k2 = %.4f rad/m\n', f2, lambda2, k2);
fprintf('  Velocidad de fase a f1: c1 = ω1/k1 = %.1f m/s\n', omega1/k1);
fprintf('  Velocidad de fase a f2: c2 = ω2/k2 = %.1f m/s\n', omega2/k2);
fprintf('  c1 = c2 = Vs: la velocidad NO depende de la frecuencia (NO dispersivo).\n\n');

% Dominio para esta figura: espacial corto para ver bien los ciclos
x_disp  = linspace(0, 400, 4000);
t_eval  = [0, 0.2, 0.4];   % tres instantes [s]

figure('Name', 'Fig 3 — No-dispersividad de ondas de cuerpo (Foti Sec. 2.2.2)', ...
       'NumberTitle', 'off', 'Position', [780 600 900 550]);

colores3 = {'b', 'r', [0.1 0.6 0.1]};

for it = 1:length(t_eval)
    t_k = t_eval(it);
    subplot(length(t_eval), 1, it);
    hold on;

    % Onda S a frecuencia f1
    u1 = cos(k1*x_disp - omega1*t_k);

    % Onda S a frecuencia f2
    u2 = 0.6 * cos(k2*x_disp - omega2*t_k);

    % Señal compuesta: superposición de las dos componentes
    u_sum = u1 + u2;

    plot(x_disp, u_sum, 'Color', colores3{it}, 'LineWidth', 1.5);
    plot(x_disp, u1, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);
    plot(x_disp, u2, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);

    xlabel('Posición x [m]', 'FontSize', 9);
    ylabel('Desplaz. [norm.]', 'FontSize', 9);
    title(sprintf('t = %.1f s  — el patrón se traslada sin deformarse (velocidad = %.0f m/s)', ...
        t_k, Vs), 'FontSize', 9);
    ylim([-2.2 2.2]);
    xlim([0 400]);
    grid on;

    if it == 1
        legend({'Señal compuesta (f1+f2)', ...
                sprintf('Componente f1=%d Hz', f1), ...
                sprintf('Componente f2=%d Hz', f2)}, ...
               'Location', 'northeast', 'FontSize', 8);
    end
end

sgtitle({sprintf('Fig 3: No-dispersividad de ondas S en medio homogéneo (Vs = %.0f m/s)', Vs), ...
         'La señal compuesta se traslada SIN CAMBIAR DE FORMA — es la firma de una onda no dispersiva'}, ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 3 generada: no-dispersividad de ondas de cuerpo.\n');
fprintf('  La señal compuesta se traslada sin distorsión.\n');
fprintf('  CONTRASTE: con ondas superficiales en medios estratificados,\n');
fprintf('  cada frecuencia viaja a velocidad distinta → la señal se deforma.\n\n');
drawnow;

% =========================================================================
% FIGURA 4: Polarización — la diferencia fundamental entre P y S
% =========================================================================
%
% La polarización describe la DIRECCIÓN DEL MOVIMIENTO DE LAS PARTÍCULAS
% respecto a la dirección de propagación de la onda.
%
% ONDA P (primaria, compresional, longitudinal):
%   - Las partículas se mueven PARALELO a la dirección de propagación
%   - El material se comprime y dilata alternativamente
%   - Analogía: acordeón / resorte
%   - Detectada por: geófonos orientados en la dirección de propagación
%
% ONDA S (secundaria, de corte, transversal):
%   - Las partículas se mueven PERPENDICULAR a la dirección de propagación
%   - El material se deforma en corte puro (sin cambio de volumen)
%   - Analogía: cuerda de guitarra oscilando
%   - Componente SV: polarización en el plano vertical → detectada por geófonos verticales
%   - Componente SH: polarización horizontal → detectada por geófonos horizontales transversales
%   - Los fluidos perfectos NO transmiten ondas S (μ=0 → Vs=0)
%
% Referencia: Foti Sec. 2.1.3, Fig. 2.7 y 2.9

figure('Name', 'Fig 4 — Polarización de ondas P y S (Foti Fig. 2.7 y 2.9)', ...
       'NumberTitle', 'off', 'Position', [780 100 900 620]);

% Usamos un dominio pequeño para visualizar pocos ciclos
N_part  = 20;   % número de "partículas" que vamos a mostrar
x_p     = linspace(0, 200, N_part);   % posiciones de las partículas [m]
t_show  = 0;                           % instante de visualización [s]
f_show  = 5;                           % frecuencia para visualización [Hz]
omega_show = 2*pi*f_show;
k_P_show   = omega_show / Vp;
k_S_show   = omega_show / Vs;
amp_disp   = 5;   % amplitud de desplazamiento para visualización [m] (exagerada)

% --- Panel izquierdo: onda P ---
subplot(1, 2, 1);
hold on;

% Posición equilibrio de cada partícula (puntos grises)
plot(x_p, zeros(size(x_p)), 'o', 'MarkerSize', 4, 'MarkerFaceColor', [0.7 0.7 0.7], ...
     'MarkerEdgeColor', [0.5 0.5 0.5]);

% Desplazamiento de onda P: el movimiento es en X (dirección de propagación)
% Para onda P propagándose en +x: u_x = A·cos(k·x - ω·t), u_z = 0
u_x_P = amp_disp * cos(k_P_show * x_p - omega_show * t_show);
u_z_P = zeros(size(x_p));   % sin movimiento vertical para onda P pura en 1D

% Dibujar las partículas desplazadas
plot(x_p + u_x_P, u_z_P, 'o', 'MarkerSize', 7, 'MarkerFaceColor', [0.2 0.2 0.8], ...
     'MarkerEdgeColor', 'k');

% Dibujar flechas de desplazamiento
for i = 1:N_part
    if abs(u_x_P(i)) > 0.3
        quiver(x_p(i), 0, u_x_P(i)*0.9, 0, 0, 'b', 'MaxHeadSize', 0.5, 'LineWidth', 1);
    end
end

% Flecha de dirección de propagación
annotation('arrow', [0.08 0.42], [0.36 0.36], 'Color', 'k', 'LineWidth', 1.5);
text(90, -14, '→ Dirección de propagación', 'FontSize', 9, 'HorizontalAlignment', 'center');

xlabel('x [m]', 'FontSize', 10);
ylabel('z [m]', 'FontSize', 10);
title({'ONDA P (compresional)', ...
       'Movimiento de partículas || propagación', ...
       '(Foti Sec. 2.1.3, Fig. 2.7a)'}, 'FontSize', 10);
ylim([-20 20]);
xlim([-10 210]);
grid on;
axis equal;

% Anotación explicativa
text(100, 15, {'Las partículas se mueven', 'hacia/desde el frente de onda', ...
               '(compresión y dilatación)'}, ...
    'FontSize', 8, 'HorizontalAlignment', 'center', ...
    'BackgroundColor', [0.9 0.9 1.0], 'EdgeColor', 'b');

% --- Panel derecho: onda S (SV) ---
subplot(1, 2, 2);
hold on;

% Posición equilibrio
plot(x_p, zeros(size(x_p)), 'o', 'MarkerSize', 4, 'MarkerFaceColor', [0.7 0.7 0.7], ...
     'MarkerEdgeColor', [0.5 0.5 0.5]);

% Desplazamiento de onda S: el movimiento es en Z (perpendicular a propagación)
% Para onda SV propagándose en +x: u_x = 0, u_z = A·cos(k·x - ω·t)
u_x_S = zeros(size(x_p));   % sin movimiento horizontal para onda S pura
u_z_S = amp_disp * cos(k_S_show * x_p - omega_show * t_show);

% Partículas desplazadas
plot(x_p + u_x_S, u_z_S, 'o', 'MarkerSize', 7, 'MarkerFaceColor', [0.8 0.2 0.2], ...
     'MarkerEdgeColor', 'k');

% Flechas de desplazamiento
for i = 1:N_part
    if abs(u_z_S(i)) > 0.3
        quiver(x_p(i), 0, 0, u_z_S(i)*0.9, 0, 'r', 'MaxHeadSize', 0.5, 'LineWidth', 1);
    end
end

% Curva sinusoidal para guía visual
x_cont = linspace(0, 200, 500);
u_z_cont = amp_disp * cos(k_S_show * x_cont - omega_show * t_show);
plot(x_cont, u_z_cont, '--', 'Color', [0.8 0.5 0.5], 'LineWidth', 0.8);

annotation('arrow', [0.55 0.89], [0.36 0.36], 'Color', 'k', 'LineWidth', 1.5);
text(90, -14, '→ Dirección de propagación', 'FontSize', 9, 'HorizontalAlignment', 'center');

xlabel('x [m]', 'FontSize', 10);
ylabel('z [m]', 'FontSize', 10);
title({'ONDA S (corte, componente SV)', ...
       'Movimiento de partículas ⊥ propagación', ...
       '(Foti Sec. 2.1.3, Fig. 2.7b y 2.9)'}, 'FontSize', 10);
ylim([-20 20]);
xlim([-10 210]);
grid on;
axis equal;

text(100, 15, {'Las partículas se mueven', 'perpendicular al frente de onda', ...
               '(deformación de corte puro)'}, ...
    'FontSize', 8, 'HorizontalAlignment', 'center', ...
    'BackgroundColor', [1.0 0.9 0.9], 'EdgeColor', 'r');

sgtitle({'Fig 4: Polarización de ondas P y S en un medio elástico homogéneo', ...
         'La diferencia en polarización determina qué tipo de geófono detecta cada onda'}, ...
        'FontSize', 10, 'FontWeight', 'bold');

fprintf('FIG 4 generada: polarización de ondas P y S.\n');
fprintf('  Onda P: movimiento de partículas PARALELO a propagación.\n');
fprintf('  Onda S: movimiento de partículas PERPENDICULAR a propagación.\n');
fprintf('  Consecuencia para los geófonos:\n');
fprintf('    - Geófono vertical detecta principalmente SV (y Rayleigh en superficie)\n');
fprintf('    - Geófono horizontal transversal detecta SH (y Love en superficie)\n\n');
drawnow;

% =========================================================================
% FIGURA 5: Relación de dispersión ω-k (espectro de frecuencias)
% =========================================================================
%
% La relación de dispersión ω(k) es la firma matemática de cómo se propaga
% una onda. Para ondas de cuerpo en medio homogéneo (Foti Ec. 2.5 y 2.21):
%
%   ω = V · k    (relación LINEAL)
%
% Esto significa:
%   - La curva ω(k) es una recta con pendiente V
%   - La velocidad de fase c = ω/k = V·k/k = V = constante
%   - La velocidad de grupo cg = dω/dk = V = constante
%   - c = cg en todo punto → las ondas de cuerpo no son dispersivas
%
% CONTRASTE: cuando veamos ondas superficiales, la curva ω(k) será NO lineal,
% lo que significa c ≠ cg y c depende de la frecuencia → DISPERSIÓN.

k_vec = linspace(0, 0.3, 300);   % vector de número de onda [rad/m]

omega_P = Vp * k_vec;   % relación de dispersión para onda P: ω = Vp·k
omega_S = Vs * k_vec;   % relación de dispersión para onda S: ω = Vs·k

% Convertir a frecuencia Hz para el eje y
f_P = omega_P / (2*pi);
f_S = omega_S / (2*pi);

figure('Name', 'Fig 5 — Relación de dispersión ω-k (Foti Ec. 2.5 y 2.21)', ...
       'NumberTitle', 'off', 'Position', [50 100 700 500]);

hold on;

% Graficar las dos relaciones de dispersión
plot(k_vec, f_P, 'b-', 'LineWidth', 2.5, 'DisplayName', sprintf('Onda P (Vp=%.0f m/s)', Vp));
plot(k_vec, f_S, 'r-', 'LineWidth', 2.5, 'DisplayName', sprintf('Onda S (Vs=%.0f m/s)', Vs));

% Mostrar que la pendiente es la velocidad de fase
% Trazar líneas de velocidad constante de referencia
k_ref = 0.2;
plot([0 k_ref], [0 Vp*k_ref/(2*pi)], '--b', 'LineWidth', 0.8, 'HandleVisibility', 'off');
plot([0 k_ref], [0 Vs*k_ref/(2*pi)], '--r', 'LineWidth', 0.8, 'HandleVisibility', 'off');

% Anotar la pendiente (velocidad de fase)
text(0.18, Vp*0.18/(2*pi) + 2, sprintf('pendiente = V_P = %.0f m/s', Vp), ...
    'FontSize', 9, 'Color', 'b', 'FontWeight', 'bold');
text(0.18, Vs*0.18/(2*pi) + 2, sprintf('pendiente = V_S = %.0f m/s', Vs), ...
    'FontSize', 9, 'Color', 'r', 'FontWeight', 'bold');

% Marcar un punto y mostrar c = ω/k
k_mark = 0.1;
f_mark = Vs * k_mark / (2*pi);
plot(k_mark, f_mark, 'ro', 'MarkerSize', 9, 'MarkerFaceColor', 'r');
text(k_mark + 0.005, f_mark - 2, sprintf('  c = ω/k = %.0f m/s = Vs', Vs), ...
    'FontSize', 8, 'Color', 'r');

xlabel('Número de onda k  [rad/m]', 'FontSize', 11);
ylabel('Frecuencia f = ω/2π  [Hz]', 'FontSize', 11);
title({'Relación de dispersión ω-k de ondas P y S', ...
       '(Foti Ec. 2.21: k_χ = ω/V_χ)   — curva lineal = NO dispersivo'}, 'FontSize', 11);
legend('Location', 'northwest', 'FontSize', 10);
grid on;
xlim([0 0.3]);
ylim([0 max(f_P)*1.05]);

% Añadir nota sobre la diferencia con ondas superficiales
text(0.15, max(f_P)*0.15, ...
    {'NOTA: La curva ω-k lineal', 'es la firma de NO-dispersión.', ...
     'Con ondas superficiales veremos', 'curvas ω-k NO lineales → dispersión.'}, ...
    'FontSize', 8, 'BackgroundColor', [1 1 0.85], 'EdgeColor', [0.8 0.8 0], ...
    'HorizontalAlignment', 'left');

fprintf('FIG 5 generada: relación de dispersión ω-k.\n');
fprintf('  Observar las rectas con pendiente Vp y Vs.\n');
fprintf('  c = ω/k = pendiente = constante → no dispersivo.\n');
fprintf('  La velocidad de grupo cg = dω/dk = pendiente = V = c → c = cg siempre.\n\n');
drawnow;

% =========================================================================
% RESUMEN FINAL EN CONSOLA
% =========================================================================

fprintf('=================================================================\n');
fprintf(' RESUMEN — Ondas de cuerpo en medio elástico homogéneo\n');
fprintf('=================================================================\n\n');

fprintf('PROPIEDADES DEL MEDIO SIMULADO:\n');
fprintf('  ρ = %.0f kg/m³,  μ = %.0f MPa,  λ = %.0f MPa,  ν = %.2f\n', ...
    rho, mu/1e6, lambda/1e6, nu);
fprintf('  Vp = %.1f m/s,  Vs = %.1f m/s,  Vp/Vs = %.2f\n\n', Vp, Vs, Vp/Vs);

fprintf('CONCEPTOS DEMOSTRADOS:\n');
fprintf('  1. Vp > Vs siempre (Fig 1, Fig 2)\n');
fprintf('  2. En suelos saturados (ν→0.5), Vp→∞ mientras Vs permanece finito\n');
fprintf('     → Vp es insensible a la rigidez del esqueleto sólido\n');
fprintf('     → Vs es el parámetro geotécnicamente relevante\n');
fprintf('  3. Las ondas P y S son NO dispersivas en medio homogéneo:\n');
fprintf('     c(ω) = Vp o Vs = constante (Fig 3, Fig 5)\n');
fprintf('  4. P: movimiento de partículas || propagación (longitudinal) (Fig 4)\n');
fprintf('     S: movimiento de partículas ⊥ propagación (transversal) (Fig 4)\n');
fprintf('  5. La relación de dispersión ω-k es LINEAL (Fig 5)\n');
fprintf('     → cuando sea no lineal, tendremos dispersión (ondas superficiales)\n\n');

fprintf('PRÓXIMOS SCRIPTS:\n');
fprintf('  p02_rayleigh_half_space.m — Rayleigh waves en half-space homogéneo\n');
fprintf('    (cómo surge una onda superficial de las condiciones de frontera)\n');
fprintf('  p03_dispersion_capas.m   — efecto de las capas: aparece la dispersión\n\n');

fprintf('=================================================================\n');
