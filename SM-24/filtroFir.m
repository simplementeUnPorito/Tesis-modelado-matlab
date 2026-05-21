% 1. Parámetros principales (¡Cambia 'fs' por tu frecuencia real!)
fs = 1465;              % Frecuencia de muestreo en Hz
Nyq = fs / 2;           % Frecuencia de Nyquist

% 2. Definición de las bandas (Frecuencias en Hz)
% Banda 1: Pasa todo de 0 a 45 Hz
% Banda 2: Notch (Corte) de 49 a 51 Hz (para el ruido de 50 Hz)
% Banda 3: Pasa todo de 55 a 90 Hz
% Banda 4: Lowpass (Corte profundo) desde 100 Hz hasta Nyquist
f_bands = [0 45, 49 51, 55 90, 100 Nyq]; 


% Normalizamos las frecuencias para firpm (escala de 0 a 1)
f_norm = f_bands / Nyq;

% 3. Amplitudes deseadas por banda (1 = Pasa, 0 = Corta)
a = [1 1, 0 0, 1 1, 0 0];

% 1. Definir los errores máximos permitidos (Ripples)
delta_paso = 0.01;                        % Permite un 1% de variación en las bandas pasantes
delta_50Hz = 10^(-40 / 20);               % 40 dB convertidos a lineal
delta_100Hz = 10^(-200/ 20);             % 100 dB convertidos a lineal

% 2. Calcular los pesos relativos (tomando la banda de paso como referencia = 1)
peso_paso = 1;
peso_50Hz = delta_paso / delta_50Hz;      % Resulta en 1
peso_100Hz = delta_paso / delta_100Hz;    % Resulta en 1000

% 3. Armar el vector W en el mismo orden que tus bandas
% Orden: [Pasa(1), Corta50(2), Pasa(3), Corta100(4)]
w = [peso_paso, peso_50Hz, peso_paso, peso_100Hz];

% 5. Orden del filtro (N)
% Las transiciones abruptas (ej. de 90Hz a 100Hz) y atenuaciones de 100dB 
% requieren un orden ALTO. Empieza con 400 y ajusta.
N = 128; 

% 6. Generación de los coeficientes FIR
coeficientes_b = firpm(800, [0 100, 110 510]/(510), [1 1, 0 0], [1, 1/(10^(-100 / 20))]);%firpm(N, f_norm, a, w);

% firpm(400, [0 45, 49 51, 55 90, 100 510]/510, [1 1, 0 0, 1 1, 0 0], [1, 1/(10^(-40 / 20)), 1, 1/(10^(-100 / 20))]);

% 7. Visualización
% Esto abrirá una ventana donde podrás ver exactamente los dB de caída
fvtool(coeficientes_b, 1, 'Fs', fs);

