% analisis_espectral.m
% Análisis espectral por ENTIDAD (circuito analógico).
%
% Combina todas las mediciones de cada entidad para obtener:
%   · PSD promediada ± desviación estándar (dB re 1 mV²/Hz)
%   · SNR = media_densidad_inband / media_densidad_outband  (dB)
%     → positivo cuando la densidad en [fMin,fMax] supera al resto
%   · Espectrograma promediado de todas las muestras
%
% Lee únicamente datos\ (formato nuevo muestras+entidad).
% Toma la señal completa de cada medición (sin selección interactiva).

clc; close all; clear;

% =========================================================================
%% PARÁMETROS CONFIGURABLES
% =========================================================================
% Resolución espectral: Δf = fs / WIN_WELCH
%   fs=1020, WIN=16384 → Δf=0.062 Hz  (resuelve hasta 0.1 Hz, req. ≥32 s de señal)
%   fs=1020, WIN= 8192 → Δf=0.124 Hz  (resuelve hasta ~0.2 Hz, req. ≥16 s)
%   fs=1020, WIN=  256 → Δf=3.98 Hz   (no sirve para bajas frecuencias)
WIN_WELCH    = 2^14;   % 16384 muestras → Δf ≈ 0.062 Hz a 1020 SPS
OVL_WELCH    = 2^13;   % 50% solapamiento
NFFT_WELCH   = 2^14;   % igual a WIN para máxima resolución
F_BANDA_BAJA = 0.1;    % Hz — fallback fMin si la entidad tiene fMin=0
F_BANDA_MED  = 100;    % Hz — fallback fMax si la entidad tiene fMax=0
% =========================================================================

scriptDir = fileparts(mfilename('fullpath'));
datosDir  = fullfile(scriptDir, 'datos');

% =========================================================================
%% PASO 1 — Cargar mediciones desde datos\
% =========================================================================
fprintf('=== ANÁLISIS ESPECTRAL POR ENTIDAD ===\n');
fprintf('Welch: ventana=%d  overlap=%d  NFFT=%d  Δf=%.4f Hz\n\n',...
    WIN_WELCH, OVL_WELCH, NFFT_WELCH, 1020/WIN_WELCH);

catalog = [];

if ~isfolder(datosDir)
    fprintf('No existe la carpeta datos\\\n'); return
end

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
            c.raw_mV    = double(m.raw_mV(:));
            c.filtered  = double(m.filtered(:));
            if isempty(catalog), catalog = c; else, catalog(end+1) = c; end %#ok<AGROW>
        end
    catch e
        fprintf('  [aviso] %s: %s\n', f.name, e.message);
    end
end

if isempty(catalog)
    fprintf('No se encontraron mediciones en datos\\\n'); return
end

% =========================================================================
%% PASO 2 — Selección de ENTIDADES por consola
% =========================================================================
% Construir lista de entidades únicas con sus mediciones
todosEnt = unique({catalog.entNombre},'stable');
fprintf('Entidades disponibles:\n');
fprintf('  %3s  %-24s  %5s  %6s  %s\n','#','Entidad','Meds','fs','Puntas usadas');
fprintf('  %s\n', repmat('-',1,70));
for ei = 1:numel(todosEnt)
    enm = todosEnt{ei};
    mask = strcmp({catalog.entNombre}, enm);
    meds = catalog(mask);
    puntas = strjoin(unique({meds.punta},'stable'),', ');
    fprintf('  %3d  %-24s  %5d  %6g  %s\n', ei, enm, sum(mask), meds(1).fs, puntas);
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

% Tomar TODAS las mediciones de las entidades seleccionadas
mask_sel = ismember({catalog.entNombre}, sel_ent);
datos    = catalog(mask_sel);
N        = numel(datos);
entUnicas = unique({datos.entNombre},'stable');
fprintf('\nAnalizando %d medición(es) en %d entidad(es).\n\n', N, numel(entUnicas));

% Señal completa = el segmento ES toda la señal
for i = 1:N
    datos(i).seg_raw = datos(i).raw_mV;
    datos(i).seg_fil = datos(i).filtered;
end

paleta = lines(max(numel(entUnicas),1));
colMap = containers.Map('KeyType','char','ValueType','any');
for ei = 1:numel(entUnicas), colMap(entUnicas{ei}) = paleta(ei,:); end

% =========================================================================
%% FIGURA GLOBAL — PSD (dB) superpuesta de todas las mediciones
% =========================================================================
figG = figure('Name','PSD global — todas las mediciones','NumberTitle','off',...
    'Position',[40 40 1200 500]);
axGr = subplot(1,2,1); hold(axGr,'on');
axGf = subplot(1,2,2); hold(axGf,'on');

tablaGlobal = cell(N+1,8);
tablaGlobal(1,:) = {'#','Entidad','m#','Punta','fs','Filtro','SNR raw(dB)','SNR fil(dB)'};

for i = 1:N
    fs  = datos(i).fs; fn = fs/2;
    col = colMap(datos(i).entNombre);
    lbl = sprintf('%s #%d (%s)', datos(i).entNombre, datos(i).musIdx, datos(i).punta);
    flo = datos(i).fMin; fhi = datos(i).fMax;
    if flo==0 && fhi==0, flo=F_BANDA_BAJA; fhi=F_BANDA_MED; end

    [snrr, pxxr, fr] = calcPSD(datos(i).seg_raw, fs, fn, WIN_WELCH, OVL_WELCH, NFFT_WELCH, flo, fhi);
    [snrf, pxxf, ff] = calcPSD(datos(i).seg_fil, fs, fn, WIN_WELCH, OVL_WELCH, NFFT_WELCH, flo, fhi);

    if ~isempty(pxxr), plot(axGr, fr, 10*log10(pxxr), 'Color',col,'LineWidth',1,'DisplayName',lbl); end
    if ~isempty(pxxf), plot(axGf, ff, 10*log10(pxxf), 'Color',col,'LineWidth',1,'DisplayName',lbl); end

    tablaGlobal{i+1,1} = num2str(i);
    tablaGlobal{i+1,2} = datos(i).entNombre;
    tablaGlobal{i+1,3} = num2str(datos(i).musIdx);
    tablaGlobal{i+1,4} = datos(i).punta;
    tablaGlobal{i+1,5} = num2str(fs);
    tablaGlobal{i+1,6} = datos(i).filtCmd;
    tablaGlobal{i+1,7} = sprintf('%.1f', snrr);
    tablaGlobal{i+1,8} = sprintf('%.1f', snrf);
end

fn0 = datos(1).fs/2;
for axd = [axGr axGf]
    for ei2 = 1:numel(entUnicas)
        enm2 = entUnicas{ei2}; ce = colMap(enm2)*0.65;
        idx_e = find(strcmp({datos.entNombre},enm2),1);
        flo2 = datos(idx_e).fMin; fhi2 = datos(idx_e).fMax;
        if flo2==0&&fhi2==0, flo2=F_BANDA_BAJA; fhi2=F_BANDA_MED; end
        if flo2>0, xline(axd,flo2,'--','Color',ce,'LineWidth',0.9,'Alpha',0.7); end
        if fhi2>0&&fhi2<=fn0
            xline(axd,fhi2,'-','Color',ce,'LineWidth',0.9,'Alpha',0.7,...
                'Label',sprintf('%s %gHz',enm2,fhi2),...
                'LabelVerticalAlignment','bottom','FontSize',7);
        end
    end
    xline(axd,fn0,'--k','LineWidth',0.8,'Alpha',0.5);
    xlabel(axd,'Frecuencia (Hz)'); ylabel(axd,'PSD (dB re 1 mV²/Hz)');
    legend(axd,'Location','northeast','Interpreter','none','FontSize',7);
    grid(axd,'on'); xlim(axd,[0 fn0]);
    set(axd,'XScale','log');
end
title(axGr, sprintf('PSD raw PSoC  (vent=%d, Δf=%.3fHz)', WIN_WELCH, datos(1).fs/WIN_WELCH));
title(axGf, sprintf('PSD filtrada MATLAB  (vent=%d)', WIN_WELCH));
sgtitle(figG,'PSD global — colores por entidad | líneas verticales = fMin/fMax');

% =========================================================================
%% FIGURAS POR ENTIDAD — 3 tipos de figura:
%%   A) PSD (1×2): raw | filtrada  con media±σ
%%   B) SNR (1×1): bar chart por medición
%%   C) Espectrogramas: hasta 2 muestras por página
%%      cada muestra ocupa 3 filas: tiempo | spect raw | spect filtrada
% =========================================================================
resumenEnt = cell(numel(entUnicas),1);
MEDS_POR_FIG = 2;   % máximo de mediciones por figura de espectrogramas

for ei = 1:numel(entUnicas)
    enm   = entUnicas{ei};
    de    = datos(strcmp({datos.entNombre},enm));
    Nm    = numel(de);
    col_e = colMap(enm);
    fs_e  = de(1).fs; fn_e = fs_e/2;
    flo   = de(1).fMin; fhi = de(1).fMax;
    if flo==0 && fhi==0, flo=F_BANDA_BAJA; fhi=F_BANDA_MED; end
    df    = fs_e / WIN_WELCH;

    headerBase = sprintf('%s  |  BW: %g–%g Hz  |  G=%g  |  fs=%g SPS  |  Δf=%.3f Hz',...
        enm, flo, fhi, de(1).ganancia, fs_e, df);

    % ------------------------------------------------------------------
    % Calcular PSD por muestra
    % ------------------------------------------------------------------
    psd_raw_mat = []; psd_fil_mat = []; f_ref = [];
    snr_raw_vec = nan(1,Nm); snr_fil_vec = nan(1,Nm);

    for mi = 1:Nm
        [snrr, pxxr, fr] = calcPSD(de(mi).seg_raw, fs_e, fn_e, WIN_WELCH, OVL_WELCH, NFFT_WELCH, flo, fhi);
        [snrf, pxxf, ~]  = calcPSD(de(mi).seg_fil, fs_e, fn_e, WIN_WELCH, OVL_WELCH, NFFT_WELCH, flo, fhi);
        if isempty(pxxr), continue; end
        if isempty(f_ref), f_ref = fr(:)'; end
        if numel(pxxr) ~= numel(f_ref)
            pxxr = interp1(fr, pxxr, f_ref, 'linear', pxxr(end));
            pxxf = interp1(fr, pxxf, f_ref, 'linear', pxxf(end));
        end
        psd_raw_mat(end+1,:) = 10*log10(pxxr(:)'+eps); %#ok<AGROW>
        psd_fil_mat(end+1,:) = 10*log10(pxxf(:)'+eps); %#ok<AGROW>
        snr_raw_vec(mi) = snrr;
        snr_fil_vec(mi) = snrf;
    end

    if isempty(psd_raw_mat)
        fprintf('AVISO: %s sin segmentos válidos (necesita ≥ %d muestras = %.0f s).\n',...
            enm, WIN_WELCH, WIN_WELCH/fs_e);
        continue;
    end

    mean_raw_dB = mean(psd_raw_mat, 1);
    std_raw_dB  = std(psd_raw_mat, 0, 1);
    mean_fil_dB = mean(psd_fil_mat, 1);
    std_fil_dB  = std(psd_fil_mat, 0, 1);

    snr_raw_v  = snr_raw_vec(~isnan(snr_raw_vec));
    snr_fil_v  = snr_fil_vec(~isnan(snr_fil_vec));
    snr_raw_mu = mean(snr_raw_v); snr_raw_sg = std(snr_raw_v);
    snr_fil_mu = mean(snr_fil_v); snr_fil_sg = std(snr_fil_v);

    dc = f_ref > 2*df;
    ftmp = f_ref(dc);
    [~,ik]  = max(10.^(mean_raw_dB(dc)/10)); fpk_raw = ftmp(ik);
    [~,ikf] = max(10.^(mean_fil_dB(dc)/10)); fpk_fil = ftmp(ikf);

    % ==================================================================
    % FIGURA A — PSD raw y filtrada
    % ==================================================================
    figA = figure('Name',sprintf('[A] PSD — %s',enm),'NumberTitle','off',...
        'Position',[30+15*ei 600 1300 520]);

    axA1 = subplot(1,2,1); hold(axA1,'on');
    for mi = 1:size(psd_raw_mat,1)
        plot(axA1, f_ref, psd_raw_mat(mi,:), 'Color',[0.72 0.72 0.72 0.4], 'LineWidth',0.7,...
            'DisplayName',sprintf('#%d %s',de(mi).musIdx,de(mi).punta));
    end
    fr_ = f_ref(:)'; mu_r = mean_raw_dB(:)'; sg_r = std_raw_dB(:)';
    fill(axA1,[fr_ fliplr(fr_)],[(mu_r+sg_r) fliplr(mu_r-sg_r)],...
        [0.5 0.5 0.5],'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
    plot(axA1, f_ref, mean_raw_dB, 'Color',[0.1 0.1 0.1],'LineWidth',2.2,...
        'DisplayName',sprintf('Media (pico=%.1fHz)',fpk_raw));
    decorarPSD(axA1, flo, fhi, fn_e);
    xlabel(axA1,'Frecuencia (Hz)'); ylabel(axA1,'dB re 1 mV²/Hz');
    title(axA1,sprintf('PSD raw PSoC  —  %d mediciones + media±σ',Nm));
    set(axA1,'XScale','log'); grid(axA1,'on'); xlim(axA1,[max(df,0.05) fn_e]);
    legend(axA1,'show','Location','southwest','FontSize',7);

    axA2 = subplot(1,2,2); hold(axA2,'on');
    for mi = 1:size(psd_fil_mat,1)
        plot(axA2, f_ref, psd_fil_mat(mi,:), 'Color',[col_e 0.35], 'LineWidth',0.7,...
            'DisplayName',sprintf('#%d %s',de(mi).musIdx,de(mi).punta));
    end
    fr_ = f_ref(:)'; mu_f = mean_fil_dB(:)'; sg_f = std_fil_dB(:)';
    fill(axA2,[fr_ fliplr(fr_)],[(mu_f+sg_f) fliplr(mu_f-sg_f)],...
        col_e,'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
    plot(axA2, f_ref, mean_fil_dB, 'Color',col_e,'LineWidth',2.2,...
        'DisplayName',sprintf('Media (pico=%.1fHz)',fpk_fil));
    decorarPSD(axA2, flo, fhi, fn_e);
    xlabel(axA2,'Frecuencia (Hz)'); ylabel(axA2,'dB re 1 mV²/Hz');
    title(axA2,'PSD filtrada MATLAB  —  media±σ');
    set(axA2,'XScale','log'); grid(axA2,'on'); xlim(axA2,[max(df,0.05) fn_e]);
    legend(axA2,'show','Location','southwest','FontSize',7);
    sgtitle(figA, [headerBase sprintf('  |  %d medición(es)',Nm)],'FontSize',9,'FontWeight','bold');

    % ==================================================================
    % FIGURA B — SNR por medición
    % ==================================================================
    figB = figure('Name',sprintf('[B] SNR — %s',enm),'NumberTitle','off',...
        'Position',[30+15*ei 200 700 420]);

    axB = axes('Parent',figB); hold(axB,'on');
    xb = 1:Nm;
    bh = bar(axB, xb, [snr_raw_vec(:) snr_fil_vec(:)], 0.7);
    bh(1).FaceColor = [0.45 0.45 0.45];
    bh(2).FaceColor = col_e;
    if ~isnan(snr_raw_mu)
        yline(axB, snr_raw_mu,'--','Color',[0.2 0.2 0.2],'LineWidth',1.5,...
            'Label',sprintf('μ raw=%.1fdB',snr_raw_mu),...
            'LabelVerticalAlignment','bottom','FontSize',8);
    end
    if ~isnan(snr_fil_mu)
        yline(axB, snr_fil_mu,'-','Color',col_e*0.7,'LineWidth',1.5,...
            'Label',sprintf('μ fil=%.1fdB',snr_fil_mu),...
            'LabelVerticalAlignment','top','FontSize',8);
    end
    yline(axB, 0, ':k','LineWidth',1,'Alpha',0.6);
    hold(axB,'off');
    xlabel(axB,'Medición'); ylabel(axB,'SNR (dB)');
    xticks(axB, xb);
    xticklabels(axB, arrayfun(@(i) sprintf('#%d\n%s',de(i).musIdx,de(i).punta),...
        xb,'UniformOutput',false));
    title(axB, sprintf('SNR en banda [%g–%g Hz]  —  raw: %.1f±%.1f dB  |  fil: %.1f±%.1f dB',...
        flo,fhi,snr_raw_mu,snr_raw_sg,snr_fil_mu,snr_fil_sg));
    legend(axB,{'raw PSoC','filtrada MATLAB'},'Location','best','FontSize',9);
    grid(axB,'on');
    sgtitle(figB, headerBase,'FontSize',9,'FontWeight','bold');

    % ==================================================================
    % FIGURA(S) C — Espectrogramas: hasta MEDS_POR_FIG por figura
    %   Layout por figura: cols=mediciones, filas=3 (tiempo|spect_raw|spect_fil)
    % ==================================================================
    nFigs_C = ceil(Nm / MEDS_POR_FIG);
    for fg = 1:nFigs_C
        idx_start = (fg-1)*MEDS_POR_FIG + 1;
        idx_end   = min(fg*MEDS_POR_FIG, Nm);
        meds_page = idx_start:idx_end;
        nCols     = numel(meds_page);

        figC = figure('Name',sprintf('[C%d] Espectrogramas — %s',fg,enm),...
            'NumberTitle','off',...
            'Position',[60+15*ei+fg*30 30 700*nCols 860]);

        for ci = 1:nCols
            mi  = meds_page(ci);
            raw = de(mi).seg_raw;
            fil = de(mi).seg_fil;
            t   = (0:numel(raw)-1)/fs_e;
            mTitle = sprintf('#%d | punta: %s | %s\n%s',...
                de(mi).musIdx, de(mi).punta, de(mi).timestamp,...
                de(mi).filtCmd);

            % -- Fila 1: señal en tiempo --
            axT = subplot(3, nCols, ci);
            plot(axT, t, raw, 'Color',[0.65 0.65 0.65],'LineWidth',0.6); hold(axT,'on');
            plot(axT, t, fil, 'Color',col_e,'LineWidth',0.9);
            hold(axT,'off');
            xlabel(axT,'Tiempo (s)'); ylabel(axT,'mV');
            title(axT, mTitle,'Interpreter','none','FontSize',7.5);
            legend(axT,{'raw','filtrada'},'Location','northeast','FontSize',7);
            grid(axT,'on'); xlim(axT,[0 t(end)]);

            % -- Fila 2: espectrograma raw --
            axSr = subplot(3, nCols, nCols + ci);
            if numel(raw) >= WIN_WELCH
                spectrogram(raw, hann(WIN_WELCH), OVL_WELCH, WIN_WELCH, fs_e, 'yaxis');
                colormap(axSr, jet); colorbar(axSr);
                if flo>0, yline(axSr,flo/1000,'--w','LineWidth',1); end
                if fhi>0&&fhi<=fn_e, yline(axSr,fhi/1000,'-w','LineWidth',1.3); end
                ylim(axSr,[0 fn_e/1000]);
                title(axSr,'Espectrograma raw','FontSize',8);
            else
                text(0.5,0.5,'señal muy corta','Parent',axSr,'HorizontalAlignment','center');
            end

            % -- Fila 3: espectrograma filtrada --
            axSf = subplot(3, nCols, 2*nCols + ci);
            if numel(fil) >= WIN_WELCH
                spectrogram(fil, hann(WIN_WELCH), OVL_WELCH, WIN_WELCH, fs_e, 'yaxis');
                colormap(axSf, jet); colorbar(axSf);
                if flo>0, yline(axSf,flo/1000,'--w','LineWidth',1); end
                if fhi>0&&fhi<=fn_e, yline(axSf,fhi/1000,'-w','LineWidth',1.3); end
                ylim(axSf,[0 fn_e/1000]);
                title(axSf,'Espectrograma filtrada','FontSize',8);
            else
                text(0.5,0.5,'señal muy corta','Parent',axSf,'HorizontalAlignment','center');
            end
        end

        sgtitle(figC, sprintf('%s  —  espectrogramas  (pág %d/%d)',enm,fg,nFigs_C),...
            'FontSize',9,'FontWeight','bold');
    end

    resumenEnt{ei} = struct('nombre',enm,'Nm',Nm,...
        'fpk_raw',fpk_raw,'fpk_fil',fpk_fil,...
        'snr_raw_mu',snr_raw_mu,'snr_raw_sg',snr_raw_sg,...
        'snr_fil_mu',snr_fil_mu,'snr_fil_sg',snr_fil_sg,...
        'flo',flo,'fhi',fhi);
end

% =========================================================================
%% Tablas resumen en consola
% =========================================================================
fprintf('\n=== TABLA GLOBAL ===\n');
fmt = '%3s  %-18s %3s  %-7s %6s  %11s  %11s\n';
fprintf(fmt, tablaGlobal{1,[1 2 3 4 5 7 8]});
fprintf('%s\n',repmat('-',1,72));
for i = 2:N+1
    if ~isempty(tablaGlobal{i,1})
        fprintf(fmt, tablaGlobal{i,[1 2 3 4 5 7 8]});
    end
end

fprintf('\n=== RESUMEN POR ENTIDAD ===\n');
fprintf('  %-20s  %3s  %12s  %-22s  %-22s\n',...
    'Entidad','Nm','Banda (Hz)','SNR raw (dB)','SNR filtrada (dB)');
fprintf('  %s\n',repmat('-',1,86));
for ei = 1:numel(resumenEnt)
    r = resumenEnt{ei}; if isempty(r), continue; end
    fprintf('  %-20s  %3d  %5g – %-5g   %8.1f ± %-8.1f  %8.1f ± %-8.1f\n',...
        r.nombre, r.Nm, r.flo, r.fhi,...
        r.snr_raw_mu, r.snr_raw_sg, r.snr_fil_mu, r.snr_fil_sg);
end
fprintf(['\nSNR = 10·log10( mean_PSD_inband / mean_PSD_outband )  — sin bin DC\n',...
         '  > 0 dB → densidad espectral DENTRO de [fMin,fMax] > fuera de banda\n',...
         '  < 0 dB → hay más densidad espectral fuera de la banda que dentro\n',...
         '  Nota: se substrae la media del segmento antes del PSD (elimina DC/offset).\n']);

% =========================================================================
%% Funciones locales
% =========================================================================
function [snr_dB, pxx, f] = calcPSD(seg, fs, fn, win, ovl, nfft, flo, fhi)
    pxx = []; f = []; snr_dB = NaN;
    if numel(seg) < win, return; end
    % Restar media antes de PSD: elimina el spike DC (f=0) que contaminaría el SNR
    seg = seg - mean(seg);
    [pxx, f] = pwelch(seg, hann(win), ovl, nfft, fs);
    % Excluir el bin DC (f=0) de ambas regiones para no contaminar el outband
    df       = f(2) - f(1);           % resolución espectral
    f_start  = df;                    % primer bin no-DC
    inband   = f >= flo & f <= fhi;
    outband  = f >= f_start & ~inband;  % empieza en df, no en 0
    if sum(inband)<2 || sum(outband)<2, return; end
    % SNR como cociente de densidades medias (independiente del ancho de banda)
    E_in  = mean(pxx(inband));
    E_out = mean(pxx(outband));
    snr_dB = 10*log10(E_in / (E_out + eps));
end

function decorarPSD(ax, flo, fhi, fn)
    yl = ylim(ax);
    if flo > 0
        xline(ax, flo, '--', 'Color',[0 0.55 0], 'LineWidth',1, 'Alpha',0.8,...
            'Label',sprintf('fMin=%gHz',flo),'LabelVerticalAlignment','bottom','FontSize',7);
    end
    if fhi > 0 && fhi <= fn
        xline(ax, fhi, '-', 'Color',[0 0.55 0], 'LineWidth',1, 'Alpha',0.8,...
            'Label',sprintf('fMax=%gHz',fhi),'LabelVerticalAlignment','bottom','FontSize',7);
    end
    if flo < fhi
        fill(ax, [flo fhi fhi flo], [yl(1) yl(1) yl(2) yl(2)],...
            [0.8 1 0.8], 'FaceAlpha',0.15, 'EdgeColor','none', 'HandleVisibility','off');
    end
    xline(ax, fn, '--k', 'LineWidth',0.7, 'Alpha',0.4);
end
