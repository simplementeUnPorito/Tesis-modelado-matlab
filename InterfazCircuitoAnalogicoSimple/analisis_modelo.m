% analisis_modelo.m
% Estimación de la respuesta del sistema (circuito+geófono) usando el modelo físico
% del experimento de impacto con martillo.
%
% MODELO FORWARD:
%   Y(f) = H_sys(f) × H_tip(f) × H_suelo(f,r) × F_0
%
%   Donde:
%     H_sys(f)     = H_circuito(f) × H_geofono(f)  ← lo que queremos estimar
%     H_tip(f)     = TF de la punta (ventana Hann de duración T_c = 0.9/fc)
%     H_suelo(f,r) = dinámica suelo+interfaz: propagación geométrica (1/√r para
%                    ondas Rayleigh) + atenuación anelástica del medio. DESCONOCIDA
%                    pero aproximadamente constante si la posición es fija.
%     F_0          = amplitud de fuerza del golpe (desconocida, constante relativa)
%
%   H_sys_est(f) = Y_stack(f) / H_tip(f) / G_dist(r)
%
%   IMPORTANTE: H_sys_est absorbe H_suelo. Para comparar dos circuitos al mismo r,
%   H_suelo cancela y la comparación es válida. Para valores absolutos se necesita
%   calibrar H_suelo (p.ej. medición a múltiples distancias tipo MASW, o geófono
%   calibrado como referencia).
%
% FLUJO:
%   1. Seleccionar medición
%   2. Extraer hits (secuencia marcada O onsets automáticos)
%   3. Alinear hits por xcorr de envolvente
%   4. Stack coherente (promedio) → SNR mejora ~√N
%   5. Deconvolucionar H_tip (Hann model)
%   6. Corregir factor geométrico 1/√r si distancia disponible
%   7. Figuras: tiempo | stack | espectro | H_sys_est

clc; close all;

% =========================================================================
%% PARÁMETROS CONFIGURABLES
% =========================================================================
PRE_PAD_SEC    = 0.05;   % padding antes del onset (s)
POST_PAD_MAX_S = 1.50;   % máximo de ventana post-onset (s)
SMOOTH_ENV_SEC = 0.05;   % suavizado envolvente Hilbert
THRESH_SIGMA   = 2.5;
PRE_DET_SEC    = 0.30;
POST_DET_SEC   = 2.00;
MIN_QUIET_SEC  = 0.50;
MAX_ALIGN_FRAC = 0.20;   % si xcorr da offset > 20% del T, descartar hit

% Datos de puntas TLD086D20 — fc leído del gráfico (−3 dB)
PUNTA_FC = containers.Map( ...
    {'gris','marron','roja','negra'}, ...
    {170,    250,    650,   1600});
PUNTA_DESC = containers.Map( ...
    {'gris','marron','roja','negra'}, ...
    {'Very Soft','Soft (084B61)','Medium (084B62)','Med/Hard (084B63)'});

% =========================================================================
scriptDir = fileparts(mfilename('fullpath'));
datosDir  = fullfile(scriptDir, 'datos');

% =========================================================================
%% PASO 1 — Seleccionar archivo y medición
% =========================================================================
archivos = dir(fullfile(datosDir, '*.mat'));
if isempty(archivos), fprintf('Sin .mat en %s\n', datosDir); return; end

fprintf('\n=== ANÁLISIS DE MODELO FÍSICO ===\n');
for k = 1:numel(archivos)
    fprintf('  %3d  %s\n', k, archivos(k).name);
end
opc_f = input(sprintf('\nArchivo (1–%d): ', numel(archivos)));
if isempty(opc_f) || opc_f<1 || opc_f>numel(archivos), fprintf('Inv.\n'); return; end
fname = archivos(opc_f).name;
fpath = fullfile(datosDir, fname);

d = load(fpath);
if ~isfield(d,'muestras'), error('Sin campo "muestras".'); end
muestras = d.muestras;
N = numel(muestras);

ent = struct('nombre','','fs',1020,'fMin',0,'fMax',0,'ganancia',1,'observ','');
if isfield(d,'entidad'), ent = d.entidad; end

fprintf('\n%-4s  %-8s  %-20s  %6s  %8s  %6s  %6s  %s\n', ...
    '#','Punta','Timestamp','Dur(s)','SeqIni','Dist','PGA','Observ');
fprintf('%s\n', repmat('-',1,82));
for i = 1:N
    m = muestras(i);
    pnt2=''; if isfield(m,'punta'),     pnt2=m.punta;     end
    ts2 =''; if isfield(m,'timestamp'), ts2 =m.timestamp; end
    obs2=''; if isfield(m,'observ'),    obs2=m.observ;    end
    if isfield(m,'raw_V'),   dur=numel(m.raw_V)/double(m.fs);
    elseif isfield(m,'raw_mV'), dur=numel(m.raw_mV)/double(m.fs);
    else, dur=0; end
    ini_s = '—';
    if isfield(m,'secuencia_inicio_s') && ~isnan(m.secuencia_inicio_s)
        ini_s = sprintf('%.2f',m.secuencia_inicio_s);
    end
    dist_s = '—';
    if isfield(m,'distancia') && ~isnan(m.distancia)
        dist_s = sprintf('%.0f',m.distancia);
        if isfield(m,'unidad') && ~isempty(m.unidad)
            dist_s = [dist_s ' ' m.unidad];
        end
    end
    pga_s = '—';
    if isfield(m,'ganancia_pga') && ~isnan(m.ganancia_pga)
        pga_s = sprintf('%.0f',m.ganancia_pga);
    end
    fprintf('%-4d  %-8s  %-20s  %6.1f  %8s  %6s  %6s  %s\n', ...
        i,pnt2,ts2,dur,ini_s,dist_s,pga_s,obs2);
end

if N==1, idx=1; else
    idx = input(sprintf('\nMedición (1–%d): ',N));
    if isempty(idx)||idx<1||idx>N, fprintf('Inv.\n'); return; end
    idx = round(idx);
end

m  = muestras(idx);
fs = double(m.fs);
if isfield(m,'raw_V')
    raw = double(m.raw_V(:));
elseif isfield(m,'raw_mV')
    raw = double(m.raw_mV(:)) / 1000;
else
    error('Sin raw_V ni raw_mV.');
end
fil = [];
if isfield(m,'filtered') && ~isempty(m.filtered), fil = double(m.filtered(:)); end

pnt  = ''; if isfield(m,'punta'),     pnt  = lower(m.punta);     end
dist = NaN; if isfield(m,'distancia'), dist = m.distancia;        end
und  = ''; if isfield(m,'unidad'),    und  = m.unidad;            end
pga  = NaN; if isfield(m,'ganancia_pga'), pga = m.ganancia_pga;   end

% Elegir señal
if ~isempty(fil)
    opc_sig = input('Señal: 1=raw  2=filtrada [2]: ');
    if isempty(opc_sig)||opc_sig~=1, opc_sig=2; end
else
    opc_sig = 1;
end
sig = raw; if opc_sig==2&&~isempty(fil), sig=fil; end
lbl_sig = ternario(opc_sig==2&&~isempty(fil),'filtrada','raw PSoC');

Ns = numel(sig);
t  = (0:Ns-1)'/fs;

fprintf('\nMedición #%d | punta=%s | dur=%.1fs | PGA=%s | dist=%s%s\n', ...
    idx, pnt, t(end), numstr_o(pga,'—'), numstr_o(dist,'—'), und);

% =========================================================================
%% PASO 2 — Extraer onsets (secuencia o automático)
% =========================================================================
[mask_hit, ~, env_sm, env_th] = detectarGolpes(sig, fs, ...
    SMOOTH_ENV_SEC, THRESH_SIGMA, PRE_DET_SEC, POST_DET_SEC, MIN_QUIET_SEC);
d_mh    = diff([0; double(mask_hit); 0]);
onsets_auto = find(d_mh == 1);
offs_auto   = min(find(d_mh == -1) - 1, Ns);

tiene_seq = isfield(m,'secuencia_inicio_s') && ~isnan(m.secuencia_inicio_s) && ...
            isfield(m,'periodo_estimado_s') && ~isnan(m.periodo_estimado_s);

if tiene_seq
    t_ini  = m.secuencia_inicio_s;
    T_est  = m.periodo_estimado_s;
    % generar onsets desde secuencia marcada
    n_max = floor((t(end) - t_ini) / T_est) + 1;
    t_ons  = t_ini + (0:n_max-1) * T_est;
    t_ons  = t_ons(t_ons >= 0 & t_ons <= t(end));
    onsets_seq = round(t_ons * fs) + 1;
    onsets_seq = onsets_seq(onsets_seq>=1 & onsets_seq<=Ns);
    onsets_use = onsets_seq;
    fprintf('Modo secuencia: %d golpes (T=%.3fs inicio=%.3fs)\n', numel(onsets_use), T_est, t_ini);
else
    onsets_use = onsets_auto;
    T_est = NaN;
    if numel(onsets_use) >= 2
        T_est = median(diff(onsets_use)/fs);
    end
    fprintf('Sin secuencia definida — usando %d onsets automáticos', numel(onsets_use));
    if ~isnan(T_est), fprintf(' (T≈%.3fs)', T_est); end
    fprintf('\n');
    if isempty(onsets_use)
        fprintf('No hay hits detectados. Ajustar THRESH_SIGMA o SMOOTH_ENV_SEC.\n');
        return
    end
end

% =========================================================================
%% PASO 3 — Extraer ventanas de hit
% =========================================================================
pre_smp  = round(PRE_PAD_SEC * fs);
if ~isnan(T_est)
    post_smp = min(round(T_est * 0.90 * fs), round(POST_PAD_MAX_S * fs));
else
    post_smp = round(POST_PAD_MAX_S * fs);
end
win_len = pre_smp + post_smp;

hits = {};
ons_valid = [];
for k = 1:numel(onsets_use)
    i_start = onsets_use(k) - pre_smp;
    i_end   = onsets_use(k) + post_smp - 1;
    if i_start < 1 || i_end > Ns, continue; end
    hits{end+1} = sig(i_start:i_end); %#ok<AGROW>
    ons_valid(end+1) = onsets_use(k); %#ok<AGROW>
end
fprintf('Ventanas extraídas: %d  (duracion=%.3fs)\n', numel(hits), win_len/fs);

if isempty(hits)
    fprintf('No se pudieron extraer ventanas válidas.\n'); return
end

% =========================================================================
%% PASO 4 — Alinear hits por xcorr de envolvente
% =========================================================================
max_shift = round(MAX_ALIGN_FRAC * (isnan(T_est)*post_smp + ~isnan(T_est)*round(T_est*fs)));
max_shift = max(max_shift, round(0.05*fs));
ref_env   = abs(hilbert(hits{1} - mean(hits{1})));
descartados = [];
hits_aligned = {hits{1}};
for k = 2:numel(hits)
    h_k    = hits{k} - mean(hits{k});
    env_k  = abs(hilbert(h_k));
    [xc, lag] = xcorr(env_k, ref_env, max_shift);
    [~, im]   = max(xc);
    delay_k   = lag(im);
    if abs(delay_k) > max_shift
        descartados(end+1) = k; %#ok<AGROW>
        fprintf('  Hit %d descartado (alineación=±%d muestras > umbral %d)\n', k, abs(delay_k), max_shift);
        continue
    end
    hits_aligned{end+1} = circshift(hits{k}(:)', -delay_k); %#ok<AGROW>
end
fprintf('Hits usados: %d / %d  (%d descartados)\n', numel(hits_aligned), numel(hits), numel(descartados));

% =========================================================================
%% PASO 5 — Stack coherente
% =========================================================================
L = min(cellfun(@numel, hits_aligned));
mat = cell2mat(cellfun(@(h) h(1:L)', hits_aligned, 'UniformOutput',false));
hit_stack   = mean(mat, 2);
hit_std     = std(mat,  0, 2);
snr_stack_dB = 10*log10(var(hit_stack) / (mean(hit_std.^2) + eps));
t_hit = (0:L-1)'/fs - PRE_PAD_SEC;
fprintf('SNR stack: %.1f dB  (teórico máx: %.1f dB para N=%d)\n', ...
    snr_stack_dB, 10*log10(numel(hits_aligned)), numel(hits_aligned));

% =========================================================================
%% PASO 6 — Espectro del stack y deconvolución de punta
% =========================================================================
Ns2  = numel(hit_stack);
win_an = hann(Ns2);
X_stack = abs(fft((hit_stack - mean(hit_stack)) .* win_an));
X_stack = X_stack(1:floor(Ns2/2)+1) * 2 / sum(win_an);
f_stack = (0:numel(X_stack)-1)' * (fs / Ns2);

% Deconvolución individual (para banda de confianza ±1σ)
X_indiv = zeros(numel(X_stack), numel(hits_aligned));
for k = 1:numel(hits_aligned)
    h_k = hits_aligned{k}(1:L)' - mean(hits_aligned{k}(1:L));
    Xk  = abs(fft(h_k .* win_an));
    X_indiv(:,k) = Xk(1:floor(Ns2/2)+1) * 2 / sum(win_an);
end

% Modelo Hann para la punta
H_tip_f = ones(numel(X_stack), 1);
fc_tip  = NaN;
tip_lbl = '(punta desconocida — sin corrección)';
if PUNTA_FC.isKey(pnt)
    fc_tip = PUNTA_FC(pnt);
    tc     = 0.9 / fc_tip;
    Ntc    = min(round(tc * fs) + 1, Ns2);
    h_p    = hann(Ntc, 'periodic')';
    H_tip_t = [h_p, zeros(1, Ns2 - Ntc)];
    H_tip_f_full = abs(fft(H_tip_t));
    H_tip_f = (H_tip_f_full(1:floor(Ns2/2)+1) / max(H_tip_f_full(1),eps))';
    tip_lbl = sprintf('punta %s — %s  fc=%.0fHz  T_c=%.1fms', ...
        pnt, PUNTA_DESC(pnt), fc_tip, tc*1000);
end

X_deconv = X_stack ./ max(H_tip_f, 1e-3);
X_ind_d  = X_indiv ./ max(H_tip_f, 1e-3);

% =========================================================================
%% PASO 7 — Corrección de distancia
% =========================================================================
G_dist = 1;
dist_lbl = 'sin corrección de distancia';
if ~isnan(dist) && dist > 0
    % Referencia: el experimento actual. Normalización relativa (√r).
    % H_suelo(f,r) absorbe todo lo que no es circuito ni geófono.
    % La escala absoluta es arbitraria; sirve para comparar entre mediciones.
    G_dist   = sqrt(dist);
    dist_lbl = sprintf('corr. geométrica: ×√%.1f = ×%.2f  (%s %s)', ...
        dist, G_dist, numstr_o(dist,'?'), und);
end
X_final = X_deconv * G_dist;
X_ind_f = X_ind_d  * G_dist;

X_mu_dB  = 20*log10(X_final + eps);
X_sg_dB  = std(20*log10(X_ind_f + eps), 0, 2);

% =========================================================================
%% PASO 8 — Figuras
% =========================================================================
figTitle = sprintf('%s #%d | punta=%s | %s | %s', fname, idx, pnt, lbl_sig, tip_lbl);
fig = figure('Name', figTitle, 'NumberTitle','off', 'Position',[40 40 1380 780]);

% -- (1,1) Señal completa con hits marcados --
ax1 = subplot(2,2,1);
plot(ax1, t, sig, 'Color',[0.4 0.4 0.4], 'LineWidth',0.6, 'DisplayName','señal');
hold(ax1,'on');
cols_hit = lines(numel(hits_aligned));
for k = 1:numel(ons_valid)
    if ismember(k, descartados), continue; end
    ki = ons_valid(k);
    i_s = max(1, ki - pre_smp);
    i_e = min(Ns, ki + post_smp - 1);
    fill(ax1, [t(i_s) t(i_e) t(i_e) t(i_s)], [min(sig) min(sig) max(sig) max(sig)], ...
        cols_hit(min(k,size(cols_hit,1)),:), 'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
    plot(ax1, t(ki), sig(ki), 'o','Color',cols_hit(min(k,size(cols_hit,1)),:),...
        'MarkerSize',6,'MarkerFaceColor',cols_hit(min(k,size(cols_hit,1)),:),'LineStyle','none',...
        'HandleVisibility','off');
end
hold(ax1,'off');
xlabel(ax1,'Tiempo (s)'); ylabel(ax1,'V');
title(ax1, sprintf('Señal completa — %d hits usados, %d desc.', numel(hits_aligned), numel(descartados)));
legend(ax1,'show','Location','northeast','FontSize',7);
grid(ax1,'on'); xlim(ax1,[0 t(end)]);

% -- (1,2) Stack vs hit individual --
ax2 = subplot(2,2,2);
plot(ax2, t_hit, mat(:,1), 'Color',[0.75 0.75 0.75], 'LineWidth',0.5, 'DisplayName','hit #1');
hold(ax2,'on');
for k = 2:min(size(mat,2),4)
    plot(ax2, t_hit, mat(:,k), 'Color',[0.75 0.75 0.75], 'LineWidth',0.5, 'HandleVisibility','off');
end
plot(ax2, t_hit, hit_stack, 'Color',[0.18 0.54 0.34], 'LineWidth',1.8, ...
    'DisplayName',sprintf('Stack N=%d (%.1f dB)', numel(hits_aligned), snr_stack_dB));
fill(ax2, [t_hit; flipud(t_hit)], ...
    [(hit_stack+hit_std); flipud(hit_stack-hit_std)], ...
    [0.18 0.54 0.34],'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
xline(ax2,0,'--k','LineWidth',1,'Label','onset','FontSize',7,'HandleVisibility','off');
hold(ax2,'off');
xlabel(ax2,'Tiempo relativo al onset (s)'); ylabel(ax2,'V');
title(ax2, sprintf('Stacking — μ±σ sobre %d hits', numel(hits_aligned)));
legend(ax2,'show','Location','northeast','FontSize',8);
grid(ax2,'on');

% -- (2,1) Espectros: medido | deconvolucionado | H_tip --
ax3 = subplot(2,2,3);
plot(ax3, f_stack(2:end), 20*log10(X_stack(2:end)+eps), ...
    'Color',[0.25 0.55 0.80], 'LineWidth',1.2, 'DisplayName','stack (medido)');
hold(ax3,'on');
if PUNTA_FC.isKey(pnt)
    plot(ax3, f_stack(2:end), 20*log10(X_deconv(2:end)+eps), ...
        '--','Color',[0.95 0.50 0.05], 'LineWidth',1.5, 'DisplayName','stack deconvolucionado');
    H_dB_n = 20*log10(H_tip_f(2:end)+eps);
    plot(ax3, f_stack(2:end), H_dB_n - max(H_dB_n), ...
        ':','Color',[0.6 0.6 0.6], 'LineWidth',0.9, 'DisplayName','H_{punta} (norm.)');
    if fc_tip <= fs/2
        xline(ax3, fc_tip, '-.','Color',[0.95 0.50 0.05],'LineWidth',1.0,...
            'Label',sprintf('fc=%gHz',fc_tip),'FontSize',7,'LabelVerticalAlignment','bottom',...
            'HandleVisibility','off');
    end
end
flo = double(ent.fMin); fhi = double(ent.fMax);
if flo>0, xline(ax3,flo,'--g','LineWidth',1,'Label',sprintf('fMin=%gHz',flo),'FontSize',7,'LabelVerticalAlignment','bottom'); end
if fhi>0&&fhi<=fs/2, xline(ax3,fhi,'-g','LineWidth',1,'Label',sprintf('fMax=%gHz',fhi),'FontSize',7,'LabelVerticalAlignment','bottom'); end
hold(ax3,'off');
set(ax3,'XScale','log'); grid(ax3,'on');
xlim(ax3,[f_stack(2) fs/2]);
xlabel(ax3,'Frecuencia (Hz)'); ylabel(ax3,'dB re 1 V');
title(ax3,'Espectro stack: medido vs deconvolucionado por H_{punta}');
legend(ax3,'show','Location','southwest','FontSize',8);

% -- (2,2) H_sys estimado con banda ±1σ --
ax4 = subplot(2,2,4);
fill(ax4, [f_stack(2:end); flipud(f_stack(2:end))], ...
    [(X_mu_dB(2:end)+X_sg_dB(2:end)); flipud(X_mu_dB(2:end)-X_sg_dB(2:end))], ...
    [0.18 0.40 0.80],'FaceAlpha',0.20,'EdgeColor','none','HandleVisibility','off');
plot(ax4, f_stack(2:end), X_mu_dB(2:end), ...
    'Color',[0.18 0.40 0.80], 'LineWidth',2.0, ...
    'DisplayName',sprintf('H_{sys,est} (%s)', dist_lbl));
hold(ax4,'on');
if flo>0, xline(ax4,flo,'--g','LineWidth',1,'Label',sprintf('fMin=%gHz',flo),'FontSize',7,'LabelVerticalAlignment','bottom'); end
if fhi>0&&fhi<=fs/2, xline(ax4,fhi,'-g','LineWidth',1,'Label',sprintf('fMax=%gHz',fhi),'FontSize',7,'LabelVerticalAlignment','bottom'); end
hold(ax4,'off');
set(ax4,'XScale','log'); grid(ax4,'on');
xlim(ax4,[f_stack(2) fs/2]);
xlabel(ax4,'Frecuencia (Hz)');
ylabel(ax4,'dB re 1 V (relativo)');
title(ax4,'H_{sys,est}(f) = Y_{stack}/H_{punta}/G(r)  — ±1σ de hits');
legend(ax4,'show','Location','southwest','FontSize',8);

% Nota en figura
nota = sprintf(['NOTA: H_{sys,est} = H_{circuito} × H_{geofono} × H_{suelo}  ' ...
    '(H_{suelo} incl. propagación y dinámica del piso — const. si r fijo). ' ...
    'Valores relativos, no absolutos.']);
annotation(fig,'textbox',[0.01 0.005 0.98 0.03],'String',nota,'EdgeColor','none',...
    'FontSize',6.5,'Color',[0.35 0.35 0.35],'FitBoxToText','off');

sgtitle(fig, figTitle, 'Interpreter','none','FontSize',9,'FontWeight','bold');

% =========================================================================
%% Resumen consola
% =========================================================================
fprintf('\n=== RESUMEN ===\n');
fprintf('  Entidad     : %s\n', ent.nombre);
fprintf('  Punta       : %s  —  %s\n', pnt, ternario(PUNTA_FC.isKey(pnt), PUNTA_DESC(pnt), 'desconocida'));
fprintf('  Distancia   : %s\n', ternario(~isnan(dist), sprintf('%.1f %s', dist, und), '—'));
fprintf('  PGA         : %s\n', numstr_o(pga, '—'));
fprintf('  Señal       : %s\n', lbl_sig);
fprintf('  Hits usados : %d / %d extraídos\n', numel(hits_aligned), numel(hits));
fprintf('  SNR stack   : %.1f dB\n', snr_stack_dB);
if PUNTA_FC.isKey(pnt)
    fprintf('  fc punta    : %.0f Hz  (T_c = %.1f ms)\n', fc_tip, 0.9/fc_tip*1000);
end
fprintf('  Dist corr   : %s\n', dist_lbl);
fprintf('\n');
fprintf('H_suelo no calibrado — comparación válida entre circuitos al mismo r y posición.\n');
fprintf('Para desacoplar H_suelo: necesitarías medición de referencia (cable directo)\n');
fprintf('o múltiples distancias (tipo MASW) para estimar la atenuación del medio.\n');

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

function out = ternario(cond, a, b)
    if cond, out = a; else, out = b; end
end

function s = numstr_o(v, fallback)
    if isnumeric(v) && ~isnan(v)
        s = num2str(v);
    else
        s = fallback;
    end
end
