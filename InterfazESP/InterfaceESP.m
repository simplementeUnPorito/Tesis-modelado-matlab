function InterfaceESP()
% InterfaceESP — GUI multi-nodo geófono ESP32
% Layout: TabGroup izquierdo (columna única) + plots a la derecha
% Tabs: Maestro | Esclavo 1..N | Stream & Stats | Log

%% ── Constantes ─────────────────────────────────────────────────────────
MAX_NODES    = 4;           % 1 maestro + 3 esclavos
BAUD         = 921600;
PKT_HEADER   = hex2dec('56');
CMD_HEADER   = hex2dec('AB');
CMD_DIRECTED = hex2dec('BD');
FS           = 4000;        % Hz
DISP_SAMP    = FS * 5;
VDAC_STEP    = 0.004;       % V/LSB
NODE_NAMES   = {'Maestro','Esclavo 1','Esclavo 2','Esclavo 3'};
APP_DIR      = fileparts(mfilename('fullpath'));
LOG_DIR      = fullfile(APP_DIR, 'logs');
DATA_DIR     = fullfile(APP_DIR, 'datos');
CFG_FILE     = fullfile(APP_DIR, 'scope_config.mat');
N_LOG_SLOTS  = 10;

%% ── Estado ──────────────────────────────────────────────────────────────
S.port      = [];
S.rxBuf     = uint8([]);
S.streaming = false;
S.nSlaves   = 0;
logSlot     = 1;
tmr         = [];

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
    S.node(ch).dcRemove  = false;
    S.node(ch).visible   = true;
    S.node(ch).driftHist = [];
    S.node(ch).batchCount= 0;
    S.node(ch).salud     = 0;
    % handles UI (poblados en buildTab)
    S.node(ch).ax        = [];
    S.node(ch).hRaw      = [];
    S.node(ch).hFilt     = [];
    S.node(ch).lblStats  = [];
    S.node(ch).lblLastVal= [];
    S.node(ch).lblFiltSt = [];
end

%% ── Handles UI en scope padre (compartidos entre nested functions) ───────
% Conexión / Stream (buildStreamTab los asigna, callbacks los usan)
ddPort = []; spnSlaves = []; btnConnect = []; btnDisconn = []; lblConn = [];
btnArm = []; btnStart  = []; btnStop    = [];
lblSyncSt = []; lblArmCnt = [];
btnStreamOn = []; btnStreamOff = [];
cbLine = []; efMu = []; spnHarm = [];
driftLabels  = gobjects(3,1);
globalBatch  = gobjects(MAX_NODES,1);
efSaveName = []; lblSaveSt = [];
taLog      = [];
% Maestro test (tab Maestro y onTestMaestro comparten estos)
btnTestMaestro = []; lblMaestroInd = []; lblMaestroTxt = [];
% Checkboxes de visibilidad de plots (creados después de buildPlots)
cbVis = gobjects(MAX_NODES,1);

%% ── Cargar config ───────────────────────────────────────────────────────
if isfile(CFG_FILE)
    try
        c = load(CFG_FILE);
        if isfield(c,'logSlot'),  logSlot   = c.logSlot; end
        if isfield(c,'nodesCfg')
            nc = c.nodesCfg;
            campos = {'pga_code','vdac_byte','pgavdac','cal','filtCmd','dcRemove'};
            for ch = 1:min(MAX_NODES, numel(nc))
                for f = campos
                    if isfield(nc(ch),f{1}), S.node(ch).(f{1}) = nc(ch).(f{1}); end
                end
            end
        end
    catch, end
end

%% ── Logs dobles, 10 slots rotativos ─────────────────────────────────────
if ~isfolder(LOG_DIR), mkdir(LOG_DIR); end
if ~isfolder(DATA_DIR), mkdir(DATA_DIR); end
machLog = fullfile(LOG_DIR, sprintf('InterfaceESP_machine_%02d.log', logSlot));
humLog  = fullfile(LOG_DIR, sprintf('InterfaceESP_human_%02d.log',  logSlot));
nextSlot = mod(logSlot, N_LOG_SLOTS) + 1;
iniciarLog(machLog); iniciarLog(humLog);

    function iniciarLog(f)
        fid = fopen(f,'w');
        if fid >= 0
            fprintf(fid,'=== InterfaceESP %s ===\n', datestr(now));
            fclose(fid);
        end
    end
    function agregarLog(f, linea)
        fid = fopen(f,'a');
        if fid >= 0, fprintf(fid,'%s\n',linea); fclose(fid); end
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
tabs(2) = uitab(tg,'Title','Esclavo 1');
tabs(3) = uitab(tg,'Title','Esclavo 2');
tabs(4) = uitab(tg,'Title','Esclavo 3');
tabs(5) = uitab(tg,'Title','Stream');
tabs(6) = uitab(tg,'Title','Log');

buildMaestroTab(tabs(1));
for slv = 1:3, buildSlaveTab(slv+1, tabs(slv+1)); end
buildStreamTab(tabs(5));
buildLogTab(tabs(6));
applyTabVisibility();

%% ── Plots ────────────────────────────────────────────────────────────────
layoutFigure();
buildPlots();
applyPlotVisibility();  % ocultar plots de esclavos inactivos al arrancar

%% ════════════════════════════════════════════════════════════════════════
%%  Construcción de tabs
%% ════════════════════════════════════════════════════════════════════════

    function buildMaestroTab(tab)
        W = TG_W - 12;
        % Test
        pT = uipanel(tab,'Title','Test Maestro','Position',[4 816 W 78]);
        btnTestMaestro = uibutton(pT,'Text','Iniciar Test','Position',[4 24 110 28], ...
            'ButtonPushedFcn',@onTestMaestro,'Enable','off');
        lblMaestroInd  = uilabel(pT,'Text','●','Position',[122 24 22 28], ...
            'FontColor',[0.7 0.7 0.7],'FontSize',16);
        lblMaestroTxt  = uilabel(pT,'Text','Sin test','Position',[148 24 W-150 28]);

        % FIR martillo
        pF = uipanel(tab,'Title','Filtro FIR — Martillo','Position',[4 736 W 76]);
        uilabel(pF,'Text','Cmd:','Position',[4 36 34 20]);
        efFirM = uieditfield(pF,'text','Position',[40 36 170 22],'Value',S.node(1).filtCmd);
        uibutton(pF,'Text','Aplicar','Position',[214 36 72 22], ...
            'ButtonPushedFcn',@(~,~)applyFir(1,efFirM.Value));
        cbDCM = uicheckbox(pF,'Text','Quitar DC','Position',[4 10 82 20], ...
            'Value',S.node(1).dcRemove, ...
            'ValueChangedFcn',@(cb,~)setDcRemove(1,cb.Value));
        uibutton(pF,'Text','Quitar filtro','Position',[90 10 84 22], ...
            'ButtonPushedFcn',@(~,~)removeFir(1));
        lblFiltM = uilabel(pF,'Text','Sin filtro','Position',[180 10 W-185 20]);
        S.node(1).efFir    = efFirM;
        S.node(1).cbDC     = cbDCM;
        S.node(1).lblFiltSt= lblFiltM;

        % Stats maestro
        pS = uipanel(tab,'Title','Estadísticas','Position',[4 656 W 76]);
        S.node(1).lblStats   = uilabel(pS,'Text','Batches: 0','Position',[4 36 W-12 20]);
        S.node(1).lblLastVal = uilabel(pS,'Text','Último: --', 'Position',[4 10 W-12 20]);
    end

    function buildSlaveTab(ch, tab)
        W = TG_W - 12;
        gains = {'1x','2x','4x','5x','8x','10x','16x','32x','50x'};

        % VRef DC
        pV = uipanel(tab,'Title','VRef DC','Position',[4 720 W 178]);
        uilabel(pV,'Text','VDAC byte:','Position',[4 140 68 20]);
        efVdac = uieditfield(pV,'numeric','Position',[76 140 52 22], ...
            'Value',S.node(ch).vdac_byte,'Limits',[0 255],'RoundFractionalValues',true, ...
            'ValueChangedFcn',@(ef,~)onVdacEdit(ch,ef));
        uilabel(pV,'Text','=','Position',[132 140 10 20]);
        lblDacV = uilabel(pV,'Text',sprintf('%.3f V',S.node(ch).vdac_byte*VDAC_STEP), ...
            'Position',[144 140 80 20]);
        uilabel(pV,'Text','Target V:','Position',[4 112 58 20]);
        efTgt = uieditfield(pV,'numeric','Position',[66 112 58 22],'Value',0.512);
        uibutton(pV,'Text','Set', 'Position',[128 112 42 22], ...
            'ButtonPushedFcn',@(~,~)sendVdacTarget(ch,efTgt.Value,efVdac,lblDacV));
        uibutton(pV,'Text','−','Position',[174 112 26 22], ...
            'ButtonPushedFcn',@(~,~)adjustVdac(ch,efVdac,lblDacV,-1));
        uibutton(pV,'Text','+','Position',[202 112 26 22], ...
            'ButtonPushedFcn',@(~,~)adjustVdac(ch,efVdac,lblDacV,+1));
        uilabel(pV,'Text','PGAvdac:','Position',[4 84 58 20]);
        ddPgaVdac = uidropdown(pV,'Position',[66 84 78 22],'Items',gains, ...
            'Value',gains{S.node(ch).pgavdac+1}, ...
            'ValueChangedFcn',@(dd,~)sendPgaVdac(ch,dd,gains));
        uilabel(pV,'Text','Cal:','Position',[4 56 28 20]);
        lblCalSt = uilabel(pV,'Text','Sin cal','Position',[36 56 W-44 20]);
        uibutton(pV,'Text','Guardar cal','Position',[4 28 100 22], ...
            'ButtonPushedFcn',@(~,~)saveCalForPGA(ch,lblCalSt));
        uibutton(pV,'Text','Aplicar cal','Position',[108 28 90 22], ...
            'ButtonPushedFcn',@(~,~)applyCal(ch));
        S.node(ch).efVdac    = efVdac;
        S.node(ch).lblDacV   = lblDacV;
        S.node(ch).ddPgaVdac = ddPgaVdac;
        S.node(ch).lblCalSt  = lblCalSt;

        % PGA
        pP = uipanel(tab,'Title','Ganancia PGA','Position',[4 658 W 58]);
        ddPga = uidropdown(pP,'Position',[4 14 90 22],'Items',gains, ...
            'Value',gains{S.node(ch).pga_code+1});
        uibutton(pP,'Text','Set PGA','Position',[98 14 66 22], ...
            'ButtonPushedFcn',@(~,~)sendPga(ch,ddPga,gains));
        lblPgaSt = uilabel(pP,'Text',sprintf('Actual: %s',gains{S.node(ch).pga_code+1}), ...
            'Position',[170 14 W-176 22]);
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
        lblFiltSt = uilabel(pF,'Text','Sin filtro','Position',[180 12 W-188 20]);
        S.node(ch).efFir    = efFir;
        S.node(ch).cbDC     = cbDC;
        S.node(ch).lblFiltSt= lblFiltSt;

        % Debug / Test
        pD = uipanel(tab,'Title','Debug / Test','Position',[4 488 W 82]);
        btnTest = uibutton(pD,'Text',sprintf('Test Esclavo %d',ch-1), ...
            'Position',[4 46 130 26], ...
            'ButtonPushedFcn',@(~,~)onTestEsclavo(ch),'Enable','off');
        lblSalud    = uilabel(pD,'Text','●','Position',[140 46 22 26], ...
            'FontColor',[0.7 0.7 0.7],'FontSize',16);
        lblSaludTxt = uilabel(pD,'Text','Sin test','Position',[164 46 W-168 26]);
        uilabel(pD,'Text','TX Mode:','Position',[4 14 58 20]);
        ddTX = uidropdown(pD,'Position',[66 14 96 22],'Items',{'Raw','Filtrado'}, ...
            'ValueChangedFcn',@(dd,~)sendTxMode(ch,strcmp(dd.Value,'Filtrado')));
        S.node(ch).btnTest     = btnTest;
        S.node(ch).lblSalud    = lblSalud;
        S.node(ch).lblSaludTxt = lblSaludTxt;
        S.node(ch).ddTX        = ddTX;

        % Stats
        pSt = uipanel(tab,'Title','Estadísticas','Position',[4 402 W 82]);
        S.node(ch).lblStats   = uilabel(pSt,'Text','Batches: 0  Drift: --', ...
            'Position',[4 40 W-12 20]);
        S.node(ch).lblLastVal = uilabel(pSt,'Text','Último: --', ...
            'Position',[4 14 W-12 20]);
    end

    function buildStreamTab(tab)
        W = TG_W - 12;

        % Conexión
        pC = uipanel(tab,'Title','Conexión USB','Position',[4 788 W 110]);
        uilabel(pC,'Text','Puerto:','Position',[4 72 46 20]);
        ddPort = uidropdown(pC,'Position',[54 72 186 22],'Items',listSerialPorts());
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
        btnArm   = uibutton(pS,'Text','ARM',       'Position',[4  62 80 26], ...
            'ButtonPushedFcn',@onArm,'Enable','off');
        btnStart = uibutton(pS,'Text','SYNC START','Position',[88 62 112 26], ...
            'ButtonPushedFcn',@onSyncStart,'Enable','off');
        btnStop  = uibutton(pS,'Text','STOP',      'Position',[204 62 W-208 26], ...
            'ButtonPushedFcn',@onSyncStop,'Enable','off');
        lblSyncSt = uilabel(pS,'Text','Estado: IDLE',      'Position',[4 36 W-8 20]);
        lblArmCnt = uilabel(pS,'Text','Esclavos listos: 0','Position',[4 12 W-8 20]);

        % Stream
        pSt = uipanel(tab,'Title','Stream','Position',[4 568 W 110]);
        btnStreamOn  = uibutton(pSt,'Text','▶ Iniciar','Position',[4  74 158 28], ...
            'ButtonPushedFcn',@onStreamOn,'Enable','off');
        btnStreamOff = uibutton(pSt,'Text','■ Detener','Position',[166 74 W-170 28], ...
            'ButtonPushedFcn',@onStreamOff,'Enable','off');
        uibutton(pSt,'Text','Limpiar buffers','Position',[4 44 W-8 26], ...
            'ButtonPushedFcn',@onClear);
        cbLine  = uicheckbox(pSt,'Text','Cancelador 50 Hz','Position',[4 18 136 20], ...
            'ValueChangedFcn',@onLineCancellerToggle);
        uilabel(pSt,'Text','µ:','Position',[146 18 20 20]);
        efMu    = uieditfield(pSt,'numeric','Position',[168 18 52 20],'Value',0.002);
        uilabel(pSt,'Text','Arm:','Position',[226 18 32 20]);
        spnHarm = uispinner(pSt,'Position',[260 18 W-264 20],'Value',3,'Limits',[1 5]);

        % Deriva
        pDr = uipanel(tab,'Title','Deriva (µs)','Position',[4 464 W 100]);
        for k = 1:3
            driftLabels(k) = uilabel(pDr,'Text',sprintf('Esclavo %d: --',k), ...
                'Position',[4 (3-k)*28+8 W-8 22]);
        end

        % Batches globales
        pBt = uipanel(tab,'Title','Batches recibidos','Position',[4 356 W 104]);
        for ch = 1:MAX_NODES
            globalBatch(ch) = uilabel(pBt,'Text', ...
                sprintf('%s: 0', NODE_NAMES{ch}), ...
                'Position',[4 (MAX_NODES-ch)*22+8 W-8 20]);
        end

        % Guardar
        pSv = uipanel(tab,'Title','Guardar','Position',[4 264 W 88]);
        uilabel(pSv,'Text','Nombre:','Position',[4 48 54 20]);
        efSaveName = uieditfield(pSv,'text','Position',[62 48 154 22],'Value','muestra');
        uibutton(pSv,'Text','Guardar .mat','Position',[220 48 W-224 22], ...
            'ButtonPushedFcn',@onSave);
        lblSaveSt = uilabel(pSv,'Text','','Position',[4 16 W-8 24], ...
            'FontColor',[0.1 0.5 0.1]);

        % Canales visibles
        pCh = uipanel(tab,'Title','Canales visibles','Position',[4 156 W 104]);
        for ch = 1:MAX_NODES
            cbVis(ch) = uicheckbox(pCh,'Text',NODE_NAMES{ch}, ...
                'Position',[4 (MAX_NODES-ch)*22+8 W-8 20], ...
                'Value',true, ...
                'ValueChangedFcn',@(src,~)onCheckboxChannel(ch,src.Value));
        end
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
        % Re-agregar en orden visual: Stream, Maestro, Esclavos, Log
        tabs(5).Parent = tg;                  % Stream primero
        tabs(1).Parent = tg;                  % Maestro siempre
        for slv = 1:S.nSlaves
            tabs(slv+1).Parent = tg;         % Esclavos activos
        end
        tabs(6).Parent = tg;                  % Log
        tg.SelectedTab = tabs(5);
        % Solo actualizar plots si ya fueron creados
        if isLiveHandle(S.node(1).ax), applyPlotVisibility(); end
    end

    function applyPlotVisibility()
        % Ocultar plots y checkboxes de esclavos inactivos
        for ch = 1:MAX_NODES
            % ch=1 = Maestro siempre visible
            % ch=2..nSlaves+1 = esclavos activos
            active = (ch == 1) || (ch <= 1 + S.nSlaves);
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
            active = (ch == 1) || (ch <= 1 + S.nSlaves);
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
        logH(sprintf('Esclavos: %d', S.nSlaves));
        logM(sprintf('nSlaves=%d', S.nSlaves));
    end

    function onConnect(~,~)
        portName = ddPort.Value;
        if isempty(portName) || strcmp(portName,'(sin puertos)')
            logH('Selecciona un puerto COM válido'); return;
        end
        try
            S.port = serialport(portName, BAUD);
            flush(S.port);
            S.rxBuf = uint8([]);
        catch ME
            logH(['Error conexión: ' ME.message]);
            logM(['onConnect FAIL port=' portName ' ' ME.message]);
            return;
        end
        lblConn.Text      = ['● Conectado: ' portName];
        lblConn.FontColor = [0.0 0.55 0.0];
        btnConnect.Enable = 'off';
        btnDisconn.Enable = 'on';
        btnArm.Enable     = 'on';
        btnStreamOn.Enable= 'on';
        btnTestMaestro.Enable = 'on';
        for ch = 2:1+S.nSlaves
            if isfield(S.node(ch),'btnTest') && ~isempty(S.node(ch).btnTest)
                S.node(ch).btnTest.Enable = 'on';
            end
        end
        % Crear timer si no existe o fue borrado
        if isempty(tmr) || ~isvalid(tmr)
            tmr = timer('ExecutionMode','fixedRate','Period',0.05, ...
                'TimerFcn',@timerRX,'BusyMode','drop');
        end
        if strcmp(tmr.Running,'off'), start(tmr); end
        logH(['Conectado: ' portName]);
        logM(sprintf('onConnect OK port=%s', portName));
    end

    function onDisconnect(~,~)
        if ~isempty(tmr) && isvalid(tmr) && strcmp(tmr.Running,'on')
            stop(tmr);
        end
        if ~isempty(S.port) && isvalid(S.port), delete(S.port); end
        S.port = [];
        lblConn.Text      = '● Sin conexión';
        lblConn.FontColor = [0.5 0.5 0.5];
        btnConnect.Enable = 'on';
        btnDisconn.Enable = 'off';
        btnArm.Enable     = 'off';
        btnStart.Enable   = 'off';
        btnStop.Enable    = 'off';
        btnStreamOn.Enable   = 'off';
        btnStreamOff.Enable  = 'off';
        btnTestMaestro.Enable= 'off';
        for ch = 2:MAX_NODES
            if isfield(S.node(ch),'btnTest') && ~isempty(S.node(ch).btnTest)
                S.node(ch).btnTest.Enable = 'off';
            end
        end
        logH('Desconectado');
        logM('onDisconnect');
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Callbacks — Sincronización / Stream
%% ════════════════════════════════════════════════════════════════════════

    function onArm(~,~)
        psocCmd(hex2dec('A2'), S.nSlaves);
        lblSyncSt.Text = 'Estado: ARMING...';
        lblArmCnt.Text = 'Esclavos listos: 0';
        btnStart.Enable = 'on';
        logH(sprintf('ARM → %d esclavos', S.nSlaves));
        logM(sprintf('CMD ARM n=%d', S.nSlaves));
    end

    function onSyncStart(~,~)
        psocCmd(hex2dec('A3'), 0);
        lblSyncSt.Text = 'Estado: RUNNING';
        btnStop.Enable = 'on';
        logH('SYNC START'); logM('CMD START');
    end

    function onSyncStop(~,~)
        psocCmd(hex2dec('A4'), 0);
        lblSyncSt.Text = 'Estado: STOPPING';
        btnStop.Enable = 'off';
        logH('SYNC STOP'); logM('CMD STOP');
    end

    function onStreamOn(~,~)
        psocCmd(hex2dec('A1'), 1);
        S.streaming = true;
        btnStreamOn.Enable  = 'off';
        btnStreamOff.Enable = 'on';
        logH('Stream iniciado'); logM('STREAM ON');
    end

    function onStreamOff(~,~)
        psocCmd(hex2dec('A1'), 0);
        S.streaming = false;
        btnStreamOn.Enable  = 'on';
        btnStreamOff.Enable = 'off';
        logH('Stream detenido'); logM('STREAM OFF');
    end

    function onClear(~,~)
        for ch = 1:MAX_NODES
            S.node(ch).notchBuf  = [];
            S.node(ch).filtBuf   = [];
            S.node(ch).filtZi    = [];
            S.node(ch).lineW     = [];
            S.node(ch).driftHist = [];
            S.node(ch).batchCount= 0;
            if isLiveHandle(S.node(ch).ax)
                set(S.node(ch).hRaw, 'XData',NaN,'YData',NaN);
                set(S.node(ch).hFilt,'XData',NaN,'YData',NaN);
            end
        end
        for k = 1:3, driftLabels(k).Text = sprintf('Esclavo %d: --',k); end
        logH('Buffers limpiados'); logM('CLEAR');
    end

    function onLineCancellerToggle(cb,~)
        if ~cb.Value
            for ch = 1:MAX_NODES, S.node(ch).lineW = []; end
        end
        logM(sprintf('cancelador50=%d', cb.Value));
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Callbacks — Test
%% ════════════════════════════════════════════════════════════════════════

    function onTestMaestro(~,~)
        % 0xA7 param=1: firmware pone g_streaming=true, g_state=RUNNING
        % y envía stub sinusoidal del martillo → datos en plot Maestro
        psocCmd(hex2dec('A7'), 1);
        S.streaming = true;
        lblMaestroInd.FontColor = [0.8 0.6 0.0];
        lblMaestroTxt.Text = 'Probando...';
        logM('testMaestro START debug ON');
        init0 = S.node(1).batchCount;
        tmrT  = timer('StartDelay',3,'ExecutionMode','singleShot','TimerFcn',@ck);
        start(tmrT);
        function ck(~,~)
            try, psocCmd(hex2dec('A7'), 0); catch, end
            try, timerRX([],[]); catch, end
            S.streaming = false;
            g  = S.node(1).batchCount - init0;
            ok = g >= 10;   % ~4000 Hz × 3 s → esperar al menos 10 muestras
            if ok
                lblMaestroInd.FontColor = [0.0 0.7 0.0];
                lblMaestroTxt.Text = sprintf('OK (%d muestras)',g);
                logH(sprintf('Test maestro: OK (%d muestras)',g));
            else
                lblMaestroInd.FontColor = [0.8 0.1 0.1];
                lblMaestroTxt.Text = sprintf('FAIL (%d muestras)',g);
                logH(sprintf('Test maestro: FAIL (%d muestras)',g));
            end
            logM(sprintf('testMaestro END batches=%d ok=%d',g,ok));
            try, delete(tmrT); catch, end
        end
    end

    function onTestEsclavo(ch)
        if ch < 2 || ch > MAX_NODES, return; end
        wasStreaming = S.streaming;
        if ~wasStreaming
            psocCmd(hex2dec('A1'), 1);
            S.streaming = true;
            if isLiveHandle(btnStreamOn),  btnStreamOn.Enable  = 'off'; end
            if isLiveHandle(btnStreamOff), btnStreamOff.Enable = 'on';  end
        end
        enviarDirigido(ch, hex2dec('A7'), 1);
        init0 = S.node(ch).batchCount;
        S.node(ch).lblSalud.FontColor   = [0.8 0.6 0.0];
        S.node(ch).lblSaludTxt.Text     = 'Probando...';
        tmrS = timer('StartDelay',4,'ExecutionMode','singleShot','TimerFcn',@ck);
        start(tmrS);
        function ck(~,~)
            try, enviarDirigido(ch, hex2dec('A7'), 0); catch, end
            try, timerRX([],[]); catch, end
            if ~wasStreaming
                try, psocCmd(hex2dec('A1'), 0); catch, end
                S.streaming = false;
                if isLiveHandle(btnStreamOn),  btnStreamOn.Enable  = 'on';  end
                if isLiveHandle(btnStreamOff), btnStreamOff.Enable = 'off'; end
            end
            g  = S.node(ch).batchCount - init0;
            ok = g >= 10;
            S.node(ch).salud = 1 + ~ok;
            if ok
                S.node(ch).lblSalud.FontColor   = [0.0 0.7 0.0];
                S.node(ch).lblSaludTxt.Text     = 'OK';
                logH(sprintf('Test Esclavo %d: OK',ch-1));
            else
                S.node(ch).lblSalud.FontColor   = [0.8 0.1 0.1];
                S.node(ch).lblSaludTxt.Text     = sprintf('FAIL (%d)',g);
                logH(sprintf('Test Esclavo %d: FAIL (%d batches)',ch-1,g));
            end
            logM(sprintf('testEsclavo ch=%d batches=%d ok=%d',ch-1,g,ok));
            try, delete(tmrS); catch, end
        end
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Callbacks — VRef DC (solo esclavos)
%% ════════════════════════════════════════════════════════════════════════

    function onVdacEdit(ch, ef)
        S.node(ch).vdac_byte = ef.Value;
        if ~isempty(S.node(ch).lblDacV)
            S.node(ch).lblDacV.Text = sprintf('%.3f V', ef.Value*VDAC_STEP);
        end
    end

    function sendVdacTarget(ch, targetV, efVdac, lblDacV)
        byte = max(0, min(255, round(targetV/VDAC_STEP)));
        efVdac.Value = byte; lblDacV.Text = sprintf('%.3f V',byte*VDAC_STEP);
        S.node(ch).vdac_byte = byte;
        enviarDirigido(ch, hex2dec('AA'), byte);
        logH(sprintf('Nodo %d VDAC→%d (%.3fV)',ch-1,byte,byte*VDAC_STEP));
    end

    function adjustVdac(ch, efVdac, lblDacV, delta)
        v = max(0, min(255, efVdac.Value + delta));
        efVdac.Value = v; lblDacV.Text = sprintf('%.3f V',v*VDAC_STEP);
        S.node(ch).vdac_byte = v;
        enviarDirigido(ch, hex2dec('AA'), v);
    end

    function sendPgaVdac(ch, dd, gains)
        code = find(strcmp(gains,dd.Value)) - 1;
        S.node(ch).pgavdac = code;
        enviarDirigido(ch, hex2dec('A9'), code);
        logH(sprintf('Nodo %d PGAvdac→%s',ch-1,dd.Value));
    end

    function sendPga(ch, dd, gains)
        code = find(strcmp(gains,dd.Value)) - 1;
        S.node(ch).pga_code = code;
        S.node(ch).lblPgaSt.Text = sprintf('Actual: %s',dd.Value);
        enviarDirigido(ch, hex2dec('A6'), code);
        logH(sprintf('Nodo %d PGA→%s',ch-1,dd.Value));
    end

    function saveCalForPGA(ch, lblCalSt)
        if isempty(S.node(ch).notchBuf), logH('Sin datos'); return; end
        code = S.node(ch).pga_code;
        dc   = mean(S.node(ch).notchBuf(max(1,end-FS+1):end));
        S.node(ch).cal(code+1,:) = [code, S.node(ch).vdac_byte, dc];
        lblCalSt.Text = sprintf('Cal PGA%d: VDAC=%d',code,S.node(ch).vdac_byte);
        logH(sprintf('Cal nodo %d PGA%d guardada',ch-1,code));
    end

    function applyCal(ch)
        code = S.node(ch).pga_code;
        row  = S.node(ch).cal(code+1,:);
        if row(2)==0, logH('Sin cal para esta PGA'); return; end
        enviarDirigido(ch, hex2dec('AA'), row(2));
        logH(sprintf('Cal aplicada nodo %d VDAC=%d',ch-1,row(2)));
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Callbacks — FIR / DC
%% ════════════════════════════════════════════════════════════════════════

    function applyFir(ch, cmdStr)
        cmdStr = strtrim(cmdStr);
        if isempty(cmdStr), return; end
        try
            b = eval(cmdStr);
            if ~isvector(b)||~isnumeric(b), error('No es vector'); end
            b = b(:)'/sum(abs(b));
            S.node(ch).filtB   = b;
            S.node(ch).filtCmd = cmdStr;
            S.node(ch).filtZi  = zeros(1,length(b)-1);
            S.node(ch).lblFiltSt.Text = sprintf('FIR %d coefs',length(b));
            S.node(ch).hFilt.Visible  = 'on';
            logH(sprintf('Nodo %d FIR %d coefs',ch-1,length(b)));
            logM(sprintf('FIR ch=%d n=%d cmd="%s"',ch-1,length(b),cmdStr));
        catch ME
            logH(['FIR error: ' ME.message]);
        end
    end

    function removeFir(ch)
        S.node(ch).filtB  = []; S.node(ch).filtZi = [];
        S.node(ch).lblFiltSt.Text = 'Sin filtro';
        S.node(ch).hFilt.Visible  = 'off';
    end

    function setDcRemove(ch, val), S.node(ch).dcRemove = val; end

    function sendTxMode(ch, filtrado)
        enviarDirigido(ch, hex2dec('A8'), uint8(filtrado));
        logH(sprintf('Nodo %d TX→%s',ch-1,ternary(filtrado,'Filtrado','Raw')));
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
        if isempty(S.port) || ~isvalid(S.port), return; end
        try
            n = S.port.NumBytesAvailable;
            if n > 0, S.rxBuf = [S.rxBuf, read(S.port,n,'uint8')]; end
        catch; return; end

        changedChannels = false(1, MAX_NODES);
        while length(S.rxBuf) >= 6
            idx = find(S.rxBuf == PKT_HEADER, 1);
            if isempty(idx), S.rxBuf = uint8([]); break; end
            if idx > 1, S.rxBuf = S.rxBuf(idx:end); end
            if length(S.rxBuf) < 6, break; end
            changedCh = decodePkt(S.rxBuf(1:6));
            if changedCh >= 1 && changedCh <= MAX_NODES
                changedChannels(changedCh) = true;
            end
            S.rxBuf  = S.rxBuf(7:end);
        end
        for chUpd = find(changedChannels)
            updatePlot(chUpd);
        end
        if any(changedChannels), drawnow limitrate; end
    end

    function changedCh = decodePkt(pkt)
        changedCh = 0;
        node_id = double(pkt(2));
        typ     = double(pkt(3));
        b2=double(pkt(4)); b1=double(pkt(5)); b0=double(pkt(6));

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

            case 7    % ACK [cmd, val, 0]
                logH(sprintf('ACK nodo=%d cmd=0x%02X val=%d',node_id,b2,b1));
                logM(sprintf('ACK ch=%d cmd=0x%02X val=%d',node_id,b2,b1));

            case 254  % READY (0xFE)
                lblArmCnt.Text = sprintf('Esclavos listos: %d',b2);
                lblSyncSt.Text = 'Estado: ARMED';
                logH(sprintf('READY: %d esclavos',b2));
                logM(sprintf('READY n=%d',b2));
        end
    end

    function appendSample(ch, val)
        S.node(ch).notchBuf(end+1) = double(val);
        S.node(ch).batchCount = S.node(ch).batchCount + 1;
        if length(S.node(ch).notchBuf) > DISP_SAMP
            S.node(ch).notchBuf = S.node(ch).notchBuf(end-DISP_SAMP+1:end);
        end
        % Cancelador 50 Hz
        if cbLine.Value
            [sv, S.node(ch).lineW] = lineCanceller(S.node(ch).notchBuf(end), ...
                S.node(ch).lineW, S.node(ch).batchCount, FS, 50, ...
                spnHarm.Value, efMu.Value);
            S.node(ch).notchBuf(end) = sv;
        end
        % FIR incremental
        if ~isempty(S.node(ch).filtB)
            [fv, S.node(ch).filtZi] = filter(S.node(ch).filtB,1, ...
                S.node(ch).notchBuf(end), S.node(ch).filtZi);
            S.node(ch).filtBuf(end+1) = fv;
            if length(S.node(ch).filtBuf) > DISP_SAMP
                S.node(ch).filtBuf = S.node(ch).filtBuf(end-DISP_SAMP+1:end);
            end
        end
        % Stats cada 200 muestras
        if mod(S.node(ch).batchCount, 200) == 0, updateStats(ch); end
    end

    function updatePlot(ch)
        if ~S.node(ch).visible || ~isLiveHandle(S.node(ch).ax), return; end
        raw = S.node(ch).notchBuf;
        if isempty(raw), return; end
        y = raw;
        if S.node(ch).dcRemove, y = raw - mean(raw); end
        S.node(ch).hRaw.XData = 1:length(y);
        S.node(ch).hRaw.YData = y;
        if ~isempty(S.node(ch).filtBuf)
            fb = S.node(ch).filtBuf;
            S.node(ch).hFilt.XData = 1:length(fb);
            S.node(ch).hFilt.YData = fb;
        end
    end

    function updateStats(ch)
        dStr = '--';
        if ~isempty(S.node(ch).driftHist)
            dStr = sprintf('%.1f±%.1f µs', ...
                mean(S.node(ch).driftHist), std(S.node(ch).driftHist));
        end
        if isLiveHandle(S.node(ch).lblStats)
            S.node(ch).lblStats.Text = sprintf('Batches: %d  Drift: %s', ...
                S.node(ch).batchCount, dStr);
        end
        if ~isempty(S.node(ch).notchBuf) && isLiveHandle(S.node(ch).lblLastVal)
            S.node(ch).lblLastVal.Text = sprintf('Último: %d LSB', ...
                round(S.node(ch).notchBuf(end)));
        end
        if isLiveHandle(globalBatch(ch))
            globalBatch(ch).Text = sprintf('%s: %d', NODE_NAMES{ch}, S.node(ch).batchCount);
        end
        if ch >= 2 && isLiveHandle(driftLabels(ch-1)) && ~isempty(S.node(ch).driftHist)
            driftLabels(ch-1).Text = sprintf('Esclavo %d: %.1f±%.1f µs', ...
                ch-1, mean(S.node(ch).driftHist), std(S.node(ch).driftHist));
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
        ex   = dir(fullfile(DATA_DIR,[base '_*.mat']));
        idx  = length(ex)+1;
        fn   = sprintf('%s_%03d.mat',base,idx);
        fp   = fullfile(DATA_DIR,fn);

        muestras.fecha   = datestr(now);
        muestras.fs      = FS;
        muestras.nSlaves = S.nSlaves;
        for ch = 1:MAX_NODES
            muestras.node(ch).node_id       = ch-1;
            muestras.node(ch).raw_samples   = S.node(ch).notchBuf;
            muestras.node(ch).filt_samples  = S.node(ch).filtBuf;
            muestras.node(ch).pga_code      = S.node(ch).pga_code;
            muestras.node(ch).vdac_byte     = S.node(ch).vdac_byte;
            muestras.node(ch).fir_cmd       = S.node(ch).filtCmd;
            muestras.node(ch).drift_us_hist = S.node(ch).driftHist;
            muestras.node(ch).drift_us_mean = safeStatF(S.node(ch).driftHist,'mean');
            muestras.node(ch).drift_us_std  = safeStatF(S.node(ch).driftHist,'std');
            muestras.node(ch).batch_count   = S.node(ch).batchCount;
            muestras.node(ch).salud         = S.node(ch).salud;
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
        nodesCfg = struct();
        for ch = 1:MAX_NODES
            nodesCfg(ch).pga_code  = S.node(ch).pga_code;
            nodesCfg(ch).vdac_byte = S.node(ch).vdac_byte;
            nodesCfg(ch).pgavdac   = S.node(ch).pgavdac;
            nodesCfg(ch).cal       = S.node(ch).cal;
            nodesCfg(ch).filtCmd   = S.node(ch).filtCmd;
            nodesCfg(ch).dcRemove  = S.node(ch).dcRemove;
        end
        logSlot = nextSlot;    %#ok
        try
            save(CFG_FILE,'nodesCfg','logSlot');
        catch
        end
    end

    function v = safeStatF(vec, tipo)
        if isempty(vec), v = NaN; return; end
        if strcmp(tipo,'mean'), v = mean(vec); else, v = std(vec); end
    end

%% ════════════════════════════════════════════════════════════════════════
%%  Cierre
%% ════════════════════════════════════════════════════════════════════════

    function onClose(~,~)
        try
            if ~isempty(tmr) && isvalid(tmr)
                if strcmp(tmr.Running,'on'), stop(tmr); end
                delete(tmr);
            end
        catch, end
        if S.streaming, try, psocCmd(hex2dec('A1'),0); catch, end; end
        if ~isempty(S.port) && isvalid(S.port), delete(S.port); end
        guardarConfig();
        logH('Sesión cerrada');
        logM('onClose');
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
        agregarLog(humLog,line);
        cur = taLog.Value;
        if ischar(cur), cur = {cur}; end
        cur = [cur; {line}];
        if length(cur) > 200, cur = cur(end-199:end); end
        taLog.Value = cur;
        scroll(taLog,'bottom');
    end

    function logM(msg)
        ts   = datestr(now,'HH:MM:SS.FFF');
        agregarLog(machLog, sprintf('[%s] %s',ts,msg));
    end

    function r = ternary(c,a,b), if c, r=a; else, r=b; end; end

    function ports = listSerialPorts()
        try, ports = cellstr(serialportlist('available'));
        catch, ports = {}; end
        if isempty(ports), ports = {'(sin puertos)'}; end
    end

end
