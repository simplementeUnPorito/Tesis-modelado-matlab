%% 
function InterfaceESP()
% InterfaceESP — GUI multi-nodo geófono ESP32
% Layout: TabGroup izquierdo (columna única) + plots a la derecha
% Tabs: Maestro | Esclavo 1..N | Stream & Stats | Log

% Limpiar timers de instancias anteriores que quedaron corriendo
try, tAll = timerfindall(); if ~isempty(tAll), stop(tAll); delete(tAll); end; catch, end

%% ── Constantes ─────────────────────────────────────────────────────────
MAX_NODES    = 4;           % 1 maestro + 2 esclavos
BAUD         = 921600;
PKT_HEADER   = hex2dec('56');
CMD_HEADER   = hex2dec('AB');
CMD_DIRECTED = hex2dec('BD');
FS           = 2604;        % Hz nativos (N=1); HELLO exacto actualiza cada nodo
DISP_SAMP    = FS * 3;
VDAC_STEP    = 0.004;       % V/LSB
NODE_NAMES   = {'Maestro','Esclavo 1','Esclavo 2','Esclavo 3'};
TX_MODE_ITEMS = {'Raw ADC','Filtered ADC'};
TX_RAW       = uint8(0);
TX_FILTERED  = uint8(1);
TX_DEBUG     = uint8(2);
APP_DIR      = fileparts(mfilename('fullpath'));
LOG_DIR      = fullfile(APP_DIR, 'logs');
DATA_DIR     = fullfile(APP_DIR, 'datos');
CFG_FILE     = fullfile(APP_DIR, 'scope_config.mat');
MASTER_PIO_INI = fullfile(APP_DIR, '..', '..', 'esp', 'Nodo comunicación', 'master', 'platformio.ini');
N_LOG_SESSIONS = 10;
START_LATENCY_PROBES = 12;
START_LATENCY_PROBE_GAP_S = 0.04;
CMD_START_PROBE = hex2dec('AF');
CMD_DEBUG_RESPONSE = hex2dec('B0');
MASTER_STATE_ARMED = 2;
MASTER_STATE_PRESTART = 6;
MASTER_STATE_SCOPE_MULTI = 7;
HOTWAIT_QUERY_DELAY_S = readBuildDefine(MASTER_PIO_INI, 'HOTWAIT_QUERY_DELAY_MS', 20) / 1000;
HOTWAIT_QUERY_TIMEOUT_S = readBuildDefine(MASTER_PIO_INI, 'HOTWAIT_QUERY_TIMEOUT_MS', 120) / 1000;
HOTWAIT_QUERY_RETRIES = readBuildDefine(MASTER_PIO_INI, 'HOTWAIT_QUERY_RETRIES', 3);
HOTWAIT_SETTLE_S = readBuildDefine(MASTER_PIO_INI, 'HOTWAIT_SETTLE_MS', 50) / 1000;
SCOPE_MULTI_START_COUNT = readBuildDefine(MASTER_PIO_INI, 'SCOPE_MULTI_START_COUNT', 128);
SCOPE_MULTI_START_GAP_S = readBuildDefine(MASTER_PIO_INI, 'SCOPE_MULTI_START_GAP_MS', 1000) / 1000;

%% ── Estado ──────────────────────────────────────────────────────────────
S.port            = [];
S.rxBuf           = uint8([]);
S.streaming       = false;
S.nSlaves         = 0;
S.hammerTip       = 'gris';
S.driftMeasuring  = false;
S.driftT0         = [];
S.driftDebugActive = false;
S.streamDebug     = false;
S.streamDebugActive = false;
S.startsMultiple  = false;
S.multiStartActive = false;
S.armPending      = false;
S.armTimer        = [];
S.renderDirty     = false(1, MAX_NODES);
S.maxBuf          = FS * 10;
S.saveBaseName    = 'muestra';
S.lastUsbPort     = '';
S.recordingActive = false;   % true durante grabación: suprime render
S.dumpStarted     = false;   % true cuando maestro entra en DUMPING
S.prevMasterState = -1;      % estado anterior del heartbeat del maestro
S.nBatches        = 80;      % n_batches usado por el PRESTART del maestro
S.autoStopTimer   = [];      % handle del timer de auto-stop
tmr         = [];
tmrRender   = [];

for ch = 1:MAX_NODES
    S.node(ch).notchBuf  = [];
    S.node(ch).filtBuf   = [];
    S.node(ch).filtB     = [];
    S.node(ch).filtCmd   = '';
    S.node(ch).filtZi    = [];
    S.node(ch).lineW     = [];
    S.node(ch).pga_code  = 0;
    S.node(ch).vdac_byte = 128;
    S.node(ch).pgavdac   = 0;
    S.node(ch).cal       = zeros(9,3);
    S.node(ch).calValid  = false(9,1);
    S.node(ch).dcRemove  = false;
    S.node(ch).visible   = true;
    S.node(ch).driftHist = [];
    S.node(ch).startLatencyHist = [];
    S.node(ch).batchCount    = 0;
    S.node(ch).salud         = 0;
    S.node(ch).psocOk        = [];   % [] = desconocido, true/false tras primer HELLO
    S.node(ch).tx_mode       = TX_RAW;
    S.node(ch).debugActive   = false;
    S.node(ch).gotFirst      = false;
    S.node(ch).tFirst        = 0;
    S.node(ch).fs            = FS;    % Hz reportado por PSoC; se actualiza con HELLO
    S.node(ch).fsKnown       = false; % evita confundir el default con un HELLO exacto igual a 2604
    S.node(ch).notchEnabled  = false;
    S.node(ch).notchMu       = 0.002;
    S.node(ch).notchHarm     = 3;
    S.node(ch).pending = struct('sub_cmds',[],'params',[],'times',uint64([]),'retries',[]);
    if ch == 1
        S.node(ch).slave_id = 'M';
    else
        S.node(ch).slave_id = sprintf('S%d', ch-1);
    end
    % handles UI (poblados en buildTab)
    S.node(ch).ax        = [];
    S.node(ch).hRaw      = [];
    S.node(ch).hFilt     = [];
    S.node(ch).lblStats  = [];
    S.node(ch).lblLastVal= [];
    S.node(ch).lblFiltSt = [];
    S.node(ch).dbgPort    = [];
    S.node(ch).dbgBuf     = '';
    S.node(ch).dbgTa      = [];
    S.node(ch).dbgPending = {};
end

%% ── Handles UI en scope padre (compartidos entre nested functions) ───────
% Conexión / Stream (buildStreamTab los asigna, callbacks los usan)
ddPort = []; spnSlaves = []; btnConnect = []; btnDisconn = []; lblConn = [];
btnArm = []; spnRecBatches = [];
spnRecN = []; lblBatchInfo = [];
lblSyncSt = []; lblArmCnt = [];
lblDatos  = [];
btnStreamOn = [];
% notch controls: now per-node in S.node(ch).notchEnabled/Mu/Harm
driftLabels  = gobjects(3,1);
latencyLabels = gobjects(3,1);
globalBatch  = gobjects(MAX_NODES,1);
efSaveName = []; lblSaveSt = [];
taLog      = [];
% Checkboxes de visibilidad de plots (creados después de buildPlots)
cbVis = gobjects(MAX_NODES,1);

%% ── Cargar config ───────────────────────────────────────────────────────
if isfile(CFG_FILE)
    try
        c = load(CFG_FILE);
        if isfield(c,'appCfg')
            applyConfigSnapshot(c.appCfg);
        elseif isfield(c,'nodesCfg')
            nc = c.nodesCfg;
            campos = {'pga_code','vdac_byte','pgavdac','cal','filtCmd','dcRemove', ...
                'tx_mode','notchEnabled','notchMu','notchHarm','visible','filtB', ...
                'slave_id','calValid'};
            for ch = 1:min(MAX_NODES, numel(nc))
                for f = campos
                    if isfield(nc(ch),f{1}), S.node(ch).(f{1}) = nc(ch).(f{1}); end
                end
                if ~isempty(S.node(ch).filtB)
                    S.node(ch).filtZi = zeros(1,max(0,length(S.node(ch).filtB)-1));
                elseif ~isempty(S.node(ch).filtCmd)
                    S.node(ch).filtB = compileFirCommand(S.node(ch).filtCmd, ch);
                    if ~isempty(S.node(ch).filtB)
                        S.node(ch).filtZi = zeros(1,max(0,length(S.node(ch).filtB)-1));
                    end
                end
            end
        end
    catch, end
end

%% ── Logs dobles, 10 sesiones fechadas ───────────────────────────────────
if ~isfolder(LOG_DIR), mkdir(LOG_DIR); end
if ~isfolder(DATA_DIR), mkdir(DATA_DIR); end
logStamp = datestr(now, 'yyyymmdd_HHMMSS');
machLog = fullfile(LOG_DIR, sprintf('InterfaceESP_machine_%s.log', logStamp));
humLog  = fullfile(LOG_DIR, sprintf('InterfaceESP_human_%s.log',  logStamp));
machFid = -1;
humFid  = -1;
machFid = iniciarLog(machLog, 'machine');
humFid  = iniciarLog(humLog,  'human');
cleanupOldLogs(LOG_DIR, N_LOG_SESSIONS);

    function fid = iniciarLog(f, tipo)
        fid = fopen(f,'w');
        if fid >= 0
            fprintf(fid,'=== InterfaceESP %s | %s ===\n', tipo, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
        end
    end
    function agregarLog(fid, linea)
        if fid >= 0, fprintf(fid,'%s\n',linea); end
    end
    function cleanupOldLogs(logDir, maxSessions)
        cleanupLogPrefix(logDir, 'InterfaceESP_human_*.log', maxSessions);
        cleanupLogPrefix(logDir, 'InterfaceESP_machine_*.log', maxSessions);
    end
    function cleanupLogPrefix(logDir, pattern, maxKeep)
        files = dir(fullfile(logDir, pattern));
        if numel(files) <= maxKeep, return; end
        keys = zeros(1, numel(files));
        for iKey = 1:numel(files)
            keys(iKey) = logFileSortKey(files(iKey));
        end
        [~, ord] = sort(keys, 'descend');
        for iFile = ord(maxKeep+1:end)
            try, delete(fullfile(files(iFile).folder, files(iFile).name)); catch, end
        end
    end
    function key = logFileSortKey(fileInfo)
        tok = regexp(fileInfo.name, '_(\d{8}_\d{6})', 'tokens', 'once');
        if isempty(tok)
            key = fileInfo.datenum;
            return;
        end
        try
            key = datenum(tok{1}, 'yyyymmdd_HHMMSS');
        catch
            key = fileInfo.datenum;
        end
    end

%% ── Figura ──────────────────────────────────────────────────────────────
fig = uifigure('Name','InterfaceESP — Geófono Multi-Nodo', ...
    'Position',[30 30 1440 920], 'CloseRequestFcn',@onClose, ...
    'AutoResizeChildren','off');

%% ── TabGroup izquierdo (columna única) ──────────────────────────────────
TG_W = 340;
UI_H = 908;
AX_X = TG_W + 8;
AX_W = 1440 - AX_X - 8;
tg       = uitabgroup(fig,'Position',[4 4 TG_W UI_H]);
tgHidden = uitabgroup(fig,'Position',[-3000 -3000 TG_W UI_H]);
fig.SizeChangedFcn = @onResize;

%  índices fijos: 1=Maestro, 2-4=Esclavos, 5=Stream, 6=Log
tabs = gobjects(6,1);
tabs(1) = uitab(tg,'Title','Maestro');
tabs(2) = uitab(tg,'Title',slaveTabTitle(2));
tabs(3) = uitab(tg,'Title',slaveTabTitle(3));
tabs(4) = uitab(tg,'Title',slaveTabTitle(4));
tabs(5) = uitab(tg,'Title','Stream');
tabs(6) = uitab(tg,'Title','Log');

buildMaestroTab(tabs(1));
for slv = 1:3, buildSlaveTab(slv+1, tabs(slv+1)); end
buildStreamTab(tabs(5));
updateBatchInfoLabel();
buildLogTab(tabs(6));
applyTabVisibility();
updateDriftBatchVisibility();

%% ── Plots ────────────────────────────────────────────────────────────────
layoutFigure();
buildPlots();
applyPlotVisibility();  % ocultar plots de esclavos inactivos al arrancar

%% ════════════════════════════════════════════════════════════════════════
%%  Construcción de tabs
%% ════════════════════════════════════════════════════════════════════════

    function buildMaestroTab(tab)
        W = TG_W - 12;
        % El maestro es solo gateway: ya NO muestrea ningún sensor (el martillo
        % es un esclavo normal). Sin gráfico ni controles de acelerómetro.
        uilabel(tab,'Text', ...
            ['Maestro = gateway. No muestrea sensores; el martillo es un' newline ...
             'esclavo normal. Aquí solo el log de debug del maestro (Serial1).'], ...
            'Position',[4 856 W 36],'FontSize',9);

        % Debug COM Maestro (Serial1 del maestro, NO el USB binario de datos)
        pDbg = uipanel(tab,'Title','Debug COM Maestro (Serial1, opcional)', ...
            'Position',[4 4 W 846]);
        uilabel(pDbg,'Text','Puerto serial:','Position',[4 802 80 20]);
        mstDd = uidropdown(pDbg,'Position',[88 800 W-160 22], ...
            'Items',listSerialPorts());
        uibutton(pDbg,'Text','↺','Position',[W-68 800 64 22], ...
            'ButtonPushedFcn',@(~,~) set(mstDd,'Items',listSerialPorts()));
        mstBtnC = uibutton(pDbg,'Text','Conectar', 'Position',[4  774 90   22]);
        mstBtnD = uibutton(pDbg,'Text','Desconectar','Position',[98 774 W-102 22],'Enable','off');
        mstBtnC.ButtonPushedFcn = @(~,~) connectDbg(true,  1, mstDd, mstBtnC, mstBtnD);
        mstBtnD.ButtonPushedFcn = @(~,~) disconnectDbg(true, 1, mstBtnC, mstBtnD);
        mstTa = uitextarea(pDbg,'Position',[4 4 W-8 766], ...
            'Editable','off','FontName','Courier New','FontSize',8);
        S.node(1).dbgTa = mstTa;
    end

    function buildSlaveTab(ch, tab)
        W = TG_W - 12;
        gains = {'1x','2x','4x','5x','8x','10x','16x','32x','50x'};

        % VRef DC
        pV = uipanel(tab,'Title','VRef DC','Position',[4 720 W 178]);
        uilabel(pV,'Text','ID:','Position',[4 146 22 20]);
        uieditfield(pV,'text','Position',[30 146 98 22], ...
            'Value',S.node(ch).slave_id, ...
            'ValueChangedFcn',@(ef,~)setSlaveId(ch,ef.Value));
        uilabel(pV,'Text','VDAC byte:','Position',[4 118 68 20]);
        efVdac = uieditfield(pV,'numeric','Position',[76 118 90 22], ...
            'Value',S.node(ch).vdac_byte,'Limits',[0 255],'RoundFractionalValues',true, ...
            'ValueChangedFcn',@(ef,~)sendVdacByte(ch,ef.Value,ef,lblDacV));
        lblDacV = uilabel(pV,'Text',sprintf('%.3f V',S.node(ch).vdac_byte*VDAC_STEP), ...
            'Position',[172 118 104 20]);
        uilabel(pV,'Text','Target V:','Position',[4 90 58 20]);
        efTgt = uieditfield(pV,'numeric','Position',[66 90 100 22],'Value',0.512, ...
            'ValueChangedFcn',@(ef,~)sendVdacTarget(ch,ef.Value,efVdac,lblDacV));
        uibutton(pV,'Text','−','Position',[170 90 26 22], ...
            'ButtonPushedFcn',@(~,~)adjustVdac(ch,efVdac,lblDacV,-1));
        uibutton(pV,'Text','+','Position',[200 90 26 22], ...
            'ButtonPushedFcn',@(~,~)adjustVdac(ch,efVdac,lblDacV,+1));
        lblPgaVdacSt = uilabel(pV,'Text', ...
            sprintf('PGAvdac: %s (auto)', gains{S.node(ch).pgavdac+1}), ...
            'Position',[4 62 W-8 20]);
        uilabel(pV,'Text','PGA→VDAC:','Position',[4 36 76 20]);
        lblCalSt = uilabel(pV,'Text',calStatusText(ch),'Position',[82 36 W-90 20]);
        uibutton(pV,'Text','Guardar VDAC','Position',[4 8 104 22], ...
            'ButtonPushedFcn',@(~,~)saveCalForPGA(ch,lblCalSt));
        uibutton(pV,'Text','Aplicar VDAC','Position',[112 8 104 22], ...
            'ButtonPushedFcn',@(~,~)applyCal(ch));
        S.node(ch).efVdac       = efVdac;
        S.node(ch).lblDacV      = lblDacV;
        S.node(ch).lblPgaVdacSt = lblPgaVdacSt;
        S.node(ch).lblCalSt     = lblCalSt;

        % PGA
        pP = uipanel(tab,'Title','Ganancia PGA','Position',[4 658 W 58]);
        ddPga = uidropdown(pP,'Position',[4 14 120 22],'Items',gains, ...
            'Value',gains{S.node(ch).pga_code+1}, ...
            'ValueChangedFcn',@(dd,~)sendPga(ch,dd,gains));
        lblPgaSt = uilabel(pP,'Text',sprintf('Actual: %s',gains{S.node(ch).pga_code+1}), ...
            'Position',[130 14 W-134 22]);
        S.node(ch).ddPga    = ddPga;
        S.node(ch).lblPgaSt = lblPgaSt;

        % FIR
        pF = uipanel(tab,'Title','Filtro FIR','Position',[4 574 W 80]);
        uilabel(pF,'Text','Cmd:','Position',[4 38 34 20]);
        efFir = uieditfield(pF,'text','Position',[40 38 170 22],'Value',S.node(ch).filtCmd);
        uibutton(pF,'Text','Aplicar','Position',[214 38 72 22], ...
            'ButtonPushedFcn',@(~,~)applyFir(ch,efFir.Value));
        cbDC = uicheckbox(pF,'Text','Quitar DC','Position',[4 12 82 20], ...
            'Value',S.node(ch).dcRemove, ...
            'ValueChangedFcn',@(cb,~)setDcRemove(ch,cb.Value));
        uibutton(pF,'Text','Quitar filtro','Position',[90 12 84 22], ...
            'ButtonPushedFcn',@(~,~)removeFir(ch));
        lblFiltSt = uilabel(pF,'Text',firStatusText(ch),'Position',[180 12 W-188 20]);
        S.node(ch).efFir    = efFir;
        S.node(ch).cbDC     = cbDC;
        S.node(ch).lblFiltSt= lblFiltSt;

        % Send
        pD = uipanel(tab,'Title','Send','Position',[4 488 W 82]);
        btnTest = uibutton(pD,'Text',sprintf('Test Esclavo %d',ch-1), ...
            'Position',[4 46 130 26], ...
            'ButtonPushedFcn',@(~,~)onTestEsclavo(ch),'Enable','off');
        lblSalud    = uilabel(pD,'Text','●','Position',[140 46 22 26], ...
            'FontColor',[0.7 0.7 0.7],'FontSize',16);
        lblSaludTxt = uilabel(pD,'Text','Sin test','Position',[164 46 W-168 26]);
        % "Ver": captura única de N lotes de este nodo (calibrar VDAC en vivo)
        btnVer = uibutton(pD,'Text','Ver','Position',[4 10 80 24], ...
            'ButtonPushedFcn',@(~,~)onVerNodo(ch));
        uilabel(pD,'Text','captura única (calibra VDAC en vivo)', ...
            'Position',[90 12 W-94 20],'FontSize',8);
        S.node(ch).btnTest     = btnTest;
        S.node(ch).lblSalud    = lblSalud;
        S.node(ch).lblSaludTxt = lblSaludTxt;
        S.node(ch).btnVer      = btnVer;

        % Stats
        pSt = uipanel(tab,'Title','Estadísticas','Position',[4 402 W 82]);
        S.node(ch).lblStats   = uilabel(pSt,'Text','Mts: 0  Bat: 0  Drift: --', ...
            'Position',[4 40 W-12 20]);
        S.node(ch).lblLastVal = uilabel(pSt,'Text','Último: --', ...
            'Position',[4 14 W-12 20]);

        % Cancelador 50 Hz — por esclavo
        pN = uipanel(tab,'Title','Cancelador 50 Hz','Position',[4 316 W 82]);
        uicheckbox(pN,'Text','Activar','Position',[4 38 80 22], ...
            'Value',S.node(ch).notchEnabled, ...
            'ValueChangedFcn',@(cb,~)onNotchToggle(ch,cb.Value));
        uilabel(pN,'Text','µ:','Position',[4 10 20 20]);
        uieditfield(pN,'numeric','Position',[26 10 60 22], ...
            'Value',S.node(ch).notchMu, ...
            'ValueChangedFcn',@(ef,~)onNotchMu(ch,ef.Value));
        uilabel(pN,'Text','Arm:','Position',[92 10 34 20]);
        uispinner(pN,'Position',[128 10 W-132 22],'Value',S.node(ch).notchHarm, ...
            'Limits',[1 5],'ValueChangedFcn',@(sp,~)onNotchHarm(ch,sp.Value));

        % Debug COM esclavo (opcional) — panel expandido para más log
        pDbg = uipanel(tab,'Title',sprintf('Debug COM Esclavo %d (opcional)',ch-1), ...
            'Position',[4 4 W 308]);
        uilabel(pDbg,'Text','Puerto serial:','Position',[4 264 80 20]);
        slvDd = uidropdown(pDbg,'Position',[88 262 W-160 22], ...
            'Items',listSerialPorts());
        uibutton(pDbg,'Text','↺','Position',[W-68 262 64 22], ...
            'ButtonPushedFcn',@(~,~) set(slvDd,'Items',listSerialPorts()));
        slvBtnC = uibutton(pDbg,'Text','Conectar', 'Position',[4  236 90   22]);
        slvBtnD = uibutton(pDbg,'Text','Desconectar','Position',[98 236 W-102 22],'Enable','off');
        slvBtnC.ButtonPushedFcn = @(~,~) connectDbg(false,  ch, slvDd, slvBtnC, slvBtnD);
        slvBtnD.ButtonPushedFcn = @(~,~) disconnectDbg(false, ch, slvBtnC, slvBtnD);
        slvTa = uitextarea(pDbg,'Position',[4 4 W-8 228], ...
            'Editable','off','FontName','Courier New','FontSize',8);
        S.node(ch).dbgTa = slvTa;
    end

    function buildStreamTab(tab)
        W = TG_W - 12;

        % Conexión
        pC = uipanel(tab,'Title','Conexión USB','Position',[4 788 W 110]);
        uilabel(pC,'Text','Puerto:','Position',[4 72 46 20]);
        portItems = listSerialPorts();
        ddPort = uidropdown(pC,'Position',[54 72 186 22],'Items',portItems);
        if any(strcmp(portItems, S.lastUsbPort)), ddPort.Value = S.lastUsbPort; end
        uibutton(pC,'Text','↺','Position',[244 72 W-248 22], ...
            'ButtonPushedFcn',@(~,~)refreshPorts());
        uilabel(pC,'Text','Esclavos:','Position',[4 44 62 20]);
        spnSlaves = uispinner(pC,'Position',[70 44 52 22],'Value',S.nSlaves, ...
            'Limits',[0 3],'Step',1,'RoundFractionalValues',true, ...
            'ValueChangedFcn',@onNSlavesChanged);
        btnConnect = uibutton(pC,'Text','Conectar',   'Position',[128 44 96 22], ...
            'ButtonPushedFcn',@onConnect);
        btnDisconn = uibutton(pC,'Text','Desconectar','Position',[228 44 W-232 22], ...
            'ButtonPushedFcn',@onDisconnect,'Enable','off');
        lblConn = uilabel(pC,'Text','● Sin conexión','Position',[4 8 W-8 22], ...
            'FontColor',[0.5 0.5 0.5]);

        % Sincronización
        pS = uipanel(tab,'Title','Sincronización','Position',[4 682 W 102]);
        btnArm  = uibutton(pS,'Text','Descubrir','Position',[4  62 W-8 26], ...
            'ButtonPushedFcn',@onArm,'Enable','off');
        lblSyncSt = uilabel(pS,'Text','Estado: IDLE',      'Position',[4 36 W-8 20]);
        lblArmCnt = uilabel(pS,'Text','Esclavos listos: 0','Position',[4 12 W-8 20]);

        % Stream
        pSt = uipanel(tab,'Title','Stream','Position',[4 562 W 116]);
        btnStreamOn = uibutton(pSt,'Text','▶ Iniciar','Position',[4 90 W-8 24], ...
            'ButtonPushedFcn',@onStreamOn,'Enable','off');
        uilabel(pSt,'Text','Batches:','Position',[4 66 66 18]);
        spnRecN = uispinner(pSt,'Position',[70 64 60 22], ...
            'Value',80,'Limits',[1 65535],'Step',1,'RoundFractionalValues',true, ...
            'ValueChangedFcn',@(~,~)updateBatchInfoLabel());
        lblBatchInfo = uilabel(pSt,'Text','80 bat → 2400 mts ≈ 2.4 s', ...
            'Position',[136 64 W-140 22],'FontSize',8);
        uicheckbox(pSt,'Text','Debug','Position',[4 40 80 18], ...
            'Value',S.streamDebug,'ValueChangedFcn',@(cb,~)onStreamDebugToggle(cb.Value));
        uicheckbox(pSt,'Text','Starts multiples','Position',[92 40 W-96 18], ...
            'Value',S.startsMultiple,'ValueChangedFcn',@(cb,~)onStartsMultipleToggle(cb.Value));
        uibutton(pSt,'Text','Limpiar buffers','Position',[4 14 W-8 20], ...
            'ButtonPushedFcn',@onClear);

        % Reaccion ESP-NOW estimada por START_ACK (RTT/2)
        pDr = uipanel(tab,'Title','Reaccion ESP-NOW','Position',[4 476 W 84]);
        for k = 1:3
            rowY = (3-k)*20 + 8;
            driftLabels(k) = uilabel(pDr,'Text','', ...
                'Position',[0 0 1 1], 'Visible','off');
            latencyLabels(k) = uilabel(pDr,'Text',sprintf('S%d: --',k), ...
                'Position',[6 rowY W-12 16], 'FontSize',9);
        end

        % Muestras/batches globales
        pBt = uipanel(tab,'Title','Datos recibidos','Position',[4 356 W 104]);
        for ch = 1:MAX_NODES
            globalBatch(ch) = uilabel(pBt,'Text', ...
                sprintf('%s: 0 bat (0 mts)', NODE_NAMES{ch}), ...
                'Position',[4 (MAX_NODES-ch)*22+8 W-8 20]);
        end

        % Guardar
        pSv = uipanel(tab,'Title','Guardar','Position',[4 264 W 88]);
        uilabel(pSv,'Text','Nombre:','Position',[4 48 54 20]);
        efSaveName = uieditfield(pSv,'text','Position',[62 48 154 22],'Value',S.saveBaseName);
        uibutton(pSv,'Text','Guardar .mat','Position',[220 48 W-224 22], ...
            'ButtonPushedFcn',@onSave);
        lblSaveSt = uilabel(pSv,'Text','','Position',[4 16 W-8 24], ...
            'FontColor',[0.1 0.5 0.1]);

        % Canales visibles
        pCh = uipanel(tab,'Title','Canales visibles','Position',[4 156 W 104]);
        for ch = 1:MAX_NODES
            cbVis(ch) = uicheckbox(pCh,'Text',NODE_NAMES{ch}, ...
                'Position',[4 (MAX_NODES-ch)*22+8 W-8 20], ...
                'Value',S.node(ch).visible, ...
                'ValueChangedFcn',@(src,~)onCheckboxChannel(ch,src.Value));
        end

        % Datos
        pDa = uipanel(tab,'Title','Datos','Position',[4 4 W 148]);
        lblDatos = uilabel(pDa,'Text','Buf: 0 mts  |  RX: 0 mts', ...
            'Position',[4 108 W-8 20]);
        uilabel(pDa,'Text','Vista(s):','Position',[4 84 56 20]);
        uispinner(pDa,'Position',[62 82 W-66 22], ...
            'Value',DISP_SAMP/FS,'Limits',[1 10],'Step',1,'RoundFractionalValues',true, ...
            'ValueChangedFcn',@(sp,~)onVistaSecs(sp.Value));
        uilabel(pDa,'Text','Max buf(s):','Position',[4 58 70 20]);
        uispinner(pDa,'Position',[76 56 W-80 22], ...
            'Value',S.maxBuf/FS,'Limits',[5 60],'Step',5,'RoundFractionalValues',true, ...
            'ValueChangedFcn',@(sp,~)onMaxBufSecs(sp.Value));
        uilabel(pDa,'Text','Render ms:','Position',[4 32 60 20]);
        uispinner(pDa,'Position',[66 30 W-70 22], ...
            'Value',150,'Limits',[50 500],'Step',10,'RoundFractionalValues',true, ...
            'ValueChangedFcn',@(sp,~)onRenderPeriod(sp.Value));
    end

    function buildLogTab(tab)
        W = TG_W - 12;
        uilabel(tab,'Text','Log (simplificado - ver carpeta logs):', ...
            'Position',[4 878 W 20],'FontSize',8);
        taLog = uitextarea(tab,'Position',[4 4 W 872],'Editable','off','FontSize',9);
    end

%% ── Plots ────────────────────────────────────────────────────────────────

    function onResize(~,~)
        layoutFigure();
    end

    function layoutFigure()
        fp = fig.Position;
        UI_H = max(320, fp(4) - 12);
        AX_X = TG_W + 8;
        AX_W = max(320, fp(3) - AX_X - 8);
        tg.Position = [4 4 TG_W UI_H];
        tgHidden.Position = [-3000 -3000 TG_W UI_H];
        if isLiveHandle(S.node(1).ax)
            updatePlotLayout();
        end
    end

    function buildPlots()
        AH = floor((UI_H - 4 - (MAX_NODES-1)*4) / MAX_NODES);
        for ch = 1:MAX_NODES
            yb = 4 + (MAX_NODES - ch) * (AH + 4);
            ax = uiaxes(fig,'Position',[AX_X yb AX_W AH]);
            ax.XGrid = 'on'; ax.YGrid = 'on';
            ax.Title.String  = NODE_NAMES{ch};
            ax.XLabel.String = 'Muestras';
            hold(ax,'on');
            S.node(ch).hRaw  = plot(ax, NaN, NaN, 'b-', 'LineWidth', 0.8);
            S.node(ch).hFilt = plot(ax, NaN, NaN, 'r-', 'LineWidth', 0.8, 'Visible','off');
            hold(ax,'off');
            S.node(ch).ax = ax;
        end
    end

    function applyTabVisibility()
        % Retirar todos los tabs del tabgroup visible
        for t = 1:6, tabs(t).Parent = tgHidden; end
        % Re-agregar en orden visual: Stream, Esclavos, Log
        % (Tab Maestro omitido: sus logs van a Serial1/GPIO16-17, no al USB de datos)
        tabs(5).Parent = tg;                  % Stream primero
        for slv = 1:S.nSlaves
            tabs(slv+1).Parent = tg;         % Esclavos activos
        end
        tabs(6).Parent = tg;                  % Log
        tg.SelectedTab = tabs(5);
        % Solo actualizar plots si ya fueron creados
        if isLiveHandle(S.node(1).ax), applyPlotVisibility(); end
    end

    function updateDriftBatchVisibility()
        for k = 1:3
            if isLiveHandle(driftLabels(k))
                driftLabels(k).Visible = 'off';
            end
            if isLiveHandle(latencyLabels(k))
                latencyLabels(k).Visible = ternary(k <= S.nSlaves, 'on', 'off');
            end
        end
        for ch = 1:MAX_NODES
            if isLiveHandle(globalBatch(ch))
                show = (ch >= 2) && (ch <= 1 + S.nSlaves);
                globalBatch(ch).Visible = ternary(show, 'on', 'off');
            end
        end
    end

    function applyPlotVisibility()
        % Ocultar plots y checkboxes de esclavos inactivos
        for ch = 1:MAX_NODES
            % ch=1 = Maestro: gateway, sin gráfico. ch=2..nSlaves+1 = esclavos.
            active = (ch >= 2) && (ch <= 1 + S.nSlaves);
            if isLiveHandle(cbVis(ch))
                wasActive = strcmp(cbVis(ch).Visible,'on');
                if active && ~wasActive
                    cbVis(ch).Value = true;
                elseif ~active
                    cbVis(ch).Value = false;
                end
                cbVis(ch).Visible = ternary(active,'on','off');
            end
            S.node(ch).visible = active && isLiveHandle(cbVis(ch)) && cbVis(ch).Value;
        end
        updatePlotLayout();
    end

    function updatePlotLayout()
        visibleChannels = [];
        for ch = 1:MAX_NODES
            active = (ch >= 2) && (ch <= 1 + S.nSlaves);
            if active && S.node(ch).visible
                visibleChannels(end+1) = ch; %#ok<AGROW>
            end
        end

        nVis = numel(visibleChannels);
        for ch = 1:MAX_NODES
            if ~isLiveHandle(S.node(ch).ax), continue; end
            if ~ismember(ch, visibleChannels)
                S.node(ch).ax.Visible    = 'off';
                S.node(ch).ax.Position   = [AX_X -3000 AX_W 1];
                S.node(ch).hRaw.Visible  = 'off';
                S.node(ch).hFilt.Visible = 'off';
            end
        end

        if nVis == 0, return; end
        ah = floor((UI_H - 4 - (nVis-1)*4) / nVis);
        for k = 1:nVis
            ch = visibleChannels(k);
            yb = 4 + (nVis - k) * (ah + 4);
            S.node(ch).ax.Position   = [AX_X yb AX_W ah];
            S.node(ch).ax.Visible    = 'on';
            S.node(ch).hRaw.Visible  = 'on';
            S.node(ch).hFilt.Visible = ternary(~isempty(S.node(ch).filtBuf),'on','off');
        end
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Callbacks — conexión
%% ════════════════════════════════════════════════════════════════════════

    function refreshPorts()
        ddPort.Items = listSerialPorts();
    end

    function onNSlavesChanged(~,~)
        S.nSlaves = max(0, min(3, round(spnSlaves.Value)));
        spnSlaves.Value = S.nSlaves;
        applyTabVisibility();
        updateDriftBatchVisibility();
        logH(sprintf('Esclavos: %d', S.nSlaves));
        logM(sprintf('nSlaves=%d', S.nSlaves));
    end

    function onConnect(~,~)
        portName = ddPort.Value;
        if isempty(portName) || strcmp(portName,'(sin puertos)')
            logH('Selecciona un puerto COM válido'); return;
        end
        S.lastUsbPort = portName;
        try
            S.port = serialport(portName, BAUD);
            flush(S.port);
            S.rxBuf = uint8([]);
        catch ME
            logH(['Error conexión: ' ME.message]);
            logM(['onConnect FAIL port=' portName ' ' ME.message]);
            return;
        end
        % Enviar STOP al reconectar para que el maestro vuelva a IDLE
        try
            cs = bitxor(uint8(hex2dec('A4')), uint8(0));
            write(S.port, uint8([CMD_HEADER, hex2dec('A4'), 0, cs]), 'uint8');
            pause(0.15);
            flush(S.port);
            S.rxBuf = uint8([]);
        catch, end
        lblConn.Text      = ['● Conectado: ' portName];
        lblConn.FontColor = [0.0 0.55 0.0];
        btnConnect.Enable = 'off';
        btnDisconn.Enable = 'on';
        btnArm.Enable     = 'on';
        btnStreamOn.Enable= 'on';
        for ch = 2:1+S.nSlaves
            if isfield(S.node(ch),'btnTest') && ~isempty(S.node(ch).btnTest)
                S.node(ch).btnTest.Enable = 'on';
            end
        end
        % Crear timers si no existen o fueron borrados
        if isempty(tmr) || ~isvalid(tmr)
            tmr = timer('ExecutionMode','fixedRate','Period',0.05, ...
                'TimerFcn',@timerRX,'BusyMode','drop');
        end
        if strcmp(tmr.Running,'off'), start(tmr); end
        if isempty(tmrRender) || ~isvalid(tmrRender)
            tmrRender = timer('ExecutionMode','fixedRate','Period',0.15, ...
                'TimerFcn',@timerRenderFcn,'BusyMode','drop');
        end
        if strcmp(tmrRender.Running,'off'), start(tmrRender); end
        logH(['Conectado: ' portName]);
        logM(sprintf('onConnect OK port=%s', portName));
    end

    function onDisconnect(~,~)
        if ~isempty(tmr) && isvalid(tmr) && strcmp(tmr.Running,'on')
            stop(tmr);
        end
        if ~isempty(tmrRender) && isvalid(tmrRender) && strcmp(tmrRender.Running,'on')
            stop(tmrRender);
        end
        if S.multiStartActive
            try, psocCmd(CMD_DEBUG_RESPONSE, 0); catch, end
            S.multiStartActive = false;
        end
        setDriftDebugSlaves(false);
        setStreamDebugSignal(false);
        if ~isempty(S.port) && isvalid(S.port), delete(S.port); end
        S.port = [];
        lblConn.Text      = '● Sin conexión';
        lblConn.FontColor = [0.5 0.5 0.5];
        btnConnect.Enable = 'on';
        btnDisconn.Enable = 'off';
        btnArm.Enable     = 'off';
        btnArm.Text       = 'Descubrir';
        btnStreamOn.Enable= 'off';
        btnStreamOn.Text  = '▶ Iniciar';
        S.armPending = false; S.armTimer = [];
        for ch = 2:MAX_NODES
            if isfield(S.node(ch),'btnTest') && ~isempty(S.node(ch).btnTest)
                S.node(ch).btnTest.Enable = 'off';
            end
        end
        S.streaming       = false;
        S.recordingActive = false;
        S.dumpStarted     = false;
        S.multiStartActive = false;
        S.prevMasterState = -1;
        S.nBatches        = max(1, min(65535, round(spnRecN.Value)));
        if ~isempty(S.autoStopTimer) && isvalid(S.autoStopTimer)
            try, stop(S.autoStopTimer); delete(S.autoStopTimer); catch, end
        end
        S.autoStopTimer = [];
        logH('Desconectado');
        logM('onDisconnect');
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Callbacks — Sincronización / Stream
%% ════════════════════════════════════════════════════════════════════════

    function onArm(~,~)
        % Toggle: second press cancels
        if S.armPending
            cancelArmDrift();
            return;
        end
        if S.nSlaves == 0, logH('Configura el nº de esclavos primero'); return; end
        % Descubrir: sólo ARM en modo streaming (n=0) para que los esclavos
        % queden disponibles para tests. No hay medición de drift aquí.
        psocCmd16(hex2dec('AE'), 0);
        psocCmd(hex2dec('A2'), S.nSlaves);
        S.armPending = true;
        lblSyncSt.Text = 'Estado: DISCOVERING...';
        btnArm.Text = 'Cancelar';
        logH(sprintf('ARM → buscando %d esclavos', S.nSlaves));
        logM(sprintf('CMD ARM n=%d', S.nSlaves));
        tmrA = timer('StartDelay', 1.0, 'ExecutionMode', 'singleShot', 'TimerFcn', @armDone);
        S.armTimer = tmrA;
        start(tmrA);
        function armDone(~,~)
            try, delete(tmrA); catch, end
            S.armTimer = [];
            S.armPending = false;
            if isLiveHandle(btnArm), btnArm.Text = 'Descubrir'; end
        end
    end

    function checkFsConsistency()
        if S.nSlaves == 0, return; end
        fsVals = zeros(1, S.nSlaves);
        fsKnown = false(1, S.nSlaves);
        for k = 1:S.nSlaves
            ch = k + 1;
            fsVals(k)  = S.node(ch).fs;
            fsKnown(k) = S.node(ch).fsKnown;
        end
        if ~any(fsKnown)
            logH('ARM: FS no reportada aún (esperando HELLO de esclavos)');
            return;
        end
        parts = {};
        for k = 1:S.nSlaves
            parts{end+1} = sprintf('S%d=%dHz', k, fsVals(k)); %#ok<AGROW>
        end
        fsStr = strjoin(parts, '  ');
        if ~all(fsVals == fsVals(1))
            logH(sprintf('ADVERTENCIA: esclavos con distintas frecuencias de muestreo — %s', fsStr));
        else
            logH(sprintf('ARM: todos los esclavos a %d Hz', fsVals(1)));
        end
        logM(sprintf('fs_check: %s', fsStr));
    end

    function fsHz = currentAcquisitionFs()
        % Primera Fs confirmada de un esclavo activo; FS es solo el fallback
        % nativo de arranque mientras todavía no llegó el HELLO exacto.
        fsHz = FS;
        for kFs = 1:max(0, S.nSlaves)
            chFs = kFs + 1;
            if S.node(chFs).fsKnown && S.node(chFs).fs > 0
                fsHz = S.node(chFs).fs;
                return;
            end
        end
    end

    function cancelArmDrift()
        if ~isempty(S.armTimer) && isvalid(S.armTimer)
            try, stop(S.armTimer); delete(S.armTimer); catch, end
        end
        S.armTimer = [];
        S.armPending = false;
        S.driftMeasuring = false;
        if isLiveHandle(btnArm),      btnArm.Text     = 'Descubrir'; end
        if isLiveHandle(btnStreamOn), btnStreamOn.Text = '▶ Iniciar'; end
        lblSyncSt.Text = 'Estado: IDLE';
        logH('Descubrir cancelado'); logM('ARM cancel');
    end

    function onStop(~,~)
        if ~isempty(S.autoStopTimer) && isvalid(S.autoStopTimer)
            try, stop(S.autoStopTimer); delete(S.autoStopTimer); catch, end
            S.autoStopTimer = [];
        end
        S.driftT0 = [];
        setDriftDebugSlaves(false);
        setStreamDebugSignal(false);
        try, psocCmd(hex2dec('A4'), 0); catch, end
        try, psocCmd(hex2dec('A1'), 0); catch, end
        S.streaming = false;
        S.recordingActive = false;
        S.renderDirty(:) = true;
        if isLiveHandle(btnStreamOn), btnStreamOn.Text = '▶ Iniciar'; end
        lblSyncSt.Text = 'Estado: STOPPING...';
        logH('STOP'); logM('CMD STOP');
    end

    % ── Drift measurement cycle: START → 1.5 s → STOP → compute ────────────
    function doDriftMeasure()
        if S.driftMeasuring, return; end
        if isempty(S.port) || ~isvalid(S.port), return; end
        S.driftMeasuring = true;
        % Activar stream brevemente para recibir muestras
        psocCmd16(hex2dec('AE'), 0);
        psocCmd(hex2dec('A1'), 1);
        S.streaming = true;
        % Marcar tiempo y limpiar flags de primera muestra
        S.driftT0 = tic;
        for chD = 1:MAX_NODES
            S.node(chD).gotFirst = false;
            S.node(chD).tFirst   = 0;
        end
        setDriftDebugSlaves(true);
        psocCmd16(hex2dec('A3'), 0);
        waitBudget = hotWaitBudgetS();
        lblSyncSt.Text = sprintf('Estado: HOT_WAIT drift (max %.1f s)', waitBudget);
        logM('driftMeasure START');
        tmrDM = timer('StartDelay', waitBudget + 1.5, ...
            'ExecutionMode', 'singleShot', 'TimerFcn', @finishDrift);
        start(tmrDM);
        function finishDrift(~,~)
            try, delete(tmrDM); catch, end
            setDriftDebugSlaves(false);
            try, psocCmd(hex2dec('A4'), 0); catch, end
            try, psocCmd(hex2dec('A1'), 0); catch, end
            S.streaming = false;
            if ~isempty(S.driftT0), computeDrift(); end
            S.driftMeasuring = false;
            lblSyncSt.Text = 'Estado: ARMED';
            logM('driftMeasure STOP');
        end
    end

    function setDriftDebugSlaves(enable)
        if isempty(S.port) || ~isvalid(S.port), S.driftDebugActive = false; return; end
        if S.nSlaves == 0, S.driftDebugActive = false; return; end
        for chDbg = 2:1+S.nSlaves
            try, enviarDirigido(chDbg, hex2dec('A7'), uint8(enable)); catch, end
        end
        S.driftDebugActive = logical(enable);
        logM(sprintf('driftMeasure slaveDebug=%d', uint8(enable)));
    end

    function computeDrift()
        if S.nSlaves == 0, S.driftT0 = []; return; end
        times = zeros(1, S.nSlaves);
        anyData = false;
        for k = 1:S.nSlaves
            ch = k + 1;
            if S.node(ch).gotFirst
                times(k) = S.node(ch).tFirst;
                anyData = true;
            else
                times(k) = NaN;
            end
        end
        S.driftT0 = [];
        if ~anyData, logH('Drift: sin datos de esclavos'); return; end
        if S.node(1).gotFirst
            refTime = S.node(1).tFirst;
            refName = 'M';
        else
            refTime = 0;
            refName = 'START';
        end
        parts = {};
        for k = 1:S.nSlaves
            ch = k + 1;
            if ~isnan(times(k))
                % Diferencia de llegada de primera muestra; no es RTT, no se divide por 2.
                d = times(k) - refTime;
                S.node(ch).driftHist(end+1) = d;
                if length(S.node(ch).driftHist) > 50
                    S.node(ch).driftHist = S.node(ch).driftHist(end-49:end);
                end
                updateStats(ch);
                parts{end+1} = sprintf('S%d=%s', k, formatDriftScalar(d)); %#ok
            end
        end
        logH(sprintf('Drift ref=%s: %s', refName, strjoin(parts, '  ')));
        logM(sprintf('drift ref=%s M=%s %s', refName, ...
            formatDriftScalar(S.node(1).tFirst), strjoin(parts, ' ')));
    end

    function updateBatchInfoLabel()
        if ~isLiveHandle(spnRecN) || ~isLiveHandle(lblBatchInfo), return; end
        n = max(1, min(65535, round(spnRecN.Value)));
        S.nBatches = n;
        dur = n * 30 / currentAcquisitionFs();
        lblBatchInfo.Text = sprintf('%d bat → %d mts ≈ %.1f s', n, n*30, dur);
    end

    function s = hotWaitBudgetS()
        tries = max(1, HOTWAIT_QUERY_RETRIES + 1);
        s = HOTWAIT_QUERY_DELAY_S + ...
            max(0, S.nSlaves) * tries * HOTWAIT_QUERY_TIMEOUT_S + ...
            HOTWAIT_SETTLE_S + 0.10;
    end

    function onStreamOn(~,~)
        logM(sprintf('BTN Iniciar streaming=%d nBatches=%d', S.streaming, round(spnRecN.Value)));
        if S.streaming
            onStreamOff();
            return;
        end
        if S.nSlaves == 0, logH('Configura el nº de esclavos primero'); return; end
        n = max(1, min(65535, round(spnRecN.Value)));
        S.nBatches = n;
        updateBatchInfoLabel();
        % Limpiar todos los buffers para que cada grabación empiece desde cero
        for chCl = 1:MAX_NODES
            S.node(chCl).notchBuf  = [];
            S.node(chCl).filtBuf   = [];
            S.node(chCl).batchCount = 0;
            if isLiveHandle(S.node(chCl).hRaw)
                set(S.node(chCl).hRaw,  'XData', NaN, 'YData', NaN);
                set(S.node(chCl).hFilt, 'XData', NaN, 'YData', NaN);
            end
            updateStats(chCl);
        end
        if S.startsMultiple
            S.streaming = true;
            S.multiStartActive = true;
            S.recordingActive = false;
            btnStreamOn.Text = '■ Detener';
            waitBudget = hotWaitBudgetS();
            lblSyncSt.Text = sprintf('Estado: HOT_WAIT multiples (max %.1f s)', waitBudget);
            psocCmd(CMD_DEBUG_RESPONSE, 1);
            logH(sprintf('Starts multiples: %d ciclos de HOT_WAIT + START + %.1f s extra', ...
                SCOPE_MULTI_START_COUNT, SCOPE_MULTI_START_GAP_S));
            logM(sprintf('scopeMulti START n=0 count=%d hotwaitMax=%.3fs gap=%.3fs', ...
                SCOPE_MULTI_START_COUNT, waitBudget, SCOPE_MULTI_START_GAP_S));
            return;
        end
        % El maestro manda PRESTART, confirma HOT_WAIT en cada esclavo y luego START.
        if S.streamDebug
            psocCmd16(hex2dec('AE'), S.nBatches);   % fijar n_batches ANTES de A7: maestro y esclavos ven g_rec_n_batches>0
            setStreamDebugSignal(true);            % A7 con g_rec_n_batches>0 → maestro queda ARMED, esclavos ARMED (no SAMPLING)
            psocCmd16(hex2dec('A3'), S.nBatches);
        else
            psocCmd(hex2dec('A1'), 1);    % A1(1) → master stream live ADC real
            psocCmd16(hex2dec('A3'), S.nBatches);
        end
        S.streaming = true;
        S.recordingActive = true;
        S.prevMasterState = -1;   % forzar que el próximo heartbeat IDLE libere render
        btnStreamOn.Text = '■ Detener';
        durRec = S.nBatches * 30 / currentAcquisitionFs();
        waitBudget = hotWaitBudgetS();
        lblSyncSt.Text = sprintf('Estado: HOT_WAIT → START (max %.1f s)', waitBudget);
        logH(sprintf('Iniciar: HOT_WAIT + grabando %.1f s', durRec));
        logM(sprintf('CMD START store n=%d hotwaitMax=%.1fs', S.nBatches, waitBudget));
        % Auto-stop: redondear a ms para evitar warning de precisión sub-ms
        delayAS = round((waitBudget + durRec + 3.0) * 1000) / 1000;
        if delayAS < 0.001, delayAS = 0.001; end
        tmrAS = timer('StartDelay', delayAS, 'ExecutionMode', 'singleShot', ...
                      'TimerFcn', @doAutoStop);
        S.autoStopTimer = tmrAS;
        start(tmrAS);
        function doAutoStop(~,~)
            try, delete(S.autoStopTimer); catch, end
            S.autoStopTimer = [];
            setStreamDebugSignal(false);
            try, psocCmd(hex2dec('A1'), 0); catch, end
            try, psocCmd(hex2dec('A4'), 0); catch, end
            S.streaming = false;
            % Marcar dump iniciado aquí para que el trim dispare en IDLE incluso
            % si la fase DUMPING es tan corta que no llega ningún heartbeat con state=5
            S.dumpStarted = true;
            if isLiveHandle(btnStreamOn)
                btnStreamOn.Text   = '▶ Iniciar';
                btnStreamOn.Enable = 'on';
            end
            lblSyncSt.Text = 'Estado: STOPPING...';
            logH('Auto-stop: esperando datos de esclavos...');
            logM('doAutoStop A4');
        end
    end

    function onStreamOff(~,~)
        if S.multiStartActive
            try, psocCmd(CMD_DEBUG_RESPONSE, 0); catch, end
            S.multiStartActive = false;
            S.streaming = false;
            S.recordingActive = false;
            S.renderDirty(:) = true;
            if isLiveHandle(btnStreamOn), btnStreamOn.Text = '▶ Iniciar'; end
            lblSyncSt.Text = 'Estado: ARMED';
            logH('Starts multiples detenido');
            logM('scopeMulti STOP');
            return;
        end
        if ~isempty(S.autoStopTimer) && isvalid(S.autoStopTimer)
            try, stop(S.autoStopTimer); delete(S.autoStopTimer); catch, end
            S.autoStopTimer = [];
        end
        setStreamDebugSignal(false);
        try, psocCmd(hex2dec('A4'), 0); catch, end
        try, psocCmd(hex2dec('A1'), 0); catch, end
        S.streaming = false;
        S.driftT0   = [];
        if S.recordingActive
            S.dumpStarted = true;   % trigger trim en IDLE
        end
        S.recordingActive = false;
        S.renderDirty(:) = true;
        if isLiveHandle(btnStreamOn), btnStreamOn.Text = '▶ Iniciar'; end
        lblSyncSt.Text = 'Estado: STOPPING...';
        logH('Stream detenido'); logM('STREAM OFF');
    end

    function onStreamDebugToggle(val)
        S.streamDebug = logical(val);
        logM(sprintf('streamDebug=%d', uint8(S.streamDebug)));
        if S.streaming && ~S.multiStartActive
            setStreamDebugSignal(S.streamDebug);
        end
    end

    function onStartsMultipleToggle(val)
        S.startsMultiple = logical(val);
        logM(sprintf('startsMultiple=%d', uint8(S.startsMultiple)));
    end

    function finishMultipleStarts()
        S.multiStartActive = false;
        S.streaming = false;
        S.recordingActive = false;
        S.renderDirty(:) = true;
        if isLiveHandle(btnStreamOn)
            btnStreamOn.Text = '▶ Iniciar';
            btnStreamOn.Enable = 'on';
        end
        lblSyncSt.Text = 'Estado: ARMED';
        logH('Starts multiples terminado');
        logM('scopeMulti DONE');
    end

    function onVistaSecs(val)
        v = max(1, min(10, round(val)));
        DISP_SAMP = FS * v;
        logM(sprintf('dispSecs=%d DISP_SAMP=%d', v, DISP_SAMP));
    end

    function onMaxBufSecs(val)
        v = max(5, min(60, round(val / 5) * 5));
        S.maxBuf = FS * v;
        logM(sprintf('maxBufSecs=%d maxBuf=%d', v, S.maxBuf));
    end

    function onRenderPeriod(val)
        ms = max(50, min(500, round(val / 10) * 10));
        if ~isempty(tmrRender) && isvalid(tmrRender)
            wasOn = strcmp(tmrRender.Running, 'on');
            if wasOn, stop(tmrRender); end
            tmrRender.Period = ms / 1000;
            if wasOn, start(tmrRender); end
        end
        logM(sprintf('renderPeriod=%dms', ms));
    end

    function setStreamDebugSignal(enable)
        if isempty(S.port) || ~isvalid(S.port)
            S.streamDebugActive = false;
            return;
        end
        if ~enable && ~S.streamDebugActive
            return;
        end
        if enable
            lastDebugCh = 1 + S.nSlaves;
        else
            lastDebugCh = MAX_NODES;
        end
        if enable
            for chDbg = 2:lastDebugCh
                try, enviarDirigido(chDbg, hex2dec('A7'), uint8(enable)); catch, end
            end
            try, psocCmd(hex2dec('A7'), uint8(enable)); catch, end
        else
            try, psocCmd(hex2dec('A7'), uint8(enable)); catch, end
            for chDbg = 2:lastDebugCh
                try, enviarDirigido(chDbg, hex2dec('A7'), uint8(enable)); catch, end
            end
        end
        S.streamDebugActive = logical(enable);
        logM(sprintf('streamDebugSignal=%d', uint8(enable)));
    end

    function registerPending(ch, sub_cmd, param)
        if ch < 2 || ch > MAX_NODES, return; end
        p = S.node(ch).pending;
        idx = find(p.sub_cmds == sub_cmd, 1);
        if isempty(idx)
            p.sub_cmds(end+1) = sub_cmd;
            p.params(end+1)   = param;
            p.times(end+1)    = tic;
            p.retries(end+1)  = 0;
        else
            p.params(idx)  = param;
            p.times(idx)   = tic;
            p.retries(idx) = 0;
        end
        S.node(ch).pending = p;
    end

    function clearPending(ch, sub_cmd)
        if ch < 2 || ch > MAX_NODES, return; end
        p = S.node(ch).pending;
        keep = p.sub_cmds ~= sub_cmd;
        p.sub_cmds = p.sub_cmds(keep);
        p.params   = p.params(keep);
        p.times    = p.times(keep);
        p.retries  = p.retries(keep);
        S.node(ch).pending = p;
    end

    function checkRetries()
        if isempty(S.port) || ~isvalid(S.port), return; end
        MAX_RETRIES = 3;
        RETRY_SEC   = 1.5;
        for ch = 2:MAX_NODES
            p = S.node(ch).pending;
            if isempty(p.sub_cmds), continue; end
            for i = 1:numel(p.sub_cmds)
                if toc(p.times(i)) >= RETRY_SEC
                    if p.retries(i) < MAX_RETRIES
                        enviarDirigido(ch, p.sub_cmds(i), p.params(i));
                        p.retries(i) = p.retries(i) + 1;
                        p.times(i)   = tic;
                        logM(sprintf('retry ch=%d sub=0x%02X param=%d attempt=%d', ...
                            ch-1, p.sub_cmds(i), p.params(i), p.retries(i)));
                    else
                        logH(sprintf('%s: sin ACK sub=0x%02X tras %d reintentos', ...
                            nodeDisplayName(ch), p.sub_cmds(i), MAX_RETRIES));
                        % Marcar para borrar este pendiente agotado
                        p.retries(i) = MAX_RETRIES + 1;
                    end
                end
            end
            % Limpiar entradas agotadas
            keep = p.retries <= MAX_RETRIES;
            p.sub_cmds = p.sub_cmds(keep);
            p.params   = p.params(keep);
            p.times    = p.times(keep);
            p.retries  = p.retries(keep);
            S.node(ch).pending = p;
        end
    end

    function onClear(~,~)
        for ch = 1:MAX_NODES
            S.node(ch).notchBuf  = [];
            S.node(ch).filtBuf   = [];
            S.node(ch).filtZi    = [];
            S.node(ch).lineW     = [];
            S.node(ch).batchCount= 0;
            % driftHist se conserva — es calibración, no datos de muestra
            if isLiveHandle(S.node(ch).ax)
                set(S.node(ch).hRaw, 'XData',NaN,'YData',NaN);
                set(S.node(ch).hFilt,'XData',NaN,'YData',NaN);
            end
            updateStats(ch);
        end
        logH('Buffers limpiados'); logM('CLEAR');
    end

    function onNotchToggle(ch, val)
        S.node(ch).notchEnabled = val;
        if ~val, S.node(ch).lineW = []; end
        logM(sprintf('notch ch=%d enabled=%d', ch-1, val));
    end

    function onNotchMu(ch, val)
        S.node(ch).notchMu = val;
    end

    function onNotchHarm(ch, val)
        S.node(ch).notchHarm = max(1, min(5, round(val)));
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Callbacks — Test
%% ════════════════════════════════════════════════════════════════════════

    function runStartLatencyProbe(ch)
        if isempty(S.port) || ~isvalid(S.port), return; end
        clearStartLatency(ch);
        for kProbe = 1:START_LATENCY_PROBES
            enviarDirigido(ch, CMD_START_PROBE, mod(kProbe, 256));
            pause(START_LATENCY_PROBE_GAP_S);
            try, timerRX([],[]); catch, end
        end
        pause(START_LATENCY_PROBE_GAP_S);
        try, timerRX([],[]); catch, end
        if isempty(S.node(ch).startLatencyHist)
            logH(sprintf('Reacción ESP-NOW Esclavo %d: sin ACK', ch-1));
        else
            logH(sprintf('Reacción ESP-NOW Esclavo %d: %s', ...
                ch-1, formatLatencyStats(S.node(ch).startLatencyHist)));
        end
    end

    function onTestEsclavo(ch)
        if ch < 2 || ch > MAX_NODES, return; end
        if S.recordingActive, logH('Grabación activa — espera a que termine'); return; end
        wasStreaming = S.streaming;
        % Asegurar que el maestro no esté en modo debug antes del test
        psocCmd(hex2dec('A7'), 0);
        % Poner esclavos en modo streaming (AE=0) para que los batches de debug
        % se transmitan en lugar de almacenarse en RAM. El siguiente Inicio
        % reenvia n_batches en A3 y el maestro lo aplica en PRESTART.
        psocCmd16(hex2dec('AE'), 0);
        % Limpiar todos los buffers para que el test empiece sin datos rancios
        for chCl = 1:MAX_NODES
            S.node(chCl).notchBuf  = [];
            S.node(chCl).filtBuf   = [];
            S.node(chCl).batchCount = 0;
            if isLiveHandle(S.node(chCl).hRaw)
                set(S.node(chCl).hRaw,  'XData', NaN, 'YData', NaN);
                set(S.node(chCl).hFilt, 'XData', NaN, 'YData', NaN);
            end
            updateStats(chCl);
        end
        runStartLatencyProbe(ch);
        if ~wasStreaming
            psocCmd(hex2dec('A1'), 1);
            S.streaming = true;
        end
        % Setup drift: registrar tiempo de llegada del primer batch de este esclavo
        S.driftT0 = tic;
        S.node(ch).gotFirst  = false;
        S.node(ch).tFirst    = 0;
        enviarDirigido(ch, hex2dec('A7'), 1);
        init0 = S.node(ch).batchCount;
        S.node(ch).lblSalud.FontColor   = [0.8 0.6 0.0];
        S.node(ch).lblSaludTxt.Text     = 'Probando...';
        tmrS = timer('StartDelay',1.5,'ExecutionMode','singleShot','TimerFcn',@ck);
        start(tmrS);
        function ck(~,~)
            try, enviarDirigido(ch, hex2dec('A7'), 0); catch, end
            try, timerRX([],[]); catch, end
            if ~wasStreaming
                try, psocCmd(hex2dec('A1'), 0); catch, end
                S.streaming = false;
            end
            % Calcular deriva directamente desde tFirst (sin esperar a otros nodos)
            if S.node(ch).gotFirst
                dVal = S.node(ch).tFirst;
                S.node(ch).driftHist(end+1) = dVal;
                if length(S.node(ch).driftHist) > 50
                    S.node(ch).driftHist = S.node(ch).driftHist(end-49:end);
                end
                logM(sprintf('drift Esclavo %d tFirst=%.0f us', ch-1, dVal));
            end
            S.driftT0 = [];   % limpiar para no afectar próximas mediciones
            g  = S.node(ch).batchCount - init0;
            ok = g >= 3;
            S.node(ch).salud = 1 + ~ok;
            psocStr = psocStatusStr(ch);
            if ok
                S.node(ch).lblSalud.FontColor   = [0.0 0.7 0.0];
                S.node(ch).lblSaludTxt.Text     = ['OK  ' psocStr];
                logH(sprintf('Test Esclavo %d: OK  |  %s', ch-1, psocStr));
                if ~isempty(S.node(ch).driftHist) && isLiveHandle(driftLabels(ch-1))
                    driftLabels(ch-1).Text = sprintf('S%d deriva: %s', ...
                        ch-1, formatDriftStats(S.node(ch).driftHist));
                end
            else
                S.node(ch).lblSalud.FontColor   = [0.8 0.1 0.1];
                S.node(ch).lblSaludTxt.Text     = sprintf('FAIL (%d)  %s', g, psocStr);
                logH(sprintf('Test Esclavo %d: FAIL (%d batches)  |  %s', ch-1, g, psocStr));
            end
            logM(sprintf('testEsclavo ch=%d batches=%d ok=%d psoc=%s', ...
                ch-1, g, ok, psocStr));
            try, delete(tmrS); catch, end
        end
    end

    function onVerNodo(ch)
        % "Ver": disparo único. El PSoC del nodo muestrea N lotes y los envía
        % solo (sin esperar el START broadcast). Pseudo-tiempo-real para calibrar
        % VDAC observando un único nodo.
        if ch < 2 || ch > MAX_NODES, return; end
        if isempty(S.port) || ~isvalid(S.port)
            logH('Ver: conecta el maestro primero'); return;
        end
        if S.recordingActive
            logH('Ver: grabación activa — espera a que termine'); return;
        end
        % Verificar que el PSoC esté detectado (HELLO con psoc_ok=1)
        if ~isempty(S.node(ch).psocOk) && ~S.node(ch).psocOk
            logH(sprintf('Ver Esclavo %d: PSoC no detectado — espera a que el esclavo lo encuentre', ch-1));
            return;
        end
        n = max(1, min(65535, round(spnRecN.Value)));
        % Fijar N en el maestro (lo usa para MsgView). El esclavo objetivo entra
        % en modo "sin store" (envío en vivo) en su handler de CMD_VIEW.
        psocCmd16(hex2dec('AE'), n);
        % Limpiar buffer del nodo y hacerlo visible para verlo en vivo
        S.node(ch).notchBuf   = [];
        S.node(ch).filtBuf    = [];
        S.node(ch).batchCount = 0;
        S.node(ch).visible    = true;
        if isLiveHandle(cbVis(ch)), cbVis(ch).Value = true; end
        updatePlotLayout();   % asegurar que el eje esté visible (Value programático no dispara callback)
        if isLiveHandle(S.node(ch).hRaw)
            set(S.node(ch).hRaw,  'XData', NaN, 'YData', NaN);
            set(S.node(ch).hFilt, 'XData', NaN, 'YData', NaN);
        end
        S.streaming = true;
        % Disparo dirigido: sub_cmd 0xB2 = Ver
        enviarDirigido(ch, hex2dec('B2'), 1);
        S.renderDirty(ch) = true;
        logH(sprintf('Ver nodo Esclavo %d: captura única N=%d lotes', ch-1, n));
        logM(sprintf('VER ch=%d n=%d', ch-1, n));
        % Timeout: si no llegan lotes en el tiempo esperado, avisar y frenar el esclavo
        fsNode = max(1, S.node(ch).fs);
        toutSecs = max(3.0, n * 30 / fsNode * 1.5 + 1.0);
        tmrVer = timer('StartDelay', toutSecs, 'ExecutionMode', 'singleShot', ...
            'TimerFcn', @(~,~) verTimeout(ch));
        start(tmrVer);
    end

    function s = psocStatusStr(ch)
        if isempty(S.node(ch).psocOk)
            s = 'PSoC: ?';
        elseif S.node(ch).psocOk
            s = 'PSoC: DETECTADO';
        else
            s = 'PSoC: no detectado';
        end
    end

    function verTimeout(ch)
        if S.node(ch).batchCount == 0
            logH(sprintf('Ver Esclavo %d: timeout (%.1fs) — sin datos. ¿PSoC conectado?', ...
                ch-1, max(3.0, round(spnRecN.Value) * 30 / max(1, S.node(ch).fs) * 1.5 + 1.0)));
            logM(sprintf('VER_TIMEOUT ch=%d', ch-1));
            if ~isempty(S.port) && isvalid(S.port)
                % Limpiar g_rec_n_batches en el maestro ANTES del STOP para
                % evitar que el maestro intente volcar datos que no existen.
                psocCmd16(hex2dec('AE'), 0);
                psocCmd(hex2dec('A4'), 0);
            end
            S.streaming = false;
        end
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Callbacks — VRef DC (solo esclavos)
%% ════════════════════════════════════════════════════════════════════════

    function sendVdacByte(ch, byte, efVdac, lblDacV)
        byte = max(0, min(255, round(byte)));
        if byte == S.node(ch).vdac_byte && ~isempty(S.node(ch).pending.sub_cmds) && ...
                any(S.node(ch).pending.sub_cmds == hex2dec('AA'))
            return;  % valor sin cambio y ya hay pending
        end
        S.node(ch).vdac_byte = byte;
        if nargin >= 3 && isLiveHandle(efVdac), efVdac.Value = byte; end
        if nargin >= 4 && isLiveHandle(lblDacV)
            lblDacV.Text = sprintf('%.3f V', byte*VDAC_STEP);
        end
        enviarDirigido(ch, hex2dec('AA'), byte);
        registerPending(ch, hex2dec('AA'), byte);
        logH(sprintf('%s VDAC→%d (%.3fV)', nodeDisplayName(ch), byte, byte*VDAC_STEP));
        logM(sprintf('VDAC ch=%d byte=%d volts=%.3f', ch-1, byte, byte*VDAC_STEP));
    end

    function [vbyte, pcode] = calcVdacSetting(targetV)
        gain_vals = [1, 2, 4, 5, 8, 10, 16, 32, 50];
        MAX_VDAC_V = 255 * VDAC_STEP;
        targetV = max(0, targetV);
        min_gain = targetV / MAX_VDAC_V;
        valid = gain_vals(gain_vals >= min_gain);
        if isempty(valid)
            pcode = numel(gain_vals) - 1;
            g = gain_vals(end);
        else
            pcode = find(gain_vals == valid(1), 1) - 1;
            g = valid(1);
        end
        vbyte = min(255, max(0, round(targetV / g / VDAC_STEP)));
    end

    function sendVdacTarget(ch, targetV, efVdac, lblDacV)
        gains = {'1x','2x','4x','5x','8x','10x','16x','32x','50x'};
        [byte, pcode] = calcVdacSetting(targetV);
        if pcode ~= S.node(ch).pgavdac
            S.node(ch).pgavdac = pcode;
            enviarDirigido(ch, hex2dec('A9'), pcode);
            registerPending(ch, hex2dec('A9'), pcode);
            if isLiveHandle(S.node(ch).lblPgaVdacSt)
                S.node(ch).lblPgaVdacSt.Text = sprintf('PGAvdac: %s (auto)', gains{pcode+1});
            end
            logH(sprintf('%s PGAvdac→%s (auto)', nodeDisplayName(ch), gains{pcode+1}));
        end
        sendVdacByte(ch, byte, efVdac, lblDacV);
    end

    function adjustVdac(ch, efVdac, lblDacV, delta)
        gain_vals = [1, 2, 4, 5, 8, 10, 16, 32, 50];
        cur_gain = gain_vals(S.node(ch).pgavdac + 1);
        V_cur = double(S.node(ch).vdac_byte) * VDAC_STEP * cur_gain;
        V_new = max(0, V_cur + delta * VDAC_STEP * cur_gain);
        sendVdacTarget(ch, V_new, efVdac, lblDacV);
    end

    function sendPgaVdac(ch, dd, gains)
        code = find(strcmp(gains,dd.Value)) - 1;
        S.node(ch).pgavdac = code;
        enviarDirigido(ch, hex2dec('A9'), code);
        registerPending(ch, hex2dec('A9'), code);
        logH(sprintf('Nodo %d PGAvdac→%s',ch-1,dd.Value));
    end

    function sendPga(ch, dd, gains)
        code = find(strcmp(gains,dd.Value)) - 1;
        if code == S.node(ch).pga_code, return; end
        S.node(ch).pga_code = code;
        S.node(ch).lblPgaSt.Text = sprintf('Actual: %s',dd.Value);
        if isLiveHandle(S.node(ch).lblCalSt), S.node(ch).lblCalSt.Text = calStatusText(ch); end
        enviarDirigido(ch, hex2dec('A6'), code);
        registerPending(ch, hex2dec('A6'), code);
        logH(sprintf('Nodo %d PGA→%s',ch-1,dd.Value));
    end

    function saveCalForPGA(ch, lblCalSt)
        code = S.node(ch).pga_code;
        if isempty(S.node(ch).notchBuf)
            dc = NaN;
        else
            dc = mean(S.node(ch).notchBuf(max(1,end-S.node(ch).fs+1):end));
        end
        S.node(ch).cal(code+1,:) = [code, S.node(ch).vdac_byte, dc];
        S.node(ch).calValid(code+1) = true;
        lblCalSt.Text = calStatusText(ch);
        logH(sprintf('%s: guardado PGA %s → VDAC %d', ...
            nodeDisplayName(ch), pgaGainName(code), S.node(ch).vdac_byte));
    end

    function applyCal(ch)
        code = S.node(ch).pga_code;
        row  = S.node(ch).cal(code+1,:);
        if ~S.node(ch).calValid(code+1)
            logH(sprintf('%s: sin VDAC guardado para PGA %s', ...
                nodeDisplayName(ch), pgaGainName(code)));
            return;
        end
        sendVdacByte(ch, row(2), S.node(ch).efVdac, S.node(ch).lblDacV);
        if isLiveHandle(S.node(ch).lblCalSt), S.node(ch).lblCalSt.Text = calStatusText(ch); end
        logH(sprintf('%s: aplicado PGA %s → VDAC %d', ...
            nodeDisplayName(ch), pgaGainName(code), row(2)));
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Callbacks — FIR / DC
%% ════════════════════════════════════════════════════════════════════════

    function applyFir(ch, cmdStr)
        cmdStr = strtrim(cmdStr);
        if isempty(cmdStr), return; end
        b = compileFirCommand(cmdStr, ch);
        if isempty(b)
            logH('FIR error: expresión/atajo inválido o coeficientes vacíos');
            return;
        end
        S.node(ch).filtB   = b;
        S.node(ch).filtCmd = cmdStr;
        S.node(ch).filtZi  = zeros(1,length(b)-1);
        S.node(ch).lblFiltSt.Text = sprintf('FIR %d coefs',length(b));
        S.node(ch).hFilt.Visible  = 'on';
        logH(sprintf('Nodo %d FIR %d coefs (fs=%dHz)',ch-1,length(b),S.node(ch).fs));
        logM(sprintf('FIR ch=%d n=%d fs=%d cmd="%s"',ch-1,length(b),S.node(ch).fs,cmdStr));
    end

    function removeFir(ch)
        S.node(ch).filtB  = []; S.node(ch).filtZi = [];
        S.node(ch).lblFiltSt.Text = 'Sin filtro';
        S.node(ch).hFilt.Visible  = 'off';
    end

    function setDcRemove(ch, val), S.node(ch).dcRemove = val; end


    function sendTxMode(ch, modeName)
        mode = txModeCode(modeName);
        if mode == S.node(ch).tx_mode, return; end
        S.node(ch).tx_mode = mode;
        if S.node(ch).debugActive
            try, enviarDirigido(ch, hex2dec('A7'), 0); catch, end
            S.node(ch).debugActive = false;
        end
        enviarDirigido(ch, hex2dec('A8'), mode);
        registerPending(ch, hex2dec('A8'), mode);
        logH(sprintf('%s TX→%s', nodeDisplayName(ch), txModeName(mode)));
        logM(sprintf('TX mode ch=%d mode=%s code=%d',ch-1,txModeName(mode),mode));
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Callback — visibilidad plots
%% ════════════════════════════════════════════════════════════════════════

    function onCheckboxChannel(ch, val)
        S.node(ch).visible = val;
        updatePlotLayout();
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Timer RX
%% ════════════════════════════════════════════════════════════════════════

    function timerRX(~,~)
        try, checkRetries(); catch, end
        try, pollAllDbg(); catch, end
        if isempty(S.port) || ~isvalid(S.port), return; end
        try
            n = S.port.NumBytesAvailable;
            if n > 0, S.rxBuf = [S.rxBuf, read(S.port,n,'uint8')]; end
        catch; return; end

        while length(S.rxBuf) >= 6
            idx = find(S.rxBuf == PKT_HEADER, 1);
            if isempty(idx), S.rxBuf = uint8([]); break; end
            if idx > 1, S.rxBuf = S.rxBuf(idx:end); end
            if length(S.rxBuf) < 6, break; end
            changedCh = decodePkt(S.rxBuf(1:6));
            if changedCh >= 1 && changedCh <= MAX_NODES
                S.renderDirty(changedCh) = true;
            end
            S.rxBuf = S.rxBuf(7:end);
        end
    end

    function timerRenderFcn(~,~)
        dirty = S.renderDirty;
        S.renderDirty(:) = false;
        if ~S.recordingActive
            for chUpd = find(dirty)
                updatePlot(chUpd);
            end
            if any(dirty)
                drawnow limitrate;
            end
        end
        if any(dirty) && isLiveHandle(lblDatos)
            totalSamp = 0;
            for ccc = 1:MAX_NODES
                totalSamp = totalSamp + length(S.node(ccc).notchBuf);
            end
            totalRx = sum([S.node.batchCount]);
            lblDatos.Text = sprintf('Buf: %d mts  |  RX: %d mts', totalSamp, totalRx);
        end
        % Volcar líneas de debug pendientes a sus textareas (batched, fuera del timer RX)
        for dCh = 1:MAX_NODES
            if ~isempty(S.node(dCh).dbgPending) && isLiveHandle(S.node(dCh).dbgTa)
                ta = S.node(dCh).dbgTa;
                try
                    cur = ta.Value;
                    if ischar(cur), cur = {cur}; end
                    cur = [cur; S.node(dCh).dbgPending(:)];
                    if numel(cur) > 80, cur = cur(end-79:end); end
                    ta.Value = cur;
                    scroll(ta,'bottom');
                catch, end
                S.node(dCh).dbgPending = {};
            end
        end
    end

    function changedCh = decodePkt(pkt)
        changedCh = 0;
        node_id = double(pkt(2));
        typ     = double(pkt(3));
        b2=double(pkt(4)); b1=double(pkt(5)); b0=double(pkt(6));

        % 0xFC — estimación reacción ESP-NOW START: RTT/2 en microsegundos
        if typ == 252
            if node_id == 255, return; end
            chLat = node_id + 1;
            if chLat < 2 || chLat > MAX_NODES, return; end
            tofUs = b2*65536 + b1*256 + b0;
            S.node(chLat).startLatencyHist(end+1) = tofUs;
            if length(S.node(chLat).startLatencyHist) > 50
                S.node(chLat).startLatencyHist = S.node(chLat).startLatencyHist(end-49:end);
            end
            updateLatencyLabel(chLat);
            logM(sprintf('startLatency Esclavo %d tof_us=%d', node_id, tofUs));
            return;
        end

        % 0xFD — diagnóstico: master status o HELLO de esclavo
        if typ == 253
            if node_id == 255
                logH(sprintf('Master: ESP-NOW=%s  ch=%d', ternary(b2==1,'OK','FAIL'), b1));
            else
                ch = node_id + 1;
                if b2 == 5
                    fs_exact = b1*256 + b0;
                    if ch >= 2 && ch <= MAX_NODES && fs_exact > 0
                        S.node(ch).fs = fs_exact;
                        S.node(ch).fsKnown = true;
                        if isLiveHandle(S.node(ch).lblStats), updateStats(ch); end
                    end
                    logM(sprintf('HELLO node=%d fs_exact=%dHz', node_id, fs_exact));
                elseif b2 == 1
                    % b2=0x01 = HELLO legacy, b1=psoc_ok, b0=fs/100 (0=desconocido)
                    if ch >= 2 && ch <= MAX_NODES
                        S.node(ch).psocOk = (b1 == 1);
                        if b0 > 0
                            S.node(ch).fs = b0 * 100;
                            S.node(ch).fsKnown = true;
                            if isLiveHandle(S.node(ch).lblStats), updateStats(ch); end
                        end
                    end
                    fs_str = ternary(b0 > 0, sprintf(' fs=%dHz', b0*100), '');
                    logM(sprintf('HELLO node=%d psoc=%d%s', node_id, b1, fs_str));
                elseif b2 >= 2 && b2 <= 4
                    % MAC byte-pair packet, handled by newer web/Python clients.
                else
                    logM(sprintf('STATUS node=%d b=[%d,%d,%d]', node_id, b2, b1, b0));
                end
            end
            return;
        end

        % node_id 0xFF = mensaje global del maestro → tratar como nodo 0
        if node_id == 255
            if typ == 1 || typ == 7 || typ == 254
                node_id = 0;
            else
                return;
            end
        end

        ch = node_id + 1;
        if ch < 1 || ch > MAX_NODES, return; end

        switch typ
            case 0    % dato
                v24 = b2*65536 + b1*256 + b0;
                if v24 >= 2^23, v24 = v24 - 2^24; end
                appendSample(ch, v24);
                changedCh = ch;

            case 1    % heartbeat [pga, vdac, state]
                updateHBUI(ch, b2, b1);
                logM(sprintf('HB ch=%d pga=%d vdac=%d state=%d',node_id,b2,b1,b0));
                if ch == 1, handleMasterStateChange(b0); end

            case 7    % ACK [cmd, val, 0]
                logH(sprintf('ACK nodo=%d cmd=0x%02X val=%d',node_id,b2,b1));
                logM(sprintf('ACK ch=%d cmd=0x%02X val=%d',node_id,b2,b1));
                if ch >= 2 && ch <= MAX_NODES
                    clearPending(ch, b2);
                end

            case 254  % READY (0xFE)
                lblArmCnt.Text = sprintf('Esclavos listos: %d',b2);
                if ~S.streaming && ~S.multiStartActive
                    lblSyncSt.Text = 'Estado: ARMED';
                end
                logH(sprintf('READY: %d esclavos',b2));
                logM(sprintf('READY n=%d',b2));
                checkFsConsistency();
        end
    end

    function appendSample(ch, val)
        S.node(ch).notchBuf(end+1) = double(val);
        S.node(ch).batchCount = S.node(ch).batchCount + 1;
        % Registrar tiempo de primera muestra (para estimación de drift)
        if ch <= 1 + S.nSlaves && ~isempty(S.driftT0) && ~S.node(ch).gotFirst
            S.node(ch).gotFirst = true;
            S.node(ch).tFirst   = toc(S.driftT0) * 1e6;   % µs desde START
            activeDriftCh = 1:(1 + S.nSlaves);
            if all([S.node(activeDriftCh).gotFirst])
                computeDrift();
            end
        end
        if length(S.node(ch).notchBuf) > S.maxBuf
            S.node(ch).notchBuf = S.node(ch).notchBuf(end-S.maxBuf+1:end);
        end
        % Cancelador 50 Hz (por nodo)
        if S.node(ch).notchEnabled
            [sv, S.node(ch).lineW] = lineCanceller(S.node(ch).notchBuf(end), ...
                S.node(ch).lineW, S.node(ch).batchCount, S.node(ch).fs, 50, ...
                S.node(ch).notchHarm, S.node(ch).notchMu);
            S.node(ch).notchBuf(end) = sv;
        end
        % FIR incremental
        if ~isempty(S.node(ch).filtB)
            [fv, S.node(ch).filtZi] = filter(S.node(ch).filtB,1, ...
                S.node(ch).notchBuf(end), S.node(ch).filtZi);
            S.node(ch).filtBuf(end+1) = fv;
            if length(S.node(ch).filtBuf) > S.maxBuf
                S.node(ch).filtBuf = S.node(ch).filtBuf(end-S.maxBuf+1:end);
            end
        end
        % Stats cada 200 muestras
        if mod(S.node(ch).batchCount, 200) == 0, updateStats(ch); end
    end

    function updatePlot(ch)
        if ~S.node(ch).visible || ~isLiveHandle(S.node(ch).ax), return; end
        raw = S.node(ch).notchBuf;
        if isempty(raw), return; end
        if length(raw) > DISP_SAMP
            raw = raw(end-DISP_SAMP+1:end);
        end
        y = raw;
        if S.node(ch).dcRemove, y = raw - mean(raw); end
        S.node(ch).hRaw.XData = 1:length(y);
        S.node(ch).hRaw.YData = y;
        if ~isempty(S.node(ch).filtBuf)
            fb = S.node(ch).filtBuf;
            if length(fb) > DISP_SAMP
                fb = fb(end-DISP_SAMP+1:end);
            end
            S.node(ch).hFilt.XData = 1:length(fb);
            S.node(ch).hFilt.YData = fb;
        end
    end

    function updateStats(ch)
        dStr = '--';
        if ~isempty(S.node(ch).driftHist)
            dStr = formatDriftStats(S.node(ch).driftHist);
        end
        nSamples = S.node(ch).batchCount;
        nBatches = floor(nSamples / 30);
        if isLiveHandle(S.node(ch).lblStats)
            if ch == 1
                S.node(ch).lblStats.Text = sprintf('Mts: %d  Bat: %d', ...
                    nSamples, nBatches);
            else
                fsLbl = ternary(S.node(ch).fsKnown, sprintf('  FS:%dHz',S.node(ch).fs), '');
                S.node(ch).lblStats.Text = sprintf('Mts: %d  Bat: %d  Drift: %s%s', ...
                    nSamples, nBatches, dStr, fsLbl);
            end
        end
        if ~isempty(S.node(ch).notchBuf) && isLiveHandle(S.node(ch).lblLastVal)
            S.node(ch).lblLastVal.Text = sprintf('Último: %d LSB', ...
                round(S.node(ch).notchBuf(end)));
        end
        if isLiveHandle(globalBatch(ch))
            globalBatch(ch).Text = sprintf('%s: %d bat (%d mts)', ...
                NODE_NAMES{ch}, nBatches, nSamples);
        end
        if ch >= 2 && isLiveHandle(driftLabels(ch-1)) && ~isempty(S.node(ch).driftHist)
            driftLabels(ch-1).Text = sprintf('S%d deriva: %s', ...
                ch-1, formatDriftStats(S.node(ch).driftHist));
        end
        if ch >= 2 && isLiveHandle(latencyLabels(ch-1)) && ~isempty(S.node(ch).startLatencyHist)
            updateLatencyLabel(ch);
        end
    end

    function updateLatencyLabel(ch)
        if ch < 2 || ch > MAX_NODES, return; end
        if ~isLiveHandle(latencyLabels(ch-1)), return; end
        latencyLabels(ch-1).Text = sprintf('S%d: %s', ...
            ch-1, formatLatencyStats(S.node(ch).startLatencyHist));
    end

    function s = formatDriftScalar(valueUs)
        if isempty(valueUs) || isnan(valueUs)
            s = '--';
            return;
        end
        s = sprintf('%.6E s', valueUs * 1e-6);
    end

    function s = formatDriftStats(valuesUs)
        mu = mean(valuesUs);
        n = numel(valuesUs);
        if n < 2
            s = sprintf('%.6E±-- s n=%d', mu * 1e-6, n);
            return;
        end
        sig = std(valuesUs);
        s = sprintf('%.6E±%.6E s n=%d', mu * 1e-6, sig * 1e-6, n);
    end

    function s = formatLatencyStats(valuesUs)
        if isempty(valuesUs)
            s = '--';
            return;
        end
        mu = mean(valuesUs) / 1000;
        n = numel(valuesUs);
        if n < 2
            s = sprintf('%.3f±-- ms n=%d', mu, n);
            return;
        end
        sig = std(valuesUs) / 1000;
        s = sprintf('%.3f±%.3f ms n=%d', mu, sig, n);
    end

    function clearStartLatency(ch)
        if ch < 2 || ch > MAX_NODES, return; end
        S.node(ch).startLatencyHist = [];
        if isLiveHandle(latencyLabels(ch-1))
            latencyLabels(ch-1).Text = sprintf('S%d: --', ch-1);
        end
    end

    function appCfg = makeConfigSnapshot()
        appCfg.version = 3;
        appCfg.saved_at = datestr(now);
        appCfg.fs = currentAcquisitionFs();
        appCfg.max_nodes = MAX_NODES;
        appCfg.vdac_step_volts = VDAC_STEP;
        appCfg.node_names = NODE_NAMES;
        appCfg.tx_mode_items = TX_MODE_ITEMS;
        appCfg.nSlaves = S.nSlaves;
        appCfg.hammer_tip = S.hammerTip;
        appCfg.stream_debug = S.streamDebug;
        appCfg.starts_multiple = S.startsMultiple;
        appCfg.plot_visible = [S.node.visible];
        if isLiveHandle(efSaveName)
            appCfg.save_basename = efSaveName.Value;
        else
            appCfg.save_basename = S.saveBaseName;
        end
        if isLiveHandle(ddPort)
            appCfg.last_usb_port = ddPort.Value;
        else
            appCfg.last_usb_port = S.lastUsbPort;
        end
        for chCfg = 1:MAX_NODES
            appCfg.node(chCfg) = makeNodeConfigSnapshot(chCfg); %#ok<AGROW>
        end
        appCfg.hammer = appCfg.node(1);
        if S.nSlaves > 0
            appCfg.slave = appCfg.node(2:1+S.nSlaves);
        else
            appCfg.slave = struct([]);
        end
    end

    function nodeCfg = makeNodeConfigSnapshot(chCfg)
        nodeCfg.node_id = chCfg - 1;
        nodeCfg.name = nodeDisplayName(chCfg);
        nodeCfg.default_name = NODE_NAMES{chCfg};
        nodeCfg.slave_id = S.node(chCfg).slave_id;
        nodeCfg.is_master = (chCfg == 1);
        nodeCfg.is_active = (chCfg == 1) || (chCfg <= 1 + S.nSlaves);
        nodeCfg.visible = S.node(chCfg).visible;
        nodeCfg.pga_code = S.node(chCfg).pga_code;
        nodeCfg.pga_gain = pgaGainName(S.node(chCfg).pga_code);
        nodeCfg.vdac_byte = S.node(chCfg).vdac_byte;
        nodeCfg.vdac_volts = S.node(chCfg).vdac_byte * VDAC_STEP;
        nodeCfg.pgavdac = S.node(chCfg).pgavdac;
        nodeCfg.pgavdac_gain = pgaGainName(S.node(chCfg).pgavdac);
        nodeCfg.calibration = S.node(chCfg).cal;
        nodeCfg.calibration_valid = S.node(chCfg).calValid;
        nodeCfg.fir_cmd = S.node(chCfg).filtCmd;
        nodeCfg.fir_coeffs = S.node(chCfg).filtB;
        nodeCfg.fir_enabled = ~isempty(S.node(chCfg).filtB);
        nodeCfg.dc_remove = S.node(chCfg).dcRemove;
        nodeCfg.notch_enabled = S.node(chCfg).notchEnabled;
        nodeCfg.notch_mu = S.node(chCfg).notchMu;
        nodeCfg.notch_harmonics = S.node(chCfg).notchHarm;
        nodeCfg.tx_mode = uint8(txModeCode(S.node(chCfg).tx_mode));
        nodeCfg.tx_mode_name = txModeName(S.node(chCfg).tx_mode);
        nodeCfg.debug_on_start = (nodeCfg.tx_mode == TX_DEBUG);
        nodeCfg.fs = S.node(chCfg).fs;
        nodeCfg.fs_known = S.node(chCfg).fsKnown;
    end

    function applyConfigSnapshot(appCfg)
        if isfield(appCfg,'nSlaves'), S.nSlaves = max(0, min(3, round(appCfg.nSlaves))); end
        if isfield(appCfg,'hammer_tip'), S.hammerTip = appCfg.hammer_tip; end
        if isfield(appCfg,'stream_debug'), S.streamDebug = logical(appCfg.stream_debug); end
        if isfield(appCfg,'starts_multiple'), S.startsMultiple = logical(appCfg.starts_multiple); end
        if isfield(appCfg,'save_basename'), S.saveBaseName = appCfg.save_basename; end
        if isfield(appCfg,'last_usb_port'), S.lastUsbPort = appCfg.last_usb_port; end
        if ~isfield(appCfg,'node'), return; end
        nc = appCfg.node;
        for chCfg = 1:min(MAX_NODES, numel(nc))
            restoreNodeConfig(chCfg, nc(chCfg));
        end
        if isfield(appCfg,'plot_visible')
            for chCfg = 1:min(MAX_NODES, numel(appCfg.plot_visible))
                S.node(chCfg).visible = logical(appCfg.plot_visible(chCfg));
            end
        end
    end

    function restoreNodeConfig(chCfg, nodeCfg)
        if isfield(nodeCfg,'slave_id'), S.node(chCfg).slave_id = nodeCfg.slave_id; end
        if isfield(nodeCfg,'pga_code'), S.node(chCfg).pga_code = nodeCfg.pga_code; end
        if isfield(nodeCfg,'vdac_byte'), S.node(chCfg).vdac_byte = nodeCfg.vdac_byte; end
        if isfield(nodeCfg,'pgavdac'), S.node(chCfg).pgavdac = nodeCfg.pgavdac; end
        if isfield(nodeCfg,'calibration'), S.node(chCfg).cal = nodeCfg.calibration; end
        if isfield(nodeCfg,'cal'), S.node(chCfg).cal = nodeCfg.cal; end
        if isfield(nodeCfg,'calibration_valid')
            S.node(chCfg).calValid = logical(nodeCfg.calibration_valid);
        elseif isfield(nodeCfg,'calValid')
            S.node(chCfg).calValid = logical(nodeCfg.calValid);
        else
            S.node(chCfg).calValid = any(S.node(chCfg).cal ~= 0, 2);
        end
        if isfield(nodeCfg,'fir_cmd'), S.node(chCfg).filtCmd = nodeCfg.fir_cmd; end
        if isfield(nodeCfg,'filtCmd'), S.node(chCfg).filtCmd = nodeCfg.filtCmd; end
        if isfield(nodeCfg,'fir_coeffs')
            S.node(chCfg).filtB = nodeCfg.fir_coeffs;
        elseif isfield(nodeCfg,'filtB')
            S.node(chCfg).filtB = nodeCfg.filtB;
        elseif ~isempty(S.node(chCfg).filtCmd)
            S.node(chCfg).filtB = compileFirCommand(S.node(chCfg).filtCmd, chCfg);
        end
        if ~isempty(S.node(chCfg).filtB)
            S.node(chCfg).filtZi = zeros(1,max(0,length(S.node(chCfg).filtB)-1));
        end
        if isfield(nodeCfg,'dc_remove'), S.node(chCfg).dcRemove = logical(nodeCfg.dc_remove); end
        if isfield(nodeCfg,'dcRemove'), S.node(chCfg).dcRemove = logical(nodeCfg.dcRemove); end
        if isfield(nodeCfg,'notch_enabled'), S.node(chCfg).notchEnabled = logical(nodeCfg.notch_enabled); end
        if isfield(nodeCfg,'notchEnabled'), S.node(chCfg).notchEnabled = logical(nodeCfg.notchEnabled); end
        if isfield(nodeCfg,'notch_mu'), S.node(chCfg).notchMu = nodeCfg.notch_mu; end
        if isfield(nodeCfg,'notchMu'), S.node(chCfg).notchMu = nodeCfg.notchMu; end
        if isfield(nodeCfg,'notch_harmonics'), S.node(chCfg).notchHarm = nodeCfg.notch_harmonics; end
        if isfield(nodeCfg,'notchHarm'), S.node(chCfg).notchHarm = nodeCfg.notchHarm; end
        if isfield(nodeCfg,'tx_mode'), S.node(chCfg).tx_mode = txModeCode(nodeCfg.tx_mode); end
        if isfield(nodeCfg,'tx_mode_name'), S.node(chCfg).tx_mode = txModeCode(nodeCfg.tx_mode_name); end
        if isfield(nodeCfg,'visible'), S.node(chCfg).visible = logical(nodeCfg.visible); end
    end

    function b = compileFirCommand(cmdStr, ch)
        b = [];
        cmdStr = strtrim(cmdStr);
        if isempty(cmdStr), return; end
        fsHz = S.node(ch).fs;                 % fs reportada por el nodo (HELLO); FS es solo el valor nominal de arranque
        if ~isnumeric(fsHz) || isempty(fsHz) || fsHz <= 0, fsHz = FS; end
        try
            b = parseFilterShorthand(cmdStr, fsHz);
            if isempty(b)
                fs = fsHz; %#ok<NASGU> % disponible para expresiones tipo fir1(64,[235 245]/(fs/2),'stop')
                b = eval(cmdStr);
            end
            if ~isvector(b) || ~isnumeric(b), b = []; return; end
            b = b(:)' / sum(abs(b));
        catch
            b = [];
        end
    end

    function b = parseFilterShorthand(cmdStr, fsHz)
        % Atajos de texto: "lp Fc" | "hp Fc" | "bp F1 F2" | "sb Fc" | "sb F1 F2"
        % (lowpass / highpass / bandpass / stopband-notch), diseñados con fir1
        % usando la fs real del nodo (fsHz). Devuelve [] si cmdStr no matchea
        % el atajo, para que compileFirCommand caiga al eval() genérico.
        b = [];
        toks = strsplit(lower(cmdStr));
        if numel(toks) < 2, return; end
        key = toks{1};
        if ~any(strcmp(key, {'lp','hp','bp','sb','notch'})), return; end
        nums = str2double(toks(2:end));
        if isempty(nums) || any(isnan(nums)), return; end
        nyq      = fsHz / 2;
        ORDER    = 64;   % orden FIR por defecto (fir1 lo ajusta a par si hace falta)
        NOTCH_BW = 10;   % Hz de ancho total cuando "sb" recibe solo la frecuencia central
        switch key
            case 'lp'
                if numel(nums) ~= 1, return; end
                b = fir1(ORDER, nums(1)/nyq, 'low');
            case 'hp'
                if numel(nums) ~= 1, return; end
                b = fir1(ORDER, nums(1)/nyq, 'high');
            case 'bp'
                if numel(nums) ~= 2, return; end
                b = fir1(ORDER, sort(nums)/nyq, 'bandpass');
            case {'sb','notch'}
                if numel(nums) == 1
                    band = [nums(1)-NOTCH_BW/2, nums(1)+NOTCH_BW/2];
                elseif numel(nums) == 2
                    band = sort(nums);
                else
                    return
                end
                band = min(max(band, 0.01), nyq-0.01);
                b = fir1(ORDER, band/nyq, 'stop');
        end
        b = b(:)';
    end

    function txt = firStatusText(chCfg)
        if isempty(S.node(chCfg).filtB)
            txt = 'Sin filtro';
        else
            txt = sprintf('FIR %d coefs', length(S.node(chCfg).filtB));
        end
    end

    function mode = txModeCode(modeName)
        if isnumeric(modeName) || islogical(modeName)
            mode = uint8(modeName);
            % TX_DEBUG ya no existe en la UI; degradar a TX_RAW
            if mode == TX_DEBUG, mode = TX_RAW; end
            return;
        end
        if any(strcmpi(modeName, {'Filtered ADC','Filtrado','Filtered','Filtro'}))
            mode = TX_FILTERED;
        else
            mode = TX_RAW;
        end
    end

    function name = txModeName(mode)
        mode = txModeCode(mode);
        if mode == TX_FILTERED
            name = 'Filtered ADC';
        else
            name = 'Raw ADC';
        end
    end

    function name = pgaGainName(code)
        gains = {'1x','2x','4x','5x','8x','10x','16x','32x','50x'};
        idx = double(code) + 1;
        if idx >= 1 && idx <= numel(gains)
            name = gains{idx};
        else
            name = sprintf('code_%d', double(code));
        end
    end

    function name = nodeDisplayName(chCfg)
        if chCfg == 1
            name = NODE_NAMES{chCfg};
            return;
        end
        id = strtrim(S.node(chCfg).slave_id);
        if isempty(id)
            name = NODE_NAMES{chCfg};
        else
            name = sprintf('%s (%s)', NODE_NAMES{chCfg}, id);
        end
    end

    function titleText = slaveTabTitle(chCfg)
        id = strtrim(S.node(chCfg).slave_id);
        if isempty(id)
            titleText = sprintf('Esclavo %d', chCfg-1);
        else
            titleText = sprintf('Esclavo %d - %s', chCfg-1, id);
        end
    end

    function setSlaveId(chCfg, id)
        id = strtrim(id);
        if isempty(id), id = sprintf('S%d', chCfg-1); end
        S.node(chCfg).slave_id = id;
        updateSlaveTitle(chCfg);
        logM(sprintf('slave_id ch=%d id="%s"', chCfg-1, id));
    end

    function updateSlaveTitle(chCfg)
        if chCfg >= 2 && chCfg <= 4 && isLiveHandle(tabs(chCfg))
            tabs(chCfg).Title = slaveTabTitle(chCfg);
        end
    end

    function txt = calStatusText(chCfg)
        code = S.node(chCfg).pga_code;
        if S.node(chCfg).calValid(code+1)
            row = S.node(chCfg).cal(code+1,:);
            txt = sprintf('%s → VDAC %d', pgaGainName(code), round(row(2)));
        else
            txt = sprintf('%s sin VDAC', pgaGainName(code));
        end
    end

    function handleMasterStateChange(masterState)
        % Llamado desde heartbeat del maestro (ch=1). Detecta DUMPING e IDLE post-dump.
        oldState = S.prevMasterState;
        if masterState == oldState, return; end
        S.prevMasterState = masterState;
        switch masterState
            case MASTER_STATE_PRESTART
                if S.multiStartActive && isLiveHandle(lblSyncSt)
                    lblSyncSt.Text = sprintf('Estado: HOT_WAIT multiples (max %.1f s)', hotWaitBudgetS());
                end
            case MASTER_STATE_SCOPE_MULTI
                if S.multiStartActive && isLiveHandle(lblSyncSt)
                    lblSyncSt.Text = sprintf('Estado: STARTs multiples (%d)', SCOPE_MULTI_START_COUNT);
                end
            case MASTER_STATE_ARMED
                if S.multiStartActive && ...
                        (oldState == MASTER_STATE_SCOPE_MULTI || oldState == MASTER_STATE_PRESTART)
                    finishMultipleStarts();
                end
            case 5   % DUMPING — el maestro está descargando batches de esclavos
                if ~S.dumpStarted
                    S.dumpStarted = true;
                    nExp = S.nBatches * 30;
                    logH(sprintf('DUMP iniciado (~%d muestras por esclavo)', nExp));
                    logM(sprintf('DUMP started nExp=%d', nExp * S.nSlaves));
                end
                if isLiveHandle(lblSyncSt)
                    totalRecv = 0;
                    for kD = 2:1+S.nSlaves
                        totalRecv = totalRecv + S.node(kD).batchCount;
                    end
                    lblSyncSt.Text = sprintf('Estado: DUMP (%d mts)', totalRecv);
                end
            case 0   % IDLE — puede ser post-dump o inicio normal
                if S.multiStartActive
                    finishMultipleStarts();
                elseif S.dumpStarted || S.recordingActive
                    S.dumpStarted = false;
                    S.recordingActive = false;   % liberar render tras dump
                    S.renderDirty(:) = true;
                    % Recortar canal maestro al mismo número de muestras que los esclavos
                    nExp = S.nBatches * 30;
                    if nExp > 0
                        if length(S.node(1).notchBuf) > nExp
                            S.node(1).notchBuf = S.node(1).notchBuf(1:nExp);
                        end
                        if length(S.node(1).filtBuf) > nExp
                            S.node(1).filtBuf = S.node(1).filtBuf(1:nExp);
                        end
                        S.node(1).batchCount = length(S.node(1).notchBuf);
                    end
                    totalRecv = 0;
                    for kD = 2:1+S.nSlaves
                        totalRecv = totalRecv + S.node(kD).batchCount;
                    end
                    for kD = 1:1+S.nSlaves
                        updateStats(kD);
                    end
                    logH(sprintf('DUMP completo — %d muestras esclavos recibidas', totalRecv));
                    logM(sprintf('DUMP complete recv=%d', totalRecv));
                    if isLiveHandle(lblSyncSt)
                        lblSyncSt.Text = 'Estado: IDLE';
                    end
                end
        end
    end

    function updateHBUI(ch, pga, vdac)
        gains = {'1x','2x','4x','5x','8x','10x','16x','32x','50x'};
        code  = double(pga)+1;
        if code>=1 && code<=9 && isfield(S.node(ch),'ddPga') && ~isempty(S.node(ch).ddPga)
            S.node(ch).ddPga.Value   = gains{code};
            S.node(ch).pga_code      = double(pga);
            S.node(ch).lblPgaSt.Text = sprintf('Actual: %s',gains{code});
        end
        v = double(vdac);
        S.node(ch).vdac_byte = v;
        if isfield(S.node(ch),'efVdac') && ~isempty(S.node(ch).efVdac)
            S.node(ch).efVdac.Value = v;
            S.node(ch).lblDacV.Text = sprintf('%.3f V',v*VDAC_STEP);
        end
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Guardar
%% ════════════════════════════════════════════════════════════════════════

    function onSave(~,~)
        base = strtrim(efSaveName.Value);
        if isempty(base), base = 'muestra'; end
        S.saveBaseName = base;
        ex   = dir(fullfile(DATA_DIR,[base '_*.mat']));
        idx  = length(ex)+1;
        fn   = sprintf('%s_%03d.mat',base,idx);
        fp   = fullfile(DATA_DIR,fn);
        appCfg = makeConfigSnapshot();

        muestras.version       = 3;
        muestras.fecha         = datestr(now);
        muestras.fs            = currentAcquisitionFs();
        muestras.nSlaves       = S.nSlaves;
        muestras.hammer_tip    = S.hammerTip;
        muestras.tx_mode_items = TX_MODE_ITEMS;
        muestras.hammer.node_id = 0;
        muestras.hammer.tip     = S.hammerTip;
        muestras.hammer.raw_samples  = S.node(1).notchBuf;
        muestras.hammer.filt_samples = S.node(1).filtBuf;
        muestras.config = appCfg;
        for ch = 1:MAX_NODES
            driftMeanUs = safeStatF(S.node(ch).driftHist,'mean');
            driftStdUs  = safeStatF(S.node(ch).driftHist,'std');
            startLatencyMeanUs = safeStatF(S.node(ch).startLatencyHist,'mean');
            startLatencyStdUs  = safeStatF(S.node(ch).startLatencyHist,'std');
            muestras.node(ch).node_id          = ch-1;
            muestras.node(ch).name             = nodeDisplayName(ch);
            muestras.node(ch).default_name     = NODE_NAMES{ch};
            muestras.node(ch).slave_id         = S.node(ch).slave_id;
            muestras.node(ch).is_active        = (ch >= 2) && (ch <= 1 + S.nSlaves);
            muestras.node(ch).raw_samples      = S.node(ch).notchBuf;
            muestras.node(ch).filt_samples     = S.node(ch).filtBuf;
            muestras.node(ch).pga_code         = S.node(ch).pga_code;
            muestras.node(ch).pga_gain         = pgaGainName(S.node(ch).pga_code);
            muestras.node(ch).vdac_byte        = S.node(ch).vdac_byte;
            muestras.node(ch).vdac_volts       = S.node(ch).vdac_byte * VDAC_STEP;
            muestras.node(ch).pgavdac          = S.node(ch).pgavdac;
            muestras.node(ch).pgavdac_gain     = pgaGainName(S.node(ch).pgavdac);
            muestras.node(ch).calibration      = S.node(ch).cal;
            muestras.node(ch).calibration_valid = S.node(ch).calValid;
            muestras.node(ch).tx_mode          = uint8(S.node(ch).tx_mode);
            muestras.node(ch).tx_mode_name     = txModeName(S.node(ch).tx_mode);
            muestras.node(ch).fir_cmd          = S.node(ch).filtCmd;
            muestras.node(ch).fir_coeffs       = S.node(ch).filtB;
            muestras.node(ch).fir_enabled      = ~isempty(S.node(ch).filtB);
            muestras.node(ch).dc_remove        = S.node(ch).dcRemove;
            muestras.node(ch).notch_enabled    = S.node(ch).notchEnabled;
            muestras.node(ch).notch_mu         = S.node(ch).notchMu;
            muestras.node(ch).notch_harmonics  = S.node(ch).notchHarm;
            muestras.node(ch).drift_us_hist    = S.node(ch).driftHist;
            muestras.node(ch).drift_us_mean    = driftMeanUs;
            muestras.node(ch).drift_us_std     = driftStdUs;
            muestras.node(ch).drift_s_hist     = S.node(ch).driftHist * 1e-6;
            muestras.node(ch).drift_s_mean     = driftMeanUs * 1e-6;
            muestras.node(ch).drift_s_std      = driftStdUs * 1e-6;
            muestras.node(ch).start_latency_us_hist = S.node(ch).startLatencyHist;
            muestras.node(ch).start_latency_us_mean = startLatencyMeanUs;
            muestras.node(ch).start_latency_us_std  = startLatencyStdUs;
            muestras.node(ch).start_latency_s_hist  = S.node(ch).startLatencyHist * 1e-6;
            muestras.node(ch).start_latency_s_mean  = startLatencyMeanUs * 1e-6;
            muestras.node(ch).start_latency_s_std   = startLatencyStdUs * 1e-6;
            muestras.node(ch).first_sample_us  = S.node(ch).tFirst;
            muestras.node(ch).got_first_sample = S.node(ch).gotFirst;
            muestras.node(ch).batch_count      = S.node(ch).batchCount;
            muestras.node(ch).salud            = S.node(ch).salud;
            muestras.node(ch).visible          = S.node(ch).visible;
            muestras.node(ch).fs               = S.node(ch).fs;
            muestras.node(ch).fs_known         = S.node(ch).fsKnown;
            muestras.node(ch).config           = appCfg.node(ch);
        end
        if S.nSlaves > 0
            for k = 1:S.nSlaves
                muestras.slave(k) = muestras.node(k+1); %#ok<AGROW>
            end
        else
            muestras.slave = struct([]);
        end
        try
            save(fp,'muestras');
            lblSaveSt.Text = ['✓ ' fn];
            logH(['Guardado: ' fn]);
            logM(['save ' fp]);
        catch ME
            logH(['Error guardar: ' ME.message]);
        end
        guardarConfig();
    end

    function guardarConfig()
        appCfg = makeConfigSnapshot();
        nodesCfg = appCfg.node;
        try
            save(CFG_FILE,'appCfg','nodesCfg');
        catch
        end
    end

    function v = safeStatF(vec, tipo)
        if isempty(vec), v = NaN; return; end
        if strcmp(tipo,'mean')
            v = mean(vec);
        elseif numel(vec) < 2
            v = NaN;
        else
            v = std(vec);
        end
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Cierre
%% ════════════════════════════════════════════════════════════════════════

    function onClose(~,~)
        try, setDriftDebugSlaves(false); catch, end
        try, setStreamDebugSignal(false); catch, end
        try
            if S.multiStartActive, psocCmd(CMD_DEBUG_RESPONSE, 0); end
        catch, end
        try
            if ~isempty(S.autoStopTimer) && isvalid(S.autoStopTimer)
                stop(S.autoStopTimer); delete(S.autoStopTimer);
            end
        catch, end
        try
            if ~isempty(S.armTimer) && isvalid(S.armTimer)
                stop(S.armTimer); delete(S.armTimer);
            end
        catch, end
        try
            if ~isempty(tmr) && isvalid(tmr)
                if strcmp(tmr.Running,'on'), stop(tmr); end
                delete(tmr);
            end
        catch, end
        try
            if ~isempty(tmrRender) && isvalid(tmrRender)
                if strcmp(tmrRender.Running,'on'), stop(tmrRender); end
                delete(tmrRender);
            end
        catch, end
        if S.streaming, try, psocCmd(hex2dec('A1'),0); catch, end; end
        if ~isempty(S.port) && isvalid(S.port), delete(S.port); end
        % Cerrar puertos debug esclavos
        for ch = 1:MAX_NODES
            if ~isempty(S.node(ch).dbgPort) && isvalid(S.node(ch).dbgPort)
                delete(S.node(ch).dbgPort);
            end
        end
        guardarConfig();
        logH('Sesión cerrada');
        logM('onClose');
        try, if machFid >= 0, fclose(machFid); machFid = -1; end; catch, end
        try, if humFid >= 0,  fclose(humFid);  humFid  = -1; end; catch, end
        delete(fig);
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Protocolo serial
%% ════════════════════════════════════════════════════════════════════════

    function psocCmd(cmd, param)
        if isempty(S.port)||~isvalid(S.port), return; end
        cs = bitxor(uint8(cmd),uint8(param));
        try
            write(S.port,uint8([CMD_HEADER,cmd,param,cs]),'uint8');
            logM(sprintf('TX std cmd=0x%02X p=%d',cmd,param));
        catch ME
            logM(['TX err: ' ME.message]);
        end
    end

    function psocCmd16(cmd, value)
        % Comando "set N" de 16 bits: [0xAB][cmd][n_lo][n_hi][cmd^n_lo^n_hi]
        if isempty(S.port)||~isvalid(S.port), return; end
        v   = uint16(max(0, min(65535, round(value))));
        nlo = uint8(bitand(v,255));
        nhi = uint8(bitshift(v,-8));
        cs  = bitxor(bitxor(uint8(cmd),nlo),nhi);
        try
            write(S.port,uint8([CMD_HEADER,cmd,nlo,nhi,cs]),'uint8');
            logM(sprintf('TX std16 cmd=0x%02X N=%d',cmd,v));
        catch ME
            logM(['TX err: ' ME.message]);
        end
    end

    function enviarDirigido(ch, sub_cmd, param)
        if isempty(S.port)||~isvalid(S.port), return; end
        ni=uint8(ch-1); sc=uint8(sub_cmd); p=uint8(param);
        cs=bitxor(bitxor(ni,sc),p);
        try
            write(S.port,uint8([CMD_HEADER,CMD_DIRECTED,ni,sc,p,cs]),'uint8');
            logM(sprintf('TX dir n=%d sub=0x%02X p=%d',ni,sc,p));
        catch ME
            logM(['TX dir err: ' ME.message]);
        end
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Utilidades
%% ════════════════════════════════════════════════════════════════════════

%% ════════════════════════════════════════════════════════════════════════
%%  Debug COM — conectar / desconectar / polling
%% ════════════════════════════════════════════════════════════════════════

    function connectDbg(isMaster, ch, dd, btnC, btnD)
        portName = dd.Value;
        if isempty(portName) || strcmp(portName,'(sin puertos)'), return; end
        try
            sp = serialport(portName, 115200, 'Timeout', 0.1);
            flush(sp);
        catch ME
            logH(sprintf('Debug COM error: %s', ME.message)); return;
        end
        if ~isempty(S.node(ch).dbgPort) && isvalid(S.node(ch).dbgPort)
            delete(S.node(ch).dbgPort);
        end
        S.node(ch).dbgPort = sp;
        S.node(ch).dbgBuf  = '';
        btnC.Enable = 'off';
        btnD.Enable = 'on';
        if isMaster
            logH(sprintf('Debug COM Maestro conectado: %s', portName));
        else
            logH(sprintf('Debug COM esclavo %d conectado: %s', ch-1, portName));
        end
        if isempty(tmr) || ~isvalid(tmr)
            tmr = timer('ExecutionMode','fixedRate','Period',0.05, ...
                'TimerFcn',@timerRX,'BusyMode','drop');
        end
        if strcmp(tmr.Running,'off'), start(tmr); end
        if isempty(tmrRender) || ~isvalid(tmrRender)
            tmrRender = timer('ExecutionMode','fixedRate','Period',0.15, ...
                'TimerFcn',@timerRenderFcn,'BusyMode','drop');
        end
        if strcmp(tmrRender.Running,'off'), start(tmrRender); end
    end

    function disconnectDbg(isMaster, ch, btnC, btnD)
        if ~isempty(S.node(ch).dbgPort) && isvalid(S.node(ch).dbgPort)
            delete(S.node(ch).dbgPort);
        end
        S.node(ch).dbgPort = [];
        S.node(ch).dbgBuf  = '';
        btnC.Enable = 'on';
        btnD.Enable = 'off';
        if isMaster
            logH('Debug COM Maestro desconectado');
        else
            logH(sprintf('Debug COM esclavo %d desconectado', ch-1));
        end
    end

    function pollAllDbg()
        for dCh = 1:MAX_NODES
            if ~isempty(S.node(dCh).dbgPort) && isvalid(S.node(dCh).dbgPort)
                S.node(dCh).dbgBuf = drainDbgPort(S.node(dCh).dbgPort, ...
                    S.node(dCh).dbgBuf, (dCh == 1), dCh);
            end
        end
    end

    function newBuf = drainDbgPort(sp, buf, isMaster, ch)
        newBuf = buf;
        try
            nb = sp.NumBytesAvailable;
            if nb == 0, return; end
            raw = read(sp, nb, 'uint8');
        catch
            return;
        end
        for k = 1:numel(raw)
            c = char(raw(k));
            if c == newline || c == char(13)
                line = strtrim(newBuf);
                if ~isempty(line)
                    ts  = datestr(now,'HH:MM:SS.FFF');
                    if isMaster
                        prefix = 'M';
                    else
                        prefix = sprintf('S%d', ch-1);
                    end
                    msg = sprintf('[%s][%s] %s', ts, prefix, line);
                    % Línea máquina (#M,...) o ruido humano → solo log máquina.
                    % Resto → Log tab humano + acumular en textarea del nodo.
                    if startsWith(string(line),'#M,') || isNoisyHumanLogLine(line)
                        logM(sprintf('DBG %s %s', prefix, line));
                    else
                        logH(msg);
                    end
                    % Acumular en buffer pendiente — timerRenderFcn vuelca a la textarea
                    S.node(ch).dbgPending{end+1} = msg;
                end
                newBuf = '';
            else
                newBuf = [newBuf, c]; %#ok<AGROW>
            end
        end
    end

    function tf = isLiveHandle(h)
        if isempty(h)
            tf = false;
            return;
        end
        try
            tf = all(isvalid(h));
        catch
            tf = false;
        end
    end

    function tf = isNoisyHumanLogLine(line)
        line = lower(string(line));
        tf = contains(line, 'hello tx') || ...
             contains(line, 'hello recibido') || ...
             (contains(line, 'bok=') && contains(line, 'txok='));
    end

    function [yOut, w] = lineCanceller(x, w, n, fs, f0, nH, mu)
        if isempty(w), w = zeros(1,nH*2); end
        phi = zeros(1,nH*2);
        for h = 1:nH
            phi(2*h-1) = sin(2*pi*f0*h*n/fs);
            phi(2*h)   = cos(2*pi*f0*h*n/fs);
        end
        yOut = x - dot(w,phi);
        w    = w + 2*mu*yOut*phi;
    end

    function logH(msg)
        ts   = datestr(now,'HH:MM:SS');
        line = sprintf('[%s] %s',ts,msg);
        agregarLog(humFid,line);
        cur = taLog.Value;
        if ischar(cur), cur = {cur}; end
        cur = [cur; {line}];
        if length(cur) > 200, cur = cur(end-199:end); end
        taLog.Value = cur;
        scroll(taLog,'bottom');
    end

    function logM(msg)
        ts   = datestr(now,'HH:MM:SS.FFF');
        agregarLog(machFid, sprintf('[%s] %s',ts,msg));
    end

    function val = readBuildDefine(iniPath, defineName, defaultVal)
        val = defaultVal;
        try
            txt = fileread(iniPath);
            expr = ['-D' regexptranslate('escape', defineName) '=([^\s;]+)'];
            tok = regexp(txt, expr, 'tokens', 'once');
            if ~isempty(tok)
                parsed = str2double(tok{1});
                if ~isnan(parsed), val = parsed; end
            end
        catch
        end
    end

    function r = ternary(c,a,b), if c, r=a; else, r=b; end; end

    function ports = listSerialPorts()
        try, ports = cellstr(serialportlist('available'));
        catch, ports = {}; end
        if isempty(ports), ports = {'(sin puertos)'}; end
    end

end
