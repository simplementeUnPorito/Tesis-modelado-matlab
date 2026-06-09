% prueba_removeLineNoise.m
% Prueba removeLineNoise_SpectrumEstimation con datos de muestra ESP32.
% Carga geo1 y geo2 desde muestra_20260608_174501 y compara antes/después.
%
% Parámetros ajustables:
%   LF  = frecuencia de red (50 Hz en Argentina)
%   NH  = número de armónicos a eliminar
%   HW  = semi-ancho del pico en bins (2 = default)

clc; close all;

DATA_DIR = 'C:\Github\Tesis\Crudos\muestra_20260608_174501';
LF       = 50;
NH       = 5;
HW       = 2;

opts = sprintf('LF=%d, NH=%d, HW=%d', LF, NH, HW);

% =========================================================================
%% 1. Leer metadata
% =========================================================================
meta = jsondecode(fileread(fullfile(DATA_DIR, 'metadata.json')));
fs   = meta.fs;
fprintf('fs = %d Hz  |  %d nodos activos\n', fs, meta.n_slaves);

% Identificar nodos con datos
nodos = struct('nombre',{},'dir',{},'pga',{},'notch_on',{});
for k = 1:numel(meta.nodes)
    nd = meta.nodes(k);
    if nd.raw_count > 0 && ~isempty(nd.data_dir)
        nodos(end+1).nombre   = nd.name;        %#ok<AGROW>
        nodos(end).dir        = nd.data_dir;
        nodos(end).pga        = nd.pga_gain;
        nodos(end).notch_on   = nd.notch_enabled;
    end
end
fprintf('%d nodos con datos: %s\n\n', numel(nodos), ...
    strjoin({nodos.nombre}, ', '));

% =========================================================================
%% 2. Cargar señales raw
% =========================================================================
raw_all = cell(1, numel(nodos));
for k = 1:numel(nodos)
    fpath = fullfile(DATA_DIR, nodos(k).dir, 'raw_f32le.bin');
    fid   = fopen(fpath, 'rb');
    raw_all{k} = fread(fid, inf, 'float32', 0, 'ieee-le')';
    fclose(fid);
    fprintf('Nodo %s: %d muestras  (PGA x%d, notch_web=%d)\n', ...
        nodos(k).nombre, numel(raw_all{k}), nodos(k).pga, nodos(k).notch_on);
end

% =========================================================================
%% 3. Aplicar removeLineNoise_SpectrumEstimation
% =========================================================================
fprintf('\n');
denoised_all = cell(1, numel(nodos));
for k = 1:numel(nodos)
    fprintf('--- %s ---\n', nodos(k).nombre);
    denoised_all{k} = removeLineNoise_SpectrumEstimation(raw_all{k}, fs, opts);
end

% =========================================================================
%% 4. Función auxiliar: espectro en dB
% =========================================================================
function [f, X_dB] = espectro_dB(sig, fs)
    N     = numel(sig);
    win   = hann(N,'periodic')';
    X     = abs(fft((sig - mean(sig)) .* win));
    X     = X(1:floor(N/2)+1) * 2 / sum(win);
    f     = (0:numel(X)-1) * (fs / N);
    X_dB  = 20*log10(X + eps);
end

% =========================================================================
%% 5. Figura comparativa
% =========================================================================
nN    = numel(nodos);
t_vec = (0:numel(raw_all{1})-1) / fs;

col_raw  = [0.25 0.55 0.80];
col_den  = [0.90 0.35 0.10];

fig = figure('Name','Prueba removeLineNoise — Comparación por nodo', ...
    'NumberTitle','off', 'Position',[40 40 1400 260*nN+60]);

for k = 1:nN
    raw     = raw_all{k};
    den     = denoised_all{k};
    nombre  = nodos(k).nombre;
    t       = (0:numel(raw)-1) / fs;

    % ── Señal en tiempo ──────────────────────────────────────────────────
    ax_t = subplot(nN, 3, (k-1)*3 + 1);
    plot(ax_t, t, raw, 'Color',[col_raw 0.7], 'LineWidth',0.6, 'DisplayName','raw');
    hold(ax_t,'on');
    plot(ax_t, t, den, 'Color',col_den,        'LineWidth',0.7, 'DisplayName','denoised');
    hold(ax_t,'off');
    xlabel(ax_t,'Tiempo (s)'); ylabel(ax_t,'V');
    title(ax_t, sprintf('%s — tiempo', nombre));
    legend(ax_t,'show','Location','northeast','FontSize',7);
    grid(ax_t,'on'); xlim(ax_t,[0 t(end)]);

    % ── Espectro completo (log-x) ─────────────────────────────────────────
    [f_r, Xr_dB] = espectro_dB(raw, fs);
    [f_d, Xd_dB] = espectro_dB(den, fs);

    ax_f = subplot(nN, 3, (k-1)*3 + 2);
    plot(ax_f, f_r(2:end), Xr_dB(2:end), 'Color',[col_raw 0.8], ...
        'LineWidth',0.7, 'DisplayName','raw');
    hold(ax_f,'on');
    plot(ax_f, f_d(2:end), Xd_dB(2:end), 'Color',col_den, ...
        'LineWidth',0.8, 'DisplayName','denoised');
    % Marcar armónicos de red
    for h = 1:NH
        xline(ax_f, LF*h, '--', 'Color',[0.5 0.5 0.5], 'LineWidth',0.7, ...
            'Alpha',0.7, 'HandleVisibility','off');
    end
    hold(ax_f,'off');
    set(ax_f,'XScale','log');
    xlim(ax_f,[f_r(2) fs/2]);
    xlabel(ax_f,'Frecuencia (Hz)'); ylabel(ax_f,'dB re 1V');
    title(ax_f, sprintf('%s — espectro (log)', nombre));
    legend(ax_f,'show','Location','southwest','FontSize',7);
    grid(ax_f,'on');

    % ── Zoom espectro 0–300 Hz (lineal) ──────────────────────────────────
    ax_z = subplot(nN, 3, (k-1)*3 + 3);
    plot(ax_z, f_r, Xr_dB, 'Color',[col_raw 0.8], ...
        'LineWidth',0.7, 'DisplayName','raw');
    hold(ax_z,'on');
    plot(ax_z, f_d, Xd_dB, 'Color',col_den, ...
        'LineWidth',0.9, 'DisplayName','denoised');
    for h = 1:NH
        xline(ax_z, LF*h, '--', 'Color',[0.5 0.5 0.5], 'LineWidth',0.7, ...
            'Alpha',0.7, 'HandleVisibility','off');
    end
    hold(ax_z,'off');
    xlim(ax_z,[0 300]); ylim_auto = ylim(ax_z); ylim(ax_z, ylim_auto);
    xlabel(ax_z,'Frecuencia (Hz)'); ylabel(ax_z,'dB re 1V');
    title(ax_z, sprintf('%s — zoom 0–300 Hz', nombre));
    legend(ax_z,'show','Location','southwest','FontSize',7);
    grid(ax_z,'on');

    % ── Estadísticas de reducción ─────────────────────────────────────────
    for h = 1:NH
        f_harm = LF * h;
        mask   = f_r >= f_harm - 2 & f_r <= f_harm + 2;
        if any(mask)
            red_dB = mean(Xr_dB(mask)) - mean(Xd_dB(mask));
            fprintf('  %s  %3d Hz:  reducción %.1f dB\n', nombre, f_harm, red_dB);
        end
    end
end

sgtitle(fig, sprintf('removeLineNoise_SpectrumEstimation  |  LF=%dHz  NH=%d  HW=%d  |  fs=%dHz', ...
    LF, NH, HW, fs), 'FontSize',10, 'FontWeight','bold');

fprintf('\nListo.\n');
