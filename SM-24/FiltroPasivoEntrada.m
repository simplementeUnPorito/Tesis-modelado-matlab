%% Optimizador Target - Búsqueda EXACTA de 6.50 Hz (Solo Rp y C)
clear; clc; close all;

% 1. PARÁMETROS DEL GEÓFONO (SM-24)
m = 0.011; k = 43.4; G = 28.8; c_m = 0.05; R_coil = 375;
Rs = 0; % FIJAMOS Rs EN CERO

% 2. OBJETIVO EXACTO
target_fc = 6.5; 

% 3. CONFIGURACIÓN DEL OPTIMIZADOR
% Tolerancias ultra finas (1e-12) para forzar la precisión en los decimales
options = optimoptions('fmincon', 'Display', 'iter', 'Algorithm', 'sqp', ...
    'StepTolerance', 1e-12, 'OptimalityTolerance', 1e-12, 'MaxFunctionEvaluations', 5000);

% 4. LÍMITES FÍSICOS DE LOS COMPONENTES
% x = [Rp, C]
lb = [100, 1e-9]; 
ub = [1e6, 1e-3]; 

% Usamos tu último resultado como punto de partida para que llegue más rápido
x0 = [1509.05, 20.86e-6]; 

fprintf('\n=== INICIANDO BÚSQUEDA DE PRECISIÓN (Objetivo: %.2f Hz) ===\n', target_fc);

% LA MAGIA: La función objetivo ahora minimiza el error al cuadrado respecto a 6.50
obj_fun = @(x) (get_fc(x, Rs, m, c_m, k, G, R_coil) - target_fc)^2;

[x_opt, error_cuadratico] = fmincon(obj_fun, x0, [], [], [], [], ...
    lb, ub, @(x) nonlcon(x, Rs, m, c_m, k, G, R_coil), options);

% 5. CÁLCULO FINAL Y RESULTADOS
Rp_opt = x_opt(1);
C_opt = x_opt(2);
Req = R_coil + Rs + Rp_opt;
f_final = get_fc(x_opt, Rs, m, c_m, k, G, R_coil);

fprintf('\n================ RESULTADO EXACTO =================\n');
fprintf('Rs (Ohms)       : %10.2f (Fija)\n', Rs);
fprintf('Rp (Ohms)       : %10.2f\n', Rp_opt);
fprintf('C  (uF)         : %10.4f\n', C_opt * 1e6);
fprintf('Req Total (Ohms): %10.2f\n', Req);
fprintf('Frec. Corte (-3dB): %8.3f Hz\n', f_final);
fprintf('Error al objetivo : %8.6f Hz\n', abs(f_final - target_fc));
fprintf('===================================================\n');

% 6. GRAFICACIÓN
w = 2 * pi * logspace(-1, 2, 3000); % Más resolución para el gráfico
f_hz = w / (2*pi);

a3 = m * C_opt * Req; a2 = m + c_m * C_opt * Req + G^2 * C_opt;
a1 = c_m + k * C_opt * Req; a0 = k;
sys = tf([G * m * C_opt * Rp_opt, 0, 0, 0], [a3, a2, a1, a0]);

[mag, ~] = bode(sys, w); mag = squeeze(mag); 
gain_inf = (G * Rp_opt) / Req;
mag_db = 20*log10(mag / gain_inf);

figure('Name', 'Respuesta Exacta 6.50 Hz', 'Color', 'w');
semilogx(f_hz, mag_db, 'b', 'LineWidth', 2); hold on;
yline(-3, 'r:', '-3 dB');
xline(f_final, 'k--', sprintf('%.3f Hz', f_final), 'LabelVerticalAlignment', 'bottom');
grid on;
title(sprintf('Diseño Calibrado Exacto a %.2f Hz', f_final));
xlabel('Frecuencia (Hz)'); ylabel('Magnitud Normalizada (dB)');
xlim([1 100]); ylim([-20 10]);

% --- FUNCIONES AUXILIARES ---

function f_c = get_fc(x, Rs, m, c_m, k, G, R_coil)
    % Aislamos el cálculo de frecuencia para usarlo de objetivo directo
    Rp = x(1); C = x(2); Req = R_coil + Rs + Rp;
    a3 = m * C * Req; a2 = m + c_m * C * Req + G^2 * C;
    a1 = c_m + k * C * Req; a0 = k;
    
    sys = tf([G * m * C * Rp, 0, 0, 0], [a3, a2, a1, a0]);
    w = 2 * pi * logspace(-1, 2, 1000);
    [mag, ~] = bode(sys, w); mag = squeeze(mag);
    
    gain_inf = (G * Rp) / Req;
    if gain_inf == 0, f_c = 100; return; end
    mag_norm = mag / gain_inf;
    
    idx = find(mag_norm >= 1/sqrt(2), 1, 'first');
    if isempty(idx) || idx == 1
        f_c = 100; 
    else
        w1 = w(idx-1); w2 = w(idx);
        m1 = mag_norm(idx-1); m2 = mag_norm(idx);
        w_c = w1 + (w2 - w1) * (1/sqrt(2) - m1) / (m2 - m1);
        f_c = w_c / (2*pi);
    end
end

function [c, ceq] = nonlcon(x, Rs, m, c_m, k, G, R_coil)
    Rp = x(1); C = x(2); Req = R_coil + Rs + Rp;
    a3 = m * C * Req; a2 = m + c_m * C * Req + G^2 * C;
    a1 = c_m + k * C * Req; a0 = k;
    
    p = roots([a3, a2, a1, a0]);
    c(1) = max(real(p)) + 1e-4; % Mantener sistema estable
    
    % Ponemos un piso de damping muy permisivo (0.15) solo para evitar 
    % que el optimizador proponga un circuito que oscile eternamente.
    complejos = p(imag(p) ~= 0);
    if ~isempty(complejos)
        zeta = -real(complejos) ./ abs(complejos);
        c(2) = 0.15 - min(zeta); 
    else
        c(2) = -1; 
    end
    ceq = [];
end