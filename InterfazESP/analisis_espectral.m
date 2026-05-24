% analisis_espectral.m
% Análisis espectral del geófono SM-24 + circuito compensador por entidad.
%
% ── CÓMO FUNCIONA ──────────────────────────────────────────────────────────
%
% 1. DETECCIÓN DE GOLPES (detectarGolpes)
%    Envolvente instantánea via Hilbert: env(t) = |hilbert(x_ac(t))|
%    Suavizada ~50 ms. Umbral adaptativo: media(env) + N·sigma(env).
%    Padding pre/post para capturar la respuesta completa del sistema.
%
% 2. PSD POR WELCH (calcPSD, calcPSD_SNR)
%    Se trabaja con UNA sola señal (raw o filtrada, elegida al inicio).
%    PSD_golpes / PSD_ruido → SNR(f) frecuencia a frecuencia.
%    Límites: f_min = fs/WIN_WELCH  |  f_max = fs/2 (Nyquist)
%
% 3. FIGURAS POR ENTIDAD
%    G  — PSD global de todas las mediciones
%    A  — PSD: curvas individuales + media ± σ
%    B  — SNR escalar por medición (en-banda vs. fuera-de-banda)
%    D  — SNR(f): PSD_golpes vs. PSD_ruido + ancho de banda efectivo
%    C  — Espectrogramas (tiempo con golpes detectados | espectrograma)
%
% 4. NOTA SOBRE MARTILLO SIN REFERENCIA
%    Sin canal de fuerza no se puede deconvolucionar la respuesta del martillo.
%    PCB con punta blanda ≥500 Hz → en ≤300 Hz espectro salida ≈ respuesta sistema.
%
% ───────────────────────────────────────────────────────────────────────────

clc; close all; clear;

% =========================================================================
%% PARÁMETROS CONFIGURABLES
% =========================================================================
WIN_WELCH    = 2^14;   % 16384 muestras → Δf ≈ 0.062 Hz a 1020 SPS
OVL_WELCH    = 2^13;   % 50% solapamiento
NFFT_WELCH   = 2^14;
F_BANDA_BAJA = 0.1;    % Hz — fallback fMin
F_BANDA_MED  = 100;    % Hz — fallback fMax
% --- Detección de golpes ---
WIN_ENERGIA_SEC = 0.05;  % suavizado envolvente Hilbert (seg)
THRESH_SIGMA    = 2.5;
PRE_PAD_SEC     = 0.30;
POST_PAD_SEC    = 2.00;
MIN_QUIET_SEC   = 1.00;
% =========================================================================

scriptDir = fileparts(mfilename('fullpath'));
datosDir  = fullfile(scriptDir, 'datos');

% =========================================================================
%% PASO 1 — Cargar mediciones
% =========================================================================
fprintf('=== ANÁLISIS ESPECTRAL POR ENTIDAD ===\n');
fprintf('(Parámetros Welch se seleccionan después de elegir entidades)\n\n');

catalog = [];
if ~isfolder(datosDir), fprintf('No existe datos\\\n'); return; end

for f = dir(fullfile(datosDir,'*.mat'))'
    try
        d = load(fullfile(datosDir, f.name));
        if ~isfield(d,'muestras'), continue; end
        ent = struct('nombre','','fs',1020,'fMin',0,'fMax',0,'ganancia',1,'observ','');
        if isfield(d,'entidad'), ent = d.entidad; end
        for mi = 1:numel(d.muestras)
            m = d.muestras(mi);
            c.entNombre = ent.nombre;
            c.fMin      = double(ent.fMin);
            c.fMax      = double(ent.fMax);
            c.ganancia  = double(ent.ganancia);
            c.musIdx    = mi;
            c.fs        = double(m.fs);
            c.punta     = ''; if isfield(m,'punta'),     c.punta     = m.punta;     end
            c.filtCmd   = ''; if isfield(m,'filtCmd'),   c.filtCmd   = m.filtCmd;   end
            c.timestamp = ''; if isfield(m,'timestamp'), c.timestamp = m.timestamp; end
            c.observ    = ''; if isfield(m,'observ'),    c.observ    = m.observ;    end
            % Campos de metadata extendida
            c.seq_ini      = NaN; if isfield(m,'secuencia_inicio_s'), c.seq_ini      = m.secuencia_inicio_s; end
            c.T_est        = NaN; if isfield(m,'periodo_estimado_s'),  c.T_est        = m.periodo_estimado_s;  end
            c.distancia    = NaN; if isfield(m,'distancia'),           c.distancia    = m.distancia;           end
            c.ganancia_pga = NaN; if isfield(m,'ganancia_pga'),        c.ganancia_pga = m.ganancia_pga;        end
            if isfield(m,'raw_V')
                c.raw_V = double(m.raw_V(:));
            elseif isfield(m,'raw_mV')
                c.raw_V = double(m.raw_mV(:)) / 1000;  % legado mV → V
            else
                fprintf('  [aviso] medición %d sin raw_V ni raw_mV, saltando.\n', mi);
                continue;
            end
            c.filtered  = double(m.filtered(:));
            if isempty(catalog), catalog = c; else, catalog(end+1) = c; end %#ok<AGROW>
        end
    catch e
        fprintf('  [aviso] %s: %s\n', f.name, e.message);
    end
end
if isempty(catalog), fprintf('No se encontraron mediciones.\n'); return; end

% =========================================================================
%% PASO 2 — Selección de entidades
% =========================================================================
todosEnt = unique({catalog.entNombre},'stable');
fprintf('Entidades disponibles:\n');
fprintf('  %3s  %-24s  %5s  %6s  %s\n','#','Entidad','Meds','fs','Puntas');
fprintf('  %s\n', repmat('-',1,65));
for ei = 1:numel(todosEnt)
    enm  = todosEnt{ei};
    mask = strcmp({catalog.entNombre}, enm);
    meds = catalog(mask);
    fprintf('  %3d  %-24s  %5d  %6g  %s\n', ei, enm, sum(mask), meds(1).fs, ...
        strjoin(unique({meds.punta},'stable'),', '));
end
fprintf('\n');
sel_str = input('Entidades a analizar (ej: 1 2) — ENTER = todas: ','s');
if isempty(strtrim(sel_str))
    sel_ent = todosEnt;
else
    sel_nums = str2num(sel_str); %#ok<ST2NM>
    sel_nums = sel_nums(sel_nums>=1 & sel_nums<=numel(todosEnt));
    if isempty(sel_nums), fprintf('Selección vacía.\n'); return; end
    sel_ent = todosEnt(sel_nums);
end

mask_sel  = ismember({catalog.entNombre}, sel_ent);
datos     = catalog(mask_sel);
N         = numel(datos);
entUnicas = unique({datos.entNombre},'stable');
fprintf('\n%d medición(es) en %d entidad(es).\n\n', N, numel(entUnicas));

% =========================================================================
%% PASO 3 — Elegir señal a analizar
% =========================================================================
fprintf('Señal a analizar:\n  1 = raw PSoC\n  2 = filtrada MATLAB  (recomendado)\n');
opc_sig = input('Opción [2]: ');
if isempty(opc_sig) || opc_sig ~= 1, opc_sig = 2; end
lbl_sig = 'raw PSoC';
if opc_sig == 2, lbl_sig = 'filtrada MATLAB'; end
fprintf('→ Usando: %s\n\n', lbl_sig);

for i = 1:N
    if opc_sig == 2
        datos(i).seg = datos(i).filtered;
    else
        datos(i).seg = datos(i).raw_V;
    end
end

% =========================================================================
%% PASO 3.5 — Selección de parámetros Welch
% =========================================================================
fprintf('Parámetros Welch:\n');
fprintf('  1 = auto    (adapta ventana a fMin y duración de señal)\n');
fprintf('  2 = manual  (ingresás WIN, OVL=WIN/2, NFFT=WIN)\n');
fprintf('  3 = default (WIN=%d, OVL=%d, NFFT=%d → Δf=%.4fHz)\n', ...
    WIN_WELCH, OVL_WELCH, NFFT_WELCH, datos(1).fs/WIN_WELCH);
opc_welch = input('Opción [1]: ');
if isempty(opc_welch), opc_welch = 1; end

switch opc_welch
    case 1  % ---- AUTO ----
        fs_ref   = datos(1).fs;
        durs_s   = arrayfun(@(d) numel(d.seg) / d.fs, datos);
        min_dur  = min(durs_s);

        fMin_vals = max([datos.fMin], 0);
        fMin_nz   = fMin_vals(fMin_vals > 0);
        if isempty(fMin_nz)
            fMin_use = F_BANDA_BAJA;
            fprintf('  (fMin=0 en todas las entidades — usando fallback %.2fHz)\n', fMin_use);
        else
            fMin_use = min(fMin_nz);
        end

        Df_target = fMin_use / 10;          % resolver 10 bins dentro de fMin
        WIN_ideal = fs_ref / Df_target;
        WIN_auto  = 2^ceil(log2(WIN_ideal));

        WIN_max = max(2^8, 2^floor(log2(min_dur * fs_ref / 3)));

        WIN_WELCH  = min(WIN_auto, WIN_max);
        OVL_WELCH  = WIN_WELCH / 2;
        NFFT_WELCH = WIN_WELCH;

        Df_real   = fs_ref / WIN_WELCH;
        n_segs_mn = floor((min_dur * fs_ref - WIN_WELCH) / OVL_WELCH) + 1;

        fprintf('\n  Auto-selección Welch:\n');
        fprintf('  fMin considerado   : %.2f Hz\n', fMin_use);
        fprintf('  Duración mínima    : %.1f s\n', min_dur);
        fprintf('  Target Δf          : %.4f Hz  (fMin/10)\n', Df_target);
        fprintf('  WIN ideal = %d (Δf=%.4fHz)  |  WIN_max por duración = %d\n', ...
            WIN_auto, fs_ref/WIN_auto, WIN_max);
        fprintf('  %s\n', repmat('─',1,50));
        fprintf('  WIN_WELCH  = %-6d  →  Δf = %.4f Hz\n', WIN_WELCH, Df_real);
        fprintf('  OVL_WELCH  = %d\n', OVL_WELCH);
        fprintf('  NFFT_WELCH = %d\n', NFFT_WELCH);
        fprintf('  Segmentos por medición (mínimo) : ~%d\n', n_segs_mn);
        if WIN_WELCH == WIN_max && WIN_auto > WIN_max
            fprintf('  AVISO: ventana reducida por duración de señal (ideal=%d)\n', WIN_auto);
        end
        fprintf('  %s\n', repmat('─',1,50));

        % Permitir ajuste manual rápido
        adj_raw = input('  [Enter=usar estos, o ingresá WIN diferente]: ','s');
        adj_val = str2double(strtrim(adj_raw));
        if ~isnan(adj_val) && adj_val > 0
            WIN_WELCH  = 2^round(log2(adj_val));   % redondear a potencia de 2
            OVL_WELCH  = WIN_WELCH / 2;
            NFFT_WELCH = WIN_WELCH;
            fprintf('  Usando WIN=%d  →  Δf=%.4fHz\n', WIN_WELCH, fs_ref/WIN_WELCH);
        end

    case 2  % ---- MANUAL ----
        fs_ref   = datos(1).fs;
        durs_s   = arrayfun(@(d) numel(d.seg) / d.fs, datos);
        min_dur  = min(durs_s);
        win_raw  = input(sprintf('  WIN_WELCH [actual %d]: ', WIN_WELCH));
        if ~isempty(win_raw) && win_raw > 0
            WIN_WELCH  = 2^round(log2(win_raw));
            OVL_WELCH  = WIN_WELCH / 2;
            NFFT_WELCH = WIN_WELCH;
        end
        n_segs_mn = floor((min_dur * fs_ref - WIN_WELCH) / OVL_WELCH) + 1;
        fprintf('  WIN=%d  OVL=%d  NFFT=%d  →  Δf=%.4fHz  segs_min≈%d\n', ...
            WIN_WELCH, OVL_WELCH, NFFT_WELCH, datos(1).fs/WIN_WELCH, n_segs_mn);

    otherwise  % ---- DEFAULT (caso 3 o cualquier otra entrada) ----
        fprintf('  Usando default: WIN=%d OVL=%d NFFT=%d → Δf=%.4fHz\n', ...
            WIN_WELCH, OVL_WELCH, NFFT_WELCH, datos(1).fs/WIN_WELCH);
end

% Nota informativa si hay secuencias marcadas
n_con_seq = 0;
for i = 1:N
    m_tmp = datos(i);
    if isfield(m_tmp,'secuencia_inicio_s') && ~isnan(m_tmp.secuencia_inicio_s)
        n_con_seq = n_con_seq + 1;
    end
end
if n_con_seq > 0
    fprintf('  Nota: %d/%d mediciones tienen secuencia marcada.\n', n_con_seq, N);
    fprintf('  Para análisis por-golpe (stacking + deconvolución) usar analisis_modelo.m\n');
end
fprintf('\n');

% =========================================================================
%% Paleta de colores
% =========================================================================
paleta_base = [
    0.216  0.494  0.722;
    0.894  0.102  0.110;
    0.188  0.631  0.278;
    0.988  0.553  0.035;
    0.557  0.267  0.678;
    0.933  0.169  0.529;
    0.173  0.627  0.643;
    0.769  0.608  0.102;
];
n_ent  = max(numel(entUnicas), 1);
paleta = paleta_base(mod(0:n_ent-1, size(paleta_base,1))+1, :);
colMap = containers.Map('KeyType','char','ValueType','any');
for ei = 1:numel(entUnicas), colMap(entUnicas{ei}) = paleta(ei,:); end

fprintf('=== Parámetros finales Welch ===  WIN=%d  OVL=%d  NFFT=%d  Δf=%.4fHz\n\n',...
    WIN_WELCH, OVL_WELCH, NFFT_WELCH, datos(1).fs/WIN_WELCH);

% ¿Generar espectrogramas?
resp_sp = strtrim(input('¿Generar espectrogramas? [s/N]: ','s'));
GEN_SPECT = strcmpi(resp_sp,'s');
if GEN_SPECT
    fprintf('  Por entidad preguntaré cuáles mostrar.\n');
    fprintf('  Formatos: todos | 1,2,3 | 5-10 | a5=auto 5 representativos\n\n');
else
    fprintf('  Omitiendo espectrogramas.\n\n');
end

% =========================================================================
%% FIGURA GLOBAL — PSD superpuesta
% =========================================================================
figG = figure('Name',sprintf('PSD global — %s', lbl_sig),'NumberTitle','off',...
    'Position',[40 40 900 500]);
axG = axes('Parent',figG); hold(axG,'on');

tablaGlobal = cell(N+1,7);
tablaGlobal(1,:) = {'#','Entidad','m#','Punta','fs','SNR(dB)','BW−3dB(Hz)'};

for i = 1:N
    fs_i = datos(i).fs; fn_i = fs_i/2;
    col  = colMap(datos(i).entNombre);
    lbl  = sprintf('%s #%d (%s)', datos(i).entNombre, datos(i).musIdx, datos(i).punta);
    flo  = datos(i).fMin; fhi = datos(i).fMax;
    if flo==0 && fhi==0, flo=F_BANDA_BAJA; fhi=F_BANDA_MED; end

    [snr_i, pxx_i, f_i] = calcPSD(datos(i).seg, fs_i, fn_i, WIN_WELCH, OVL_WELCH, NFFT_WELCH, flo, fhi);
    if ~isempty(pxx_i)
        plot(axG, f_i, 10*log10(pxx_i), 'Color',col, 'LineWidth',1, 'DisplayName',lbl);
    end
    tablaGlobal{i+1,1} = num2str(i);
    tablaGlobal{i+1,2} = datos(i).entNombre;
    tablaGlobal{i+1,3} = num2str(datos(i).musIdx);
    tablaGlobal{i+1,4} = datos(i).punta;
    tablaGlobal{i+1,5} = num2str(fs_i);
    tablaGlobal{i+1,6} = sprintf('%.1f', snr_i);
end

fn0 = datos(1).fs/2;
for ei2 = 1:numel(entUnicas)
    enm2  = entUnicas{ei2}; ce = colMap(enm2)*0.82;
    idx_e = find(strcmp({datos.entNombre},enm2),1);
    flo2  = datos(idx_e).fMin; fhi2 = datos(idx_e).fMax;
    if flo2==0&&fhi2==0, flo2=F_BANDA_BAJA; fhi2=F_BANDA_MED; end
    if flo2>0, xline(axG,flo2,'--','Color',ce,'LineWidth',0.9,'Alpha',0.7); end
    if fhi2>0&&fhi2<=fn0
        xline(axG,fhi2,'-','Color',ce,'LineWidth',0.9,'Alpha',0.7,...
            'Label',sprintf('%s %gHz',enm2,fhi2),'LabelVerticalAlignment','bottom','FontSize',7);
    end
end
xline(axG,fn0,'--k','LineWidth',0.8,'Alpha',0.5);
xlabel(axG,'Frecuencia (Hz)'); ylabel(axG,'PSD (dB re 1 V²/Hz)');
legend(axG,'Location','northeast','Interpreter','none','FontSize',7);
grid(axG,'on'); xlim(axG,[datos(1).fs/WIN_WELCH fn0]);
set(axG,'XScale','log');
title(axG, sprintf('PSD global — %s  (vent=%d, Δf=%.3fHz)', lbl_sig, WIN_WELCH, datos(1).fs/WIN_WELCH));

% =========================================================================
%% FIGURAS POR ENTIDAD
% =========================================================================
resumenEnt = cell(numel(entUnicas),1);
MEDS_POR_FIG = 2;

for ei = 1:numel(entUnicas)
    enm   = entUnicas{ei};
    de     = datos(strcmp({datos.entNombre},enm));
    de_all = de;           % todas las mediciones de la entidad (para spectrogramas)
    Nm     = numel(de);

    % --- Tabla de mediciones ---
    fprintf('\n  [%s] Mediciones disponibles (%d):\n', enm, Nm);
    fprintf('   %-3s  %-8s  %-6s  %-4s  %-4s  %s\n','#','Punta','Dist','PGA','Seq','Timestamp');
    fprintf('   %s\n', repmat('-',1,58));
    for mi = 1:Nm
        dist_s = '—'; if ~isnan(de(mi).distancia),    dist_s = sprintf('%gp',de(mi).distancia);    end
        pga_s  = '—'; if ~isnan(de(mi).ganancia_pga), pga_s  = sprintf('x%g',de(mi).ganancia_pga); end
        seq_s  = '—'; if ~isnan(de(mi).seq_ini),       seq_s  = 'si'; end
        fprintf('   %-3d  %-8s  %-6s  %-4s  %-4s  %s\n', ...
            mi, de(mi).punta, dist_s, pga_s, seq_s, de(mi).timestamp);
    end

    % PREGUNTA 1 — Cálculo: qué mediciones usar para PSD/SNR/media/std.
    %   Lista explícita: 1,3,5-10  → usa exactamente esas
    %   aN             : auto-selecciona N mejores → usa solo esas para cálculo
    %   ENTER/todos    : usa todas
    fprintf('   Cálculo: 1,2,3 | 5-10 | todos | aN=auto N mejores\n');
    sel_calc = strtrim(input(sprintf('  Cálculo [1-%d, ENTER=todas]: ', Nm), 's'));
    if ~isempty(sel_calc) && ~strcmpi(sel_calc,'todos')
        if ~isempty(regexp(sel_calc,'^a\d+$','once'))
            N_auto_c = str2double(regexp(sel_calc,'\d+','match','once'));
            sel_idx_calc = autoSeleccionarMeds(de, Nm, N_auto_c);
            de = de(sel_idx_calc);
            Nm = numel(de);
            fprintf('  → Auto: %d mediciones para cálculo.\n', Nm);
        else
            sel_idx_calc = parseSeleccion(sel_calc, Nm);
            if ~isempty(sel_idx_calc)
                de = de(sel_idx_calc);
                Nm = numel(de);
                fprintf('  → %d mediciones para cálculo.\n', Nm);
            end
        end
    end

    % PREGUNTA 2 — Fig A: cuáles curvas individuales mostrar (NO afecta el cálculo).
    %   La media/std siempre usa TODO el conjunto de cálculo (de).
    %   Esta selección solo controla qué líneas individuales aparecen en el gráfico.
    fprintf('   Fig A individual: todos | aN=auto N | 1,2,3 (ENTER=todas)\n');
    sel_figA = strtrim(input(sprintf('  Fig A curvas [1-%d, ENTER=todas]: ', Nm), 's'));
    if isempty(sel_figA) || strcmpi(sel_figA,'todos')
        de_plot_idx = 1:Nm;
    elseif ~isempty(regexp(sel_figA,'^a\d+$','once'))
        N_fa = str2double(regexp(sel_figA,'\d+','match','once'));
        de_plot_idx = autoSeleccionarMeds(de, Nm, N_fa);
        fprintf('  → Mostrando %d curvas (cálculo usa %d total).\n', numel(de_plot_idx), Nm);
    else
        de_plot_idx = parseSeleccion(sel_figA, Nm);
        if isempty(de_plot_idx), de_plot_idx = 1:Nm; end
        fprintf('  → Mostrando %d curvas (cálculo usa %d total).\n', numel(de_plot_idx), Nm);
    end

    % Pesos por calidad: secuencia marcada → 2×, auto-detectada → 1×
    % Se aplica al PSD COMPLETO (todos los Nm), no solo al subconjunto de display.
    w_vec = ones(1, Nm);
    for mi = 1:Nm
        if ~isnan(de(mi).seq_ini), w_vec(mi) = 2.0; end
    end

    col_e = colMap(enm);
    fs_e  = de(1).fs; fn_e = fs_e/2;
    flo   = de(1).fMin; fhi = de(1).fMax;
    if flo==0 && fhi==0, flo=F_BANDA_BAJA; fhi=F_BANDA_MED; end
    df    = fs_e / WIN_WELCH;

    % --- Detección de golpes ---
    concat_hit = []; concat_qui = [];
    pct_activo_vec = nan(1, Nm);
    for mi = 1:Nm
        [mh, mq, env_sm, thr_v] = detectarGolpes(de(mi).seg, fs_e, ...
            WIN_ENERGIA_SEC, THRESH_SIGMA, PRE_PAD_SEC, POST_PAD_SEC, MIN_QUIET_SEC);
        de(mi).maskHit   = mh;
        de(mi).maskQuiet = mq;
        de(mi).envSmooth = env_sm;
        de(mi).envThresh = thr_v;
        de(mi).envDC     = mean(de(mi).seg);
        if any(mh)
            pct_activo_vec(mi) = 100 * sum(mh) / numel(mh);
            concat_hit = [concat_hit; de(mi).seg(mh)]; %#ok<AGROW>
        end
        if any(mq)
            concat_qui = [concat_qui; de(mi).seg(mq)]; %#ok<AGROW>
        end
    end
    pct_activo_mu = mean(pct_activo_vec(~isnan(pct_activo_vec)));
    if isnan(pct_activo_mu), pct_activo_mu = 0; end
    fprintf('  [%s] %.0f%% activo  |  hit=%ds  quiet=%ds\n', ...
        enm, pct_activo_mu, round(numel(concat_hit)/fs_e), round(numel(concat_qui)/fs_e));

    headerBase = sprintf('%s  |  %s  |  BW: %g–%g Hz  |  G=%g  |  fs=%g SPS  |  Δf=%.3f Hz',...
        enm, lbl_sig, flo, fhi, de(1).ganancia, fs_e, df);

    % --- PSD por muestra (con pesos) ---
    psd_mat = []; f_ref = [];
    snr_vec = nan(1,Nm);
    psd_midx = [];   % qué índice de medición aportó cada fila de psd_mat
    for mi = 1:Nm
        [snr_i, pxx_i, f_i] = calcPSD(de(mi).seg, fs_e, fn_e, WIN_WELCH, OVL_WELCH, NFFT_WELCH, flo, fhi);
        if isempty(pxx_i), continue; end
        if isempty(f_ref), f_ref = f_i(:)'; end
        if numel(pxx_i) ~= numel(f_ref)
            pxx_i = interp1(f_i, pxx_i, f_ref, 'linear', pxx_i(end));
        end
        psd_mat(end+1,:) = 10*log10(pxx_i(:)'+eps); %#ok<AGROW>
        snr_vec(mi) = snr_i;
        psd_midx(end+1) = mi; %#ok<AGROW>
    end

    if isempty(psd_mat)
        fprintf('  AVISO: %s sin segmentos válidos (necesita ≥%.0f s).\n', enm, WIN_WELCH/fs_e);
        continue;
    end

    % Media y std ponderadas por calidad (seq marcada = 2×)
    w_sel = w_vec(psd_midx);
    w_sel = w_sel / sum(w_sel);           % normalizar
    mean_dB = w_sel * psd_mat;            % fila × (Nm×Nf) → 1×Nf
    dev     = psd_mat - mean_dB;
    std_dB  = sqrt(w_sel * dev.^2);       % desviación estándar ponderada
    snr_v   = snr_vec(~isnan(snr_vec));
    snr_mu  = mean(snr_v); snr_sg = std(snr_v);
    dc_mask = f_ref > 2*df;
    [~,ik]  = max(10.^(mean_dB(dc_mask)/10));
    ftmp    = f_ref(dc_mask); fpk = ftmp(ik);
    peak_dB_val = max(mean_dB(dc_mask));
    % Nivel del plateau: excluye ±1 octava alrededor del pico de resonancia
    res_excl  = (f_ref > fpk/sqrt(2)) & (f_ref < fpk*sqrt(2));
    flat_mask = dc_mask & ~res_excl;
    if sum(flat_mask) > 5
        ref_dB = prctile(mean_dB(flat_mask), 90);
    else
        ref_dB = peak_dB_val;
    end
    thresh3 = ref_dB - 3;
    above3  = (f_ref > 2*df) & (mean_dB >= thresh3);
    if any(above3)
        f_lo3 = f_ref(find(above3, 1, 'first'));
        f_hi3 = f_ref(find(above3, 1, 'last'));
    else
        f_lo3 = NaN; f_hi3 = NaN;
    end

    % ==================================================================
    % FIGURA A — PSD
    % ==================================================================
    figA = figure('Name',sprintf('[A] PSD — %s',enm),'NumberTitle','off',...
        'Position',[30+15*ei 600 900 500]);
    axA = axes('Parent',figA); hold(axA,'on');
    % Curvas individuales: solo las de de_plot_idx (display), pero mean/std usa todo psd_mat
    for mi = 1:size(psd_mat,1)
        orig_mi = psd_midx(mi);
        if ~ismember(orig_mi, de_plot_idx), continue; end   % skip si no está en selección display
        d_mi   = de(orig_mi);
        dist_s = ''; if ~isnan(d_mi.distancia),    dist_s = sprintf('%gp',d_mi.distancia); end
        seq_s  = ''; if ~isnan(d_mi.seq_ini),       seq_s  = '[seq]'; end
        lbl_mi = strtrim(sprintf('#%d %s %s %s', d_mi.musIdx, d_mi.punta, dist_s, seq_s));
        lw_mi  = 0.7; if ~isnan(d_mi.seq_ini), lw_mi = 1.1; end
        plot(axA, f_ref, psd_mat(mi,:), 'Color',[col_e 0.35], 'LineWidth',lw_mi,...
            'DisplayName',lbl_mi);
    end
    fr_ = f_ref(:)'; mu_ = mean_dB(:)'; sg_ = std_dB(:)';
    fill(axA,[fr_ fliplr(fr_)],[(mu_+sg_) fliplr(mu_-sg_)],...
        col_e,'FaceAlpha',0.18,'EdgeColor','none','HandleVisibility','off');
    if ~isnan(f_lo3) && ~isnan(f_hi3)
        lbl_media = sprintf('Media (pico=%.1fHz | −3dB: %.1f–%.0fHz)', fpk, f_lo3, f_hi3);
    else
        lbl_media = sprintf('Media (pico=%.1fHz)', fpk);
    end
    plot(axA, f_ref, mean_dB, 'Color',col_e, 'LineWidth',2.2, 'DisplayName',lbl_media);
    decorarPSD(axA, flo, fhi, fn_e);
    if ~isnan(f_lo3)
        yline(axA, thresh3, ':','Color',[0.3 0.3 0.9],'LineWidth',1.0,...
            'Label','plateau−3dB','LabelHorizontalAlignment','left','FontSize',7,...
            'HandleVisibility','off');
        xline(axA, f_lo3, '--','Color',[0.3 0.3 0.9],'LineWidth',1.1,...
            'Label',sprintf('%.2gHz',f_lo3),'LabelVerticalAlignment','bottom','FontSize',7,...
            'HandleVisibility','off');
    end
    if ~isnan(f_hi3) && f_hi3 <= fn_e
        xline(axA, f_hi3, '-','Color',[0.3 0.3 0.9],'LineWidth',1.1,...
            'Label',sprintf('%.0fHz',f_hi3),'LabelVerticalAlignment','bottom','FontSize',7,...
            'HandleVisibility','off');
    end
    xlabel(axA,'Frecuencia (Hz)'); ylabel(axA,'dB re 1 V²/Hz');
    title(axA, sprintf('%d mediciones + media±σ  (%.0f%% activo)', Nm, pct_activo_mu));
    set(axA,'XScale','log'); grid(axA,'on'); xlim(axA,[max(df,0.05) fn_e]);
    legend(axA,'show','Location','southwest','FontSize',7);
    sgtitle(figA, headerBase, 'FontSize',9,'FontWeight','bold');

    % ==================================================================
    % FIGURA B — SNR escalar por medición
    % ==================================================================
    figB = figure('Name',sprintf('[B] SNR — %s',enm),'NumberTitle','off',...
        'Position',[30+15*ei 200 650 400]);
    axB = axes('Parent',figB); hold(axB,'on');
    xb = 1:Nm;
    bh = bar(axB, xb, snr_vec(:), 0.6);
    bh.FaceColor = col_e;
    if ~isnan(snr_mu)
        yline(axB, snr_mu, '-', 'Color',col_e*0.75, 'LineWidth',1.8,...
            'Label',sprintf('μ=%.1fdB',snr_mu),'LabelVerticalAlignment','bottom','FontSize',8);
    end
    yline(axB, 0, ':k', 'LineWidth',1, 'Alpha',0.6);
    hold(axB,'off');
    xlabel(axB,'Medición'); ylabel(axB,'SNR (dB)');
    xticks(axB, xb);
    xticklabels(axB, arrayfun(@(i) sprintf('#%d\n%s',de(i).musIdx,de(i).punta),...
        xb,'UniformOutput',false));
    title(axB, sprintf('SNR en [%g–%g Hz]  —  %.1f±%.1f dB', flo, fhi, snr_mu, snr_sg));
    grid(axB,'on');
    sgtitle(figB, headerBase,'FontSize',9,'FontWeight','bold');

    % ==================================================================
    % FIGURA D — SNR(f)
    % ==================================================================
    [psd_hit, psd_noi, snr_f, f_snr] = calcPSD_SNR(...
        concat_hit, concat_qui, fs_e, WIN_WELCH, OVL_WELCH, NFFT_WELCH);

    if ~isempty(psd_hit)
        figD = figure('Name',sprintf('[D] SNR(f) — %s',enm),'NumberTitle','off',...
            'Position',[30+15*ei 50 1100 520]);

        snr_dB  = 10*log10(snr_f + eps);
        f_snr_v = f_snr(:);
        xlim_lo = max(df, 0.05);
        bw_mask = snr_dB > 0 & f_snr_v > df;
        if any(bw_mask)
            bw_lo = f_snr_v(find(bw_mask,1,'first'));
            bw_hi = f_snr_v(find(bw_mask,1,'last'));
        else
            bw_lo = NaN; bw_hi = NaN;
        end
        bw3_mask = snr_dB > 3 & f_snr_v > df;
        if any(bw3_mask)
            bw3_lo = f_snr_v(find(bw3_mask,1,'first'));
            bw3_hi = f_snr_v(find(bw3_mask,1,'last'));
        else
            bw3_lo = NaN; bw3_hi = NaN;
        end

        axDP = subplot(1,2,1);
        plot(axDP, f_snr_v, 10*log10(psd_hit+eps), 'Color',col_e, 'LineWidth',1.5,...
            'DisplayName','golpes'); hold(axDP,'on');
        plot(axDP, f_snr_v, 10*log10(psd_noi+eps), 'Color',[0.68 0.68 0.68], 'LineWidth',1.0,...
            'DisplayName','ruido');
        if ~isnan(bw_lo) && bw_lo >= xlim_lo
            xline(axDP,bw_lo,'--','Color',[0 0.6 0],'LineWidth',1.2,...
                'Label',sprintf('%.2fHz',bw_lo),'LabelVerticalAlignment','bottom','FontSize',7);
        end
        if ~isnan(bw_hi) && bw_hi <= fn_e
            xline(axDP,bw_hi,'-','Color',[0 0.6 0],'LineWidth',1.2,...
                'Label',sprintf('%.0fHz',bw_hi),'LabelVerticalAlignment','bottom','FontSize',7);
        end
        if ~isnan(bw3_lo) && bw3_lo >= xlim_lo
            xline(axDP,bw3_lo,'--','Color',[0 0.4 0.9],'LineWidth',1.0,...
                'Label',sprintf('%.2fHz',bw3_lo),'LabelVerticalAlignment','top','FontSize',7);
        end
        if ~isnan(bw3_hi) && bw3_hi <= fn_e
            xline(axDP,bw3_hi,'-','Color',[0 0.4 0.9],'LineWidth',1.0,...
                'Label',sprintf('%.0fHz',bw3_hi),'LabelVerticalAlignment','top','FontSize',7);
        end
        hold(axDP,'off');
        set(axDP,'XScale','log'); grid(axDP,'on');
        xlim(axDP,[xlim_lo fn_e]); xlabel(axDP,'Frecuencia (Hz)'); ylabel(axDP,'dB re 1 V²/Hz');
        if ~isnan(bw_lo)&&~isnan(bw_hi)
            if ~isnan(bw3_lo)&&~isnan(bw3_hi)
                title(axDP,sprintf('PSD  |  BW(>0dB): %.2f–%.0fHz  |  BW(>3dB): %.2f–%.0fHz',bw_lo,bw_hi,bw3_lo,bw3_hi));
            else
                title(axDP,sprintf('PSD golpes vs. ruido  |  BW(SNR>0dB): %.2f–%.0f Hz',bw_lo,bw_hi));
            end
        else
            title(axDP,'PSD golpes vs. ruido  |  SNR<0dB en toda la banda');
        end
        legend(axDP,'Location','southwest','FontSize',8);

        axDS = subplot(1,2,2);
        plot(axDS, f_snr_v, snr_dB, 'Color',[0.85 0.20 0.10], 'LineWidth',1.4);
        hold(axDS,'on');
        yline(axDS,0,'--k','LineWidth',1.2,'Label','0 dB','LabelHorizontalAlignment','left','FontSize',8);
        yline(axDS,3,':k', 'LineWidth',1.0,'Label','3 dB','LabelHorizontalAlignment','left','FontSize',7);
        if ~isnan(bw_lo)&&bw_lo>=xlim_lo
            xline(axDS,bw_lo,'--','Color',[0 0.6 0],'LineWidth',1.2,...
                'Label',sprintf('%.2fHz',bw_lo),'LabelVerticalAlignment','bottom','FontSize',7);
        end
        if ~isnan(bw_hi)&&bw_hi<=fn_e
            xline(axDS,bw_hi,'-','Color',[0 0.6 0],'LineWidth',1.2,...
                'Label',sprintf('%.0fHz',bw_hi),'LabelVerticalAlignment','bottom','FontSize',7);
        end
        if ~isnan(bw3_lo)&&bw3_lo>=xlim_lo
            xline(axDS,bw3_lo,'--','Color',[0 0.4 0.9],'LineWidth',1.0,...
                'Label',sprintf('%.2fHz',bw3_lo),'LabelVerticalAlignment','top','FontSize',7);
        end
        if ~isnan(bw3_hi)&&bw3_hi<=fn_e
            xline(axDS,bw3_hi,'-','Color',[0 0.4 0.9],'LineWidth',1.0,...
                'Label',sprintf('%.0fHz',bw3_hi),'LabelVerticalAlignment','top','FontSize',7);
        end
        hold(axDS,'off');
        set(axDS,'XScale','log'); grid(axDS,'on');
        xlim(axDS,[xlim_lo fn_e]); xlabel(axDS,'Frecuencia (Hz)'); ylabel(axDS,'SNR (dB)');
        title(axDS,'SNR(f) = PSD_{golpes} / PSD_{ruido}');
        sgtitle(figD, sprintf('%s  |  SNR(f)  |  %.0f%% activo',enm,pct_activo_mu),...
            'FontSize',9,'FontWeight','bold');
    else
        fprintf('  [Fig D] %s: señal insuficiente para SNR(f)\n', enm);
    end

    % ==================================================================
    % FIGURA(S) C — Espectrogramas (opcional)
    % ==================================================================
    de_spect = de([]); Nm_sp = 0;   % por defecto: ninguno
    if GEN_SPECT
        Nm_all = numel(de_all);
        fprintf('\n  [%s] ¿Cuáles espectrogramas? (de las %d mediciones totales)\n', enm, Nm_all);
        fprintf('  todos | 1,2,3 | 5-10 | aN=auto N representativos\n');
        sp_str = strtrim(input(sprintf('  [1-%d, Enter=omitir]: ', Nm_all), 's'));
        if ~isempty(sp_str)
            if strcmpi(sp_str,'todos')
                idx_sp = 1:Nm_all;
            elseif ~isempty(regexp(sp_str,'^a\d+$','once'))
                N_sp = str2double(regexp(sp_str,'\d+','match','once'));
                idx_sp = autoSeleccionarMeds(de_all, Nm_all, N_sp);
            else
                idx_sp = parseSeleccion(sp_str, Nm_all);
            end
            if ~isempty(idx_sp)
                de_spect = de_all(idx_sp);   % de_ALL — independiente del filtro de cálculo
                Nm_sp    = numel(de_spect);
                fprintf('  → %d espectrogramas (independiente del filtro de cálculo).\n', Nm_sp);
            end
        end
    end

    nFigs_C = ceil(Nm_sp / MEDS_POR_FIG);
    for fg = 1:nFigs_C
        meds_page = (fg-1)*MEDS_POR_FIG+1 : min(fg*MEDS_POR_FIG, Nm_sp);
        nCols     = numel(meds_page);

        figC = figure('Name',sprintf('[C%d] Espectrogramas — %s',fg,enm),...
            'NumberTitle','off',...
            'Position',[60+15*ei+fg*30 30 700*nCols 600]);

        for ci = 1:nCols
            mi  = meds_page(ci);
            sig = de_spect(mi).seg;   % usar de_spect (subset seleccionado para spectrogramas)
            t   = (0:numel(sig)-1)/fs_e;
            dist_sp = ''; if ~isnan(de_spect(mi).distancia), dist_sp = sprintf(' %gp',de_spect(mi).distancia); end
            seq_sp  = ''; if ~isnan(de_spect(mi).seq_ini),   seq_sp  = ' [seq]'; end
            mTitle = sprintf('#%d | %s%s%s | %s', de_spect(mi).musIdx, de_spect(mi).punta, dist_sp, seq_sp, de_spect(mi).timestamp);

            % -- Fila 1: tiempo con envolvente y golpes --
            axT = subplot(2, nCols, ci);
            plot(axT, t, sig, 'Color',[col_e 0.8], 'LineWidth',0.7, 'DisplayName',lbl_sig);
            hold(axT,'on');
            if isfield(de_spect(mi),'envSmooth') && ~isempty(de_spect(mi).envSmooth)
                env_v   = de_spect(mi).envSmooth;
                thr_v   = de_spect(mi).envThresh;
                dc_r    = de_spect(mi).envDC;
                col_env = [0.95 0.50 0.05];
                plot(axT, t,  dc_r+env_v, 'Color',[col_env 0.7], 'LineWidth',0.8, 'DisplayName','envolvente');
                plot(axT, t,  dc_r-env_v, 'Color',[col_env 0.7], 'LineWidth',0.8, 'HandleVisibility','off');
                yline(axT,  dc_r+thr_v,'--','Color',col_env,'LineWidth',1.0,...
                    'Label',sprintf('umbral %.2gV',thr_v),'FontSize',7,...
                    'LabelHorizontalAlignment','left','HandleVisibility','off');
                yline(axT,  dc_r-thr_v,'--','Color',col_env,'LineWidth',1.0,'HandleVisibility','off');
            end
            if isfield(de_spect(mi),'maskHit') && any(de_spect(mi).maskHit)
                yl_t  = ylim(axT);
                mh    = de_spect(mi).maskHit;
                d_mh  = diff([0; double(mh); 0]);
                h_on  = find(d_mh ==  1);
                h_off = min(find(d_mh == -1) - 1, numel(t));
                col_gm = [0.05 0.58 0.15];
                for k = 1:numel(h_on)
                    fill(axT,[t(h_on(k)) t(h_off(k)) t(h_off(k)) t(h_on(k))],...
                        [yl_t(1) yl_t(1) yl_t(2) yl_t(2)],...
                        [0.20 0.80 0.30],'FaceAlpha',0.13,'EdgeColor','none','HandleVisibility','off');
                end
                ylim(axT, yl_t);
                plot(axT,t(h_on), sig(h_on), 'o','Color',col_gm,'MarkerFaceColor',col_gm,...
                    'MarkerSize',5,'LineStyle','none','DisplayName',sprintf('%d golpes',numel(h_on)));
                plot(axT,t(h_off),sig(h_off),'s','Color',col_gm,'MarkerFaceColor','none',...
                    'MarkerSize',6,'LineStyle','none','HandleVisibility','off');
            end
            hold(axT,'off');
            xlabel(axT,'Tiempo (s)'); ylabel(axT,'V');
            title(axT, mTitle,'Interpreter','none','FontSize',7.5);
            legend(axT,'show','Location','northeast','FontSize',7);
            grid(axT,'on'); xlim(axT,[0 t(end)]);

            % -- Fila 2: espectrograma --
            axS = subplot(2, nCols, nCols + ci);
            if numel(sig) >= WIN_WELCH
                spectrogram(sig, hann(WIN_WELCH), OVL_WELCH, WIN_WELCH, fs_e, 'yaxis');
                colormap(axS, jet); colorbar(axS);
                if flo>0, yline(axS,flo/1000,'--w','LineWidth',1); end
                if fhi>0&&fhi<=fn_e, yline(axS,fhi/1000,'-w','LineWidth',1.3); end
                ylim(axS,[df/1000 fn_e/1000]);
                title(axS,sprintf('Espectrograma — %s',lbl_sig),'FontSize',8);
            else
                text(0.5,0.5,'señal muy corta','Parent',axS,'HorizontalAlignment','center');
            end
        end
        sgtitle(figC, sprintf('%s  —  espectrogramas  (pág %d/%d)',enm,fg,nFigs_C),...
            'FontSize',9,'FontWeight','bold');
    end

    resumenEnt{ei} = struct('nombre',enm,'Nm',Nm,'fpk',fpk,...
        'snr_mu',snr_mu,'snr_sg',snr_sg,'flo',flo,'fhi',fhi,...
        'f_lo3',f_lo3,'f_hi3',f_hi3,'thresh3',thresh3,...
        'pct_activo',pct_activo_mu,...
        'f_ref',f_ref,'mean_dB',mean_dB,'std_dB',std_dB);
end

% =========================================================================
%% FIGURA E — PSD media por entidad (comparación global, mediciones seleccionadas)
% =========================================================================
figE = figure('Name',sprintf('[E] PSD media comparada — %s', lbl_sig),...
    'NumberTitle','off','Position',[80 80 950 520]);
axE = axes('Parent',figE); hold(axE,'on');
for ei = 1:numel(resumenEnt)
    r = resumenEnt{ei};
    if isempty(r) || ~isfield(r,'f_ref') || isempty(r.f_ref), continue; end
    col_ei = colMap(r.nombre);
    fr_ = r.f_ref(:)'; mu_ = r.mean_dB(:)'; sg_ = r.std_dB(:)';
    fill(axE,[fr_ fliplr(fr_)],[(mu_+sg_) fliplr(mu_-sg_)],...
        col_ei,'FaceAlpha',0.13,'EdgeColor','none','HandleVisibility','off');
    if ~isnan(r.f_lo3) && ~isnan(r.f_hi3)
        lbl_e = sprintf('%s  (N=%d | −3dB: %.1f–%.0fHz)', r.nombre, r.Nm, r.f_lo3, r.f_hi3);
    else
        lbl_e = sprintf('%s  (N=%d)', r.nombre, r.Nm);
    end
    plot(axE, r.f_ref, r.mean_dB, 'Color',col_ei, 'LineWidth',2.2, 'DisplayName',lbl_e);
    if ~isnan(r.f_lo3)
        yline(axE, r.thresh3, ':','Color',col_ei*0.7,'LineWidth',0.8,...
            'HandleVisibility','off','Alpha',0.6);
        xline(axE, r.f_lo3,'--','Color',col_ei*0.8,'LineWidth',0.9,...
            'HandleVisibility','off','Alpha',0.7,...
            'Label',sprintf('%.1f',r.f_lo3),'LabelVerticalAlignment','bottom','FontSize',6);
        if r.f_hi3 <= datos(1).fs/2
            xline(axE, r.f_hi3,'-','Color',col_ei*0.8,'LineWidth',0.9,...
                'HandleVisibility','off','Alpha',0.7,...
                'Label',sprintf('%.0f',r.f_hi3),'LabelVerticalAlignment','bottom','FontSize',6);
        end
    end
end
hold(axE,'off');
set(axE,'XScale','log'); grid(axE,'on');
xlim(axE,[datos(1).fs/WIN_WELCH datos(1).fs/2]);
xlabel(axE,'Frecuencia (Hz)'); ylabel(axE,'dB re 1 V²/Hz');
legend(axE,'show','Location','southwest','FontSize',8,'Interpreter','none');
title(axE, sprintf('PSD media ± σ por entidad  —  %s', lbl_sig));

% Rellenar columna BW−3dB en tablaGlobal usando resumenEnt
bw_map = containers.Map('KeyType','char','ValueType','char');
for ei = 1:numel(resumenEnt)
    r = resumenEnt{ei}; if isempty(r), continue; end
    if isfield(r,'f_lo3') && ~isnan(r.f_lo3)
        bw_map(r.nombre) = sprintf('%.1f–%.0f', r.f_lo3, r.f_hi3);
    else
        bw_map(r.nombre) = 'N/D';
    end
end
for i = 2:N+1
    if isempty(tablaGlobal{i,2}), continue; end
    enm_i = tablaGlobal{i,2};
    if bw_map.isKey(enm_i)
        tablaGlobal{i,7} = bw_map(enm_i);
    else
        tablaGlobal{i,7} = 'N/D';
    end
end

% =========================================================================
%% Resumen en consola
% =========================================================================
fprintf('\n=== TABLA GLOBAL (%s) ===\n', lbl_sig);
fmt = '%3s  %-20s %3s  %-8s  %6s  %9s  %14s\n';
fprintf(fmt, tablaGlobal{1,[1 2 3 4 5 6 7]});
fprintf('%s\n', repmat('-',1,74));
for i = 2:N+1
    if ~isempty(tablaGlobal{i,1})
        fprintf(fmt, tablaGlobal{i,[1 2 3 4 5 6 7]});
    end
end

fprintf('\n=== RESUMEN POR ENTIDAD ===\n');
fprintf('  %-22s  %3s  %12s  %16s  %s\n','Entidad','Nm','Banda cfg (Hz)','−3dB BW (Hz)','SNR (dB)');
fprintf('  %s\n',repmat('-',1,76));
for ei = 1:numel(resumenEnt)
    r = resumenEnt{ei}; if isempty(r), continue; end
    if isfield(r,'f_lo3') && ~isnan(r.f_lo3)
        bw3_str = sprintf('%.1f – %.0f', r.f_lo3, r.f_hi3);
    else
        bw3_str = 'N/D';
    end
    fprintf('  %-22s  %3d  %5g – %-5g  %16s  %6.1f ± %.1f\n',...
        r.nombre, r.Nm, r.flo, r.fhi, bw3_str, r.snr_mu, r.snr_sg);
end
fprintf('\nSNR = E_inband / E_outband (dB)  — >0 dB: más energía dentro de la banda.\n');
fprintf('−3dB BW = rango donde PSD media >= (plateau − 3 dB), excluyendo región de resonancia.\n');

% =========================================================================
%% Exportar JSON para interpretación
% =========================================================================
exp_out              = struct();
exp_out.generado     = datestr(now, 'yyyy-mm-dd HH:MM:SS');
exp_out.script       = 'analisis_espectral.m';
exp_out.senial_usada = lbl_sig;
exp_out.welch        = struct('WIN_muestras',WIN_WELCH,'OVL_muestras',OVL_WELCH, ...
    'NFFT',NFFT_WELCH,'delta_f_Hz',datos(1).fs/WIN_WELCH);

% Índice de lookup SNR por clave "entidad|musIdx"
snr_idx = containers.Map('KeyType','char','ValueType','double');
for tgi = 2:size(tablaGlobal,1)
    if isempty(tablaGlobal{tgi,1}), continue; end
    k_snr = sprintf('%s|%s', tablaGlobal{tgi,2}, tablaGlobal{tgi,3});
    snr_idx(k_snr) = str2double(tablaGlobal{tgi,6});
end

% Tabla global plana (una fila por medición)
tg_arr = cell(N, 1);
for i = 1:N
    tg_arr{i} = struct( ...
        'n',      i, ...
        'entidad', tablaGlobal{i+1,2}, ...
        'med_idx', str2double(tablaGlobal{i+1,3}), ...
        'punta',   tablaGlobal{i+1,4}, ...
        'fs_SPS',  str2double(tablaGlobal{i+1,5}), ...
        'snr_dB',  str2double(tablaGlobal{i+1,6}), ...
        'bw3dB',   tablaGlobal{i+1,7} ...
    );
end
exp_out.tabla_global = tg_arr;

% Entidades: resumen + PSD decimada + mediciones individuales extendidas
ent_arr = {};
for ei = 1:numel(resumenEnt)
    r = resumenEnt{ei};
    if isempty(r), continue; end

    de_ei = datos(strcmp({datos.entNombre}, r.nombre));

    % Mediciones individuales con todos los metadatos
    meds_arr = cell(numel(de_ei), 1);
    for mi = 1:numel(de_ei)
        dm    = de_ei(mi);
        clave = sprintf('%s|%d', r.nombre, dm.musIdx);
        snr_m = NaN;
        if snr_idx.isKey(clave), snr_m = snr_idx(clave); end
        meds_arr{mi} = struct( ...
            'idx',                dm.musIdx, ...
            'punta',              dm.punta, ...
            'timestamp',          dm.timestamp, ...
            'observ',             dm.observ, ...
            'distancia_p',        dm.distancia, ...
            'ganancia_pga',       dm.ganancia_pga, ...
            'secuencia_marcada',  ~isnan(dm.seq_ini), ...
            'secuencia_inicio_s', dm.seq_ini, ...
            'periodo_estimado_s', dm.T_est, ...
            'snr_dB',             snr_m ...
        );
    end

    % PSD decimada: máximo 500 puntos para mantener el JSON manejable
    nf      = numel(r.f_ref);
    step    = max(1, floor(nf / 500));
    idx_dec = 1:step:nf;

    e = struct( ...
        'nombre',       r.nombre, ...
        'N_meds',       r.Nm, ...
        'fs_SPS',       de_ei(1).fs, ...
        'fMin_Hz',      r.flo, ...
        'fMax_Hz',      r.fhi, ...
        'snr_media_dB', r.snr_mu, ...
        'snr_std_dB',   r.snr_sg, ...
        'fpk_Hz',       r.fpk, ...
        'bw3dB_lo_Hz',  r.f_lo3, ...
        'bw3dB_hi_Hz',  r.f_hi3, ...
        'pct_activo',   r.pct_activo ...
    );
    e.psd = struct( ...
        'f_Hz',    r.f_ref(idx_dec), ...
        'media_dB', r.mean_dB(idx_dec), ...
        'std_dB',   r.std_dB(idx_dec) ...
    );
    e.mediciones = meds_arr;
    ent_arr{end+1} = e; %#ok<AGROW>
end
exp_out.entidades = ent_arr;

% Serializar y guardar en datos/
outname = sprintf('analisis_%s.json', datestr(now, 'yyyymmdd_HHMMSS'));
outpath = fullfile(datosDir, outname);
try
    try
        json_str = jsonencode(exp_out, 'PrettyPrint', true);   % R2020b+
    catch
        json_str = jsonencode(exp_out);                         % R2016b–R2020a
    end
    fid = fopen(outpath, 'w', 'n', 'UTF-8');
    fwrite(fid, json_str, 'char');
    fclose(fid);
    fprintf('\n[JSON exportado] %s\n', outpath);
    fprintf('  Compartir con Claude para interpretación automática de resultados.\n');
catch ex
    fprintf('\n[Aviso] No se pudo exportar JSON: %s\n', ex.message);
end

% =========================================================================
%% Funciones locales
% =========================================================================
function [snr_dB, pxx, f] = calcPSD(seg, fs, fn, win, ovl, nfft, flo, fhi)
    pxx = []; f = []; snr_dB = NaN;
    if numel(seg) < win, return; end
    seg = seg - mean(seg);
    [pxx, f] = pwelch(seg, hann(win), ovl, nfft, fs);
    df      = f(2) - f(1);
    inband  = f >= flo & f <= fhi;
    outband = f >= df & ~inband;
    if sum(inband)<2 || sum(outband)<2, return; end
    snr_dB = 10*log10(mean(pxx(inband)) / (mean(pxx(outband)) + eps));
end

function decorarPSD(ax, flo, fhi, fn)
    yl = ylim(ax);
    if flo > 0
        xline(ax,flo,'--','Color',[0 0.55 0],'LineWidth',1,'Alpha',0.8,...
            'Label',sprintf('fMin=%gHz',flo),'LabelVerticalAlignment','bottom','FontSize',7);
    end
    if fhi > 0 && fhi <= fn
        xline(ax,fhi,'-','Color',[0 0.55 0],'LineWidth',1,'Alpha',0.8,...
            'Label',sprintf('fMax=%gHz',fhi),'LabelVerticalAlignment','bottom','FontSize',7);
    end
    if flo < fhi
        fill(ax,[flo fhi fhi flo],[yl(1) yl(1) yl(2) yl(2)],...
            [0.8 1 0.8],'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
    end
    xline(ax,fn,'--k','LineWidth',0.7,'Alpha',0.4);
end

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

function idx = autoSeleccionarMeds(de, Nm, N_want)
% Selecciona N_want mediciones priorizando:
%   1. Secuencia marcada (seq_ini no-NaN): peso 3
%   2. Diversidad de punta: penaliza puntas ya elegidas
%   3. Diversidad de distancia: prefiere distancias no cubiertas
% Retorna índices ordenados por timestamp.
    N_want = min(N_want, Nm);
    scores = zeros(1, Nm);
    for k = 1:Nm
        if ~isnan(de(k).seq_ini), scores(k) = scores(k) + 3; end
        if ~isnan(de(k).distancia), scores(k) = scores(k) + 1; end
    end
    [~, si] = sort(scores, 'descend');
    % Greedy: elegir iterativamente favoreciendo diversidad de punta y dist
    chosen = [];
    puntas_usadas = {};
    dists_usadas  = [];
    for iter = 1:Nm
        k = si(iter);
        diversidad = 0;
        if ~ismember(de(k).punta, puntas_usadas), diversidad = diversidad + 2; end
        if ~isnan(de(k).distancia) && ~ismember(de(k).distancia, dists_usadas)
            diversidad = diversidad + 1;
        end
        scores(k) = scores(k) + diversidad;
    end
    [~, si2] = sort(scores, 'descend');
    idx = sort(si2(1:N_want));   % ordenar por índice original (≈ timestamp)
end

function idx = parseSeleccion(str, N)
    idx = [];
    parts = strsplit(strtrim(str), ',');
    for k = 1:numel(parts)
        p = strtrim(parts{k});
        if contains(p, '-')
            rng = str2double(strsplit(p, '-'));
            if numel(rng)==2 && ~any(isnan(rng))
                idx = [idx, rng(1):rng(2)]; %#ok<AGROW>
            end
        else
            n = str2double(p);
            if ~isnan(n), idx = [idx, n]; end %#ok<AGROW>
        end
    end
    idx = unique(round(idx));
    idx = idx(idx >= 1 & idx <= N);
end

function [psd_hit, psd_noise, snr_f, f] = calcPSD_SNR(seg_hit, seg_noise, fs, win, ovl, nfft)
    psd_hit = []; psd_noise = []; snr_f = []; f = [];
    win_act = win;
    while win_act > 256 && (numel(seg_hit) < win_act || numel(seg_noise) < win_act)
        win_act = win_act / 2;
    end
    if numel(seg_hit) < win_act || numel(seg_noise) < win_act
        fprintf('    [SNR(f)] Datos insuficientes (hit=%d, quiet=%d). Omitiendo.\n',...
            numel(seg_hit), numel(seg_noise));
        return;
    end
    if win_act < win
        fprintf('    [SNR(f)] Ventana reducida: %d (Δf=%.3f Hz)\n', win_act, fs/win_act);
    end
    ovl_act  = floor(win_act/2);
    nfft_act = max(win_act, nfft);
    seg_hit   = seg_hit   - mean(seg_hit);
    seg_noise = seg_noise - mean(seg_noise);
    [psd_hit,   f] = pwelch(seg_hit,   hann(win_act), ovl_act, nfft_act, fs);
    [psd_noise, ~] = pwelch(seg_noise, hann(win_act), ovl_act, nfft_act, fs);
    snr_f = psd_hit ./ (psd_noise + eps);
end
