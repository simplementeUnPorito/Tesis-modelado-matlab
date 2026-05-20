function geophone_scope_simple()
% geophone_scope_simple — Interfaz PSoC5, sistema de entidades y muestras
%
% Protocolo RX — 5 bytes todos los paquetes:
%   Data:     [0x56][0x00][b2][b1][b0]  int24 big-endian signed
%   HB:       [0x56][0x01][pga_code][vdac_val][tx_mode]
%   CFG-ADC:  [0x56][0x02][res][fsH][fsL]
%   CFG-PGA:  [0x56][0x03][pga_code][vrefH][vrefL]
%   CFG-VREF: [0x56][0x04][pgavdac_code][vdac_val][0x00]
%   ACK:      [0x56][0x07][cmd][val][0x00]  (nuevo)
%             [0x56][0x07][val][0x00][0x00] (legacy)
%
% Comandos TX → PSoC: [0xAB][cmd][param][cmd XOR param]
%   [0xAB][0xA5][0][0xA5]       request config
%   [0xAB][0xA1][en][cs]        stream PSoC 0=off, 1=on
%   [0xAB][0xA6][code][cs]      set PGAgain (0-8)
%   [0xAB][0xA8][mode][cs]      set tx_mode (0=crudo, 1=filter)
%   [0xAB][0xA9][code][cs]      set PGAvdac (0-8)
%   [0xAB][0xAA][v][cs]         set VDAC (0-255)
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
    S.streamStartT0= uint64(0);
    S.noDataWarned = false;
    S.parseState   = 0;
    S.pktBuf       = zeros(5,1,'uint8');
    S.pktIdx       = 0;

    S.filtZi = [];  % estado del filtro FIR incremental

    % Config recibida del PSoC (via paquetes 0x02 y 0x03)
    S.configReceived  = false;
    S.adc_bits        = 18;
    S.pktDataBytes    = 3;     % protocolo fijo: int24
    S.pktTotalBytes   = 5;     % todos los paquetes PSoC son de 5 bytes
    S.pga_gain_code   = 4;     % código PGA (0=1x 1=2x 2=4x 3=8x 4=16x 5=24x 6=32x 7=48x 8=50x)
    S.vref_halfmv     = 2500;
    S.scale = S.vref_halfmv / 2^(S.adc_bits - 1);  % mV/count — ADC signed right-justified

    S.maxPoints   = 9000;
    S.nVec        = zeros(0,1);
    S.notchVec    = zeros(0,1);
    S.filtVec     = zeros(0,1);
    S.frameCount  = 0;
    S.rxJunkBytes = 0;
    S.rxBadTypes  = 0;
    S.rxFrames    = 0;

    S.fs    = 1020;
    S.tWin  = 5000;

    S.yAuto  = true;   S.yMin = -100;  S.yMax = 100;
    S.tAuto  = true;   S.tMin = 0;     S.tMax = 5000;
    S.showRaw = true;  % visibilidad de la línea cruda

    S.filtCmd  = '';
    S.filtB    = [];
    S.dcRemove = false;
    S.yRange   = 100;
    S.lineCancel = false;
    S.lineF0 = 50;
    S.lineHarmMax = 1;
    S.lineMu = 0.001;
    S.lineEpsilon = 1e-6;   % factor de regularizacion NLMS
    S.lineWeights = [];

    S.entidades   = struct('nombre',{},'fs',{},'observ',{},'fMin',{},'fMax',{},'ganancia',{});
    S.entActiva   = 0;
    S.treeMap     = {};
    S.entCollapsed = logical([]);   % true = muestras ocultas para esa entidad

    % VRef — referencia VDAC única (single-ended)
    S.vdac_ref     = 148;   % valor VDAC (0x94 default)
    S.servo_vdac   = 148;   % valor confirmado por PSoC (via heartbeat/ACK)
    S.vdac_pga_code = 0;    % PGAvdac: 0=1x ... 8=50x
    S.servo_vdac_pga_code = 0;
    S.vdac_auto_gain = true;
    S.vref_target_v = double(S.vdac_ref) * 0.004;
    S.psoc_tx_mode = 0;     % 0=crudo ADC, 1=salida Filter (comando 0xA8)

    % Pending command — trackeo y retry automatico
    S.pend_type    = '';    % 'PGA' | 'PGAVDAC' | 'VDAC' | ''
    S.pend_val     = 0;
    S.pend_t0      = 0;     % tic del primer envio
    S.pend_active  = false;
    S.pend_bytes   = [];    % bytes a retransmitir
    S.pend_retries = 0;     % intentos realizados (0 = primer envio)
    S.pend_retry_t = 0;     % tic del ultimo intento

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
                    'lineCancel','lineF0','lineHarmMax','lineMu','lineEpsilon',...
                    'vdac_ref','vdac_pga_code','vdac_auto_gain','vref_target_v','psoc_tx_mode'};
            for k = 1:numel(flds)
                if isfield(cfg,flds{k}), S.(flds{k}) = cfg.(flds{k}); end
            end
            if ~isfield(cfg,'vref_target_v')
                gtbl = [1, 2, 4, 8, 16, 24, 32, 48, 50];
                ctmp = max(0, min(8, round(double(S.vdac_pga_code))));
                S.vref_target_v = double(S.vdac_ref) * 0.004 * gtbl(ctmp + 1);
            end
            if isfield(cfg,'com'),       defCom      = cfg.com;       end
            if isfield(cfg,'baud'),      defBaud     = cfg.baud;      end
            if isfield(cfg,'entidades'),    S.entidades    = cfg.entidades;    end
            if isfield(cfg,'entCollapsed'), S.entCollapsed = cfg.entCollapsed; end
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
    %   pConn    y=1053 h=116
    %   pServo   y=913 h=132
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
    btnShowRaw = uibutton(pCtrl,'Text','Ver crudo','Position',[8 48 70 26],...
        'ButtonPushedFcn',@(~,~)onToggleRaw());
    btnLineCancel = uibutton(pCtrl,'Text','Cancelar línea','Position',[82 48 86 26],...
        'FontSize',8,'ButtonPushedFcn',@(~,~)onToggleLineCancel(),...
        'Tooltip','Cancelador LMS de línea: 50 Hz y armónicos hasta H, limitado por Nyquist');
    uilabel(pCtrl,'Text','H:','Position',[174 52 12 18],'FontSize',8);
    edtLineHarm = uieditfield(pCtrl,'numeric','Value',S.lineHarmMax,...
        'Limits',[1 50],'RoundFractionalValues','on',...
        'Position',[188 50 28 22],'FontSize',8,...
        'ValueChangedFcn',@(~,~)onLineHarmChanged());
    btnTxMode = uibutton(pCtrl,'Text','PSoC: Crudo','Position',[8 12 86 22],...
        'FontSize',8,'BackgroundColor',CLR_OFF,'FontColor',[0 0 0],...
        'Tooltip','Alterna entre dato crudo ADC y salida del Filter DFB en el PSoC',...
        'ButtonPushedFcn',@(~,~)onToggleTxMode());
    uilabel(pCtrl,'Text','fs:','Position',[100 14 20 18],'FontSize',8);
    edtFs = uieditfield(pCtrl,'text','Value',num2str(S.fs),...
        'Position',[122 12 58 22],'FontSize',8,...
        'ValueChangedFcn',@(~,~)onFsChanged());
    uilabel(pCtrl,'Text','Hz','Position',[184 14 24 18],'FontSize',8);

    % --- VRef DC ---
    pServo = uipanel(fig,'Title','VRef DC','Position',[RX 913 RW 132]);
    uilabel(pServo,'Text','Vref:','Position',[6 84 36 18],'FontSize',8);
    edtVRef = uieditfield(pServo,'numeric','Value',S.vref_target_v,...
        'Limits',[0 51],'ValueDisplayFormat','%.3f',...
        'Position',[44 82 62 22],'FontSize',8,...
        'ValueChangedFcn',@(~,~)onVdacUiChanged());
    uilabel(pServo,'Text','V','Position',[110 84 12 18],'FontSize',8);
    chkVdacAuto = uicheckbox(pServo,'Text','Auto','Value',S.vdac_auto_gain,...
        'Position',[126 84 48 18],'FontSize',8,...
        'ValueChangedFcn',@(~,~)onVdacUiChanged());
    btnApplyServo = uibutton(pServo,'Text','OK','Position',[176 80 42 26],...
        'FontSize',8,'BackgroundColor',CLR_ON,'FontColor',[0 0 0],...
        'ButtonPushedFcn',@(~,~)onApplyServo());
    uilabel(pServo,'Text','PGA:','Position',[6 54 32 18],'FontSize',8);
    ddVdacPGA = uidropdown(pServo,'Items',pgaGainItems(),...
        'Value',num2str(pgaCodeToGain(S.vdac_pga_code)),...
        'Position',[44 52 62 22],'FontSize',8,...
        'ValueChangedFcn',@(~,~)onVdacUiChanged());
    uilabel(pServo,'Text','VDAC:','Position',[112 54 34 18],'FontSize',8);
    lblVdacCalc = uilabel(pServo,'Text','0x00 (0)',...
        'Position',[148 54 74 18],'FontSize',8,'FontWeight','bold');
    uilabel(pServo,'Text','DAC:','Position',[6 28 32 18],'FontSize',8);
    lblVdacDac = uilabel(pServo,'Text','0.000 V',...
        'Position',[44 28 76 18],'FontSize',8);
    uilabel(pServo,'Text','Out:','Position',[126 28 28 18],'FontSize',8);
    lblVdacOut = uilabel(pServo,'Text','0.000 V',...
        'Position',[154 28 66 18],'FontSize',8);
    uilabel(pServo,'Text','PSoC:','Position',[6 6 36 18],'FontSize',8);
    lblVdac = uilabel(pServo,'Text',sprintf('0x%02X (%d)',S.servo_vdac,S.servo_vdac),...
        'Position',[44 6 78 18],'FontSize',8,'FontWeight','bold');
    lblVdacPga = uilabel(pServo,'Text',sprintf('PGA %dx',pgaCodeToGain(S.servo_vdac_pga_code)),...
        'Position',[126 6 92 18],'FontSize',8,'FontWeight','bold');

    % --- Filtro FIR + DC ---
    pFilt = uipanel(fig,'Title','Filtro FIR MATLAB','Position',[RX 649 RW 124]);
    uilabel(pFilt,'Text','Cmd (retorna b):','Position',[8 80 140 18]);
    edtFiltCmd = uieditfield(pFilt,'text','Value',S.filtCmd,'Position',[8 56 148 24]);
    % Botón toggle único: "Aplicar filtro" / "Quitar filtro"
    btnFiltToggle = uibutton(pFilt,'Text','Aplicar filtro',...
        'Position',[160 28 52 52],'FontSize',8,...
        'ButtonPushedFcn',@(~,~)onFiltToggle());
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
    updateLineCancelBtn();
    updateBtnStates();
    syncFsUi();
    updateInfo();
    edtVRef.Value = double(S.vref_target_v);
    chkVdacAuto.Value = logical(S.vdac_auto_gain);
    ddVdacPGA.Value = num2str(pgaCodeToGain(S.vdac_pga_code));
    updateVdacCalcDisplay();
    refreshTree();
    if ~S.tAuto, try ax1.XLim=[S.tMin S.tMax]; catch, end; end
    if ~S.yAuto, try ax1.YLim=[S.yMin S.yMax]; catch, end; end
    if ~isempty(S.filtB), edtFiltCmd.Value=S.filtCmd; end
    updateFiltBtn();

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
    function items = pgaGainItems()
        items = {'1','2','4','8','16','24','32','48','50'};
    end

    function [code,gain,byte,vdac_v,out_v,clamped] = calcVdacSetting(target_v, forcedCode)
        gains = [1, 2, 4, 8, 16, 24, 32, 48, 50];
        target_v = double(target_v);
        if ~isfinite(target_v), target_v = 0; end
        target_v = max(0, target_v);

        if nargin < 2 || isempty(forcedCode)
            code = 8;
            for kk = 1:numel(gains)
                if target_v / gains(kk) <= 1.020 + eps
                    code = kk - 1;
                    break;
                end
            end
        else
            code = max(0, min(8, round(double(forcedCode))));
        end

        gain = gains(code + 1);
        dac_target = target_v / gain;
        byte = round(dac_target / 0.004);
        clamped = byte < 0 || byte > 255 || dac_target > 1.020;
        byte = max(0, min(255, byte));
        vdac_v = byte * 0.004;
        out_v = vdac_v * gain;
    end

    function [code,gain,byte,vdac_v,out_v,clamped] = currentVdacSetting()
        if logical(chkVdacAuto.Value)
            [code,gain,byte,vdac_v,out_v,clamped] = calcVdacSetting(edtVRef.Value, []);
        else
            forcedCode = pgaGainToCode(str2double(ddVdacPGA.Value));
            [code,gain,byte,vdac_v,out_v,clamped] = calcVdacSetting(edtVRef.Value, forcedCode);
        end
    end

    function onVdacUiChanged()
        updateVdacCalcDisplay();
    end

    function updateVdacCalcDisplay()
        [~,gain,byte,vdac_v,out_v,clamped] = currentVdacSetting();
        if logical(chkVdacAuto.Value)
            ddVdacPGA.Value = num2str(gain);
        end
        ddVdacPGA.Enable = S.isConnected && ~logical(chkVdacAuto.Value);
        lblVdacCalc.Text = sprintf('0x%02X (%d)', byte, byte);
        lblVdacDac.Text  = sprintf('%.3f V', vdac_v);
        lblVdacOut.Text  = sprintf('%.3f V', out_v);
        lblVdac.Text     = sprintf('0x%02X (%d)', S.servo_vdac, S.servo_vdac);
        lblVdacPga.Text  = sprintf('PGA %dx', pgaCodeToGain(S.servo_vdac_pga_code));
        if clamped
            lblVdacOut.FontColor = [0.85 0.15 0.15];
        else
            lblVdacOut.FontColor = [0 0 0];
        end
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

    function s = fsToText(fsVal)
        if ~isfinite(fsVal) || fsVal <= 0
            s = '0';
        elseif abs(fsVal - round(fsVal)) < 1e-9
            s = sprintf('%.0f', fsVal);
        else
            s = sprintf('%.6g', fsVal);
        end
    end

    function syncFsUi()
        try
            edtFs.Value = fsToText(S.fs);
        catch
        end
    end

    function [scale,unit,fmt] = timeUnitForMs(refMs)
        refMs = abs(double(refMs));
        if ~isfinite(refMs), refMs = 0; end
        if refMs < 1000
            scale = 1; unit = 'ms'; fmt = '%.0f';
        elseif refMs < 60000
            scale = 1000; unit = 's';
            if refMs < 10000, fmt = '%.2f'; else, fmt = '%.1f'; end
        elseif refMs < 3600000
            scale = 60000; unit = 'min';
            if refMs < 600000, fmt = '%.2f'; else, fmt = '%.1f'; end
        else
            scale = 3600000; unit = 'h';
            if refMs < 36000000, fmt = '%.2f'; else, fmt = '%.1f'; end
        end
    end

    function s = formatTimeMs(tMs)
        [scale,unit,~] = timeUnitForMs(tMs);
        val = double(tMs) / scale;
        if strcmp(unit,'ms')
            s = sprintf('%.0f ms', val);
        elseif abs(val) < 10
            s = sprintf('%.2f %s', val, unit);
        elseif abs(val) < 100
            s = sprintf('%.1f %s', val, unit);
        else
            s = sprintf('%.0f %s', val, unit);
        end
    end

    function updateTimeAxisUnits()
        try
            xl = ax1.XLim;
            refMs = max(abs(double(xl)));
            [scale,unit,fmt] = timeUnitForMs(refMs);
            ticks = ax1.XTick;
            ax1.XTickLabel = cellstr(compose(fmt, ticks ./ scale));
            xlabel(ax1, sprintf('tiempo (%s)', unit));
        catch
        end
    end

    function resetLineCanceller()
        S.lineWeights = [];
    end

    function hUse = activeLineHarmonics()
        fsVal = double(S.fs);
        f0Val = double(S.lineF0);
        hReq = max(1, round(double(S.lineHarmMax)));
        if ~isfinite(fsVal) || fsVal <= 0 || ~isfinite(f0Val) || f0Val <= 0
            hUse = 0;
            return;
        end
        hNyq = floor((fsVal/2 - 1e-9) / f0Val);
        hUse = max(0, min(hReq, hNyq));
    end

    function y = applyLineCanceller(x, nIdx)
        % Cancelador adaptativo NLMS de ruido de linea.
        % Estima y cancela f0 y sus armonicos h=1..hUse usando una base
        % senoidal: ref = [sin(h*phi), cos(h*phi)] para h = 1..hUse.
        % Actualizacion NLMS: w += mu * e * ref / (epsilon + ref'*ref)
        % Nota: ref'*ref = hUse siempre (suma de sin^2 + cos^2 por armonico),
        % por lo que el denominador NLMS es constante en epsilon + hUse.
        y = double(x(:));
        if ~S.lineCancel || isempty(y)
            return;
        end

        hUse = activeLineHarmonics();
        if hUse < 1
            return;
        end

        L = 2 * hUse;   % 2 coeficientes (sin + cos) por armonico
        if numel(S.lineWeights) ~= L
            % Reinicializar pesos si cambio el numero de armonicos
            S.lineWeights = zeros(L, 1);
        end

        fsVal   = double(S.fs);
        f0Val   = double(S.lineF0);
        mu      = double(S.lineMu);
        epsilon = double(S.lineEpsilon);
        if ~isfinite(mu)      || mu      <= 0, mu      = 0.001; end
        if ~isfinite(epsilon) || epsilon <= 0, epsilon = 1e-6;  end
        mu = min(mu, 0.5);

        harmonics = (1:hUse).';
        w  = double(S.lineWeights(:));
        n0 = double(nIdx(:)) - 1;   % indices 0-based desde frameCount
        if numel(n0) ~= numel(y)
            n0 = (0:numel(y)-1).';
        end

        for ii = 1:numel(y)
            % Vector de referencia senoidal para la muestra ii
            phase = 2*pi * f0Val * n0(ii) / fsVal;
            ref = zeros(L, 1);
            ref(1:2:end) = sin(harmonics * phase);
            ref(2:2:end) = cos(harmonics * phase);

            % Estimacion del ruido de linea y error residual
            noiseEst = w.' * ref;
            err      = y(ii) - noiseEst;

            % Actualizacion NLMS (mas estable que LMS puro en tiempo real)
            w = w + (mu * err / (epsilon + ref.' * ref)) * ref;

            y(ii) = err;   % senal cancelada = error residual
        end

        S.lineWeights = w;
    end

    function bytes = psocCmd(cmd, param)
        cmd = uint8(cmd);
        param = uint8(param);
        bytes = [uint8(0xAB), cmd, param, bitxor(cmd, param)];
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

    function updateFiltBtn()
        % Sincroniza el boton toggle FIR segun si hay filtro activo o no
        lblFiltSt.Text = filtStatusStr();
        if isempty(S.filtB)
            btnFiltToggle.Text = 'Aplicar filtro';
            btnFiltToggle.BackgroundColor = CLR_OFF;
            btnFiltToggle.FontColor = [0 0 0];
            btnFiltToggle.FontWeight = 'normal';
        else
            btnFiltToggle.Text = 'Quitar filtro';
            btnFiltToggle.BackgroundColor = CLR_STOP;
            btnFiltToggle.FontColor = [1 1 1];
            btnFiltToggle.FontWeight = 'bold';
        end
    end

    function onFiltToggle()
        % Toggle unico: aplica si no hay filtro, quita si ya hay uno activo
        if isempty(S.filtB)
            onApplyFilter();
        else
            onQuitFilter();
        end
    end

    function updateLineCancelBtn()
        if S.lineCancel
            btnLineCancel.Text='Línea ON';
            btnLineCancel.BackgroundColor=CLR_ON; btnLineCancel.FontColor=[0 0 0];
            btnLineCancel.FontWeight='bold';
        else
            btnLineCancel.Text='Cancelar línea';
            btnLineCancel.BackgroundColor=CLR_OFF; btnLineCancel.FontColor=[0 0 0];
            btnLineCancel.FontWeight='normal';
        end
        try, edtLineHarm.Value = max(1, min(50, round(double(S.lineHarmMax)))); catch, end
    end

    function updateBtnStates()
        c=S.isConnected; r=S.streamEnabled;
        edtCom.Enable=~c; edtBaud.Enable=~c;
        if c, btnConn.Text='Desconectar'; btnConn.BackgroundColor=CLR_STOP; btnConn.FontColor=[1 1 1];
        else, btnConn.Text='Conectar';    btnConn.BackgroundColor=CLR_CONN; btnConn.FontColor=[1 1 1]; end
        if r, btnStream.Text='STOP'; btnStream.BackgroundColor=CLR_STOP; btnStream.FontColor=[1 1 1];
        else, btnStream.Text='START';btnStream.BackgroundColor=CLR_START;btnStream.FontColor=[0 0 0]; end
        btnStream.Enable = c;
        edtFs.Enable = true;
        btnLineCancel.Enable = true;
        edtLineHarm.Enable = true;
        tieneEnt  = S.entActiva>=1 && S.entActiva<=numel(S.entidades);
        tieneDatos= ~isempty(S.nVec);
        btnGuardar.Enable = tieneEnt && tieneDatos && ~r;
        ddPGA.Enable     = c;
        btnSetPGA.Enable = c;
        edtMaxPts.Enable  = ~r;
        edtVRef.Enable    = c;
        chkVdacAuto.Enable = c;
        ddVdacPGA.Enable = c && ~logical(chkVdacAuto.Value);
        btnApplyServo.Enable = c;
        btnTxMode.Enable  = c;
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
        if S.logFid<=0||isempty(raw), return; end
        h = sprintf('%02X ', raw(:));
        fprintf(S.logFid,'  RX[%d]: %s\n', numel(raw), strtrim(h));
    end
    function logTX(bytes, desc)
        if S.logFid>0
            h  = sprintf('%02X ', bytes);
            ts = datestr(now,'HH:MM:SS.FFF');
            fprintf(S.logFid,'[%s] TX [%s]  %s\n', ts, strtrim(h), char(desc));
        end
    end
    function logParsed(np)
        if S.logFid<=0||np==0, return; end
        fprintf(S.logFid,'  PARSED: %d samples  frames=%d  junk=%d  badType=%d\n',...
            np, S.rxFrames, S.rxJunkBytes, S.rxBadTypes);
    end

    % ---------- Tracking de confirmaciones PSoC con retry automatico ----------
    function setPending(tipo, val, bytes)
        if nargin < 3
            bytes = uint8([]);
        end
        S.pend_type    = tipo;
        S.pend_val     = val;
        S.pend_t0      = tic;
        S.pend_active  = true;
        S.pend_bytes   = bytes;
        S.pend_retries = 0;
        S.pend_retry_t = tic;
        if S.logFid>0
            h = sprintf('%02X ', bytes);
            fprintf(S.logFid,'[%s] TX#1 [%s]  %s=%d\n',...
                datestr(now,'HH:MM:SS.FFF'), strtrim(h), tipo, val);
        end
    end

    function checkPending(src, confirmed_val)
        if ~S.pend_active, return; end
        if ~isa(S.pend_t0,'uint64') || ~isa(S.pend_retry_t,'uint64')
            S.pend_t0 = tic;
            S.pend_retry_t = S.pend_t0;
            return;
        end
        elapsed = toc(S.pend_t0);
        matched = strcmp(src, S.pend_type) && (confirmed_val == S.pend_val);
        if matched
            msg = sprintf('OK PSoC confirmo %s=%d en %.2fs (intento %d)',...
                S.pend_type, S.pend_val, elapsed, S.pend_retries+1);
            logMsg(msg);
            if S.logFid>0, fprintf(S.logFid,'[%s] CONF: %s\n',datestr(now,'HH:MM:SS.FFF'),char(msg)); end
            S.pend_active = false;
        elseif toc(S.pend_retry_t) > 0.5 && S.pend_retries < 5
            % Reenviar cada 500ms, hasta 5 reintentos
            S.pend_retries = S.pend_retries + 1;
            S.pend_retry_t = tic;
            if ~isempty(S.pend_bytes) && S.isConnected
                try
                    write(S.sp, S.pend_bytes, 'uint8');
                    msg = sprintf('RETRY %d/5  %s=%d', S.pend_retries, S.pend_type, S.pend_val);
                    logMsg(msg);
                    if S.logFid>0
                        h = sprintf('%02X ', S.pend_bytes);
                        fprintf(S.logFid,'[%s] TX#%d [%s]  %s\n',...
                            datestr(now,'HH:MM:SS.FFF'), S.pend_retries+1, strtrim(h), char(msg));
                    end
                catch
                end
            end
        elseif elapsed > 6.0 && S.pend_retries >= 5
            msg = sprintf('FAIL: PSoC no respondio %s=%d tras 5 intentos — verificar UART RX en PSoC Creator',...
                S.pend_type, S.pend_val);
            logMsg(msg);
            if S.logFid>0, fprintf(S.logFid,'[%s] FAIL: %s\n',datestr(now,'HH:MM:SS.FFF'),char(msg)); end
            S.pend_active = false;
        end
    end
    function updateInfo()
        try, n=numel(S.nVec);
            if isfinite(S.fs) && S.fs > 0
                lblInfo.Text=sprintf('n=%d  t=%s',n,formatTimeMs(n/S.fs*1000));
            else
                lblInfo.Text=sprintf('n=%d  t=--',n);
            end
        catch, end
    end
    function applyFilter()
        S.filtZi = [];
        if isempty(S.notchVec), S.filtVec=zeros(0,1); return; end
        raw_mV = S.notchVec * S.scale;
        if isempty(S.filtB)
            processed = raw_mV;
        else
            minLen = 3*(numel(S.filtB)-1);
            if numel(raw_mV) < max(minLen,4)
                processed = raw_mV;
            else
                try
                    [processed, S.filtZi] = filter(S.filtB, 1, raw_mV);
                catch
                    processed = raw_mV;
                end
            end
        end
        if S.lineCancel
            resetLineCanceller();
            processed = applyLineCanceller(processed, S.nVec);
        end
        S.filtVec = processed;
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
        if S.lineCancel
            newFilt = applyLineCanceller(newFilt, nIdx);
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
        if ~isfinite(S.fs) || S.fs <= 0, return; end
        tms    = double(S.nVec)/S.fs*1000.0;
        raw_mV = S.notchVec*S.scale;
        filt   = S.filtVec;
        if S.dcRemove && ~isempty(filt), filt = filt - mean(filt); end
        set(hRaw,   'XData', tms, 'YData', raw_mV);
        set(hNotch, 'XData', tms, 'YData', filt);
        % Línea de promedio DC (naranja punteada) + etiqueta en panel
        if ~isempty(filt)
            dcMean = mean(filt);
            set(hDCLine, 'XData', [tms(1) tms(end)], 'YData', [dcMean dcMean]);
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
            % Usar percentil 2-98 para ignorar spikes de ruido UART
            if numel(filt) >= 20
                pcts = prctile(filt, [2 98]);
                peak = max(abs(pcts));
            else
                peak = max(abs(filt));
            end
            if peak < 0.1, peak = 0.1; end
            target = peak * 1.5;
            if target > S.yRange, S.yRange = target;
            else, S.yRange = S.yRange*0.97 + target*0.03; end
            S.yRange = max(S.yRange, 1.0);
            try, ax1.YLim=[-S.yRange S.yRange]; catch, end
        end
        updateTimeAxisUnits();
    end
    function saveConfig()
        try
            cfg.fs=S.fs; cfg.com=char(edtCom.Value); cfg.baud=double(edtBaud.Value);
            cfg.maxPoints=S.maxPoints; cfg.tWin=S.tWin;
            cfg.filtCmd=S.filtCmd; cfg.filtB=S.filtB; cfg.yRange=S.yRange;
            cfg.yMin=S.yMin; cfg.yMax=S.yMax; cfg.yAuto=S.yAuto;
            cfg.tMin=S.tMin; cfg.tMax=S.tMax; cfg.tAuto=S.tAuto;
            cfg.dcRemove=S.dcRemove; cfg.showRaw=S.showRaw;
            cfg.lineCancel=S.lineCancel; cfg.lineF0=S.lineF0;
            cfg.lineHarmMax=S.lineHarmMax; cfg.lineMu=S.lineMu; cfg.lineEpsilon=S.lineEpsilon;
            cfg.vdac_ref=S.vdac_ref; cfg.vdac_pga_code=S.vdac_pga_code;
            cfg.vdac_auto_gain=S.vdac_auto_gain; cfg.vref_target_v=S.vref_target_v;
            cfg.psoc_tx_mode=S.psoc_tx_mode;
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
        oldFs = S.fs;
        S.entActiva=tm.entIdx;
        if S.entActiva>=1&&S.entActiva<=numel(S.entidades)
            S.fs=S.entidades(S.entActiva).fs;
            syncFsUi();
            if oldFs ~= S.fs
                resetLineCanceller();
                applyFilter();
            end
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
        replot(); updateInfo(); updateBtnStates();
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
                if S.entActiva == entIdx
                    S.fs = nueva.fs;
                    syncFsUi();
                    resetLineCanceller();
                    applyFilter();
                    replot();
                    updateInfo();
                end
                logMsg(sprintf('Entidad editada: %s (antes: %s)', nombre, nombreViejo));
            else
                if isempty(S.entidades)
                    S.entidades=nueva;
                else
                    S.entidades(end+1)=nueva;
                end
                S.entActiva=numel(S.entidades);
                S.fs=nueva.fs;
                syncFsUi();
                resetLineCanceller();
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
        if ~isfinite(gain), return; end
        code = pgaGainToCode(gain);
        if ~S.isConnected, logMsg('PGA: no conectado'); return; end
        bytes = psocCmd(0xA6, code);
        try
            write(S.sp, bytes, 'uint8');
        catch ex
            logMsg('PGA: error UART — ' + string(ex.message)); return;
        end
        logMsg(sprintf('TX→PSoC  [AB A6 %02X %02X]  PGA=%dx  (retry auto hasta 5x)',uint8(code),bytes(4),gain));
        S.pga_gain_code = code;
        lblPGAGain.Text = pgaGainStr(code);
        lblCfgInfo.Text = sprintf('ADC:%db  fs:%d SPS  PGA:%s  ±%dmV',...
            S.adc_bits, S.fs, pgaGainStr(code), S.vref_halfmv);
        setPending('PGA', code, bytes);
        saveConfig();
    end

    % =====================================================================
    % Callbacks de configuración
    % =====================================================================
    function onToggleLineCancel()
        S.lineCancel = ~logical(S.lineCancel);
        resetLineCanceller();
        applyFilter();
        replot();
        updateInfo();
        updateLineCancelBtn();
        saveConfig();
        hUse = activeLineHarmonics();
        if S.lineCancel
            logMsg(sprintf('Cancelador línea ON: f0=%g Hz, armónicos usados=%d/%d, mu=%g',...
                S.lineF0, hUse, S.lineHarmMax, S.lineMu));
            if hUse < S.lineHarmMax
                logMsg('Cancelador línea: algunos armónicos quedaron fuera por Nyquist/fs');
            end
        else
            logMsg('Cancelador línea OFF');
        end
    end

    function onLineHarmChanged()
        hReq = round(double(edtLineHarm.Value));
        if ~isfinite(hReq) || hReq < 1, hReq = 1; end
        S.lineHarmMax = max(1, min(50, hReq));
        resetLineCanceller();
        applyFilter();
        replot();
        updateInfo();
        updateLineCancelBtn();
        saveConfig();
        logMsg(sprintf('Cancelador línea: hasta armónico %d', S.lineHarmMax));
    end

    function onFsChanged()
        raw = strrep(strtrim(char(edtFs.Value)), ',', '.');
        fsNew = str2double(raw);
        if ~isfinite(fsNew) || fsNew <= 0
            logMsg('fs inválida: ingresa una frecuencia positiva en Hz/SPS');
            syncFsUi();
            return;
        end
        S.fs = fsNew;
        resetLineCanceller();
        if S.entActiva>=1 && S.entActiva<=numel(S.entidades)
            S.entidades(S.entActiva).fs = fsNew;
            actualizarLblEntActiva();
        end
        syncFsUi();
        applyFilter();
        replot();
        updateInfo();
        saveConfig();
        logMsg(sprintf('fs actualizada: %s Hz', fsToText(S.fs)));
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
            updateFiltBtn();
            logMsg(sprintf('FIR aplicado — N=%d  cmd:%s',numel(b)-1,cmd));
        catch e
            logMsg("ERROR filtro: "+string(e.message));
        end
    end
    function onQuitFilter()
        S.filtB=[]; S.filtCmd='';
        applyFilter(); replot(); saveConfig();
        updateFiltBtn(); logMsg("Filtro FIR desactivado.");
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
        logMsg('Solicitando config al PSoC...');
        try
            flush(S.sp);
            write(S.sp, psocCmd(0xA5, 0), 'uint8');
        catch
            logMsg('WARN: no se pudo enviar solicitud de config');
            return;
        end

        t0 = tic; cfgBuf = uint8([]);
        gotType2 = false; gotType3 = false;

        while toc(t0) < 2.0 && (~gotType2 || ~gotType3)
            pause(0.05);
            try
                n = S.sp.NumBytesAvailable;
                if n > 0
                    cfgBuf = [cfgBuf; reshape(read(S.sp, n, 'uint8'), [], 1)]; %#ok<AGROW>
                end
            catch, break; end

            while numel(cfgBuf) >= 5
                idx = find(cfgBuf == uint8(0x56), 1);
                if isempty(idx), cfgBuf = uint8([]); break; end
                cfgBuf = cfgBuf(idx:end);
                if numel(cfgBuf) < 5, break; end
                p      = double(cfgBuf(1:5));
                cfgBuf = cfgBuf(6:end);
                switch p(2)
                    case 2
                        S.adc_bits = p(3);
                        S.fs       = p(4)*256 + p(5);
                        syncFsUi();
                        resetLineCanceller();
                        gotType2   = true;
                    case 3
                        S.pga_gain_code = p(3);
                        S.vref_halfmv   = p(4)*256 + p(5);
                        gotType3        = true;
                    case 4
                        if p(3) <= 8
                            S.servo_vdac_pga_code = p(3);
                            S.vdac_pga_code = p(3);
                            S.servo_vdac = p(4);
                            S.vdac_ref = p(4);
                            updateVdacCalcDisplay();
                        end
                    % tipos 5/6 ignorados (firmware viejo) — no crash
                end
            end
        end

        if gotType2 && gotType3
            S.pktDataBytes = 3;
            S.pktTotalBytes = 5;
            S.scale = S.vref_halfmv / 2^(S.adc_bits - 1);
            syncFsUi();
            ddPGA.Value     = num2str(pgaCodeToGain(S.pga_gain_code));
            lblPGAGain.Text = pgaGainStr(S.pga_gain_code);
            updateVdacCalcDisplay();
            lblCfgInfo.Text = sprintf('ADC:%db  fs:%d SPS  PGA:%s  ±%dmV',...
                S.adc_bits, S.fs, pgaGainStr(S.pga_gain_code), S.vref_halfmv);
            S.configReceived = true;
            logMsg(sprintf('Config OK: ADC=%d bits  fs=%d SPS  PGA=%s  Vref=±%dmV  scale=%.3e mV/cnt',...
                S.adc_bits, S.fs, pgaGainStr(S.pga_gain_code), S.vref_halfmv, S.scale));
        else
            logMsg('WARN: config incompleta — usando defaults');
            lblCfgInfo.Text = 'Config: defaults (PSoC no respondió)';
        end
        try, flush(S.sp); catch, end
        S.rxBuf = uint8([]); S.parseState = 0; S.pktIdx = 0;
        S.pktBuf = zeros(5,1,'uint8');
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
                S.pktBuf=zeros(5,1,'uint8'); S.pktIdx=0;
                S.tickCount=0; S.totalBytes=0;
                S.rxJunkBytes=0; S.rxBadTypes=0; S.rxFrames=0;
                S.streamStartT0=uint64(0); S.noDataWarned=false;
                lname=fullfile(logsDir,sprintf('scope_%s.log',datestr(now,'yyyymmdd_HHMMSS')));
                S.logFid=fopen(lname,'w');
                if S.logFid>0
                    fprintf(S.logFid,'=== geophone_scope_simple — %s ===\n',datestr(now));
                    fprintf(S.logFid,'Log: %s\n', lname);
                    fprintf(S.logFid,'Puerto: %s @ %d baud\n', com, baud);
                end
                lblStat.Text='CONECTADO: '+com;
                logMsg("Conectado "+com+" @ "+string(baud));
                logMsg("Log: "+string(lname));
                logMsg("DIAG: si PGA/VDAC no responden → verificar en PSoC Creator que UART_PC tiene RX habilitado con buffer > 1");
                requestAndParseConfig();
                saveConfig(); startStreamTimer();
            catch e
                S.sp=[]; S.isConnected=false;
                logMsg("Error: "+string(e.message));
            end
        else
            stopStreamTimer(); S.streamEnabled=false;
            try
                if ~isempty(S.sp)
                    write(S.sp, psocCmd(0xA1, 0), 'uint8');
                    pause(0.02);
                end
            catch, end
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
    function ok = sendStreamCommand(enableStream)
        ok = false;
        if ~S.isConnected || isempty(S.sp), logMsg("No conectado."); return; end
        en = uint8(enableStream ~= 0);
        bytes = psocCmd(0xA1, en);
        try
            write(S.sp, bytes, 'uint8');
        catch ex
            logMsg('Stream: error UART — ' + string(ex.message)); return;
        end
        if S.logFid>0
            fprintf(S.logFid,'[%s] TX STREAM: %02X %02X %02X %02X\n',...
                datestr(now,'HH:MM:SS.FFF'), bytes(1), bytes(2), bytes(3), bytes(4));
        end
        ok = true;
    end

    function onStreamToggle(~,~)
        if ~S.isConnected, logMsg("No conectado."); return; end
        if ~S.streamEnabled
            if ~sendStreamCommand(1), return; end
            S.rxBuf=uint8([]); S.parseState=0;
            S.pktBuf=zeros(5,1,'uint8'); S.pktIdx=0;
            S.totalBytes=0; S.rxJunkBytes=0; S.rxBadTypes=0; S.rxFrames=0;
            S.streamStartT0=tic; S.noDataWarned=false;
            S.streamEnabled=true; logMsg("--- Stream ON ---");
        else
            if ~sendStreamCommand(0), return; end
            S.streamEnabled=false; logMsg("--- Stream OFF ---");
        end
        updateBtnStates();
    end
    function onClear(~,~)
        S.notchVec=[]; S.filtVec=[]; S.nVec=[]; S.frameCount=0; S.filtZi=[];
        resetLineCanceller();
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
        try
            onStreamTickImpl();
        catch e
            if S.logFid>0
                fprintf(S.logFid,'[%s] ERR timer: %s\n',datestr(now,'HH:MM:SS.FFF'),e.message);
            end
            S.rxBuf=uint8([]); S.parseState=0; S.pktIdx=0;
            logMsg('ERR timer UART — parser reiniciado: ' + string(e.message));
        end
    end

    function onStreamTickImpl()
        if ~S.isConnected||isempty(S.sp), return; end
        S.tickCount=S.tickCount+1;

        % Chequeo periódico de confirmaciones pendientes
        if S.pend_active
            checkPending('', -1);  % solo dispara el timeout si ya pasaron 8s
        end

        nAvail=S.sp.NumBytesAvailable;
        logTick(nAvail);
        if nAvail<=0
            if S.streamEnabled && S.totalBytes==0 && ~S.noDataWarned && ...
                    isa(S.streamStartT0,'uint64') && toc(S.streamStartT0) > 2.0
                logMsg('SIN RX: COM abierto pero entraron 0 bytes. Reprogramar/verificar PSoC UART TX y baud.');
                if S.logFid>0
                    fprintf(S.logFid,'[%s] NO_RX_AFTER_START\n',datestr(now,'HH:MM:SS.FFF'));
                end
                S.noDataWarned=true;
            end
            return;
        end
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
        VALID_TYPES = uint8([0, 1, 2, 3, 4, 7]);
        while i<=n
            b=S.rxBuf(i);
            switch S.parseState
                case 0  % buscar sync 0x56
                    if b==uint8(0x56)
                        S.pktBuf(1)=b; S.pktIdx=1; S.parseState=1;
                    else
                        S.rxJunkBytes = S.rxJunkBytes + 1;
                    end
                    i=i+1;
                case 1  % validar tipo (byte 2)
                    if any(b==VALID_TYPES)
                        S.pktIdx=2; S.pktBuf(2)=b; S.parseState=2; i=i+1;
                    else
                        S.rxBadTypes = S.rxBadTypes + 1;
                        S.parseState=0;
                        if b~=uint8(0x56), i=i+1; end
                    end
                case 2  % acumular bytes restantes
                    S.pktIdx=S.pktIdx+1; S.pktBuf(S.pktIdx)=b; i=i+1;
                    if S.pktIdx==S.pktTotalBytes
                        pkt=double(S.pktBuf(1:S.pktTotalBytes));
                        S.rxFrames = S.rxFrames + 1;
                        switch pkt(2)
                            case 0  % data — int24 big-endian signed
                                u = pkt(3)*65536 + pkt(4)*256 + pkt(5);
                                v = u - (pkt(3)>=128)*16777216;
                                newNotch(end+1,1)=v; %#ok<AGROW>
                            case 1  % heartbeat — lleva estado PSoC
                                hb_pga  = pkt(3);
                                hb_vdac = pkt(4);
                                hb_mode = pkt(5);
                                % Validar que es un HB real (no desync): pga<=8, mode<=1
                                if hb_pga <= 8 && hb_mode <= 1
                                    S.pga_gain_code = hb_pga;
                                    lblPGAGain.Text  = pgaGainStr(hb_pga);
                                    S.servo_vdac = double(hb_vdac);
                                    updateVdacCalcDisplay();
                                    S.psoc_tx_mode = double(hb_mode);
                                    modeStr = 'Crudo'; if hb_mode~=0, modeStr='Filter'; end
                                    btnTxMode.Text = sprintf('PSoC: %s', modeStr);
                                    logMsg(sprintf('HB  bytes=%d  PSoC→ PGA:%s  VDAC:%d  modo:%s',...
                                        S.totalBytes, pgaGainStr(hb_pga), hb_vdac, modeStr));
                                    checkPending('PGA',  hb_pga);
                                    checkPending('VDAC', hb_vdac);
                                else
                                    % Heartbeat con valores imposibles = desync, ignorar
                                    if S.logFid>0
                                        fprintf(S.logFid,'  [desync-HB] pga=0x%02X vdac=%d mode=%d\n',...
                                            hb_pga, hb_vdac, hb_mode);
                                    end
                                end
                            case 3  % confirmación PGA (send_config tras 0xA6)
                                newCode = pkt(3);
                                if newCode <= 8
                                    S.pga_gain_code = newCode;
                                    lblPGAGain.Text  = pgaGainStr(newCode);
                                    logMsg(sprintf('PSoC confirmó PGA: %s', pgaGainStr(newCode)));
                                    checkPending('PGA', newCode);
                                end
                            case 4  % confirmación VRef: PGAvdac + VDAC
                                newCode = pkt(3);
                                newVdac = pkt(4);
                                if newCode <= 8
                                    S.servo_vdac_pga_code = newCode;
                                    S.vdac_pga_code = newCode;
                                    S.servo_vdac = double(newVdac);
                                    S.vdac_ref = double(newVdac);
                                    updateVdacCalcDisplay();
                                    logMsg(sprintf('PSoC confirmó VRef: PGAvdac=%s  VDAC=0x%02X (%d)',...
                                        pgaGainStr(newCode), newVdac, newVdac));
                                    checkPending('PGAVDAC', newCode);
                                    checkPending('VDAC', newVdac);
                                end
                            case 7  % ACK [0x56][0x07][cmd][val][0x00]
                                ack_cmd = pkt(3);
                                ack_val = pkt(4);
                                switch ack_cmd
                                    case hex2dec('A1')
                                        streamVal = double(ack_val ~= 0);
                                        S.streamEnabled = logical(streamVal);
                                        logMsg(sprintf('ACK←PSoC  STREAM=%d', streamVal));
                                        updateBtnStates();
                                    case hex2dec('A8')
                                        modeVal = double(ack_val ~= 0);
                                        S.psoc_tx_mode = modeVal;
                                        btnTxMode.Text = sprintf('PSoC: %s', iif(modeVal==0,'Crudo','Filter'));
                                        logMsg(sprintf('ACK←PSoC  TXMODE=%d', modeVal));
                                        checkPending('TXMODE', modeVal);
                                    case hex2dec('AA')
                                        S.servo_vdac = double(ack_val);
                                        updateVdacCalcDisplay();
                                        logMsg(sprintf('ACK←PSoC  VDAC=0x%02X (%d)', ack_val, ack_val));
                                        checkPending('VDAC', ack_val);
                                    case hex2dec('A9')
                                        if ack_val <= 8
                                            S.servo_vdac_pga_code = double(ack_val);
                                            S.vdac_pga_code = double(ack_val);
                                            updateVdacCalcDisplay();
                                            logMsg(sprintf('ACK←PSoC  PGAvdac=%s', pgaGainStr(ack_val)));
                                            checkPending('PGAVDAC', ack_val);
                                        end
                                    otherwise
                                        logMsg(sprintf('ACK←PSoC  cmd=0x%02X val=%d', ack_cmd, ack_val));
                                end
                        end
                        S.parseState=0;
                    end
                otherwise
                    S.parseState=0;
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
    function onApplyServo()
        if ~S.isConnected, logMsg('VRef: no conectado'); return; end
        target = double(edtVRef.Value);
        if ~isfinite(target), target = 0; end
        target = max(0, min(51, target));
        edtVRef.Value = target;

        [code,gain,v,vdac_v,out_v,clamped] = currentVdacSetting();
        if logical(chkVdacAuto.Value)
            ddVdacPGA.Value = num2str(gain);
        end

        bytesGain = psocCmd(0xA9, code);
        bytesVdac = psocCmd(0xAA, v);
        try
            write(S.sp, bytesGain, 'uint8');
            pause(0.01);
            write(S.sp, bytesVdac, 'uint8');
        catch ex
            logMsg('VRef: error UART — ' + string(ex.message)); return;
        end

        logMsg(sprintf('TX→PSoC  VRef=%.3f V => PGAvdac=%dx (0x%02X), VDAC=0x%02X (%d), DAC=%.3f V, Out=%.3f V%s',...
            target, gain, code, uint8(v), v, vdac_v, out_v, iif(clamped,'  CLAMP','')));
        logTX(bytesGain, sprintf('PGAvdac=%dx code=0x%02X', gain, code));
        logTX(bytesVdac, sprintf('VDAC=0x%02X (%d)', v, v));

        S.vref_target_v = target;
        S.vdac_auto_gain = logical(chkVdacAuto.Value);
        S.vdac_pga_code = code;
        S.vdac_ref = v;
        updateVdacCalcDisplay();
        setPending('VDAC', v, bytesVdac);
        saveConfig();
    end

    % =====================================================================
    % Modo TX PSoC: crudo o Filter
    % =====================================================================
    function onToggleTxMode()
        if ~S.isConnected, logMsg('TxMode: no conectado'); return; end
        newMode = uint8(1 - S.psoc_tx_mode);
        bytes = psocCmd(0xA8, newMode);
        try
            write(S.sp, bytes, 'uint8');
        catch ex
            logMsg('TxMode: error UART — ' + string(ex.message)); return;
        end
        logMsg(sprintf('TX→PSoC  [AB A8 %02X %02X]  modo=%s (retry auto)',newMode,bytes(4),iif(newMode==0,'crudo','filter')));
        S.psoc_tx_mode = double(newMode);
        btnTxMode.Text = sprintf('PSoC: %s', iif(newMode==0,'Crudo','Filter'));
        setPending('TXMODE', double(newMode), bytes);
        saveConfig();
    end


    % =====================================================================
    % Cerrar
    % =====================================================================
    function onClose(~,~)
        try
            stopStreamTimer();
            if S.isConnected&&~isempty(S.sp)
                try write(S.sp, psocCmd(0xA1, 0), 'uint8'); pause(0.02); catch,end
                try flush(S.sp);catch,end; try delete(S.sp);catch,end
            end
        catch,end
        if S.logFid>0, try fclose(S.logFid);catch,end; S.logFid=-1; end
        saveConfig(); delete(fig);
    end

end
