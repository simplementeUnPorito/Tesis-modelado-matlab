% 1. Definir el sistema continuo (usando tus variables)
num = system.Numerator{1};
den = system.Denominator{1};
sys_continuous = tf(num, den);

% 2. Definir el vector de frecuencias de interés (en rad/s)
w = logspace(-2, 2, 500); 

% 3. Obtener la fase del sistema continuo (en grados)
[~, phase_deg] = bode(sys_continuous, w);
phase_rad = squeeze(phase_deg) * (pi / 180); % Convertir a radianes

% 4. Calcular el retardo de fase: tau = -fase / w
% Se añade un signo negativo porque un desfase negativo (atraso) implica un retardo positivo.
phase_delay = -phase_rad ./ w(:);

% 5. Graficar el resultado
figure;
semilogx(w, phase_delay, 'LineWidth', 2);
grid on;
title('Retardo de Fase - Sistema Continuo');
xlabel('Frecuencia (\omega en rad/s)');
ylabel('Retardo de Fase (\tau_p en segundos)');
figure;
bode(sys_continuous);