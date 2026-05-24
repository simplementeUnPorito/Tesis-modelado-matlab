% visor_rapido.m
% Abre un .mat, elige una medición y grafica con una sola señal.
%
% ── CÓMO FUNCIONA ──────────────────────────────────────────────────────────
% 1. Selección de archivo y medición por terminal.
% 2. Elegir señal: raw PSoC o filtrada MATLAB.
% 3. Detección de golpes via envolvente Hilbert (ver detectarGolpes).
% 4. Espectro de magnitud (FFT + Hanning).
%    f_min = fs/N  |  f_max = fs/2
%    Corrección por TF de punta del martillo PCB TLD086D20 (LP 1er orden).
%    Frecuencias -10 dB por punta: negra=1000, roja=700, marron=450, gris=400 Hz
%    f_c de cada punta = f_10dB / 3  (de la definición de LP 1er orden)
% 5. Espectrograma con ventana corta para ver golpes individuales.
%    f_min = fs/WIN_SPECT  |  f_max = fs/2
% ───────────────────────────────────────────────────────────────────────────

clc; close all;

% --- Parámetros detección de golpes ---
SMOOTH_ENV_SEC = 0.05;
THRESH_SIGMA   = 2.5;
PRE_PAD_SEC    = 0.30;
POST_PAD_SEC   = 2.00;
MIN_QUIET_SEC  = 1.00;

scriptDir = fileparts(mfilename('fullpath'));
datosDir  = fullfile(scriptDir, 'datos');

% =========================================================================
%% Seleccionar archivo
% =========================================================================
archivos = dir(fullfile(datosDir, '*.mat'));
if isempty(archivos)
    fprintf('No se encontraron archivos .mat en %s\n', datosDir); return
end

fprintf('\n=== VISOR RÁPIDO ===\n');
fprintf('Archivos disponibles:\n');
fprintf('  %3s  %s\n', '#', 'Archivo');
fprintf('  %s\n', repmat('-',1,45));
for k = 1:numel(archivos)
    fprintf('  %3d  %s\n', k, archivos(k).name);
end
fprintf('\n');
opc_f = input(sprintf('Seleccionar archivo (1–%d): ', numel(archivos)));
if isempty(opc_f) || opc_f < 1 || opc_f > numel(archivos)
    fprintf('Selección inválida.\n'); return
end
fname = archivos(opc_f).name;

d = load(fullfile(datosDir, fname));
if ~isfield(d, 'muestras')
    error('El archivo no contiene el campo "muestras".'); end

ent      = struct('nombre','','fs',1020,'fMin',0,'fMax',0,'ganancia',1,'observ','');
if isfield(d,'entidad'), ent = d.entidad; end
muestras = d.muestras;
N        = numel(muestras);

% =========================================================================
%% Seleccionar medición
% =========================================================================
fprintf('\nArchivo : %s\n', fname);
fprintf('Entidad : %s  |  fs=%g SPS  |  G=%g\n', ent.nombre, double(ent.fs), double(ent.ganancia));
fprintf('\n%-4s  %-8s  %-6s  %-5s  %-3s  %-22s  %8s  %s\n','#','Punta','Dist','PGA','Seq','Timestamp','Dur(s)','Observ');
fprintf('%s\n', repmat('-',1,82));
for i = 1:N
    m   = muestras(i);
    pnt = ''; if isfield(m,'punta'),     pnt = m.punta;     end
    ts  = ''; if isfield(m,'timestamp'), ts  = m.timestamp; end
    obs = ''; if isfield(m,'observ'),    obs = m.observ;    end
    dist_s = char(8212); % —
    pga_s  = char(8212);
    seq_s  = char(8212);
    if isfield(m,'distancia')          && ~isempty(m.distancia)          && ~isnan(double(m.distancia)),          dist_s = sprintf('%gp',double(m.distancia));    end
    if isfield(m,'ganancia_pga')       && ~isempty(m.ganancia_pga)       && ~isnan(double(m.ganancia_pga)),       pga_s  = sprintf('x%g',double(m.ganancia_pga)); end
    if isfield(m,'secuencia_inicio_s') && ~isempty(m.secuencia_inicio_s) && ~isnan(double(m.secuencia_inicio_s)), seq_s  = 'si';                                  end
    if isfield(m,'raw_V')
        dur = numel(m.raw_V)/double(m.fs);
    elseif isfield(m,'raw_mV')
        dur = numel(m.raw_mV)/double(m.fs);
    else
        dur = 0;
    end
    fprintf('%-4d  %-8s  %-6s  %-5s  %-3s  %-22s  %8.1f  %s\n', i, pnt, dist_s, pga_s, seq_s, ts, dur, obs);
end
fprintf('\n');

if N == 1
    idx = 1; fprintf('Única medición — seleccionando #1.\n');
else
    idx = input(sprintf('Seleccionar medición (1–%d): ', N));
    if isempty(idx) || idx < 1 || idx > N, fprintf('Selección inválida.\n'); return; end
    idx = round(idx);
end

% =========================================================================
%% Extraer señales
% =========================================================================
m   = muestras(idx);
fs  = double(m.fs);
if isfield(m,'raw_V')
    raw = double(m.raw_V(:));
elseif isfield(m,'raw_mV')
    raw = double(m.raw_mV(:)) / 1000;  % legado mV → V
else
    error('Medición sin campo raw_V ni raw_mV.');
end
fil = [];
if isfield(m,'filtered') && ~isempty(m.filtered), fil = double(m.filtered(:)); end
pnt = ''; if isfield(m,'punta'),     pnt = m.punta;     end
ts  = ''; if isfield(m,'timestamp'), ts  = m.timestamp; end
obs = ''; if isfield(m,'observ'),    obs = m.observ;    end

Ns  = numel(raw);
t   = (0:Ns-1).' / fs;
fn  = fs / 2;
flo = double(ent.fMin);
fhi = double(ent.fMax);

fprintf('\nMedición #%d  |  punta=%s  |  dur=%.1fs  |  %d muestras\n', idx, pnt, t(end), Ns);
if ~isempty(strtrim(obs)), fprintf('Observ: %s\n', obs); end

% --- Mostrar metadata estructurada si existe ---
meta_flds = {'distancia','unidad','ganancia_pga','tipo_dato','secuencia_inicio_s','periodo_estimado_s'};
meta_str = '';
for fi = 1:numel(meta_flds)
    fn_ = meta_flds{fi};
    if isfield(m, fn_)
        v = m.(fn_);
        if isnumeric(v) && ~isempty(v) && ~isnan(v)
            meta_str = [meta_str sprintf('%s=%g  ', fn_, v)]; %#ok<AGROW>
        elseif ischar(v) && ~isempty(strtrim(v))
            meta_str = [meta_str sprintf('%s=%s  ', fn_, strtrim(v))]; %#ok<AGROW>
        end
    end
end
if ~isempty(meta_str), fprintf('Meta   : %s\n', strtrim(meta_str)); end

% =========================================================================
%% Elegir señal
% =========================================================================
if ~isempty(fil)
    fprintf('\nSeñal a analizar:\n  1 = raw PSoC\n  2 = filtrada MATLAB  (recomendado)\n');
    opc_sig = input('Opción [2]: ');
    if isempty(opc_sig) || opc_sig ~= 1, opc_sig = 2; end
else
    opc_sig = 1;
end
sig_use = raw; lbl_use = 'raw PSoC';
if opc_sig == 2 && ~isempty(fil), sig_use = fil; lbl_use = 'filtrada'; end
fprintf('→ Usando: %s\n', lbl_use);

% =========================================================================
%% Detección de golpes
% =========================================================================
[mask_hit, ~, env_smooth, env_thresh] = detectarGolpes(sig_use, fs, ...
    SMOOTH_ENV_SEC, THRESH_SIGMA, PRE_PAD_SEC, POST_PAD_SEC, MIN_QUIET_SEC);
h_on = []; h_off = [];
if any(mask_hit)
    d_mh  = diff([0; double(mask_hit); 0]);
    h_on  = find(d_mh ==  1);
    h_off = min(find(d_mh == -1) - 1, Ns);
end
fprintf('Golpes detectados: %d  (%.0f%% activo)\n', numel(h_on), 100*sum(mask_hit)/Ns);

% =========================================================================
%% Espectro de magnitud
% =========================================================================
sig_dc = sig_use - mean(sig_use);
win_v  = hann(Ns);
X_use  = abs(fft(sig_dc .* win_v));
X_use  = X_use(1:floor(Ns/2)+1) * 2 / sum(win_v);
f_fft  = (0:numel(X_use)-1).' * (fs / Ns);

% =========================================================================
%% Estadísticas rápidas (estilo análisis espectral)
% =========================================================================
fpk_q   = NaN; f_lo3_q = NaN; f_hi3_q = NaN; snr_db_q = NaN;
dc_mask_q = f_fft > 2*(fs/Ns);
if any(dc_mask_q)
    X_dB_q  = 20*log10(X_use(dc_mask_q) + eps);
    f_dc_q  = f_fft(dc_mask_q);
    [~, ik] = max(X_dB_q);
    fpk_q   = f_dc_q(ik);
    res_excl  = (f_dc_q > fpk_q/sqrt(2)) & (f_dc_q < fpk_q*sqrt(2));
    flat_msk  = ~res_excl;
    ref_dB_q  = max(X_dB_q);
    if sum(flat_msk) > 5, ref_dB_q = prctile(X_dB_q(flat_msk), 90); end
    above3_q = X_dB_q >= ref_dB_q - 3;
    if any(above3_q)
        f_lo3_q = f_dc_q(find(above3_q, 1, 'first'));
        f_hi3_q = f_dc_q(find(above3_q, 1, 'last'));
    end
end
if flo > 0 && fhi > 0
    inb  = f_fft >= flo & f_fft <= fhi;
    outb = f_fft >= f_fft(2) & ~inb;
    if sum(inb) >= 2 && sum(outb) >= 2
        snr_db_q = 10*log10(mean(X_use(inb).^2) / (mean(X_use(outb).^2) + eps));
    end
end
fprintf('\n--- Estadísticas espectrales ---\n');
if ~isnan(fpk_q),    fprintf('  Pico FFT   : %.2f Hz\n',                 fpk_q);               end
if ~isnan(f_lo3_q),  fprintf('  −3dB BW    : %.2f – %.1f Hz\n',          f_lo3_q, f_hi3_q);    end
if ~isnan(snr_db_q), fprintf('  SNR banda  : %+.1f dB  (%g–%g Hz)\n',   snr_db_q, flo, fhi);  end
fprintf('  Golpes     : %d  (%.0f%% activo)\n', numel(h_on), 100*sum(mask_hit)/Ns);

% =========================================================================
%% Espectrograma
% =========================================================================
WIN_SPECT = min(2048, 2^nextpow2(max(64, round(Ns/16))));
OVL_SPECT = floor(WIN_SPECT * 0.75);
[s_use, f_s, t_s] = spectrogram(sig_dc, hann(WIN_SPECT), OVL_SPECT, WIN_SPECT, fs);
p_dB = 10*log10(abs(s_use).^2 + eps);

% =========================================================================
%% Figura
% =========================================================================
figTitle = sprintf('%s  —  #%d (%s)  |  %s  |  fs=%g Hz  |  dur=%.1fs', ...
    fname, idx, pnt, lbl_use, fs, t(end));

fig = figure('Name',figTitle,'NumberTitle','off','Position',[50 50 1380 700]);

% --- Tiempo ---
axT = subplot(2,2,[1 2]);
plot(axT, t, sig_use, 'Color',[0.25 0.55 0.80], 'LineWidth',0.8, 'DisplayName',lbl_use);
hold(axT,'on');

dc_use  = mean(sig_use);
col_env = [0.95 0.50 0.05];
plot(axT, t,  dc_use+env_smooth, 'Color',[col_env 0.7], 'LineWidth',0.8, 'DisplayName','envolvente');
plot(axT, t,  dc_use-env_smooth, 'Color',[col_env 0.7], 'LineWidth',0.8, 'HandleVisibility','off');
yline(axT,  dc_use+env_thresh,'--','Color',col_env,'LineWidth',1.0,...
    'Label',sprintf('umbral %.2gV',env_thresh),'FontSize',7,...
    'LabelHorizontalAlignment','left','HandleVisibility','off');
yline(axT,  dc_use-env_thresh,'--','Color',col_env,'LineWidth',1.0,'HandleVisibility','off');

if ~isempty(h_on)
    yl_t   = ylim(axT);
    col_gm = [0.05 0.58 0.15];
    for k = 1:numel(h_on)
        fill(axT,[t(h_on(k)) t(h_off(k)) t(h_off(k)) t(h_on(k))],...
            [yl_t(1) yl_t(1) yl_t(2) yl_t(2)],...
            [0.20 0.80 0.30],'FaceAlpha',0.13,'EdgeColor','none','HandleVisibility','off');
    end
    ylim(axT, yl_t);
    plot(axT,t(h_on), sig_use(h_on), 'o','Color',col_gm,'MarkerFaceColor',col_gm,...
        'MarkerSize',5,'LineStyle','none','DisplayName',sprintf('%d golpes',numel(h_on)));
    plot(axT,t(h_off),sig_use(h_off),'s','Color',col_gm,'MarkerFaceColor','none',...
        'MarkerSize',6,'LineStyle','none','HandleVisibility','off');
end

hold(axT,'off');
xlabel(axT,'Tiempo (s)'); ylabel(axT,'V');
title(axT, sprintf('Señal en tiempo — %d golpes detectados', numel(h_on)));
legend(axT,'show','Location','northeast','FontSize',8);
grid(axT,'on'); xlim(axT,[0 t(end)]);

% --- Espectro de magnitud + corrección por punta martillo TLD086D20 ---
% fc leído del gráfico del manual PCB 086D20 (−3 dB real, ventana Hann):
%   gris   = Very Soft  (otro modelo)  170 Hz  T_c≈5.3ms
%   marron = Soft       084B61         250 Hz  T_c≈3.6ms
%   rojo   = Medium     084B62         650 Hz  T_c≈1.4ms
%   negro  = Med/Hard   084B63        1600 Hz  T_c≈0.56ms
% Modelo: pulso de fuerza ≈ ventana Hann de duración T_c = 0.9/fc
punta_fc = containers.Map( ...
    {'gris','marron','roja','negra'}, ...
    {170,    250,    650,   1600});
punta_desc = containers.Map( ...
    {'gris','marron','roja','negra'}, ...
    {'Very Soft ~170Hz','Soft ~250Hz','Medium ~650Hz','Med/Hard ~1.6kHz'});

axF = subplot(2,2,3);
plot(axF, f_fft(2:end), 20*log10(X_use(2:end)+eps), ...
    'Color',[0.25 0.55 0.80], 'LineWidth',1.0, 'DisplayName',lbl_use);
hold(axF,'on');
if punta_fc.isKey(lower(pnt))
    fc_tip = punta_fc(lower(pnt));
    % Modelo Hann: pulso de contacto de duración T_c = 0.9/fc
    tc     = 0.9 / fc_tip;
    Ntc    = min(round(tc * fs) + 1, Ns);
    h_pulse = hann(Ntc, 'periodic')';
    H_tip_t = [h_pulse, zeros(1, Ns - Ntc)];
    H_tip_f = abs(fft(H_tip_t));
    H_tip_f = H_tip_f / max(H_tip_f(1), eps);   % normalizar a 1 en DC
    H_tip_f = H_tip_f(1:floor(Ns/2)+1)';        % mitad positiva
    X_corr  = X_use ./ max(H_tip_f(:), 1e-3);
    H_dB    = 20*log10(H_tip_f(2:end)+eps);
    lbl_corr = sprintf('corr. punta %s (%s)', pnt, punta_desc(lower(pnt)));
    plot(axF, f_fft(2:end), 20*log10(X_corr(2:end)+eps), ...
        '--', 'Color',[0.95 0.50 0.05], 'LineWidth',1.2, 'DisplayName',lbl_corr);
    plot(axF, f_fft(2:end), H_dB - max(H_dB), ...
        ':', 'Color',[0.6 0.6 0.6], 'LineWidth',0.8, 'DisplayName','H_{punta} (norm.)');
    % Marcar fc (−3dB) de la punta
    if fc_tip <= fn
        xline(axF, fc_tip, '-.', 'Color',[0.95 0.50 0.05], 'LineWidth',0.9, ...
            'Label', sprintf('fc=%gHz',fc_tip), ...
            'FontSize',6, 'LabelVerticalAlignment','bottom', 'HandleVisibility','off');
    end
end
if flo>0
    xline(axF,flo,'--g','LineWidth',1,'Label',sprintf('fMin=%gHz',flo),...
        'FontSize',7,'LabelVerticalAlignment','bottom');
end
if fhi>0&&fhi<=fn
    xline(axF,fhi,'-g','LineWidth',1,'Label',sprintf('fMax=%gHz',fhi),...
        'FontSize',7,'LabelVerticalAlignment','bottom');
end
xline(axF,fn,'--k','LineWidth',0.7,'Alpha',0.4);
hold(axF,'off');
set(axF,'XScale','log'); xlim(axF,[f_fft(2) fn]);
xlabel(axF,'Frecuencia (Hz)'); ylabel(axF,'dB re 1 V');
title(axF, sprintf('Espectro magnitud (Δf=%.3f Hz)', fs/Ns));
legend(axF,'Location','southwest','FontSize',8);
grid(axF,'on');

% --- Espectrograma ---
axS = subplot(2,2,4);
imagesc(axS, t_s, f_s, p_dB);
set(axS,'YDir','normal');
colormap(axS,jet); cb = colorbar(axS); ylabel(cb,'dB');
if flo>0, yline(axS,flo,'--w','LineWidth',1); end
if fhi>0&&fhi<=fn, yline(axS,fhi,'-w','LineWidth',1.3); end
ylim(axS,[fs/WIN_SPECT fn]);
xlabel(axS,'Tiempo (s)'); ylabel(axS,'Frecuencia (Hz)');
title(axS,sprintf('Espectrograma %s (vent=%d)', lbl_use, WIN_SPECT));

sgtitle(fig, figTitle,'Interpreter','none','FontSize',9,'FontWeight','bold');

% =========================================================================
%% Funciones locales
% =========================================================================
function [mask_hit, mask_quiet, env_smooth, thresh] = detectarGolpes(sig, fs, smoothSec, threshSigma, preSec, postSec, minQuietSec)
    Ns        = numel(sig);
    smoothSmp = max(1, round(smoothSec * fs));
    preSmp    = round(preSec  * fs);
    pstSmp    = round(postSec * fs);
    minQSmp   = round(minQuietSec * fs);
    sig_ac     = sig - mean(sig);
    env_inst   = abs(hilbert(sig_ac));
    env_smooth = movmean(env_inst, smoothSmp);
    thresh     = mean(env_smooth) + threshSigma * std(env_smooth);
    raw_mask   = env_smooth >= thresh;
    mask_hit   = false(Ns, 1);
    d_on  = diff([0; raw_mask]);
    d_off = diff([raw_mask; 0]);
    onsets  = find(d_on  ==  1);
    offsets = find(d_off == -1);
    nev = min(numel(onsets), numel(offsets));
    for k = 1:nev
        mask_hit(max(1,onsets(k)-preSmp) : min(Ns,offsets(k)+pstSmp)) = true;
    end
    mask_quiet = false(Ns, 1);
    dq       = diff([0; ~mask_hit; 0]);
    q_starts = find(dq ==  1);
    q_ends   = find(dq == -1) - 1;
    for k = 1:numel(q_starts)
        if (q_ends(k)-q_starts(k)+1) >= minQSmp
            mask_quiet(q_starts(k):q_ends(k)) = true;
        end
    end
end
