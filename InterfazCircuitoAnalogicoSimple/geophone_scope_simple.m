function geophone_scope_simple()
% geophone_scope_simple — Interfaz PSoC5, sistema de entidades y muestras
%
% Protocolo RX (5 bytes, UART):
%   Data:      [0x56][0x00][b2][b1][b0]   int24 big-endian signed
%   Heartbeat: [0x56][0x01][0x00][0x00][0x00]
%   ADC: 18-bit, +-6.144V, buf gain=2, Left Bit-23
%   scale = 1000/(21333*2*64) mV/count
%
% Filtro FIR: cualquier cmd MATLAB que retorne b, ej: fir1(40, 0.1)
%
% Entidades: scope_config.mat  |  Muestras: datos\<entidad>.mat
% Logs: logs\                  |  Mat viejos: viejos\

    scriptDir = fileparts(mfilename('fullpath'));
    cfgFile   = fullfile(scriptDir, 'scope_config.mat');
    datosDir  = fullfile(scriptDir, 'datos');
    logsDir   = fullfile(scriptDir, 'logs');
    viejosDir = fullfile(scriptDir, 'viejos');

    % =====================================================================
    % Colores de estado
    % =====================================================================
    CLR_ON    = [0.55 0.90 0.55];   % verde — activo
    CLR_OFF   = [0.94 0.94 0.94];   % gris  — inactivo
    CLR_MAN   = [0.90 0.20 0.20];   % rojo  — modo manual (zoom fijo)
    CLR_START = [0.20 0.75 0.25];
    CLR_STOP  = [0.90 0.20 0.20];
    CLR_CONN  = [0.20 0.45 0.85];
    CLR_DEL   = [0.85 0.15 0.15];

    PUNTAS = {'gris','roja','marron','negra'};

    % =====================================================================
    % Estado global
    % =====================================================================
    S              = struct();
    S.sp           = [];
    S.isConnected  = false;
    S.logFid       = -1;
    S.tickCount    = 0;
    S.totalBytes   = 0;
    S.streamTimer  = [];
    S.rxBuf        = uint8([]);
    S.streamEnabled= false;
    S.parseState   = 0;
    S.pktBuf       = zeros(5,1,'uint8');
    S.pktIdx       = 0;

    S.maxPoints   = 9000;
    S.nVec        = zeros(0,1);
    S.notchVec    = zeros(0,1);
    S.filtVec     = zeros(0,1);
    S.frameCount  = 0;

    S.fs    = 1020;
    S.scale = 1000.0 / (21333.0 * 2.0 * 64.0);
    S.tWin  = 5000;

    S.yAuto  = true;   S.yMin = -100;  S.yMax = 100;
    S.tAuto  = true;   S.tMin = 0;     S.tMax = 5000;
    S.showRaw = true;  % visibilidad de la línea cruda

    S.filtCmd  = '';
    S.filtB    = [];
    S.dcRemove = false;
    S.yRange   = 100;

    S.entidades   = struct('nombre',{},'fs',{},'observ',{},'fMin',{},'fMax',{},'ganancia',{});
    S.entActiva   = 0;
    S.treeMap     = {};
    S.entCollapsed = logical([]);   % true = muestras ocultas para esa entidad

    defCom  = 'COM7';
    defBaud = 115200;

    reorganizarArchivos();

    % =====================================================================
    % Cargar config
    % =====================================================================
    if isfile(cfgFile)
        try
            cfg = load(cfgFile);
            flds = {'fs','maxPoints','tWin','filtCmd','filtB','yRange',...
                    'yMin','yMax','yAuto','tMin','tMax','tAuto','dcRemove','showRaw'};
            for k = 1:numel(flds)
                if isfield(cfg,flds{k}), S.(flds{k}) = cfg.(flds{k}); end
            end
            if isfield(cfg,'com'),       defCom      = cfg.com;       end
            if isfield(cfg,'baud'),      defBaud     = cfg.baud;      end
            if isfield(cfg,'entidades'),   S.entidades   = cfg.entidades;   end
            if isfield(cfg,'entCollapsed'),S.entCollapsed= cfg.entCollapsed; end
            for ei = 1:numel(S.entidades)
                if ~isfield(S.entidades(ei),'fMin')
                    bw = 0;
                    if isfield(S.entidades(ei),'bwTeorico'), bw=S.entidades(ei).bwTeorico; end
                    S.entidades(ei).fMin = 0; S.entidades(ei).fMax = bw;
                end
                if ~isfield(S.entidades(ei),'fMax'),    S.entidades(ei).fMax    = 0; end
                if ~isfield(S.entidades(ei),'ganancia'),S.entidades(ei).ganancia= 1; end
            end
        catch, end
    end

    % =====================================================================
    % UI — figura 1100 x 960
    % Layout columna derecha (RX=860, RW=225):
    %   pConn    y=850 h=100
    %   pCtrl    y=758 h=90      ← +botón Ver crudo
    %   pFilt    y=646 h=110
    %   pEntidad y=285 h=359
    %   pGuardar y=185 h=98
    %   pData    y=108 h=75
    %   pZoom    y=35  h=71
    % =====================================================================
    fig = uifigure('Name','Geophone Scope','Position',[60 40 1100 1080]);
    fig.CloseRequestFcn = @onClose;

    ax1 = uiaxes(fig,'Position',[20 55 820 1000]);
    ax1.XGrid='on'; ax1.YGrid='on';
    ax1.XMinorGrid='on'; ax1.YMinorGrid='on';
    title(ax1,'Señal en tiempo'); ylabel(ax1,'mV'); xlabel(ax1,'tiempo (ms)');
    hold(ax1,'on');
    hRaw   = plot(ax1, nan, nan, 'Color',[0.6 0.6 0.6],'LineStyle','--','LineWidth',0.6);
    hNotch = plot(ax1, nan, nan, 'Color',[0 1 0.5],'LineWidth',1.2);

    RX=860; RW=225;

    % --- Conexion --- h=116: deja 26px bajo el título antes del primer elemento
    pConn = uipanel(fig,'Title','Conexion','Position',[RX 883 RW 116]);
    uilabel(pConn,'Text','COM:','Position',[8 70 32 20]);
    edtCom  = uieditfield(pConn,'text','Value',defCom,'Position',[44 68 58 22]);
    uilabel(pConn,'Text','Baud:','Position',[110 70 36 20]);
    edtBaud = uieditfield(pConn,'numeric','Value',defBaud,...
        'Limits',[1200 2000000],'Position',[150 68 60 22]);
    btnConn = uibutton(pConn,'Text','Conectar','Position',[8 36 100 28],...
        'BackgroundColor',CLR_CONN,'FontColor',[1 1 1],'FontWeight','bold',...
        'ButtonPushedFcn',@onConnectToggle);
    lblStat = uilabel(pConn,'Text','DESCONECTADO','Position',[114 40 104 20]);

    % --- Stream + Ver crudo --- h=106
    pCtrl = uipanel(fig,'Title','Stream','Position',[RX 775 RW 106]);
    btnStream = uibutton(pCtrl,'Text','START','Position',[8 52 90 28],...
        'BackgroundColor',CLR_START,'FontColor',[1 1 1],'FontWeight','bold',...
        'ButtonPushedFcn',@onStreamToggle);
    btnClear = uibutton(pCtrl,'Text','Clear','Position',[106 52 90 28],...
        'ButtonPushedFcn',@onClear);
    btnShowRaw = uibutton(pCtrl,'Text','Ver crudo','Position',[8 18 88 26],...
        'ButtonPushedFcn',@(~,~)onToggleRaw());
    uilabel(pCtrl,'Text','(línea gris --)', ...
        'Position',[100 20 116 20],'FontSize',8,'FontAngle','italic');

    % --- Filtro FIR + DC --- h=124
    pFilt = uipanel(fig,'Title','Filtro FIR MATLAB','Position',[RX 649 RW 124]);
    uilabel(pFilt,'Text','Cmd (retorna b):','Position',[8 80 140 18]);
    edtFiltCmd = uieditfield(pFilt,'text','Value',S.filtCmd,'Position',[8 56 148 24]);
    uibutton(pFilt,'Text','Aplicar','Position',[160 56 52 24],...
        'ButtonPushedFcn',@(~,~)onApplyFilter());
    uibutton(pFilt,'Text','Quitar FIR','Position',[160 28 52 22],...
        'ButtonPushedFcn',@(~,~)onQuitFilter());
    lblFiltSt = uilabel(pFilt,'Text',filtStatusStr(),...
        'Position',[8 28 148 22],'FontAngle','italic');
    btnDC = uibutton(pFilt,'Text','Quitar DC','Position',[8 4 90 22],...
        'ButtonPushedFcn',@(~,~)onToggleDC());
    lblDCSt = uilabel(pFilt,'Text',dcStatusStr(),...
        'Position',[104 6 108 18],'FontAngle','italic','FontSize',10);

    % =========================================================================
    % Panel ÁRBOL de entidades
    % =========================================================================
    pEntidad = uipanel(fig,'Title','Circuitos Analógicos','Position',[RX 337 RW 310]);

    lbTree = uilistbox(pEntidad,...
        'Items',    {'(sin entidades)'},...
        'Position', [4 58 RW-8 226],...
        'FontName', 'Courier New',...
        'FontSize', 9,...
        'Multiselect','off',...
        'ValueChangedFcn', @onTreeSelChanged);

    btnNuevaEnt = uibutton(pEntidad,'Text','+ Nueva',...
        'Position',[4 32 58 22],...
        'BackgroundColor',CLR_ON,'FontWeight','bold',...
        'ButtonPushedFcn',@onNuevaEntidad);
    btnEditEnt = uibutton(pEntidad,'Text','Editar',...
        'Position',[66 32 46 22],...
        'ButtonPushedFcn',@onEditarEntidad);
    btnCollapsar = uibutton(pEntidad,'Text','▼/▶',...
        'Position',[116 32 38 22],'FontSize',9,...
        'Tooltip','Colapsar/expandir muestras de la entidad seleccionada',...
        'ButtonPushedFcn',@onToggleCollapse);
    btnBorrar = uibutton(pEntidad,'Text','Borrar',...
        'Position',[158 32 58 22],...
        'BackgroundColor',CLR_DEL,'FontColor',[1 1 1],'FontWeight','bold',...
        'ButtonPushedFcn',@onBorrarSeleccion);

    lblEntActiva = uilabel(pEntidad,'Text','Activa: —',...
        'Position',[4 4 RW-8 26],'FontSize',8,'WordWrap','on');

    % --- Guardar muestra --- h=112
    pGuardar = uipanel(fig,'Title','Guardar muestra','Position',[RX 223 RW 112]);
    uilabel(pGuardar,'Text','Punta:','Position',[8 66 42 20]);
    ddPunta = uidropdown(pGuardar,'Items',PUNTAS,'Position',[54 64 80 22]);
    uilabel(pGuardar,'Text','Obs:','Position',[8 40 30 20]);
    edtObsMuestra = uieditfield(pGuardar,'text','Value','','Position',[40 38 118 22]);
    btnGuardar = uibutton(pGuardar,'Text','Guardar','Position',[162 18 52 46],...
        'BackgroundColor',CLR_ON,'FontWeight','bold',...
        'ButtonPushedFcn',@onGuardarMuestra);
    lblNMuestras = uilabel(pGuardar,'Text','—',...
        'Position',[138 66 74 20],'FontSize',9);

    % --- Datos / Config --- h=94
    pData = uipanel(fig,'Title','Datos','Position',[RX 127 RW 94]);
    lblInfo = uilabel(pData,'Text','n=0  t=0 ms','Position',[8 50 210 18]);
    uilabel(pData,'Text','fs(SPS):','Position',[8 28 52 20]);
    edtFs = uieditfield(pData,'numeric','Value',S.fs,...
        'Limits',[1 100000],'RoundFractionalValues','on',...
        'Position',[63 26 52 22],'ValueChangedFcn',@(~,~)onFsChanged());
    uilabel(pData,'Text','Vent(ms):','Position',[122 28 60 20]);
    edtTWin = uieditfield(pData,'numeric','Value',S.tWin,...
        'Limits',[0 1e8],'RoundFractionalValues','on',...
        'Position',[184 26 28 22],'ValueChangedFcn',@(~,~)onTWinChanged());
    uilabel(pData,'Text','Max pts:','Position',[8 4 54 18]);
    edtMaxPts = uieditfield(pData,'numeric','Value',S.maxPoints,...
        'Limits',[100 1e6],'RoundFractionalValues','on',...
        'Position',[63 2 52 22],'ValueChangedFcn',@(~,~)onMaxPtsChanged());

    % --- Zoom --- h=90
    pZoom = uipanel(fig,'Title','Zoom','Position',[RX 35 RW 90]);
    uilabel(pZoom,'Text','t:','Position',[4 46 14 18],'FontSize',8);
    edtTMin = uieditfield(pZoom,'numeric','Value',S.tMin,'Position',[18 44 52 20]);
    uilabel(pZoom,'Text','—','Position',[72 46 10 18],'FontSize',8);
    edtTMax = uieditfield(pZoom,'numeric','Value',S.tMax,'Position',[84 44 52 20]);
    btnTZoom = uibutton(pZoom,'Text','','Position',[140 44 76 20],...
        'FontSize',8,'FontWeight','bold','ButtonPushedFcn',@(~,~)onToggleTZoom());
    uilabel(pZoom,'Text','y:','Position',[4 18 14 18],'FontSize',8);
    edtYMin = uieditfield(pZoom,'numeric','Value',S.yMin,'Position',[18 16 52 20]);
    uilabel(pZoom,'Text','—','Position',[72 18 10 18],'FontSize',8);
    edtYMax = uieditfield(pZoom,'numeric','Value',S.yMax,'Position',[84 16 52 20]);
    btnYZoom = uibutton(pZoom,'Text','','Position',[140 16 76 20],...
        'FontSize',8,'FontWeight','bold','ButtonPushedFcn',@(~,~)onToggleYZoom());

    % Log
    txtLog = uitextarea(fig,'Editable','off','Position',[20 5 820 46]);
    txtLog.Value = strings(0,1);

    % ---- Inicializar estados ----
    updateZoomBtns();
    updateDCBtn();
    updateShowRawBtn();
    updateBtnStates();
    refreshTree();
    if ~S.tAuto, try ax1.XLim=[S.tMin S.tMax]; catch, end; end
    if ~S.yAuto, try ax1.YLim=[S.yMin S.yMax]; catch, end; end
    if ~isempty(S.filtB), edtFiltCmd.Value=S.filtCmd; lblFiltSt.Text=filtStatusStr(); end

    % =====================================================================
    % Helpers
    % =====================================================================
    function s = filtStatusStr()
        if isempty(S.filtB), s='Sin filtro activo';
        else, s=sprintf('FIR N=%d activo',numel(S.filtB)-1); end
    end
    function s = dcStatusStr()
        if S.dcRemove, s='DC: ON'; else, s='DC: OFF'; end
    end
    function s = safeFilename(nombre)
        s = regexprep(nombre,'[^\w]','_');
    end

    function setBtn(btn, active)
        if active, btn.BackgroundColor=CLR_ON; btn.FontWeight='bold';
        else,      btn.BackgroundColor=CLR_OFF; btn.FontWeight='normal'; end
    end

    function updateZoomBtns()
        % t: verde=Auto, rojo=Fix
        if S.tAuto
            btnTZoom.Text='t: Auto ●';
            btnTZoom.BackgroundColor=CLR_ON; btnTZoom.FontColor=[0 0 0];
        else
            btnTZoom.Text='t: Fijo ●';
            btnTZoom.BackgroundColor=CLR_MAN; btnTZoom.FontColor=[1 1 1];
        end
        % y: verde=Auto, rojo=Fix
        if S.yAuto
            btnYZoom.Text='y: Auto ●';
            btnYZoom.BackgroundColor=CLR_ON; btnYZoom.FontColor=[0 0 0];
        else
            btnYZoom.Text='y: Fijo ●';
            btnYZoom.BackgroundColor=CLR_MAN; btnYZoom.FontColor=[1 1 1];
        end
    end

    function updateDCBtn()
        setBtn(btnDC, S.dcRemove); lblDCSt.Text=dcStatusStr();
    end

    function updateShowRawBtn()
        if S.showRaw
            btnShowRaw.Text='Crudo: ON';
            btnShowRaw.BackgroundColor=CLR_ON; btnShowRaw.FontColor=[0 0 0];
        else
            btnShowRaw.Text='Crudo: OFF';
            btnShowRaw.BackgroundColor=CLR_OFF; btnShowRaw.FontColor=[0 0 0];
        end
        hRaw.Visible = S.showRaw;
    end

    function updateBtnStates()
        c=S.isConnected; r=S.streamEnabled;
        edtCom.Enable=~c; edtBaud.Enable=~c;
        if c, btnConn.Text='Desconectar'; btnConn.BackgroundColor=CLR_STOP;
        else,  btnConn.Text='Conectar';   btnConn.BackgroundColor=CLR_CONN; end
        if r, btnStream.Text='STOP'; btnStream.BackgroundColor=CLR_STOP;
        else,  btnStream.Text='START'; btnStream.BackgroundColor=CLR_START; end
        btnStream.Enable = c;
        tieneEnt  = S.entActiva>=1 && S.entActiva<=numel(S.entidades);
        tieneDatos= ~isempty(S.nVec);
        btnGuardar.Enable = tieneEnt && tieneDatos;
    end

    function logMsg(msg)
        ts=string(datestr(now,'HH:MM:SS.FFF'));
        line="["+ts+"] "+string(msg);
        v=txtLog.Value; if ~isstring(v), v=string(v); end
        v(end+1,1)=line; if numel(v)>200, v=v(end-199:end); end
        txtLog.Value=v;
        if S.logFid>0, fprintf(S.logFid,'%s\n',char(line)); end
        drawnow limitrate;
    end
    function logTick(nAvail)
        if S.logFid<=0, return; end
        if nAvail>0||mod(S.tickCount,50)==0
            fprintf(S.logFid,'[%s] TICK #%d  avail=%d  bytes=%d  ON=%d  ps=%d  pi=%d\n',...
                datestr(now,'HH:MM:SS.FFF'),S.tickCount,nAvail,...
                S.totalBytes,S.streamEnabled,S.parseState,S.pktIdx);
        end
    end
    function logHex(raw)
        if S.logFid<=0, return; end
        n=min(numel(raw),40); h=sprintf('%02X ',raw(1:n));
        if numel(raw)>40, h=[h '...']; end
        fprintf(S.logFid,'  RAW[%d]: %s\n',numel(raw),h);
    end
    function logParsed(np)
        if S.logFid<=0||np==0, return; end
        fprintf(S.logFid,'  PARSED: %d\n',np);
    end
    function updateInfo()
        try, n=numel(S.nVec);
            lblInfo.Text=sprintf('n=%d  t=%.0f ms  fs=%d SPS',n,n/S.fs*1000,round(S.fs));
        catch, end
    end
    function applyFilter()
        if isempty(S.notchVec), S.filtVec=zeros(0,1); return; end
        raw_mV=S.notchVec*S.scale;
        if isempty(S.filtB), sig=raw_mV;
        else
            minLen=3*(numel(S.filtB)-1);
            if numel(raw_mV)<max(minLen,4), sig=raw_mV;
            else, try, sig=filtfilt(S.filtB,1,raw_mV); catch, sig=raw_mV; end
            end
        end
        if S.dcRemove&&~isempty(sig), sig=sig-mean(sig); end
        S.filtVec=sig;
    end
    function replot()
        if isempty(S.nVec)||isempty(S.filtVec), return; end
        tms=double(S.nVec)/S.fs*1000.0;
        raw_mV=S.notchVec*S.scale;
        set(hRaw,  'XData',tms,'YData',raw_mV);
        set(hNotch,'XData',tms,'YData',S.filtVec);
        if ~S.tAuto
            try ax1.XLim=[S.tMin S.tMax]; catch, end
        elseif S.tWin>0&&~isempty(tms)
            ax1.XLim=[max(0,tms(end)-S.tWin), tms(end)];
        else, ax1.XLimMode='auto'; end
        if ~S.yAuto
            try ax1.YLim=[S.yMin S.yMax]; catch, end
        else
            peak=max(abs(S.filtVec)); if peak<0.1, peak=0.1; end
            target=peak*1.25;
            if target>S.yRange, S.yRange=target;
            else, S.yRange=S.yRange*0.97+target*0.03; end
            S.yRange=max(S.yRange,1.0);
            try ax1.YLim=[-S.yRange,S.yRange]; catch, end
        end
    end
    function saveConfig()
        try
            cfg.fs=S.fs; cfg.com=char(edtCom.Value); cfg.baud=double(edtBaud.Value);
            cfg.maxPoints=S.maxPoints; cfg.tWin=S.tWin;
            cfg.filtCmd=S.filtCmd; cfg.filtB=S.filtB; cfg.yRange=S.yRange;
            cfg.yMin=S.yMin; cfg.yMax=S.yMax; cfg.yAuto=S.yAuto;
            cfg.tMin=S.tMin; cfg.tMax=S.tMax; cfg.tAuto=S.tAuto;
            cfg.dcRemove=S.dcRemove; cfg.showRaw=S.showRaw;
            cfg.entCollapsed=S.entCollapsed;
            cfg.entidades=S.entidades;
            save(cfgFile,'-struct','cfg');
        catch, end
    end

    % =====================================================================
    % Reorganizar archivos
    % =====================================================================
    function reorganizarArchivos()
        if ~isfolder(datosDir),  mkdir(datosDir);  end
        if ~isfolder(logsDir),   mkdir(logsDir);   end
        if ~isfolder(viejosDir), mkdir(viejosDir); end
        mats=dir(fullfile(scriptDir,'*.mat'));
        for ii=1:numel(mats)
            if strcmp(mats(ii).name,'scope_config.mat'), continue; end
            try, movefile(fullfile(scriptDir,mats(ii).name),fullfile(viejosDir,mats(ii).name)); catch, end
        end
        logs=dir(fullfile(scriptDir,'*.log'));
        for ii=1:numel(logs)
            try, movefile(fullfile(scriptDir,logs(ii).name),fullfile(logsDir,logs(ii).name)); catch, end
        end
    end

    % =====================================================================
    % ÁRBOL
    % =====================================================================
    function refreshTree()
        items   = {};
        treeMap = {};
        if isempty(S.entidades)
            items{1}   = '(sin entidades — presiona + Nueva)';
            treeMap{1} = struct('tipo','vacio','entIdx',0,'musIdx',0);
        else
            % Asegurar que entCollapsed tenga el tamaño correcto
            nEnt = numel(S.entidades);
            if numel(S.entCollapsed) < nEnt
                S.entCollapsed(end+1:nEnt) = false;
            end
            for ei=1:nEnt
                e        = S.entidades(ei);
                muestras = cargarMuestras(e.nombre);
                nm       = numel(muestras);
                star     = ' '; if ei==S.entActiva, star='*'; end
                if nm==1, sfx='muestra'; else, sfx='muestras'; end
                collapsed = numel(S.entCollapsed)>=ei && S.entCollapsed(ei);
                colIcon   = '▼'; if collapsed, colIcon='▶'; end
                items{end+1} = sprintf('%s%s %s  [%g-%g Hz|G=%g]  (%d %s)',...
                    star,colIcon,e.nombre,e.fMin,e.fMax,e.ganancia,nm,sfx); %#ok<AGROW>
                treeMap{end+1}=struct('tipo','ent','entIdx',ei,'musIdx',0); %#ok<AGROW>
                if ~collapsed
                    for mi=1:nm
                        m=muestras(mi); es_ult=(mi==nm);
                        pfx='  ├ '; if es_ult, pfx='  └ '; end
                        ts=''; if isfield(m,'timestamp'), ts=m.timestamp; end
                        pt=''; if isfield(m,'punta'),     pt=m.punta;     end
                        fc=''; if isfield(m,'filtCmd')&&~isempty(m.filtCmd), fc=['[' m.filtCmd ']']; end
                        ob=''; if isfield(m,'observ')&&~isempty(m.observ)
                            ob=m.observ; if numel(ob)>16, ob=[ob(1:16) '…']; end
                        end
                        items{end+1}=sprintf('%s#%d %-7s %s %s %s',...
                            pfx,mi,pt,ts,fc,ob); %#ok<AGROW>
                        treeMap{end+1}=struct('tipo','mus','entIdx',ei,'musIdx',mi); %#ok<AGROW>
                    end
                end
            end
        end
        S.treeMap=treeMap;
        lbTree.Items=items;
        % Restaurar selección al elemento lógicamente equivalente
        selTipo=''; selEnt=S.entActiva; selMus=0;
        if ~isempty(treeMap)
            for ri=1:numel(treeMap)
                tm=treeMap{ri};
                if strcmp(tm.tipo,'ent')&&tm.entIdx==selEnt
                    selTipo='ent'; selMus=0; break;
                end
            end
        end
        for ri=1:numel(treeMap)
            tm=treeMap{ri};
            if strcmp(tm.tipo,selTipo)&&tm.entIdx==selEnt&&tm.musIdx==selMus
                try, lbTree.Value=items{ri}; break; catch, end
            end
        end
        actualizarLblEntActiva();
        updateBtnStates();
    end

    function muestras = cargarMuestras(nombre)
        muestras=struct([]);
        fname=fullfile(datosDir,[safeFilename(nombre) '.mat']);
        if ~isfile(fname), return; end
        try, tmp=load(fname,'muestras');
            if isfield(tmp,'muestras'), muestras=tmp.muestras; end
        catch, end
    end

    function actualizarLblEntActiva()
        if S.entActiva>=1&&S.entActiva<=numel(S.entidades)
            e=S.entidades(S.entActiva);
            nm=numel(cargarMuestras(e.nombre));
            lblEntActiva.Text=sprintf('Activa: %s | fs=%g | %g-%g Hz | G=%g | %d med.',...
                e.nombre,e.fs,e.fMin,e.fMax,e.ganancia,nm);
            lblNMuestras.Text=sprintf('%d med.',nm);
        else
            lblEntActiva.Text='Activa: (ninguna)';
            lblNMuestras.Text='—';
        end
    end

    function onTreeSelChanged(~,~)
        val=lbTree.Value; items=lbTree.Items;
        idx=find(strcmp(items,val),1);
        if isempty(idx)||isempty(S.treeMap)||idx>numel(S.treeMap), return; end
        tm=S.treeMap{idx};
        if strcmp(tm.tipo,'vacio'), return; end

        oldActiva=S.entActiva;
        S.entActiva=tm.entIdx;
        if S.entActiva>=1&&S.entActiva<=numel(S.entidades)
            S.fs=S.entidades(S.entActiva).fs; edtFs.Value=S.fs;
        end

        if oldActiva~=S.entActiva
            % Reconstruir árbol para mover el * pero restaurar selección exacta
            refreshTree();
            % Restaurar selección al mismo elemento lógico (ent o mus)
            for ri=1:numel(S.treeMap)
                t2=S.treeMap{ri};
                if strcmp(t2.tipo,tm.tipo)&&t2.entIdx==tm.entIdx&&t2.musIdx==tm.musIdx
                    try, lbTree.Value=lbTree.Items{ri}; break; catch, end
                end
            end
        else
            actualizarLblEntActiva();
        end
        updateBtnStates();
    end

    % =====================================================================
    % CRUD entidades
    % =====================================================================
    function onNuevaEntidad(~,~)
        abrirDialogoEntidad(struct('nombre','','fs',1020,'fMin',1,'fMax',510,...
            'ganancia',1,'observ',''), false, 0);
    end
    function onEditarEntidad(~,~)
        if S.entActiva<1||S.entActiva>numel(S.entidades), return; end
        abrirDialogoEntidad(S.entidades(S.entActiva),true,S.entActiva);
    end

    function abrirDialogoEntidad(e0, esEdicion, entIdx)
        if esEdicion, titulo='Editar entidad'; else, titulo='Nueva entidad'; end
        dlg=uifigure('Name',titulo,'Position',[280 300 360 300],'WindowStyle','modal');
        uilabel(dlg,'Text','Nombre circuito:','Position',[12 262 140 20]);
        eNombre=uieditfield(dlg,'text','Value',e0.nombre,'Position',[12 240 330 24]);
        uilabel(dlg,'Text','fs (SPS):','Position',[12 210 80 20]);
        eFs    =uieditfield(dlg,'numeric','Value',e0.fs,'Limits',[1 1e6],'Position',[12 188 80 24]);
        uilabel(dlg,'Text','f mín (Hz):','Position',[102 210 80 20]);
        eFmin  =uieditfield(dlg,'numeric','Value',e0.fMin,'Limits',[0 1e6],'Position',[102 188 80 24]);
        uilabel(dlg,'Text','f máx (Hz):','Position',[192 210 80 20]);
        eFmax  =uieditfield(dlg,'numeric','Value',e0.fMax,'Limits',[0 1e6],'Position',[192 188 80 24]);
        uilabel(dlg,'Text','Ganancia:','Position',[282 210 80 20]);
        eGan   =uieditfield(dlg,'numeric','Value',e0.ganancia,'Position',[282 188 60 24]);
        uilabel(dlg,'Text','Observación:','Position',[12 160 140 20]);
        eObs   =uieditfield(dlg,'text','Value',e0.observ,'Position',[12 138 330 24]);
        lblErr =uilabel(dlg,'Text','','Position',[12 108 330 20],'FontColor',[0.8 0 0]);
        uibutton(dlg,'Text','Guardar','Position',[12 70 130 32],...
            'BackgroundColor',CLR_ON,'FontWeight','bold',...
            'ButtonPushedFcn',@(~,~)guardarEntidad());
        uibutton(dlg,'Text','Cancelar','Position',[152 70 80 32],...
            'ButtonPushedFcn',@(~,~)delete(dlg));

        function guardarEntidad()
            nombre=strtrim(char(eNombre.Value));
            if isempty(nombre), lblErr.Text='El nombre no puede estar vacío.'; return; end
            if ~esEdicion
                for xi=1:numel(S.entidades)
                    if strcmpi(S.entidades(xi).nombre,nombre)
                        lblErr.Text=sprintf('Ya existe "%s".',nombre); return;
                    end
                end
            end
            % orden de campos idéntico al de S.entidades: nombre,fs,observ,fMin,fMax,ganancia
            nueva=struct('nombre',nombre,'fs',double(eFs.Value),...
                'observ',strtrim(char(eObs.Value)),...
                'fMin',double(eFmin.Value),'fMax',double(eFmax.Value),...
                'ganancia',double(eGan.Value));
            if esEdicion
                nombreViejo = S.entidades(entIdx).nombre;
                % Si el nombre cambió, renombrar el .mat para no perder muestras
                if ~strcmp(safeFilename(nombreViejo), safeFilename(nombre))
                    fViejo = fullfile(datosDir, [safeFilename(nombreViejo) '.mat']);
                    fNuevo = fullfile(datosDir, [safeFilename(nombre)      '.mat']);
                    if isfile(fViejo)
                        try
                            movefile(fViejo, fNuevo);
                            % Actualizar campo entidad dentro del .mat
                            tmp = load(fNuevo);
                            if isfield(tmp,'muestras')
                                muestras = tmp.muestras; %#ok<NASGU>
                                entidad  = nueva;        %#ok<NASGU>
                                save(fNuevo, 'muestras', 'entidad');
                            end
                        catch me
                            lblErr.Text = ['Error al renombrar archivo: ' me.message];
                            return;
                        end
                    end
                end
                S.entidades(entIdx)=nueva;
                logMsg(sprintf('Entidad editada: %s (antes: %s)', nombre, nombreViejo));
            else
                if isempty(S.entidades)
                    S.entidades=nueva;
                else
                    S.entidades(end+1)=nueva;
                end
                S.entActiva=numel(S.entidades);
                S.fs=nueva.fs; edtFs.Value=S.fs;
                logMsg(sprintf('Entidad creada: %s (fs=%g, %g-%g Hz, G=%g)',...
                    nombre,nueva.fs,nueva.fMin,nueva.fMax,nueva.ganancia));
            end
            saveConfig(); refreshTree(); delete(dlg);
        end
    end

    function onToggleCollapse(~,~)
        if S.entActiva<1||S.entActiva>numel(S.entidades), return; end
        % Asegurar tamaño
        if numel(S.entCollapsed)<S.entActiva
            S.entCollapsed(end+1:S.entActiva)=false;
        end
        S.entCollapsed(S.entActiva)=~S.entCollapsed(S.entActiva);
        saveConfig(); refreshTree();
    end

    function onBorrarSeleccion(~,~)
        val=lbTree.Value; items=lbTree.Items;
        idx=find(strcmp(items,val),1);
        if isempty(idx)||isempty(S.treeMap)||idx>numel(S.treeMap), return; end
        tm=S.treeMap{idx};
        if strcmp(tm.tipo,'vacio'), return; end

        if strcmp(tm.tipo,'ent')
            e=S.entidades(tm.entIdx);
            resp=uiconfirm(fig,...
                sprintf('¿Eliminar entidad "%s" y TODAS sus mediciones?',e.nombre),...
                'Confirmar','Options',{'Eliminar todo','Cancelar'},...
                'DefaultOption',2,'CancelOption',2);
            if ~strcmp(resp,'Eliminar todo'), return; end
            fname=fullfile(datosDir,[safeFilename(e.nombre) '.mat']);
            if isfile(fname), try, delete(fname); catch, end; end
            S.entidades(tm.entIdx)=[];
            if S.entActiva>=tm.entIdx, S.entActiva=max(0,S.entActiva-1); end
            logMsg(sprintf('Entidad eliminada: %s',e.nombre));

        elseif strcmp(tm.tipo,'mus')
            e=S.entidades(tm.entIdx);
            muestras=cargarMuestras(e.nombre);
            if tm.musIdx<1||tm.musIdx>numel(muestras), return; end
            m=muestras(tm.musIdx);
            ts=''; if isfield(m,'timestamp'), ts=m.timestamp; end
            pt=''; if isfield(m,'punta'),     pt=m.punta;     end
            resp=uiconfirm(fig,...
                sprintf('¿Eliminar medición #%d (%s, %s) de "%s"?',...
                tm.musIdx,pt,ts,e.nombre),...
                'Confirmar','Options',{'Eliminar','Cancelar'},...
                'DefaultOption',2,'CancelOption',2);
            if ~strcmp(resp,'Eliminar'), return; end
            muestras(tm.musIdx)=[];
            entidad=e; %#ok<NASGU>
            fname=fullfile(datosDir,[safeFilename(e.nombre) '.mat']);
            try, save(fname,'muestras','entidad'); catch, end
            logMsg(sprintf('Medición #%d eliminada de %s',tm.musIdx,e.nombre));
        end
        saveConfig(); refreshTree();
    end

    % =====================================================================
    % Guardar muestra
    % =====================================================================
    function onGuardarMuestra(~,~)
        if isempty(S.nVec), logMsg("Sin datos."); return; end
        if S.entActiva<1||S.entActiva>numel(S.entidades)
            logMsg("Selecciona una entidad primero."); return;
        end
        e=S.entidades(S.entActiva);
        nueva.raw_mV=S.notchVec*S.scale; nueva.filtered=S.filtVec;
        nueva.fs=S.fs; nueva.filtCmd=S.filtCmd; nueva.filtB=S.filtB;
        nueva.dcRemove=S.dcRemove; nueva.punta=char(ddPunta.Value);
        nueva.timestamp=datestr(now); nueva.observ=strtrim(char(edtObsMuestra.Value));
        muestras=cargarMuestras(e.nombre);
        if isempty(muestras), muestras=nueva; else, muestras(end+1)=nueva; end
        entidad=e; %#ok<NASGU>
        fname=fullfile(datosDir,[safeFilename(e.nombre) '.mat']);
        save(fname,'muestras','entidad');
        logMsg(sprintf('Muestra %d guardada — %s | punta:%s | filtro:%s',...
            numel(muestras),e.nombre,nueva.punta,S.filtCmd));
        refreshTree();
    end

    % =====================================================================
    % Callbacks de configuración
    % =====================================================================
    function onFsChanged()
        v=double(edtFs.Value);
        if isfinite(v)&&v>0, S.fs=v; applyFilter(); replot(); updateInfo(); saveConfig(); end
    end
    function onTWinChanged()
        v=double(edtTWin.Value);
        if isfinite(v)&&v>=0, S.tWin=v; replot(); saveConfig(); end
    end
    function onMaxPtsChanged()
        v=round(double(edtMaxPts.Value));
        if isfinite(v)&&v>0, S.maxPoints=v; saveConfig(); end
    end
    function onApplyFilter()
        cmd=strtrim(char(edtFiltCmd.Value));
        if isempty(cmd), logMsg("Cmd vacio."); return; end
        try
            b=eval(cmd); %#ok<EVLEQ>
            if ~isnumeric(b)||numel(b)<2
                logMsg("ERROR: comando debe retornar vector numérico (b)."); return;
            end
            S.filtB=b(:).'; S.filtCmd=cmd;
            applyFilter(); replot(); saveConfig();
            lblFiltSt.Text=filtStatusStr();
            logMsg(sprintf('FIR aplicado — N=%d  cmd:%s',numel(b)-1,cmd));
        catch e
            logMsg("ERROR filtro: "+string(e.message));
        end
    end
    function onQuitFilter()
        S.filtB=[]; S.filtCmd='';
        applyFilter(); replot(); saveConfig();
        lblFiltSt.Text=filtStatusStr(); logMsg("Filtro FIR desactivado.");
    end
    function onToggleDC()
        S.dcRemove=~S.dcRemove;
        updateDCBtn(); applyFilter(); replot(); saveConfig();
        if S.dcRemove, logMsg("Quitar DC: ON."); else, logMsg("Quitar DC: OFF."); end
    end
    function onToggleRaw()
        S.showRaw=~S.showRaw;
        updateShowRawBtn(); saveConfig();
    end
    function onToggleTZoom()
        if S.tAuto
            % Pasar a fijo: capturar límites actuales del eje
            try, xl=ax1.XLim; S.tMin=xl(1); S.tMax=xl(2);
                edtTMin.Value=S.tMin; edtTMax.Value=S.tMax; catch, end
            S.tAuto=false;
        else
            S.tAuto=true; ax1.XLimMode='auto';
        end
        updateZoomBtns(); replot(); saveConfig();
    end
    function onToggleYZoom()
        if S.yAuto
            try, yl=ax1.YLim; S.yMin=yl(1); S.yMax=yl(2);
                edtYMin.Value=S.yMin; edtYMax.Value=S.yMax; catch, end
            S.yAuto=false;
        else
            S.yAuto=true;
            if ~isempty(S.filtVec), peak=max(abs(S.filtVec)); S.yRange=max(peak*1.25,1.0); end
        end
        updateZoomBtns(); replot(); saveConfig();
    end

    % =====================================================================
    % Conexion
    % =====================================================================
    function onConnectToggle(~,~)
        if ~S.isConnected
            com=strtrim(string(edtCom.Value)); baud=double(edtBaud.Value);
            if com=="", logMsg("COM vacio."); return; end
            try
                S.sp=serialport(com,baud); S.sp.Timeout=0.05;
                flush(S.sp); pause(0.05);
                S.isConnected=true; S.streamEnabled=false;
                S.rxBuf=uint8([]); S.parseState=0;
                lname=fullfile(logsDir,sprintf('scope_%s.log',datestr(now,'yyyymmdd_HHMMSS')));
                S.logFid=fopen(lname,'w');
                if S.logFid>0
                    fprintf(S.logFid,'=== geophone_scope_simple — %s ===\n',datestr(now));
                end
                lblStat.Text='CONECTADO: '+com;
                logMsg("Conectado "+com+" @ "+string(baud));
                saveConfig(); startStreamTimer();
            catch e
                S.sp=[]; S.isConnected=false;
                logMsg("Error: "+string(e.message));
            end
        else
            stopStreamTimer(); S.streamEnabled=false;
            try, if ~isempty(S.sp), try flush(S.sp);catch,end; delete(S.sp); end; catch,end
            logMsg("Desconectado.");
            if S.logFid>0, try fclose(S.logFid);catch,end; S.logFid=-1; end
            S.sp=[]; S.isConnected=false; lblStat.Text='DESCONECTADO';
            saveConfig();
        end
        updateBtnStates();
    end

    % =====================================================================
    % Stream / Clear
    % =====================================================================
    function onStreamToggle(~,~)
        if ~S.isConnected, logMsg("No conectado."); return; end
        if ~S.streamEnabled
            S.rxBuf=uint8([]); S.parseState=0;
            S.pktBuf=zeros(5,1,'uint8'); S.pktIdx=0;
            S.streamEnabled=true; logMsg("--- Stream ON ---");
        else
            S.streamEnabled=false; logMsg("--- Stream OFF ---");
        end
        updateBtnStates();
    end
    function onClear(~,~)
        S.notchVec=[]; S.filtVec=[]; S.nVec=[]; S.frameCount=0;
        set(hRaw,  'XData',nan,'YData',nan);
        set(hNotch,'XData',nan,'YData',nan);
        ax1.XLimMode='auto'; ax1.YLimMode='auto';
        updateInfo(); updateBtnStates(); logMsg("Datos borrados.");
    end

    % =====================================================================
    % Timer
    % =====================================================================
    function startStreamTimer()
        stopStreamTimer();
        if ~S.isConnected||isempty(S.sp), return; end
        S.streamTimer=timer('ExecutionMode','fixedSpacing','Period',0.02,...
            'TimerFcn',@onStreamTick,'BusyMode','drop');
        start(S.streamTimer);
    end
    function stopStreamTimer()
        try
            if ~isempty(S.streamTimer)&&isvalid(S.streamTimer)
                stop(S.streamTimer); delete(S.streamTimer);
            end
        catch,end
        S.streamTimer=[];
    end

    % =====================================================================
    % Tick — 20 ms
    % =====================================================================
    function onStreamTick(~,~)
        if ~S.isConnected||isempty(S.sp), return; end
        S.tickCount=S.tickCount+1;
        nAvail=S.sp.NumBytesAvailable;
        logTick(nAvail); if nAvail<=0, return; end
        try, raw=read(S.sp,nAvail,"uint8");
        catch e
            if S.logFid>0
                fprintf(S.logFid,'[%s] ERR read: %s\n',datestr(now,'HH:MM:SS.FFF'),e.message);
            end; return;
        end
        if isempty(raw), return; end
        S.totalBytes=S.totalBytes+numel(raw); logHex(raw);
        if ~S.streamEnabled, return; end
        S.rxBuf=[S.rxBuf; uint8(raw(:))];
        newNotch=zeros(0,1); i=1; n=numel(S.rxBuf);
        while i<=n
            b=S.rxBuf(i);
            if S.parseState==0
                if b==uint8(0x56), S.pktBuf(1)=b; S.pktIdx=1; S.parseState=1; end
                i=i+1;
            else
                S.pktIdx=S.pktIdx+1; S.pktBuf(S.pktIdx)=b; i=i+1;
                if S.pktIdx==5
                    pkt=double(S.pktBuf);
                    if pkt(2)==1
                        logMsg(sprintf('HEARTBEAT bytes=%d',S.totalBytes));
                        S.parseState=0; continue;
                    end
                    u=pkt(3)*65536+pkt(4)*256+pkt(5);
                    if pkt(3)>=128, v=u-16777216; else, v=u; end
                    newNotch(end+1,1)=v; %#ok<AGROW>
                    S.parseState=0;
                end
            end
        end
        S.rxBuf=uint8([]); logParsed(numel(newNotch));
        if isempty(newNotch), return; end
        nNew=numel(newNotch); nIdx=(S.frameCount+1:S.frameCount+nNew).';
        S.notchVec=[S.notchVec; newNotch]; S.nVec=[S.nVec; nIdx];
        S.frameCount=S.frameCount+nNew;
        if numel(S.nVec)>S.maxPoints
            k0=numel(S.nVec)-S.maxPoints+1;
            S.notchVec=S.notchVec(k0:end); S.nVec=S.nVec(k0:end);
        end
        applyFilter(); replot(); updateInfo(); drawnow limitrate;
    end

    % =====================================================================
    % Cerrar
    % =====================================================================
    function onClose(~,~)
        try
            stopStreamTimer();
            if S.isConnected&&~isempty(S.sp)
                try flush(S.sp);catch,end; try delete(S.sp);catch,end
            end
        catch,end
        if S.logFid>0, try fclose(S.logFid);catch,end; S.logFid=-1; end
        saveConfig(); delete(fig);
    end

end
