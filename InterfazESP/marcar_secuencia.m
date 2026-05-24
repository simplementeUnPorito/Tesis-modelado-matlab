% marcar_secuencia.m  (v6)
% Batch para marcar inicio y período de secuencias de golpes.
%
% FLUJO:
%   Configuración sesión → loop por medición →
%     graficar → preguntar N (o d=descartar) →
%     editar hits (r/m/a/d/g/q) → elegir inicio → [S/n/r/q]
%
% Comandos de edición:
%   r N        — elimina hit #N y sugiere el pico más cercano no seleccionado
%   m N t      — mueve hit #N al tiempo t (s)
%   a t        — agrega hit en tiempo t (s)
%   d          — descarta esta medición y pasa a la siguiente
%   g          — continúa al paso de elección de inicio
%   q          — sale del script

clc;

% =========================================================================
%% Parámetros de detección
% =========================================================================
SMOOTH_S     = 0.05;
THRESH_SIGMA = 2.5;
PRE_DET_S    = 0.20;
POST_DET_S   = 1.50;
MIN_QUIET_S  = 0.50;
PRE_PAD_S    = 0.15;   % región sombreada antes del onset
POST_PAD_S   = 1.20;   % región sombreada después del onset (máx)

scriptDir = fileparts(mfilename('fullpath'));
datosDir  = fullfile(scriptDir, 'datos');

% =========================================================================
archivos = dir(fullfile(datosDir,'*.mat'));
if isempty(archivos), fprintf('Sin .mat en %s\n', datosDir); return; end

fprintf('\n=== MARCAR SECUENCIA ===\n');
for k = 1:numel(archivos)
    fprintf('  %3d  %s\n', k, archivos(k).name);
end
opc_f = input(sprintf('\nArchivo (1–%d): ', numel(archivos)));
if isempty(opc_f)||opc_f<1||opc_f>numel(archivos)
    fprintf('Inválido.\n'); return; end
fname = archivos(opc_f).name;
fpath = fullfile(datosDir, fname);

d0 = load(fpath);
if ~isfield(d0,'muestras'), error('Sin campo "muestras".'); end
Ntotal = numel(d0.muestras);

fprintf('\nArchivo : %s  (%d mediciones)\n', fname, Ntotal);
imprimirTabla(d0.muestras, Ntotal);

% ---- Configuración de sesión ----
N_def_raw = input('\n¿Cuántos golpes por defecto? [10]: ');
N_GOLPES_DEF = ternario(isempty(N_def_raw), 10, round(N_def_raw));

opc_s = input('Señal: 1=raw  2=filtrada  [1]: ');
OPC_SIG = ternario(isempty(opc_s)||opc_s~=2, 1, 2);

idx_start_raw = input(sprintf('Empezar desde medición # [1]: '));
IDX_START = ternario(isempty(idx_start_raw)||idx_start_raw<1, 1, round(idx_start_raw));

trim_s_raw = input('Ignorar primeros N segundos (pisadas) [3]: ');
TRIM_START_S = ternario(isempty(trim_s_raw), 3.0, trim_s_raw);

trim_e_raw = input('Ignorar últimos N segundos (pisadas) [3]: ');
TRIM_END_S   = ternario(isempty(trim_e_raw), 3.0, trim_e_raw);

fprintf('\nN_def=%d  |  IDX_start=%d  |  trim=+%.1fs/−%.1fs\n', ...
    N_GOLPES_DEF, IDX_START, TRIM_START_S, TRIM_END_S);

% =========================================================================
%% Figura reutilizada (clf en cada medición = limpieza total)
% =========================================================================
fig = figure('Name', sprintf('Marcar Secuencia — %s', fname), ...
    'NumberTitle','off', 'Position',[50 80 1280 560]);
axT = axes('Parent',fig,'Box','on');
title(axT,'Esperando...'); xlabel(axT,'t (s)'); ylabel(axT,'V');
drawnow;

% =========================================================================
%% Batch
% =========================================================================
n_guardados = 0;  n_saltados = 0;  quit_loop = false;

for idx = IDX_START:Ntotal
    if quit_loop, break; end

    d_cur = load(fpath);
    m = d_cur.muestras(idx);

    pnt2=''; if isfield(m,'punta'),  pnt2=m.punta;  end
    obs2=''; if isfield(m,'observ'), obs2=m.observ; end
    if isfield(m,'raw_V'),      dur=numel(m.raw_V)  /double(m.fs);
    elseif isfield(m,'raw_mV'), dur=numel(m.raw_mV) /double(m.fs);
    else, dur=0; end

    ya = isfield(m,'secuencia_inicio_s') && ~isnan(m.secuencia_inicio_s);
    if ya
        t0p=m.secuencia_inicio_s; Tp=NaN;
        if isfield(m,'periodo_estimado_s'), Tp=m.periodo_estimado_s; end
        stk = ternario(~isnan(Tp), sprintf('ini=%.3fs T=%.3fs',t0p,Tp), ...
            sprintf('ini=%.3fs',t0p));
        fprintf('\n[%d/%d] %s | %s  —  YA MARCADA (%s)\n', idx,Ntotal,pnt2,obs2,stk);
        rr = strtrim(input('  [S=saltar  r=remarcar  d=descartar  q=salir]: ','s'));
        if isempty(rr)||strcmpi(rr,'s'), n_saltados=n_saltados+1; continue; end
        if strcmpi(rr,'d'), fprintf('  Descartado.\n'); continue; end
        if strcmpi(rr,'q'), quit_loop=true; break; end
    else
        fprintf('\n[%d/%d] %s | %s | dur=%.1fs\n', idx,Ntotal,pnt2,obs2,dur);
    end

    % Cargar señal
    fs = double(m.fs);
    if isfield(m,'raw_V'),      raw=double(m.raw_V(:));
    elseif isfield(m,'raw_mV'), raw=double(m.raw_mV(:))/1000;
    else, fprintf('  Sin raw_V.\n'); continue; end
    fil=[];
    if isfield(m,'filtered')&&~isempty(m.filtered), fil=double(m.filtered(:)); end
    if OPC_SIG==2&&~isempty(fil), sig=fil; lbl='filtrada'; else, sig=raw; lbl='raw'; end
    Ns=numel(sig); t=(0:Ns-1).'/fs;

    % Límites de trim (excluir pisadas de inicio/fin)
    i_trim_s = max(1,   round(TRIM_START_S * fs) + 1);
    i_trim_e = min(Ns,  Ns - round(TRIM_END_S * fs));
    if i_trim_s >= i_trim_e
        i_trim_s = 1; i_trim_e = Ns;
        fprintf('  AVISO: trim supera la duración — desactivado\n');
    end

    [~,~,env_sm,env_th] = detectarGolpes(sig,fs,SMOOTH_S,THRESH_SIGMA,...
        PRE_DET_S,POST_DET_S,MIN_QUIET_S);

    redo     = true;
    N_target = N_GOLPES_DEF;

    while redo && ~quit_loop
        redo = false;

        min_gap_s  = (i_trim_e - i_trim_s)/fs / max(N_target*2.5, 1);
        [onsets_cur, cands_all] = encontrarTopN(env_sm, N_target, fs, min_gap_s, ...
            i_trim_s, i_trim_e);

        if ~isvalid(fig)
            fig = figure('Name',sprintf('Marcar Secuencia — %s',fname),...
                'NumberTitle','off','Position',[50 80 1280 560]);
        end
        titulo = sprintf('[%d/%d] #%d  %s  |  %s  |  %s  trim=[%.1f,%.1f]s', ...
            idx,Ntotal,idx,pnt2,obs2,lbl, TRIM_START_S, TRIM_END_S);

        % --- GRAFICAR PRIMERO ---
        axT = replotNumeros(fig, t, sig, env_sm, env_th, onsets_cur, fs, ...
            PRE_PAD_S, POST_PAD_S, i_trim_s, i_trim_e, titulo);
        drawnow;

        % --- PREGUNTAR N (acepta 'd' para descartar) ---
        T_med = calcT(onsets_cur, fs);
        fprintf('  Auto: %d golpes', numel(onsets_cur));
        if ~isnan(T_med), fprintf('  T≈%.3fs (%.2fHz)', T_med, 1/T_med); end
        fprintf('\n');

        N_raw_s = strtrim(input(sprintf('  ¿Cuántos golpes? [%d, d=descartar]: ', N_target),'s'));
        if strcmpi(N_raw_s,'d')
            fprintf('  Descartado.\n'); break; end
        if ~isempty(N_raw_s)
            N_num = round(str2double(N_raw_s));
            if ~isnan(N_num) && N_num > 0 && N_num ~= N_target
                N_target   = N_num;
                min_gap_s  = (i_trim_e - i_trim_s)/fs / max(N_target*2.5, 1);
                [onsets_cur, cands_all] = encontrarTopN(env_sm, N_target, fs, min_gap_s, ...
                    i_trim_s, i_trim_e);
                axT = replotNumeros(fig, t, sig, env_sm, env_th, onsets_cur, fs, ...
                    PRE_PAD_S, POST_PAD_S, i_trim_s, i_trim_e, titulo);
                drawnow;
                fprintf('  Actualizado: %d golpes', numel(onsets_cur));
                T2=calcT(onsets_cur,fs);
                if ~isnan(T2), fprintf('  T≈%.3fs', T2); end
                fprintf('\n');
            end
        end

        % --- Edición por comandos ---
        fprintf('  Editar: r N | m N t | a t | d | g | q\n');
        fprintf('          th V=threshold (sigma) | sm V=suavizado (s) | re=re-detectar\n');
        discard_flag     = false;
        quit_inner       = false;
        thresh_sigma_cur = THRESH_SIGMA;
        smooth_s_cur     = SMOOTH_S;
        removed_smp      = [];   % samples descartados — no volver a sugerir
        while true
            fprintf('  [%d hits  thr=%.1f sm=%.3fs] > ', numel(onsets_cur), thresh_sigma_cur, smooth_s_cur);
            cmd = strtrim(input('','s'));
            if isempty(cmd), continue; end
            parts = strsplit(cmd);
            act   = lower(parts{1});

            if strcmp(act,'g'), break; end
            if strcmp(act,'d'), discard_flag=true; break; end
            if strcmp(act,'q'), quit_inner=true; break; end

            % Ajuste de parámetros de detección + re-detección
            if strcmp(act,'th') && numel(parts)>=2
                v = str2double(parts{2});
                if ~isnan(v)&&v>0
                    thresh_sigma_cur = v;
                    [~,~,env_sm,env_th] = detectarGolpes(sig,fs,smooth_s_cur, ...
                        thresh_sigma_cur,PRE_DET_S,POST_DET_S,MIN_QUIET_S);
                    [onsets_cur,cands_all] = encontrarTopN(env_sm,N_target,fs,min_gap_s,i_trim_s,i_trim_e);
                    fprintf('  threshold=%.1f → %d hits\n', thresh_sigma_cur, numel(onsets_cur));
                    axT = replotNumeros(fig,t,sig,env_sm,env_th,onsets_cur,fs,...
                        PRE_PAD_S,POST_PAD_S,i_trim_s,i_trim_e,titulo);
                    drawnow;
                end; continue
            end
            if strcmp(act,'sm') && numel(parts)>=2
                v = str2double(parts{2});
                if ~isnan(v)&&v>0
                    smooth_s_cur = v;
                    [~,~,env_sm,env_th] = detectarGolpes(sig,fs,smooth_s_cur, ...
                        thresh_sigma_cur,PRE_DET_S,POST_DET_S,MIN_QUIET_S);
                    [onsets_cur,cands_all] = encontrarTopN(env_sm,N_target,fs,min_gap_s,i_trim_s,i_trim_e);
                    fprintf('  suavizado=%.3fs → %d hits\n', smooth_s_cur, numel(onsets_cur));
                    axT = replotNumeros(fig,t,sig,env_sm,env_th,onsets_cur,fs,...
                        PRE_PAD_S,POST_PAD_S,i_trim_s,i_trim_e,titulo);
                    drawnow;
                end; continue
            end
            if strcmp(act,'re')
                removed_smp = [];   % nueva detección = pizarra limpia
                [~,~,env_sm,env_th] = detectarGolpes(sig,fs,smooth_s_cur, ...
                    thresh_sigma_cur,PRE_DET_S,POST_DET_S,MIN_QUIET_S);
                [onsets_cur,cands_all] = encontrarTopN(env_sm,N_target,fs,min_gap_s,i_trim_s,i_trim_e);
                fprintf('  Re-detectado: %d hits  (historial de removidos reseteado)\n', numel(onsets_cur));
                axT = replotNumeros(fig,t,sig,env_sm,env_th,onsets_cur,fs,...
                    PRE_PAD_S,POST_PAD_S,i_trim_s,i_trim_e,titulo);
                drawnow; continue
            end

            if strcmp(act,'r') && numel(parts)>=2
                % Remoción con sugerencia de pico alternativo
                n = round(str2double(parts{2}));
                if n>=1 && n<=numel(onsets_cur)
                    t_rem    = t(onsets_cur(n));
                    smp_rem  = onsets_cur(n);
                    removed_smp(end+1) = smp_rem;   % recordar para no sugerir de nuevo
                    onsets_cur(n) = [];
                    fprintf('  Eliminado #%d (t=%.3fs) — quedan %d hits\n', n, t_rem, numel(onsets_cur));
                    % Sugerir el pico libre más cercano (excluye todos los ya removidos)
                    t_sugg = sugerirPico(cands_all, onsets_cur, removed_smp, t_rem, t);
                    if ~isnan(t_sugg)
                        fprintf('  Sugerencia: t=%.3fs  ¿Agregar? [s/N]: ', t_sugg);
                        rs = strtrim(input('','s'));
                        if strcmpi(rs,'s')
                            smp = min(max(round(t_sugg*fs)+1,1),Ns);
                            onsets_cur(end+1)=smp; onsets_cur=sort(onsets_cur);
                            fprintf('  Agregado %.3fs\n', t_sugg);
                        else
                            % Rechazada → también la excluimos de futuras sugerencias
                            removed_smp(end+1) = min(max(round(t_sugg*fs)+1,1),Ns);
                        end
                    else
                        fprintf('  Sin sugerencia disponible\n');
                    end
                else
                    fprintf('  N fuera de rango [1–%d]\n', numel(onsets_cur));
                end
            else
                [onsets_cur, msg] = aplicarComando(act, parts, onsets_cur, t, fs, Ns);
                if ~isempty(msg), fprintf('  %s\n',msg); end
            end

            axT = replotNumeros(fig, t, sig, env_sm, env_th, onsets_cur, fs, ...
                PRE_PAD_S, POST_PAD_S, i_trim_s, i_trim_e, titulo);
            drawnow;
        end

        if discard_flag, fprintf('  Descartado.\n'); break; end
        if quit_inner,   quit_loop=true; break; end
        if isempty(onsets_cur), fprintf('  Sin hits — descartando.\n'); break; end

        % --- Elegir onset inicio ---
        T_est = calcT(onsets_cur, fs);
        fprintf('  Onsets (%d):', numel(onsets_cur));
        for k = 1:numel(onsets_cur)
            if mod(k-1,5)==0, fprintf('\n   '); end
            fprintf('  #%d=%.3fs', k, t(onsets_cur(k)));
        end
        fprintf('\n');
        if ~isnan(T_est), fprintf('  T=%.4fs (%.2fHz)\n', T_est, 1/T_est); end

        ini_str = strtrim(input(sprintf('  Inicio (#N o t en s) [1=%.3fs]: ',...
            t(onsets_cur(1))),'s'));
        if strcmpi(ini_str,'d'), fprintf('  Descartado.\n'); break; end
        t_inicio = parsearInicio(ini_str, onsets_cur, t, fs, Ns);
        if isnan(t_inicio), fprintf('  Inválido.\n'); redo=true; continue; end

        % Redibujar con INICIO + Gk
        axT = replotNumeros(fig, t, sig, env_sm, env_th, onsets_cur, fs, ...
            PRE_PAD_S, POST_PAD_S, i_trim_s, i_trim_e, titulo);
        hold(axT,'on');
        xline(axT, t_inicio, '--k', 'LineWidth',2.5, ...
            'Label','INICIO','FontSize',9,'LabelVerticalAlignment','bottom',...
            'HandleVisibility','off');
        if ~isnan(T_est)
            for k = 0:numel(onsets_cur)-1
                tg = t_inicio + k*T_est;
                if tg >= 0 && tg <= t(end)+T_est
                    xline(axT, tg, '-', 'Color',[0.88 0.18 0.06], 'LineWidth',1.8,...
                        'Label',sprintf('G%d',k+1),'FontSize',7,...
                        'LabelVerticalAlignment','top','HandleVisibility','off');
                end
            end
        end
        hold(axT,'off');
        drawnow;

        % Resultado
        fprintf('  ┌─ Resultado ────────────────────────────────\n');
        fprintf('  │  Inicio : %.4f s\n', t_inicio);
        if ~isnan(T_est)
            t_ult = t_inicio + (numel(onsets_cur)-1)*T_est;
            fprintf('  │  Período: %.4f s  (%.2f Hz)\n', T_est, 1/T_est);
            fprintf('  │  N hits : %d\n', numel(onsets_cur));
            fprintf('  │  Último : %.3f s  (señal: %.1f s)\n', t_ult, t(end));
            if t_ult > t(end)+0.5
                fprintf('  │  AVISO  : último supera la duración\n'); end
        else
            fprintf('  │  Período: no estimado\n');
        end
        fprintf('  └────────────────────────────────────────────\n');

        resp2 = strtrim(input('  [S=guardar  n=descartar  r=remarcar  q=salir]: ','s'));

        if isempty(resp2)||strcmpi(resp2,'s')
            d_sv = load(fpath);
            d_sv.muestras(idx).secuencia_inicio_s = t_inicio;
            d_sv.muestras(idx).periodo_estimado_s = T_est;
            save(fpath,'-struct','d_sv');
            fprintf('  ✓ Guardado #%d (ini=%.4fs T=%.4fs)\n',idx,t_inicio,T_est);
            n_guardados = n_guardados+1;
        elseif strcmpi(resp2,'r')
            redo = true;
        elseif strcmpi(resp2,'q')
            quit_loop = true;
        else
            fprintf('  Descartado.\n');
        end
    end
end

d_fin = load(fpath);
n_con = sum(arrayfun(@(mx) isfield(mx,'secuencia_inicio_s')&&~isnan(mx.secuencia_inicio_s),...
    d_fin.muestras));
fprintf('\n=== RESUMEN ===  Guardados:%d  Saltados:%d  Con secuencia:%d/%d\n',...
    n_guardados, n_saltados, n_con, Ntotal);

% =========================================================================
%% Funciones locales
% =========================================================================

function imprimirTabla(muestras, N)
    fprintf('\n%-4s  %-8s  %-22s  %7s  %9s  %9s  %s\n',...
        '#','Punta','Timestamp','Dur(s)','SeqIni','T(s)','Observ');
    fprintf('%s\n', repmat('-',1,84));
    for i = 1:N
        m=muestras(i);
        pnt=''; if isfield(m,'punta'),    pnt=m.punta;    end
        ts =''; if isfield(m,'timestamp'),ts =m.timestamp; end
        obs=''; if isfield(m,'observ'),   obs=m.observ;   end
        if isfield(m,'raw_V'),      dur=numel(m.raw_V)  /double(m.fs);
        elseif isfield(m,'raw_mV'), dur=numel(m.raw_mV) /double(m.fs);
        else, dur=0; end
        ini='—'; Ts='—';
        if isfield(m,'secuencia_inicio_s')&&~isnan(m.secuencia_inicio_s)
            ini=sprintf('%.2f',m.secuencia_inicio_s); end
        if isfield(m,'periodo_estimado_s')&&~isnan(m.periodo_estimado_s)
            Ts=sprintf('%.3f',m.periodo_estimado_s); end
        fprintf('%-4d  %-8s  %-22s  %7.1f  %9s  %9s  %s\n',i,pnt,ts,dur,ini,Ts,obs);
    end
end

function axT = replotNumeros(fig, t, sig, env_sm, env_th, onsets, fs, ...
        pre_s, post_s, i_trim_s, i_trim_e, ttl)
    clf(fig);
    axT = axes('Parent',fig,'Box','on');
    hold(axT,'on');

    Ns = numel(sig); dc = mean(sig);

    % Zona de trim (pisadas) — sombreado gris claro en los márgenes
    yl_est = [min(sig)-0.05*(max(sig)-min(sig)), max(sig)+0.05*(max(sig)-min(sig))];
    if i_trim_s > 1
        fill(axT, [t(1) t(i_trim_s) t(i_trim_s) t(1)], ...
            [yl_est(1) yl_est(1) yl_est(2) yl_est(2)], ...
            [0.7 0.7 0.7],'FaceAlpha',0.30,'EdgeColor','none','HandleVisibility','off');
    end
    if i_trim_e < Ns
        fill(axT, [t(i_trim_e) t(end) t(end) t(i_trim_e)], ...
            [yl_est(1) yl_est(1) yl_est(2) yl_est(2)], ...
            [0.7 0.7 0.7],'FaceAlpha',0.30,'EdgeColor','none','HandleVisibility','off');
    end

    % Señal y envolvente
    plot(axT, t, sig, 'Color',[0.25 0.55 0.80], 'LineWidth',0.7, 'DisplayName','señal');
    col_e = [0.95 0.50 0.05];
    plot(axT, t, dc+env_sm, 'Color',[col_e 0.55], 'LineWidth',0.8, 'DisplayName','env');
    plot(axT, t, dc-env_sm, 'Color',[col_e 0.55], 'LineWidth',0.8, 'HandleVisibility','off');
    yline(axT, dc+env_th,'--','Color',col_e,'LineWidth',0.8,'HandleVisibility','off');
    yline(axT, dc-env_th,'--','Color',col_e,'LineWidth',0.8,'HandleVisibility','off');

    % ylim real después de graficar señal
    yl    = ylim(axT);
    y_span = yl(2)-yl(1);
    T_med  = calcT(onsets, fs);
    col_gm   = [0.05 0.55 0.15];
    col_fill = [0.20 0.80 0.30];

    for k = 1:numel(onsets)
        ons_k = min(max(onsets(k),1),Ns);
        if k < numel(onsets)
            gap_smp  = onsets(k+1)-ons_k;
            post_smp = min(round(post_s*fs), round(gap_smp*0.88));
        else
            post_smp = round(post_s*fs);
        end
        i_s = max(1, ons_k-round(pre_s*fs));
        i_e = min(Ns, ons_k+post_smp);

        fill(axT,[t(i_s) t(i_e) t(i_e) t(i_s)], ...
            [yl(1) yl(1) yl(2) yl(2)], ...
            col_fill,'FaceAlpha',0.14,'EdgeColor','none','HandleVisibility','off');
        xline(axT, t(ons_k),'--','Color',col_gm,'LineWidth',1.2,'HandleVisibility','off');
        y_txt = min(yl(2)-0.02*y_span, sig(ons_k)+0.08*y_span);
        text(axT, t(ons_k), y_txt, sprintf(' #%d',k), ...
            'Color',col_gm,'FontSize',8,'FontWeight','bold',...
            'HorizontalAlignment','left','VerticalAlignment','bottom','Clipping','on');
    end
    if ~isempty(onsets)
        ov = min(max(onsets,1),Ns);
        plot(axT,t(ov),sig(ov),'o','Color',col_gm,'MarkerFaceColor',col_gm,...
            'MarkerSize',6,'LineStyle','none','DisplayName',sprintf('%d hits',numel(onsets)));
    end

    hold(axT,'off');
    xlabel(axT,'Tiempo (s)'); ylabel(axT,'V');
    T_str = ternario(~isnan(T_med), sprintf('  T≈%.3fs (%.2fHz)',T_med,1/T_med),'');
    title(axT,[ttl T_str],'Interpreter','none','FontSize',8);
    legend(axT,'show','Location','northeast','FontSize',8);
    grid(axT,'on'); xlim(axT,[0 t(end)]);
end

function [onsets_out, cands_all] = encontrarTopN(env_sm, N, fs, min_gap_s, i_start, i_end)
    if nargin<5||isempty(i_start), i_start=1; end
    if nargin<6||isempty(i_end),   i_end=numel(env_sm); end
    i_start = max(1,i_start); i_end = min(numel(env_sm),i_end);

    env_trim = env_sm(i_start:i_end);
    min_gap_smp = max(3, round(min_gap_s*fs));
    [pks, locs_trim] = findpeaks(double(env_trim(:)'), 'MinPeakDistance', min_gap_smp);

    if isempty(pks), onsets_out=[]; cands_all=[]; return; end

    locs = locs_trim + i_start - 1;   % desplazar al índice global
    [~, si] = sort(pks,'descend');
    cands_all = locs(si);              % todos los candidatos, por amplitud

    if numel(pks) > N
        locs = locs(sort(si(1:N)));    % top-N, ordenados por tiempo
    end
    onsets_out = sort(locs(:));
end

function t_sugg = sugerirPico(cands_all, onsets_cur, removed_smp, t_removed, t)
    % Candidato libre más cercano en tiempo, excluyendo los ya removidos/rechazados
    t_sugg = NaN;
    if isempty(cands_all), return; end
    Nt = numel(t);
    excluir = [onsets_cur(:); removed_smp(:)];
    free    = cands_all(~ismember(cands_all, excluir));
    if isempty(free), return; end
    t_free = t(min(free, Nt));
    [~, imin] = min(abs(t_free - t_removed));
    t_sugg = t_free(imin);
end

function T = calcT(onsets, fs)
    T = NaN;
    if numel(onsets)>=2, T=median(diff(double(onsets)))/fs; end
end

function [onsets_out, msg] = aplicarComando(act, parts, onsets, t, fs, Ns)
    onsets_out=onsets; msg='';
    try
        switch act
            case 'm'
                n=round(str2double(parts{2})); tv=str2double(parts{3});
                if n<1||n>numel(onsets), msg='N inválido'; return; end
                if isnan(tv), msg='Tiempo inválido'; return; end
                smp=min(max(round(tv*fs)+1,1),Ns);
                onsets_out(n)=smp; onsets_out=sort(onsets_out);
                msg=sprintf('Hit #%d → %.4fs', n, tv);
            case 'a'
                tv=str2double(parts{2});
                if isnan(tv), msg='Tiempo inválido'; return; end
                smp=min(max(round(tv*fs)+1,1),Ns);
                onsets_out(end+1)=smp; onsets_out=sort(onsets_out);
                msg=sprintf('Agregado en %.4fs — total %d', tv, numel(onsets_out));
            otherwise
                msg=sprintf('Cmd "%s" desconocido (r/m/a/d/g/q)', act);
        end
    catch e
        msg=sprintf('Error: %s', e.message);
    end
end

function t_inicio = parsearInicio(raw_str, onsets, t, fs, Ns)
    t_inicio=NaN;
    if isempty(raw_str)
        if ~isempty(onsets), t_inicio=t(onsets(1)); end; return; end
    v=str2double(raw_str);
    if isnan(v), return; end
    if v==floor(v)&&v>=1&&v<=numel(onsets)
        t_inicio=t(onsets(round(v)));
    elseif v>=0&&round(v*fs)+1<=Ns
        t_inicio=v;
    end
end

function [mask_hit, mask_quiet, env_smooth, thresh] = detectarGolpes(sig, fs, sm_s, thr_sg, pre_s, post_s, mq_s)
    Ns=numel(sig);
    sm=max(1,round(sm_s*fs)); pr=round(pre_s*fs); ps=round(post_s*fs); mq=round(mq_s*fs);
    env_smooth=movmean(abs(hilbert(sig-mean(sig))),sm);
    thresh=mean(env_smooth)+thr_sg*std(env_smooth);
    rm=env_smooth>=thresh;
    mask_hit=false(Ns,1);
    don=diff([0;rm]); dof=diff([rm;0]);
    on_v=find(don==1); of_v=find(dof==-1);
    for k=1:min(numel(on_v),numel(of_v))
        mask_hit(max(1,on_v(k)-pr):min(Ns,of_v(k)+ps))=true;
    end
    mask_quiet=false(Ns,1);
    dq=diff([0;~mask_hit;0]);
    qs=find(dq==1); qe=find(dq==-1)-1;
    for k=1:numel(qs)
        if qe(k)-qs(k)+1>=mq, mask_quiet(qs(k):qe(k))=true; end
    end
end

function out = ternario(cond, a, b)
    if cond, out=a; else, out=b; end
end
