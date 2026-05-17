function geophone_scope_simple()
% geophone_scope_simple — Interfaz PSoC5, sistema de entidades y muestras
%
% Protocolo RX — 4 bytes datos/HB, 5 bytes cfg/estado:
%   Data:     [0x56][TYPE:4|CH:2|D17:1|D16:1][D15:D8][D7:D0]  18-bit signed
%   HB:       [0x56][0x10][0x00][0x00]
%   CFG-ADC:  [0x56][0x20][res][fsH][fsL]
%   CFG-PGA:  [0x56][0x30|code][vrefH][vrefL][0]
%   VREF_ST:  [0x56][0x40][vdac_p][vdac_n][0x01]
%   VREF_CFG: [0x56][0x50][vdac_p][vdac_n][0x00]
%   AMUX_ST:  [0x56][0x60|ch][0][0][0]
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

    PUNTAS = {'gris','roja','marron','negra','MEZCLADO'};

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

    S.filtZi = [];  % estado del filtro FIR incremental

    % Config recibida del PSoC (via paquetes 0x02 y 0x03)
    S.configReceived  = false;
    S.adc_bits        = 18;
    S.pktDataBytes    = 3;     % 1 / 2 / 3  según ADC bits
    S.pktTotalBytes   = 5;     % 2 + pktDataBytes
    S.pga_gain_code   = 4;     % código PGA (0=1x 1=2x 2=4x 3=8x 4=16x 5=24x 6=32x 7=48x 8=50x)
    S.vref_halfmv     = 6144;
    S.scale = (S.vref_halfmv * 2) / 2^24;  % mV/count — escala solo del ADC

    S.maxPoints   = 9000;
    S.nVec        = zeros(0,1);
    S.notchVec    = zeros(0,1);
    S.filtVec     = zeros(0,1);
    S.frameCount  = 0;

    S.fs    = 1020;
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

    % VRef — referencias de los TIAs
    S.vdac_p_ref   = 148;    % pVRef: referencia VDAC_p (0x94 default)
    S.vdac_n_ref   = 148;    % nVRef: referencia VDAC_n
    S.servo_vdac_p = 148;    % posición actual leída del PSoC
    S.servo_vdac_n = 148;
    S.dc_mean_mv   = 0;      % promedio DC actual de la señal (mV)
    % Configs VRef guardadas por ganancia PGA
    S.servo_configs = struct('pga_code',{},'p_vref',{},'n_vref',{});
    S.amux_ch    = 0;   % 0=diferencial, 1=CM positiva, 2=CM negativa
    S.calRunning = false;

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
                    'yMin','yMax','yAuto','tMin','tMax','tAuto','dcRemove','showRaw',...
                    'vdac_p_ref','vdac_n_ref','amux_ch'};
            for k = 1:numel(flds)
                if isfield(cfg,flds{k}), S.(flds{k}) = cfg.(flds{k}); end
            end
            if isfield(cfg,'com'),       defCom      = cfg.com;       end
            if isfield(cfg,'baud'),      defBaud     = cfg.baud;      end
            if isfield(cfg,'entidades'),    S.entidades    = cfg.entidades;    end
            if isfield(cfg,'entCollapsed'), S.entCollapsed = cfg.entCollapsed; end
            if isfield(cfg,'servo_configs')
                sc = cfg.servo_configs;
                % Descartar formato viejo (tiene p_nominal/n_nominal en vez de p_vref/n_vref)
                if ~isempty(sc) && isfield(sc(1),'p_vref') && isfield(sc(1),'n_vref')
                    S.servo_configs = sc;
                end
            end
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
    % UI — figura 1100 x 1194
    % Layout columna derecha (RX=860, RW=225):
    %   pConn    y=997 h=116
    %   pServo   y=883 h=112
    %   pCtrl    y=775 h=106
    %   pFilt    y=649 h=124
    %   pEntidad y=337 h=310
    %   pGuardar y=223 h=112
    %   pData    y=127 h=94
    %   pZoom    y=35  h=90
    % =====================================================================
    fig = uifigure('Name','Geophone Scope','Position',[60 40 1100 1224]);
    fig.CloseRequestFcn = @onClose;

    ax1 = uiaxes(fig,'Position',[20 55 820 1000]);
    ax1.XGrid='on'; ax1.YGrid='on';
    ax1.XMinorGrid='on'; ax1.YMinorGrid='on';
    title(ax1,'Señal en tiempo'); ylabel(ax1,'mV'); xlabel(ax1,'tiempo (ms)');
    hold(ax1,'on');
    hRaw   = plot(ax1, nan, nan, 'Color',[1.0 0.85 0.3],'LineStyle','--','LineWidth',0.8);
    hNotch  = plot(ax1, nan, nan, 'Color',[0 1 0.5],'LineWidth',1.2);
    hDCLine = plot(ax1, nan, nan, '--', 'Color',[1 0.4 0], 'LineWidth',1.5);

    RX=860; RW=225;

    % --- Conexion ---
    pConn = uipanel(fig,'Title','Conexion','Position',[RX 1053 RW 116]);
    uilabel(pConn,'Text','COM:','Position',[8 70 32 20]);
    edtCom  = uieditfield(pConn,'text','Value',defCom,'Position',[44 68 58 22]);
    uilabel(pConn,'Text','Baud:','Position',[110 70 36 20]);
    edtBaud = uieditfield(pConn,'numeric','Value',defBaud,...
        'Limits',[1200 2000000],'Position',[150 68 60 22]);
    btnConn = uibutton(pConn,'Text','Conectar','Position',[8 36 100 28],...
        'BackgroundColor',CLR_CONN,'FontColor',[1 1 1],'FontWeight','bold',...
        'ButtonPushedFcn',@onConnectToggle);
    lblStat = uilabel(pConn,'Text','DESCONECTADO','Position',[114 40 104 20]);
    lblCfgInfo = uilabel(pConn,'Text','ADC: —  fs: —  PGA: —',...
        'Position',[8 8 210 20],'FontSize',8,'FontAngle','italic');

    % --- Stream + Ver crudo + Modo Vista ---
    pCtrl = uipanel(fig,'Title','Stream','Position',[RX 775 RW 136]);
    btnStream = uibutton(pCtrl,'Text','START','Position',[8 82 90 28],...
        'BackgroundColor',CLR_START,'FontColor',[0 0 0],'FontWeight','bold',...
        'ButtonPushedFcn',@onStreamToggle);
    btnClear = uibutton(pCtrl,'Text','Clear','Position',[106 82 90 28],...
        'ButtonPushedFcn',@onClear);
    btnShowRaw = uibutton(pCtrl,'Text','Ver crudo','Position',[8 48 88 26],...
        'ButtonPushedFcn',@(~,~)onToggleRaw());
    uilabel(pCtrl,'Text','(línea gris --)', ...
        'Position',[100 50 116 20],'FontSize',8,'FontAngle','italic');
    uilabel(pCtrl,'Text','Rama:','Position',[8 14 38 18],'FontSize',8);
    ddMux = uidropdown(pCtrl,...
        'Items',{'Diferencial','CM Positiva','CM Negativa'},...
        'Value','Diferencial',...
        'Position',[48 12 168 22],'FontSize',8,...
        'ValueChangedFcn',@(~,~)onMuxChanged());

    % --- VRef DC ---
    pServo = uipanel(fig,'Title','VRef DC','Position',[RX 913 RW 138]);
    % Fila 1: pVRef y nVRef + Aplicar
    uilabel(pServo,'Text','pVRef:','Position',[4 96 36 18],'FontSize',8);
    edtPVRef = uieditfield(pServo,'numeric','Value',S.vdac_p_ref,...
        'Limits',[0 255],'RoundFractionalValues','on',...
        'Position',[42 94 36 22],'FontSize',8);
    uilabel(pServo,'Text','nVRef:','Position',[82 96 36 18],'FontSize',8);
    edtNVRef = uieditfield(pServo,'numeric','Value',S.vdac_n_ref,...
        'Limits',[0 255],'RoundFractionalValues','on',...
        'Position',[120 94 36 22],'FontSize',8);
    btnApplyServo = uibutton(pServo,'Text','Aplicar','Position',[160 94 58 22],...
        'FontSize',8,'BackgroundColor',CLR_ON,'FontColor',[0 0 0],...
        'ButtonPushedFcn',@(~,~)onApplyServo());
    % Fila 2: Guardar y Editar
    btnGuardarCfg = uibutton(pServo,'Text','Guardar cfg PGA','Position',[4 70 108 22],...
        'FontSize',8,'BackgroundColor',CLR_ON,'FontColor',[0 0 0],...
        'Tooltip','Guarda pVRef/nVRef actual como preset para la ganancia PGA activa',...
        'ButtonPushedFcn',@(~,~)onGuardarCfgPGA());
    btnEditarCfg = uibutton(pServo,'Text','Editar cfg','Position',[118 70 100 22],...
        'FontSize',8,'Tooltip','Ver/editar presets por ganancia PGA',...
        'ButtonPushedFcn',@(~,~)onEditarCfgs());
    % Fila 3: AutoCal
    btnAutoCal = uibutton(pServo,'Text','AutoCal p+n','Position',[4 46 100 22],...
        'FontSize',8,'BackgroundColor',[0.85 0.65 0.10],'FontColor',[0 0 0],...
        'FontWeight','bold',...
        'Tooltip','Calibra pVRef (CM+) y nVRef (CM-) automaticamente: va a CM+, calibra, va a CM-, calibra, vuelve a Diferencial.',...
        'ButtonPushedFcn',@(~,~)onAutoCalibrateVRef());
    lblCalSt = uilabel(pServo,'Text','CM+→CM-→Dif',...
        'Position',[108 48 114 18],'FontSize',7.5,'FontAngle','italic');
    % Fila 4: estado actual + promedio DC
    uilabel(pServo,'Text','VDp:','Position',[4 20 26 18],'FontSize',8);
    lblVdacP = uilabel(pServo,'Text','---','Position',[32 20 26 18],...
        'FontSize',8,'FontWeight','bold');
    uilabel(pServo,'Text','VDn:','Position',[62 20 26 18],'FontSize',8);
    lblVdacN = uilabel(pServo,'Text','---','Position',[90 20 26 18],...
        'FontSize',8,'FontWeight','bold');
    uilabel(pServo,'Text','DC:','Position',[120 20 20 18],'FontSize',8);
    lblDCMean = uilabel(pServo,'Text','0.0 mV','Position',[142 20 80 18],...
        'FontSize',8,'FontWeight','bold');

    % --- Filtro FIR + DC ---
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
        'BackgroundColor',CLR_ON,'FontColor',[0 0 0],'FontWeight','bold',...
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

    % --- Guardar muestra ---
    pGuardar = uipanel(fig,'Title','Guardar muestra','Position',[RX 223 RW 112]);
    uilabel(pGuardar,'Text','Punta:','Position',[8 66 42 20]);
    ddPunta = uidropdown(pGuardar,'Items',PUNTAS,'Position',[54 64 80 22]);
    uilabel(pGuardar,'Text','Obs:','Position',[8 40 30 20]);
    edtObsMuestra = uieditfield(pGuardar,'text','Value','','Position',[40 38 118 22]);
    btnGuardar = uibutton(pGuardar,'Text','Guardar','Position',[162 18 52 46],...
        'BackgroundColor',CLR_ON,'FontColor',[0 0 0],'FontWeight','bold',...
        'ButtonPushedFcn',@onGuardarMuestra);
    lblNMuestras = uilabel(pGuardar,'Text','—',...
        'Position',[138 66 74 20],'FontSize',9);

    % --- Datos / Config ---
    pData = uipanel(fig,'Title','Datos','Position',[RX 127 RW 94]);
    lblInfo = uilabel(pData,'Text','n=0  t=0 ms','Position',[8 68 210 18]);
    uilabel(pData,'Text','Vent(pts):','Position',[8 44 62 20]);
    edtTWin = uieditfield(pData,'numeric','Value',S.tWin,...
        'Limits',[0 1e8],'RoundFractionalValues','on',...
        'Position',[72 42 44 22],'ValueChangedFcn',@(~,~)onTWinChanged());
    uilabel(pData,'Text','Max pts:','Position',[122 44 54 20]);
    edtMaxPts = uieditfield(pData,'numeric','Value',S.maxPoints,...
        'Limits',[100 1e6],'RoundFractionalValues','on',...
        'Position',[178 42 36 22],'ValueChangedFcn',@(~,~)onMaxPtsChanged());
    % Fila PGA
    uilabel(pData,'Text','PGA:','Position',[8 18 34 20]);
    ddPGA = uidropdown(pData,'Items',{'1','2','4','8','16','24','32','48','50'},...
        'Value',num2str(pgaCodeToGain(S.pga_gain_code)),...
        'Position',[44 16 54 22],...
        'ValueChangedFcn',@(~,~)onPGADropChanged());
    btnSetPGA = uibutton(pData,'Text','Set','Position',[102 16 36 22],...
        'ButtonPushedFcn',@(~,~)onSetPGA());
    lblPGAGain = uilabel(pData,'Text',pgaGainStr(S.pga_gain_code),...
        'Position',[142 18 74 18],'FontSize',8,'FontAngle','italic');

    % --- Zoom ---
    pZoom = uipanel(fig,'Title','Zoom','Position',[RX 35 RW 90]);
    uilabel(pZoom,'Text','t:','Position',[4 46 14 18],'FontSize',8);
    edtTMin = uieditfield(pZoom,'numeric','Value',S.tMin,'Position',[18 44 52 20],...
        'ValueChangedFcn',@(~,~)onTMinChanged());
    uilabel(pZoom,'Text','—','Position',[72 46 10 18],'FontSize',8);
    edtTMax = uieditfield(pZoom,'numeric','Value',S.tMax,'Position',[84 44 52 20],...
        'ValueChangedFcn',@(~,~)onTMaxChanged());
    btnTZoom = uibutton(pZoom,'Text','','Position',[140 44 76 20],...
        'FontSize',8,'FontWeight','bold','ButtonPushedFcn',@(~,~)onToggleTZoom());
    uilabel(pZoom,'Text','y:','Position',[4 18 14 18],'FontSize',8);
    edtYMin = uieditfield(pZoom,'numeric','Value',S.yMin,'Position',[18 16 52 20],...
        'ValueChangedFcn',@(~,~)onYMinChanged());
    uilabel(pZoom,'Text','—','Position',[72 18 10 18],'FontSize',8);
    edtYMax = uieditfield(pZoom,'numeric','Value',S.yMax,'Position',[84 16 52 20],...
        'ValueChangedFcn',@(~,~)onYMaxChanged());
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
    updateServoDisplay();
    if S.amux_ch <= 2, ddMux.Value = ddMux.Items{S.amux_ch + 1}; end
    updateVRefEnableState();
    refreshTree();
    if ~S.tAuto, try ax1.XLim=[S.tMin S.tMax]; catch, end; end
    if ~S.yAuto, try ax1.YLim=[S.yMin S.yMax]; catch, end; end
    if ~isempty(S.filtB), edtFiltCmd.Value=S.filtCmd; lblFiltSt.Text=filtStatusStr(); end

    % =====================================================================
    % Helpers
    % =====================================================================
    function g = pgaCodeToGain(code)
        t = [1, 2, 4, 8, 16, 24, 32, 48, 50];
        code = max(0, min(8, round(double(code))));
        g = t(code + 1);
    end
    function code = pgaGainToCode(gain)
        t = [1, 2, 4, 8, 16, 24, 32, 48, 50];
        [~, idx] = min(abs(t - round(double(gain))));
        code = idx - 1;
    end
    function s = pgaGainStr(code)
        s = sprintf('%dx (0x%02X)', pgaCodeToGain(code), round(double(code)));
    end

    function s = filtStatusStr()
        if isempty(S.filtB), s='Sin filtro activo';
        else, s=sprintf('FIR N=%d activo',numel(S.filtB)-1); end
    end
    function s = dcStatusStr()
        if S.dcRemove, s='DC: ON'; else, s='DC: OFF'; end
    end
    function v = iif(cond, a, b)
        if cond, v=a; else, v=b; end
    end
    function s = safeFilename(nombre)
        s = regexprep(nombre,'[^\w]','_');
    end

    function setBtn(btn, active)
        if active
            btn.BackgroundColor=CLR_ON; btn.FontColor=[0 0 0]; btn.FontWeight='bold';
        else
            btn.BackgroundColor=CLR_OFF; btn.FontColor=[0 0 0]; btn.FontWeight='normal';
        end
    end

    function updateZoomBtns()
        if S.tAuto
            btnTZoom.Text='t: Auto ●';
            btnTZoom.BackgroundColor=CLR_ON; btnTZoom.FontColor=[0 0 0];
        else
            btnTZoom.Text='t: Fijo ●';
            btnTZoom.BackgroundColor=CLR_MAN; btnTZoom.FontColor=[1 1 1];
        end
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
        if c, btnConn.Text='Desconectar'; btnConn.BackgroundColor=CLR_STOP; btnConn.FontColor=[1 1 1];
        else, btnConn.Text='Conectar';    btnConn.BackgroundColor=CLR_CONN; btnConn.FontColor=[1 1 1]; end
        if r, btnStream.Text='STOP'; btnStream.BackgroundColor=CLR_STOP; btnStream.FontColor=[1 1 1];
        else, btnStream.Text='START';btnStream.BackgroundColor=CLR_START;btnStream.FontColor=[0 0 0]; end
        btnStream.Enable = c;
        tieneEnt  = S.entActiva>=1 && S.entActiva<=numel(S.entidades);
        tieneDatos= ~isempty(S.nVec);
        btnGuardar.Enable = tieneEnt && tieneDatos && ~r;
        ddPGA.Enable     = c;
        btnSetPGA.Enable = c;
        edtMaxPts.Enable = ~r;
        updateVRefEnableState();
    end

    function logMsg(msg)
        ts=string(datestr(now,'HH:MM:SS.FFF'));
        line="["+ts+"] "+string(msg);
        v=txtLog.Value; if ~isstring(v), v=string(v); end
        v(end+1,1)=line; if numel(v)>200, v=v(end-199:end); end
        txtLog.Value=v;
        if S.logFid>0, fprintf(S.logFid,'%s\n',char(line)); end
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
            lblInfo.Text=sprintf('n=%d  t=%.0f ms',n,n/S.fs*1000);
        catch, end
    end
    function applyFilter()
        S.filtZi = [];
        if isempty(S.notchVec), S.filtVec=zeros(0,1); return; end
        raw_mV = S.notchVec * S.scale;
        if isempty(S.filtB)
            S.filtVec = raw_mV;
        else
            minLen = 3*(numel(S.filtB)-1);
            if numel(raw_mV) < max(minLen,4)
                S.filtVec = raw_mV;
            else
                try
                    [S.filtVec, S.filtZi] = filter(S.filtB, 1, raw_mV);
                catch
                    S.filtVec = raw_mV;
                end
            end
        end
    end

    function appendSamples(newNotch)
        nNew = numel(newNotch);
        if nNew == 0, return; end
        nIdx = (S.frameCount+1 : S.frameCount+nNew).';
        S.notchVec   = [S.notchVec;  newNotch];
        S.nVec       = [S.nVec;      nIdx];
        S.frameCount = S.frameCount + nNew;

        raw_new = double(newNotch) * S.scale;
        if isempty(S.filtB)
            newFilt  = raw_new;
            S.filtZi = [];
        else
            if isempty(S.filtZi)
                S.filtZi = zeros(numel(S.filtB)-1, 1);
            end
            [newFilt, S.filtZi] = filter(S.filtB, 1, raw_new, S.filtZi);
        end
        S.filtVec = [S.filtVec; newFilt];

        if numel(S.nVec) > S.maxPoints
            ex = numel(S.nVec) - S.maxPoints;
            S.notchVec = S.notchVec(ex+1:end);
            S.nVec     = S.nVec(ex+1:end);
            S.filtVec  = S.filtVec(ex+1:end);
        end
    end

    function replot()
        if isempty(S.nVec)||isempty(S.filtVec), return; end
        tms    = double(S.nVec)/S.fs*1000.0;
        raw_mV = S.notchVec*S.scale;
        filt   = S.filtVec;
        if S.dcRemove && ~isempty(filt), filt = filt - mean(filt); end
        set(hRaw,   'XData', tms, 'YData', raw_mV);
        set(hNotch, 'XData', tms, 'YData', filt);
        % Línea de promedio DC (naranja punteada) + etiqueta en panel
        if ~isempty(filt)
            dcMean = mean(filt);
            S.dc_mean_mv = dcMean;
            set(hDCLine, 'XData', [tms(1) tms(end)], 'YData', [dcMean dcMean]);
            try, lblDCMean.Text = sprintf('%.1f mV', dcMean); catch, end
        end
        if ~S.tAuto
            try, ax1.XLim=[S.tMin S.tMax]; catch, end
        elseif S.tWin>0 && ~isempty(tms)
            tWin_ms = S.tWin/S.fs*1000;
            ax1.XLim=[max(0,tms(end)-tWin_ms), tms(end)];
        else, ax1.XLimMode='auto'; end
        if ~S.yAuto
            try, ax1.YLim=[S.yMin S.yMax]; catch, end
        else
            peak=max(abs(filt)); if peak<0.1, peak=0.1; end
            target=peak*1.25;
            if target>S.yRange, S.yRange=target;
            else, S.yRange=S.yRange*0.97+target*0.03; end
            S.yRange=max(S.yRange,1.0);
            try, ax1.YLim=[-S.yRange S.yRange]; catch, end
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
            cfg.vdac_p_ref=S.vdac_p_ref; cfg.vdac_n_ref=S.vdac_n_ref;
            cfg.amux_ch=S.amux_ch;
            cfg.servo_configs=S.servo_configs;
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
            S.fs=S.entidades(S.entActiva).fs;
        end

        if oldActiva~=S.entActiva
            refreshTree();
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
        val = lbTree.Value; items = lbTree.Items;
        idx = find(strcmp(items, val), 1);
        if isempty(idx)||isempty(S.treeMap)||idx>numel(S.treeMap), return; end
        tm = S.treeMap{idx};
        if strcmp(tm.tipo,'mus')
            abrirDialogoMuestra(tm.entIdx, tm.musIdx);
        elseif strcmp(tm.tipo,'ent')
            abrirDialogoEntidad(S.entidades(tm.entIdx), true, tm.entIdx);
        end
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
            nueva=struct('nombre',nombre,'fs',double(eFs.Value),...
                'observ',strtrim(char(eObs.Value)),...
                'fMin',double(eFmin.Value),'fMax',double(eFmax.Value),...
                'ganancia',double(eGan.Value));
            if esEdicion
                nombreViejo = S.entidades(entIdx).nombre;
                if ~strcmp(safeFilename(nombreViejo), safeFilename(nombre))
                    fViejo = fullfile(datosDir, [safeFilename(nombreViejo) '.mat']);
                    fNuevo = fullfile(datosDir, [safeFilename(nombre)      '.mat']);
                    if isfile(fViejo)
                        try
                            movefile(fViejo, fNuevo);
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
                S.fs=nueva.fs;
                logMsg(sprintf('Entidad creada: %s (fs=%g, %g-%g Hz, G=%g)',...
                    nombre,nueva.fs,nueva.fMin,nueva.fMax,nueva.ganancia));
            end
            saveConfig(); refreshTree(); delete(dlg);
        end
    end

    function abrirDialogoMuestra(entIdx, musIdx)
        e        = S.entidades(entIdx);
        muestras = cargarMuestras(e.nombre);
        if musIdx<1||musIdx>numel(muestras), return; end
        m = muestras(musIdx);

        dlg = uifigure('Name',sprintf('Editar muestra #%d — %s',musIdx,e.nombre),...
            'Position',[280 300 390 290],'WindowStyle','modal');

        uilabel(dlg,'Text','fs (SPS):','Position',[12 242 70 20]);
        eFs = uieditfield(dlg,'numeric','Value',double(m.fs),'Limits',[1 1e6],...
            'Position',[12 220 80 24]);

        uilabel(dlg,'Text','Punta:','Position',[106 242 50 20]);
        ePunta = uidropdown(dlg,'Items',PUNTAS,'Position',[106 220 120 24]);
        if isfield(m,'punta')&&ismember(m.punta,PUNTAS), ePunta.Value=m.punta; end

        uilabel(dlg,'Text','Filtro (cmd):','Position',[12 188 100 20]);
        eFiltCmd = uieditfield(dlg,'text','Value',m.filtCmd,...
            'Position',[12 166 360 24]);

        dcVal = false;
        if isfield(m,'dcRemove'), dcVal=logical(m.dcRemove); end
        chkDC = uicheckbox(dlg,'Text','Quitar DC','Value',dcVal,...
            'Position',[12 136 120 22]);

        uilabel(dlg,'Text','Observación:','Position',[12 106 100 20]);
        eObs = uieditfield(dlg,'text','Value',m.observ,...
            'Position',[12 84 360 24]);

        lblErr = uilabel(dlg,'Text','','Position',[12 56 360 20],'FontColor',[0.8 0 0]);

        uibutton(dlg,'Text','Guardar','Position',[12 16 120 32],...
            'BackgroundColor',CLR_ON,'FontWeight','bold',...
            'ButtonPushedFcn',@(~,~)guardarCambiosMuestra());
        uibutton(dlg,'Text','Cancelar','Position',[142 16 80 32],...
            'ButtonPushedFcn',@(~,~)delete(dlg));

        function guardarCambiosMuestra()
            muestras(musIdx).fs       = double(eFs.Value);
            muestras(musIdx).punta    = char(ePunta.Value);
            muestras(musIdx).filtCmd  = strtrim(char(eFiltCmd.Value));
            muestras(musIdx).dcRemove = chkDC.Value;
            muestras(musIdx).observ   = strtrim(char(eObs.Value));
            entidad = e; %#ok<NASGU>
            fname = fullfile(datosDir,[safeFilename(e.nombre) '.mat']);
            try
                save(fname,'muestras','entidad');
                logMsg(sprintf('Muestra #%d editada — %s  fs=%g  punta=%s',...
                    musIdx,e.nombre,muestras(musIdx).fs,muestras(musIdx).punta));
                delete(dlg);
                refreshTree();
            catch me
                lblErr.Text = ['Error al guardar: ' me.message];
            end
        end
    end

    function onToggleCollapse(~,~)
        if S.entActiva<1||S.entActiva>numel(S.entidades), return; end
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
        nueva.raw_mV=S.notchVec*S.scale;
        filtToSave=S.filtVec;
        if S.dcRemove&&~isempty(filtToSave), filtToSave=filtToSave-mean(filtToSave); end
        nueva.filtered=filtToSave;
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
    % PGA
    % =====================================================================
    function onPGADropChanged()
        gain = str2double(ddPGA.Value);
        code = pgaGainToCode(gain);
        lblPGAGain.Text = pgaGainStr(code);
    end

    function onSetPGA()
        gain = str2double(ddPGA.Value);
        if ~isfinite(gain), logMsg('PGA: valor inválido'); return; end
        code = pgaGainToCode(gain);
        if ~S.isConnected, logMsg('PGA: no conectado'); return; end

        wasRunning = ~isempty(S.streamTimer) && isvalid(S.streamTimer) && ...
                     strcmp(S.streamTimer.Running, 'on');
        if wasRunning, stopStreamTimer(); end

        try, flush(S.sp); catch, end

        try
            write(S.sp, uint8([0xA6, uint8(code)]), 'uint8');
        catch ex
            logMsg('PGA: error UART — ' + string(ex.message));
            if wasRunning, startStreamTimer(); end
            return;
        end
        logMsg(sprintf('PGA cmd enviado: %dx (code 0x%02X) — esperando confirmación...', gain, code));

        t0   = tic;
        vBuf = uint8([]);
        confirmed = false;
        while toc(t0) < 1.0 && ~confirmed
            pause(0.02);
            try
                n = S.sp.NumBytesAvailable;
                if n > 0
                    vBuf = [vBuf; read(S.sp, n, 'uint8')]; %#ok<AGROW>
                end
            catch ex2
                logMsg('PGA: error leyendo confirmación — ' + string(ex2.message));
                break;
            end
            while numel(vBuf) >= 5
                idx = find(vBuf == uint8(0x56), 1);
                if isempty(idx), vBuf = uint8([]); break; end
                vBuf = vBuf(idx:end);
                if numel(vBuf) < 5, break; end
                p    = double(vBuf(1:5));
                vBuf = vBuf(6:end);
                if p(2) == 3  % CFG_PGA — p(3) = pga_code
                    confirmedCode = p(3);
                    if confirmedCode == code
                        confirmed = true; break;
                    else
                        logMsg(sprintf('PGA: PSoC reporta 0x%02X (esperado 0x%02X)', confirmedCode, code));
                    end
                elseif p(2) == 4  % VREF_STATUS
                    S.servo_vdac_p = p(3);
                    S.servo_vdac_n = p(4);
                    updateServoDisplay();
                end
            end
        end

        if confirmed
            S.pga_gain_code = code;
            lblPGAGain.Text = pgaGainStr(code);
            lblCfgInfo.Text = sprintf('ADC:%db  fs:%d SPS  PGA:%s  ±%dmV',...
                S.adc_bits, S.fs, pgaGainStr(code), S.vref_halfmv);
            logMsg(sprintf('PGA confirmado: %dx (0x%02X)', pgaCodeToGain(code), code));
            saveConfig();
            % Auto-cargar config servo para esta ganancia si existe
            cfgIdx = findServoCfgByCode(code);
            if ~isempty(cfgIdx)
                c = S.servo_configs(cfgIdx);
                edtPVRef.Value = double(c.p_vref);
                edtNVRef.Value = double(c.n_vref);
                onApplyServo();
                logMsg(sprintf('Servo cfg PGA %dx cargada automáticamente', pgaCodeToGain(code)));
            end
        else
            logMsg('PGA WARN: sin confirmación del PSoC — verifica la conexión');
        end

        S.rxBuf = uint8([]);
        if wasRunning, startStreamTimer(); end
    end

    % =====================================================================
    % Callbacks de configuración
    % =====================================================================
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
        updateDCBtn(); replot(); saveConfig();
        if S.dcRemove, logMsg("Quitar DC: ON."); else, logMsg("Quitar DC: OFF."); end
    end
    function onToggleRaw()
        S.showRaw=~S.showRaw;
        updateShowRawBtn(); saveConfig();
    end
    function onTMinChanged()
        v=double(edtTMin.Value);
        if isfinite(v), S.tMin=v;
            if ~S.tAuto, try ax1.XLim=[S.tMin S.tMax]; catch, end; saveConfig(); end
        end
    end
    function onTMaxChanged()
        v=double(edtTMax.Value);
        if isfinite(v), S.tMax=v;
            if ~S.tAuto, try ax1.XLim=[S.tMin S.tMax]; catch, end; saveConfig(); end
        end
    end
    function onYMinChanged()
        v=double(edtYMin.Value);
        if isfinite(v), S.yMin=v;
            if ~S.yAuto, try ax1.YLim=[S.yMin S.yMax]; catch, end; saveConfig(); end
        end
    end
    function onYMaxChanged()
        v=double(edtYMax.Value);
        if isfinite(v), S.yMax=v;
            if ~S.yAuto, try ax1.YLim=[S.yMin S.yMax]; catch, end; saveConfig(); end
        end
    end
    function onToggleTZoom()
        if S.tAuto
            S.tAuto=false;
        else
            S.tAuto=true; ax1.XLimMode='auto';
        end
        updateZoomBtns(); replot(); saveConfig();
    end
    function onToggleYZoom()
        if S.yAuto
            S.yAuto=false;
        else
            S.yAuto=true;
            if ~isempty(S.filtVec), peak=max(abs(S.filtVec)); S.yRange=max(peak*1.25,1.0); end
        end
        updateZoomBtns(); replot(); saveConfig();
    end

    % =====================================================================
    % Handshake de configuracion con PSoC
    % =====================================================================
    function requestAndParseConfig()
        logMsg('Solicitando config al PSoC (0xA5)...');
        try
            flush(S.sp);
            write(S.sp, uint8(0xA5), 'uint8');
        catch
            logMsg('WARN: no se pudo enviar solicitud de config');
            return;
        end

        t0 = tic;
        cfgBuf   = uint8([]);
        gotType2 = false;
        gotType3 = false;
        gotType4 = false;
        gotType6 = false;
        gotAmux  = false;

        while toc(t0) < 2.0 && (~gotType2 || ~gotType3 || ~gotType4 || ~gotType6)
            pause(0.05);
            try
                n = S.sp.NumBytesAvailable;
                if n > 0
                    raw = read(S.sp, n, 'uint8');
                    cfgBuf = [cfgBuf; raw(:)]; %#ok<AGROW>
                end
            catch, break; end

            while numel(cfgBuf) >= 5
                idx = find(cfgBuf == uint8(0x56), 1);
                if isempty(idx), cfgBuf = uint8([]); break; end
                cfgBuf = cfgBuf(idx:end);
                if numel(cfgBuf) < 5, break; end
                p      = double(cfgBuf(1:5));
                cfgBuf = cfgBuf(6:end);
                if p(2) == 2
                    S.adc_bits = p(3);
                    S.fs       = p(4)*256 + p(5);
                    gotType2   = true;
                elseif p(2) == 3
                    S.pga_gain_code = p(3);
                    S.vref_halfmv   = p(4)*256 + p(5);
                    gotType3        = true;
                elseif p(2) == 4
                    S.servo_vdac_p = p(3);
                    S.servo_vdac_n = p(4);
                    gotType4       = true;
                elseif p(2) == 5  % AMUX_STATUS
                    S.amux_ch = p(3);
                    gotAmux   = true;
                elseif p(2) == 6
                    S.vdac_p_ref = p(3);
                    S.vdac_n_ref = p(4);
                    gotType6     = true;
                end
            end
        end

        if gotType2 && gotType3
            if     S.adc_bits <= 8,  S.pktDataBytes = 1;
            elseif S.adc_bits <= 16, S.pktDataBytes = 2;
            else,                    S.pktDataBytes = 3;
            end
            S.pktTotalBytes = 2 + S.pktDataBytes;
            S.scale = (S.vref_halfmv * 2) / 2^24;

            ddPGA.Value     = num2str(pgaCodeToGain(S.pga_gain_code));
            lblPGAGain.Text = pgaGainStr(S.pga_gain_code);
            lblCfgInfo.Text = sprintf('ADC:%db  fs:%d SPS  PGA:%s  ±%dmV',...
                S.adc_bits, S.fs, pgaGainStr(S.pga_gain_code), S.vref_halfmv);
            S.configReceived = true;
            logMsg(sprintf('Config OK: ADC=%d bits  fs=%d SPS  PGA code=%d(%s)  Vref=±%dmV  pktsz=%d  scale=%.3e mV/cnt',...
                S.adc_bits, S.fs, S.pga_gain_code, pgaGainStr(S.pga_gain_code), S.vref_halfmv, S.pktTotalBytes, S.scale));
        else
            logMsg(sprintf('WARN: config incompleta (tipo2=%d tipo3=%d) — usando defaults',...
                gotType2, gotType3));
            lblCfgInfo.Text = 'Config: defaults (PSoC no respondió)';
        end
        if gotType4
            updateServoDisplay();
            logMsg(sprintf('VRef actual: VDp=%d VDn=%d', S.servo_vdac_p, S.servo_vdac_n));
        end
        if gotType6
            edtPVRef.Value = double(S.vdac_p_ref);
            edtNVRef.Value = double(S.vdac_n_ref);
            logMsg(sprintf('VRef cfg: pVRef=%d (0x%02X) nVRef=%d (0x%02X)',...
                S.vdac_p_ref, S.vdac_p_ref, S.vdac_n_ref, S.vdac_n_ref));
        end
        if gotAmux && S.amux_ch <= 2
            ddMux.Value = ddMux.Items{S.amux_ch + 1};
            updateVRefEnableState();
            logMsg(sprintf('AMux: %s (ch=%d)', ddMux.Items{S.amux_ch+1}, S.amux_ch));
        end
        try, flush(S.sp); catch, end
        S.rxBuf    = uint8([]);
        S.parseState = 0;
        saveConfig();
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
                requestAndParseConfig();
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
            S.configReceived=false;
            lblCfgInfo.Text='ADC: —  fs: —  PGA: —';
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
        S.notchVec=[]; S.filtVec=[]; S.nVec=[]; S.frameCount=0; S.filtZi=[];
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
        nAvail = min(nAvail, 400);
        try, raw=read(S.sp,nAvail,"uint8");
        catch e
            if S.logFid>0
                fprintf(S.logFid,'[%s] ERR read: %s\n',datestr(now,'HH:MM:SS.FFF'),e.message);
            end
            logMsg('ERR lectura UART — desconectando.');
            forceDisconnect(); return;
        end
        if isempty(raw), return; end
        S.totalBytes=S.totalBytes+numel(raw); logHex(raw);
        S.rxBuf=[S.rxBuf; uint8(raw(:))];
        newNotch=zeros(0,1); i=1; n=numel(S.rxBuf);
        while i<=n
            b=S.rxBuf(i);
            if S.parseState==0
                if b==uint8(0x56), S.pktBuf(1)=b; S.pktIdx=1; S.parseState=1; end
                i=i+1;
            else
                S.pktIdx=S.pktIdx+1; S.pktBuf(S.pktIdx)=b; i=i+1;
                if S.pktIdx==S.pktTotalBytes
                    pkt=double(S.pktBuf(1:S.pktTotalBytes));
                    if pkt(2)==1   % heartbeat
                        logMsg(sprintf('HEARTBEAT bytes=%d',S.totalBytes));
                        S.parseState=0; continue;
                    end
                    if pkt(2)==0   % data — int24 big-endian signed
                        switch S.pktDataBytes
                            case 1
                                u = pkt(3);
                                v = u - (u>=128)*256;
                            case 2
                                u = pkt(3)*256 + pkt(4);
                                v = u - (pkt(3)>=128)*65536;
                            otherwise
                                u = pkt(3)*65536 + pkt(4)*256 + pkt(5);
                                v = u - (pkt(3)>=128)*16777216;
                        end
                        newNotch(end+1,1)=v; %#ok<AGROW>
                    elseif pkt(2)==4  % VREF_STATUS
                        S.servo_vdac_p = pkt(3);
                        S.servo_vdac_n = pkt(4);
                        updateServoDisplay();
                    elseif pkt(2)==5  % AMUX_STATUS — ch en byte 3
                        ch = pkt(3);
                        if ch <= 2
                            S.amux_ch = ch;
                            ddMux.Value = ddMux.Items{ch+1};
                            updateVRefEnableState();
                        end
                    end
                    S.parseState=0;
                end
            end
        end
        S.rxBuf=uint8([]); logParsed(numel(newNotch));
        if ~S.streamEnabled || isempty(newNotch), return; end
        appendSamples(newNotch);
        replot(); updateInfo();
        drawnow limitrate;
    end

    % =====================================================================
    % Desconexión forzada por error
    % =====================================================================
    function forceDisconnect()
        stopStreamTimer();
        S.streamEnabled = false;
        try, if ~isempty(S.sp), flush(S.sp); delete(S.sp); end; catch, end
        S.sp=[]; S.isConnected=false;
        S.rxBuf=uint8([]); S.parseState=0;
        if S.logFid>0, try fclose(S.logFid);catch,end; S.logFid=-1; end
        lblStat.Text='DESCONECTADO';
        lblCfgInfo.Text='ADC: —  fs: —  PGA: —';
        S.configReceived=false;
        logMsg('Desconectado por error de comunicación.');
        updateBtnStates();
    end

    % =====================================================================
    % Servo DC — display y envío de comandos
    % =====================================================================
    function updateServoDisplay()
        lblVdacP.Text = num2str(S.servo_vdac_p);
        lblVdacN.Text = num2str(S.servo_vdac_n);
    end

    function onApplyServo()
        if ~S.isConnected, logMsg('VRef: no conectado'); return; end
        pV = max(0, min(255, round(double(edtPVRef.Value))));
        nV = max(0, min(255, round(double(edtNVRef.Value))));
        try
            write(S.sp, uint8([0xAA, uint8(pV), uint8(nV)]), 'uint8');
        catch ex
            logMsg('VRef: error UART — ' + string(ex.message)); return;
        end
        S.vdac_p_ref = pV; S.vdac_n_ref = nV;
        S.servo_vdac_p = pV; S.servo_vdac_n = nV;
        updateServoDisplay();
        logMsg(sprintf('VRef aplicado: pVRef=%d (0x%02X)  nVRef=%d (0x%02X)', pV,pV, nV,nV));
        saveConfig();
    end

    % =====================================================================
    % AutoCal VRef — minimiza DC en modo CM
    % =====================================================================
    function onAutoCalibrateVRef()
        if ~S.isConnected, logMsg('AutoCal: no conectado'); return; end

        S.calRunning     = true;
        wasStreamEnabled = S.streamEnabled;
        S.streamEnabled  = true;
        lblCalSt.Text    = 'Calibrando...';
        updateBtnStates();
        drawnow;

        % Cambia canal AMux, actualiza UI, drena datos del canal anterior
        function cambiarCanal(ch_nuevo)
            try, write(S.sp, uint8([0xA7, uint8(ch_nuevo)]), 'uint8'); catch, end
            S.amux_ch = ch_nuevo;
            try, ddMux.Value = ddMux.Items{ch_nuevo+1}; catch, end
            pause(0.15);
            S.notchVec=[]; S.filtVec=[]; S.nVec=[]; S.frameCount=0; S.filtZi=[]; S.dc_mean_mv=0;
            set(hRaw,'XData',nan,'YData',nan); set(hNotch,'XData',nan,'YData',nan);
        end

        % Aplica VDAC, resetea dc_iir, limpia buffer para acumulacion fresca
        function ok = aplicarVDAC(pV, nV)
            ok = false;
            pV = max(0,min(255,round(double(pV))));
            nV = max(0,min(255,round(double(nV))));
            try, write(S.sp, uint8([0xAA, uint8(pV), uint8(nV)]), 'uint8'); catch, return; end
            S.servo_vdac_p=pV; S.servo_vdac_n=nV;
            edtPVRef.Value=double(pV); edtNVRef.Value=double(nV);
            updateServoDisplay();
            pause(0.05);
            try, write(S.sp, uint8([0xA7, uint8(S.amux_ch)]), 'uint8'); catch, end
            pause(0.15);
            S.notchVec=[]; S.filtVec=[]; S.nVec=[]; S.frameCount=0; S.filtZi=[]; S.dc_mean_mv=0;
            set(hRaw,'XData',nan,'YData',nan); set(hNotch,'XData',nan,'YData',nan);
            ok = true;
        end

        % Espera duracion_s seg y mide DC. Ventana FIJA para todos los pasos
        % de busqueda -> factores IIR identicos -> ratios y comparaciones exactos.
        % Descarta primeros numel(filtB)-1 muestras (transitorio FIR).
        function dc = medirDC(duracion_s)
            t0 = tic;
            while toc(t0) < duracion_s, pause(0.05); end
            nFIR = max(0, numel(S.filtB) - 1);
            raw  = double(S.notchVec);
            if numel(raw) <= nFIR, dc = 0;
            else, dc = mean(raw(nFIR+1:end)) * S.scale; end
        end

        % Calibra un canal. v0=VDAC a optimizar, vOtra=VDAC fijo, esCMPos=bool.
        % Todas las ventanas de busqueda son 2s (iguales) -> comparacion justa.
        % La ventana 5s solo se usa al final como reporte, no para decidir.
        function v_best = calibrarCanal(v0, vOtra, esCMPos)
            v_best = -1;
            nom = ddMux.Value;

            % A: medicion inicial
            if esCMPos, ok=aplicarVDAC(v0,vOtra); else, ok=aplicarVDAC(vOtra,v0); end
            if ~ok, return; end
            dc0 = medirDC(2.0);
            logMsg(sprintf('AutoCal %s: v=%d  DC=%.1f mV', nom, v0, dc0)); drawnow;

            % B: perturbacion para sensibilidad
            delta_p = 10;
            v1 = max(0, min(255, v0 + delta_p));
            if v1 == v0,  v1 = max(0, min(255, v0 - delta_p)); end
            if v1 == v0,  logMsg(sprintf('AutoCal %s: VDAC en limite', nom)); return; end
            if esCMPos, ok=aplicarVDAC(v1,vOtra); else, ok=aplicarVDAC(vOtra,v1); end
            if ~ok, return; end
            dc1 = medirDC(2.0);
            logMsg(sprintf('AutoCal %s: v=%d  DC=%.1f mV (perturb)', nom, v1, dc1)); drawnow;

            sens = (dc1 - dc0) / double(v1 - v0);
            % dc0 y dc1 usan misma ventana -> factor IIR igual -> cancela en dc0/sens
            if abs(sens) < 0.001
                logMsg(sprintf('AutoCal %s: sens~0, abortando', nom)); return;
            end

            % C: estimacion lineal (misma ventana -> factor cancela, estimado correcto)
            v_est = max(0, min(255, round(v0 - dc0 / sens)));
            logMsg(sprintf('AutoCal %s: sens=%.2f mV/cnt  v_est=%d', nom, sens, v_est));
            if esCMPos, ok=aplicarVDAC(v_est,vOtra); else, ok=aplicarVDAC(vOtra,v_est); end
            if ~ok, return; end
            dc_est = medirDC(2.0);
            logMsg(sprintf('AutoCal %s: v=%d  DC=%.1f mV', nom, v_est, dc_est)); drawnow;

            % D: busqueda fina +/-1..4 (todas 2s -> factor IIR identico -> |DC| comparables)
            best_v  = v_est;
            best_dc = abs(dc_est);
            for delta = [-4 -3 -2 -1 1 2 3 4]
                v_try = max(0, min(255, v_est + delta));
                if v_try == best_v, continue; end
                if esCMPos, ok=aplicarVDAC(v_try,vOtra); else, ok=aplicarVDAC(vOtra,v_try); end
                if ~ok, break; end
                dc_try = medirDC(2.0);
                logMsg(sprintf('AutoCal %s: v=%d  DC=%.1f mV', nom, v_try, dc_try)); drawnow;
                if abs(dc_try) < best_dc
                    best_dc = abs(dc_try); best_v = v_try;
                end
            end

            % E: aplicar mejor, verificacion final 5s (solo reporte)
            if esCMPos, aplicarVDAC(best_v,vOtra); else, aplicarVDAC(vOtra,best_v); end
            dc_fin = medirDC(5.0);
            logMsg(sprintf('AutoCal %s OK: v=%d  |DC|=%.2f mV (5s)', nom, best_v, dc_fin)); drawnow;
            v_best = best_v;
        end

        % Secuencia: CM+ -> CM- -> Diferencial
        pV_ini = S.servo_vdac_p;
        nV_ini = S.servo_vdac_n;

        logMsg('AutoCal: cambio a CM Positiva (pVRef)');
        cambiarCanal(1); drawnow;
        v_p = calibrarCanal(pV_ini, nV_ini, true);
        if v_p < 0, v_p = pV_ini; logMsg('AutoCal CM+: sin resultado, mantiene original'); end

        logMsg('AutoCal: cambio a CM Negativa (nVRef)');
        cambiarCanal(2); drawnow;
        v_n = calibrarCanal(nV_ini, v_p, false);
        if v_n < 0, v_n = nV_ini; logMsg('AutoCal CM-: sin resultado, mantiene original'); end

        logMsg('AutoCal: volviendo a Diferencial');
        cambiarCanal(0); drawnow;

        % Guardar en servo_configs para el PGA activo
        code = S.pga_gain_code;
        nueva = struct('pga_code',code,'p_vref',v_p,'n_vref',v_n);
        idx_cfg = findServoCfgByCode(code);
        if isempty(idx_cfg)
            if isempty(S.servo_configs), S.servo_configs=nueva;
            else, S.servo_configs(end+1)=nueva; end
        else, S.servo_configs(idx_cfg)=nueva; end
        S.vdac_p_ref=v_p; S.vdac_n_ref=v_n;
        saveConfig();
        logMsg(sprintf('AutoCal DONE: PGA %dx  pVRef=%d  nVRef=%d', pgaCodeToGain(code), v_p, v_n));
        lblCalSt.Text = sprintf('p=%d n=%d', v_p, v_n);

        S.calRunning     = false;
        S.streamEnabled  = wasStreamEnabled;
        updateBtnStates();
        drawnow;
    end

    % =====================================================================
    % AMux — modo de vista
    % =====================================================================
    function onMuxChanged()
        ch = find(strcmp(ddMux.Items, ddMux.Value), 1) - 1;
        S.amux_ch = ch;
        if S.isConnected
            try
                write(S.sp, uint8([0xA7, uint8(ch)]), 'uint8');
            catch ex
                logMsg('AMux: error UART — ' + string(ex.message));
            end
        end
        updateVRefEnableState();
        logMsg(sprintf('Modo: %s (ch=%d)', ddMux.Value, ch));
    end

    function updateVRefEnableState()
        en = (S.amux_ch ~= 0);
        edtPVRef.Enable      = en;
        edtNVRef.Enable      = en;
        btnApplyServo.Enable = en;
        btnGuardarCfg.Enable = en;
        btnAutoCal.Enable    = S.isConnected && ~S.calRunning;
    end

    % =====================================================================
    % Configs de servo por ganancia PGA
    % =====================================================================
    function idx = findServoCfgByCode(code)
        idx = [];
        for ii = 1:numel(S.servo_configs)
            if S.servo_configs(ii).pga_code == code
                idx = ii; return;
            end
        end
    end

    function onGuardarCfgPGA()
        try
            code = S.pga_gain_code;
            pV = double(S.servo_vdac_p);
            nV = double(S.servo_vdac_n);
            nueva = struct('pga_code', code, 'p_vref', pV, 'n_vref', nV);
            idx = findServoCfgByCode(code);
            if isempty(idx)
                if isempty(S.servo_configs), S.servo_configs = nueva;
                else, S.servo_configs(end+1) = nueva; end
                logMsg(sprintf('Cfg guardada: PGA %dx  pV=%d  nV=%d', pgaCodeToGain(code),pV,nV));
            else
                S.servo_configs(idx) = nueva;
                logMsg(sprintf('Cfg actualizada: PGA %dx  pV=%d  nV=%d', pgaCodeToGain(code),pV,nV));
            end
            edtPVRef.Value = pV;
            edtNVRef.Value = nV;
            saveConfig();
        catch ex
            logMsg('ERROR Guardar cfg PGA: ' + string(ex.message));
        end
    end

    function onEditarCfgs()
        try
            if isempty(S.servo_configs)
                logMsg('No hay configuraciones de servo guardadas'); return;
            end
            gainNames = {'1x','2x','4x','8x','16x','24x','32x','48x','50x'};
            nCfg = numel(S.servo_configs);
            data = cell(nCfg, 3);
            for ii = 1:nCfg
                c = S.servo_configs(ii);
                gIdx = max(1, min(9, c.pga_code + 1));
                data{ii,1} = gainNames{gIdx};
                data{ii,2} = double(c.p_vref);
                data{ii,3} = double(c.n_vref);
            end
            dlg = uifigure('Name','Presets Servo DC por PGA',...
                'Position',[200 350 620 230]);
            tbl = uitable(dlg,'Data',data,...
                'ColumnName',{'PGA','pVRef','nVRef'},...
                'ColumnEditable',[false true true],...
                'ColumnWidth',{80 80 80},...
                'Position',[8 48 604 150]);
            uibutton(dlg,'Text','Guardar cambios','Position',[8 8 130 32],...
                'BackgroundColor',CLR_ON,'FontWeight','bold',...
                'ButtonPushedFcn',@(~,~)guardarCambios());
            uibutton(dlg,'Text','Eliminar seleccion','Position',[148 8 130 32],...
                'BackgroundColor',CLR_DEL,'FontColor',[1 1 1],...
                'ButtonPushedFcn',@(~,~)eliminarSeleccion());
            uibutton(dlg,'Text','Cerrar','Position',[530 8 80 32],...
                'ButtonPushedFcn',@(~,~)delete(dlg));
        catch ex
            logMsg('ERROR Editar cfg: ' + string(ex.message));
        end

        function guardarCambios()
            try
                d = tbl.Data;
                nRows = size(d,1);
                for jj = 1:nRows
                    if iscell(d)
                        raw2 = d{jj,2}; raw3 = d{jj,3};
                    else
                        raw2 = d{jj,2}; raw3 = d{jj,3};
                        if iscell(raw2), raw2=raw2{1}; end
                        if iscell(raw3), raw3=raw3{1}; end
                    end
                    if ischar(raw2)||isstring(raw2), raw2=str2double(raw2); end
                    if ischar(raw3)||isstring(raw3), raw3=str2double(raw3); end
                    S.servo_configs(jj).p_vref = max(0,min(255,round(double(raw2))));
                    S.servo_configs(jj).n_vref = max(0,min(255,round(double(raw3))));
                end
                saveConfig();
                cfgIdx = findServoCfgByCode(S.pga_gain_code);
                if ~isempty(cfgIdx)
                    edtPVRef.Value = double(S.servo_configs(cfgIdx).p_vref);
                    edtNVRef.Value = double(S.servo_configs(cfgIdx).n_vref);
                end
                logMsg('Presets servo guardados');
                delete(dlg);
            catch ex
                logMsg('ERROR guardar cambios: ' + string(ex.message));
            end
        end

        function eliminarSeleccion()
            try
                sel = tbl.Selection;
                if isempty(sel), logMsg('Selecciona una fila para eliminar'); return; end
                row = sel(1);
                if row < 1 || row > numel(S.servo_configs), return; end
                code = S.servo_configs(row).pga_code;
                S.servo_configs(row) = [];
                saveConfig();
                logMsg(sprintf('Preset servo PGA %dx eliminado', pgaCodeToGain(code)));
                delete(dlg);
            catch ex
                logMsg('ERROR eliminar: ' + string(ex.message));
            end
        end
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
