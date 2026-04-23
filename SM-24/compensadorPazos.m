% =========================================================================
% Optimización Máxima: Menor Frecuencia de Corte con Damping 0.707
% =========================================================================

clear; clc; close all;

%% 1. Parámetros del Geófono SM-24 (10 Hz)
m = 0.011;                  % Masa móvil (kg)
fn = 10;                    % Frecuencia natural (Hz)
wn = 2 * pi * fn;           % Frecuencia natural en rad/s
h0 = 0.25;                  % Amortiguamiento original en circuito abierto
G = 28.8;                   % Sensibilidad intrínseca (V/(m/s))
Ri = 375;                   % Resistencia interna (Ohms)

%% 2. Parámetros de Búsqueda (Espacio Logarítmico Ampliado)
% Usamos logspace para barrer varios órdenes de magnitud eficientemente
R_L_vec = logspace(log10(100), log10(100000), 150); % 100 Ohms a 100 kOhms
C_vec = logspace(log10(1e-6), log10(1000e-6), 150);  % 1 uF a 1000 uF

target_damping = 1 / sqrt(2); % Damping ideal (0.707)
tol_damping = 0.03;           % Tolerancia permitida

% Matriz para almacenar resultados válidos: [RL, C, zeta, fc]
valid_results = [];

%% 3. Búsqueda y Evaluación de Polos
disp('Bariendo espacio de parámetros ampliado...');

for i = 1:length(R_L_vec)
    for j = 1:length(C_vec)
        
        RL = R_L_vec(i);
        C = C_vec(j);
        R_total = Ri + RL;
        
        % Coeficientes del denominador
        a3 = R_total * C;
        a2 = 1 + 2*wn*h0*R_total*C + (G^2 * C / m);
        a1 = 2*wn*h0 + wn^2*R_total*C;
        a0 = wn^2;
        den = [a3, a2, a1, a0];
        
        % Extraer polos
        p = roots(den);
        p_complex = p(imag(p) > 1e-5); % Polos complejos
        
        if ~isempty(p_complex)
            % Calcular factor de amortiguamiento
            zeta = -real(p_complex(1)) / abs(p_complex(1));
            
            % Si cumple la condición de amortiguamiento (Butterworth)
            if abs(zeta - target_damping) <= tol_damping
                
                % Evaluar la Frecuencia de Corte (-3dB)
                num = [-G*RL*C, -G, 0, 0];
                sys = tf(num, den);
                
                % Reducimos el vector de frecuencias para acelerar el cálculo
                w_eval = logspace(-1, 2, 300);
                [mag, ~, w_out] = bode(sys, w_eval);
                mag_dB = 20*log10(squeeze(mag));
                
                % Ganancia asintótica en la banda plana (altas frecuencias)
                flat_band_gain = mag_dB(end);
                
                % Buscar el punto de -3dB
                idx_cutoff = find(mag_dB >= (flat_band_gain - 3), 1, 'first');
                
                if ~isempty(idx_cutoff)
                    fc = w_out(idx_cutoff) / (2*pi);
                    % Guardar combinación válida
                    valid_results = [valid_results; RL, C, zeta, fc];
                end
            end
        end
    end
end

%% 4. Selección del Mínimo Absoluto y Visualización
if isempty(valid_results)
    disp('No se encontraron combinaciones válidas. Intenta relajar la tolerancia.');
else
    % Ordenar los resultados por la columna 4 (Frecuencia de corte) de menor a mayor
    valid_results = sortrows(valid_results, 4);
    
    % Extraer el mejor caso (el de menor fc)
    best_R = valid_results(1, 1);
    best_C = valid_results(1, 2);
    best_zeta = valid_results(1, 3);
    best_fc = valid_results(1, 4);
    
    fprintf('\n--- MEJOR RESULTADO GLOBAL (fc más baja) ---\n');
    fprintf('Resistencia de Carga (RL): %.2f Ohms\n', best_R);
    fprintf('Capacitor Serie (C): %.2f uF\n', best_C * 1e6);
    fprintf('Amortiguamiento dominante (Zeta): %.4f\n', best_zeta);
    fprintf('Frecuencia de corte original: %.2f Hz\n', fn);
    fprintf('Nueva Frecuencia de corte (-3dB): %.2f Hz\n', best_fc);
    
    % Reconstruir el mejor sistema para graficar
    R_total = Ri + best_R;
    den_best = [R_total*best_C, ...
                1 + 2*wn*h0*R_total*best_C + (G^2 * best_C / m), ...
                2*wn*h0 + wn^2*R_total*best_C, ...
                wn^2];
    num_best = [-G*best_R*best_C, -G, 0, 0];
    best_sys = tf(num_best, den_best);
    
    % Graficar
    figure;
    opts = bodeoptions('cstprefs');
    opts.FreqUnits = 'Hz';
    opts.Grid = 'on';
    bode(best_sys, opts);
    title(sprintf('Extensión Máxima SM-24 - fc=%.2f Hz, \\zeta=%.3f\nR=%.0f \\Omega, C=%.1f \\muF', ...
        best_fc, best_zeta, best_R, best_C*1e6));
end