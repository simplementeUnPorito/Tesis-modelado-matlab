function geophone_scope_simple()
% geophone_scope_simple — Interfaz PSoC5 entrada real (DelSig + DFB)
%
% Protocolo RX (PSoC -> PC, 8 bytes, USBUART CDC):
%   [0xAA][0x00][ds2][ds1][ds0][flt2][flt1][flt0]
%   ds  = int24 big-endian signed  (ADC_DelSig 18-bit, ±6.144V)
%   flt = int24 big-endian signed  (salida DFB)
%
% Uso: geophone_scope_simple()
% START habilita la captura. STOP la deshabilita.

    scriptDir = fileparts(mfilename('fullpath'));

    % =========================================================
    % Estado global
    % =========================================================
    S = struct();
    S.sp          = [];
    S.isConnected = false;
    S.logFid      = -1;
    S.tickCount   = 0;
    S.totalBytes  = 0;

    % Stream
    S.streamTimer   = [];
    S.rxBuf         = uint8([]);
    S.streamEnabled = false;

    % Parser (0=HUNT, 1=COLLECT)
    S.parseState = 0;
    S.pktBuf     = zeros(8, 1, 'uint8');
    S.pktIdx     = 0;

    % Datos acumulados
    S.maxPoints  = 9000;
    S.nVec       = zeros(0, 1);
    S.dsVec      = zeros(0, 1);
    S.fltVec     = zeros(0, 1);
    S.frameCount = 0;

    % DS/FLT: 18-bit CFG1 ±6.144V, CountsPerVolt=21333 → 1000/21333 mV/count
    S.fs    = 1500;
    S.ds_mV = 1000.0 / 21333.0;

    % =========================================================
    % UI
    % =========================================================
    fig = uifigure('Name', 'Geophone Scope Simple — PSoC5', 'Position', [60 80 1100 680]);
    fig.CloseRequestFcn = @onClose;

    % -- 2 ejes (izquierda) -----------------------------------
    ax1 = uiaxes(fig, 'Position', [20 370 820 290]);
    ax1.XGrid = 'on'; ax1.YGrid = 'on';
    ax1.XMinorGrid = 'on'; ax1.YMinorGrid = 'on';
    title(ax1, 'ADC DelSig — Crudo  [18-bit, ±6.144 V]');
    ylabel(ax1, 'mV'); xlabel(ax1, 's');
    hDs = plot(ax1, nan, nan, 'Color', [0 1 1]);

    ax2 = uiaxes(fig, 'Position', [20 55 820 290]);
    ax2.XGrid = 'on'; ax2.YGrid = 'on';
    ax2.XMinorGrid = 'on'; ax2.YMinorGrid = 'on';
    title(ax2, 'Filter DFB — Salida');
    ylabel(ax2, 'mV'); xlabel(ax2, 's');
    hFlt = plot(ax2, nan, nan, 'Color', [1 0 1]);

    % -- Panel derecho ----------------------------------------
    RX = 860; RW = 225;

    % Conexion
    pConn = uipanel(fig, 'Title', 'Conexion', 'Position', [RX 570 RW 100]);
    uilabel(pConn, 'Text', 'COM:', 'Position', [10 52 35 22]);
    edtCom  = uieditfield(pConn, 'text',    'Value', 'COM7', 'Position', [50 52 60 22]);
    uilabel(pConn, 'Text', 'Baud:', 'Position', [120 52 38 22]);
    edtBaud = uieditfield(pConn, 'numeric', 'Value', 115200, ...
        'Limits', [1200 2000000], 'Position', [162 52 55 22]);
    btnConn = uibutton(pConn, 'Text', 'Conectar', 'Position', [10 12 90 28], ...
        'ButtonPushedFcn', @onConnectToggle);
    lblStat = uilabel(pConn, 'Text', 'DESCONECTADO', 'Position', [110 12 110 28]);

    % Stream
    pCtrl = uipanel(fig, 'Title', 'Stream', 'Position', [RX 480 RW 85]);
    btnStart = uibutton(pCtrl, 'Text', 'START', 'Position', [10 40 85 28], ...
        'ButtonPushedFcn', @onStart);
    btnStop  = uibutton(pCtrl, 'Text', 'STOP',  'Position', [105 40 85 28], ...
        'ButtonPushedFcn', @onStop);
    btnClear = uibutton(pCtrl, 'Text', 'Clear', 'Position', [10 8 85 28], ...
        'ButtonPushedFcn', @onClear);

    % Datos
    pData = uipanel(fig, 'Title', 'Datos', 'Position', [RX 390 RW 85]);
    lblInfo   = uilabel(pData, 'Text', 'n=0', 'Position', [10 48 205 22]);
    btnExport = uibutton(pData, 'Text', 'Export .mat', 'Position', [10 8 110 28], ...
        'ButtonPushedFcn', @onExport);
    uilabel(pData, 'Text', 'Max pts:', 'Position', [130 14 60 18]);
    edtMaxPts = uieditfield(pData, 'numeric', 'Value', S.maxPoints, ...
        'Limits', [100 1000000], 'RoundFractionalValues', 'on', ...
        'Position', [190 11 30 22], 'ValueChangedFcn', @(~,~)onMaxPtsChanged());

    % Log
    txtLog = uitextarea(fig, 'Editable', 'off', 'Position', [RX 5 RW 380]);
    txtLog.Value = strings(0, 1);

    updateBtnStates();

    % =========================================================
    % Helpers
    % =========================================================
    function logMsg(msg)
        ts   = string(datestr(now, 'HH:MM:SS.FFF'));
        line = "[" + ts + "] " + string(msg);
        v = txtLog.Value;
        if ~isstring(v), v = string(v); end
        v(end+1, 1) = line;
        if numel(v) > 500, v = v(end-499:end); end
        txtLog.Value = v;
        if S.logFid > 0
            fprintf(S.logFid, '%s\n', char(line));
        end
        drawnow limitrate;
    end

    function logTick(nAvail)
        if S.logFid <= 0, return; end
        if nAvail > 0 || mod(S.tickCount, 50) == 0
            ts = datestr(now, 'HH:MM:SS.FFF');
            fprintf(S.logFid, '[%s] TICK #%d  avail=%d  totalBytes=%d  streamON=%d\n', ...
                ts, S.tickCount, nAvail, S.totalBytes, S.streamEnabled);
        end
    end

    function updateBtnStates()
        conn    = S.isConnected;
        running = S.streamEnabled;
        btnStart.Enable = conn && ~running;
        btnStop.Enable  = conn &&  running;
        edtCom.Enable   = ~conn;
        edtBaud.Enable  = ~conn;
    end

    function updateInfo()
        try
            tSpan = numel(S.nVec) / S.fs;
            lblInfo.Text = sprintf('n=%d  frames=%d  t=%.2f s', ...
                numel(S.nVec), S.frameCount, tSpan);
        catch, end
    end

    function onMaxPtsChanged()
        v = round(double(edtMaxPts.Value));
        if isfinite(v) && v > 0, S.maxPoints = v; end
    end

    % =========================================================
    % Conexion
    % =========================================================
    function onConnectToggle(~,~)
        if ~S.isConnected
            com  = strtrim(string(edtCom.Value));
            baud = double(edtBaud.Value);
            if com == "", logMsg("COM vacio."); return; end
            try
                S.sp = serialport(com, baud);
                S.sp.Timeout = 0.05;
                flush(S.sp);
                pause(0.05);

                S.isConnected   = true;
                S.streamEnabled = false;
                S.rxBuf         = uint8([]);
                S.parseState    = 0;

                logName = fullfile(scriptDir, sprintf('scope_%s.log', datestr(now,'yyyymmdd_HHMMSS')));
                S.logFid = fopen(logName, 'w');
                if S.logFid > 0
                    fprintf(S.logFid, '=== geophone_scope_simple log — %s ===\n', datestr(now));
                end

                btnConn.Text = 'Desconectar';
                lblStat.Text = 'CONECTADO: ' + com;
                logMsg("Conectado a " + com + " @ " + string(baud) + " baud");

                startStreamTimer();
            catch e
                S.sp = []; S.isConnected = false;
                logMsg("Error al conectar: " + string(e.message));
            end
        else
            stopStreamTimer();
            try
                if ~isempty(S.sp)
                    try flush(S.sp); catch, end
                    delete(S.sp);
                end
            catch, end
            logMsg("Desconectado.");
            if S.logFid > 0, try fclose(S.logFid); catch, end; S.logFid = -1; end
            S.sp = []; S.isConnected = false; S.streamEnabled = false;
            btnConn.Text = 'Conectar';
            lblStat.Text = 'DESCONECTADO';
        end
        updateBtnStates();
    end

    % =========================================================
    % Start / Stop / Clear
    % =========================================================
    function onStart(~,~)
        if ~S.isConnected, logMsg("No conectado."); return; end
        S.rxBuf      = uint8([]);
        S.parseState = 0;
        S.pktBuf     = zeros(8, 1, 'uint8');
        S.pktIdx     = 0;
        S.streamEnabled = true;
        logMsg("--- Stream ON ---");
        updateBtnStates();
    end

    function onStop(~,~)
        S.streamEnabled = false;
        logMsg("--- Stream OFF ---");
        updateBtnStates();
    end

    function onClear(~,~)
        S.dsVec = []; S.fltVec = []; S.nVec = []; S.frameCount = 0;
        set(hDs,  'XData', nan, 'YData', nan);
        set(hFlt, 'XData', nan, 'YData', nan);
        updateInfo();
        logMsg("Datos borrados.");
    end

    % =========================================================
    % Timer de stream (20 ms)
    % =========================================================
    function startStreamTimer()
        stopStreamTimer();
        if ~S.isConnected || isempty(S.sp), return; end
        S.streamTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.02, ...
            'TimerFcn', @onStreamTick, 'BusyMode', 'drop');
        start(S.streamTimer);
    end

    function stopStreamTimer()
        try
            if ~isempty(S.streamTimer) && isvalid(S.streamTimer)
                stop(S.streamTimer);
                delete(S.streamTimer);
            end
        catch, end
        S.streamTimer = [];
    end

    % =========================================================
    % Tick del stream — cada 20 ms
    % =========================================================
    function onStreamTick(~,~)
        if ~S.isConnected || isempty(S.sp), return; end

        S.tickCount = S.tickCount + 1;
        nAvail = S.sp.NumBytesAvailable;
        logTick(nAvail);

        if nAvail <= 0, return; end

        try
            raw = read(S.sp, nAvail, "uint8");
        catch e
            if S.logFid > 0
                fprintf(S.logFid, '[%s] ERROR read(): %s\n', datestr(now,'HH:MM:SS.FFF'), e.message);
            end
            return;
        end
        if isempty(raw), return; end

        S.totalBytes = S.totalBytes + numel(raw);

        if ~S.streamEnabled
            return;
        end

        S.rxBuf = [S.rxBuf; uint8(raw(:))];

        % ---- Parser: HUNT / COLLECT (8 bytes por paquete) ----
        newDs  = zeros(0, 1);
        newFlt = zeros(0, 1);

        i = 1;
        n = numel(S.rxBuf);

        while i <= n
            b = S.rxBuf(i);

            if S.parseState == 0
                if b == uint8(0xAA)
                    S.pktBuf(1) = b;
                    S.pktIdx    = 1;
                    S.parseState = 1;
                end
                i = i + 1;

            else
                S.pktIdx           = S.pktIdx + 1;
                S.pktBuf(S.pktIdx) = b;
                i = i + 1;

                if S.pktIdx == 8
                    pkt = double(S.pktBuf);

                    if pkt(2) == 1
                        logMsg(sprintf('HEARTBEAT  total_bytes=%d', S.totalBytes));
                        S.parseState = 0;
                        continue;
                    end

                    ds_u = pkt(3)*65536 + pkt(4)*256 + pkt(5);
                    if pkt(3) >= 128, ds_v = ds_u - 16777216; else, ds_v = ds_u; end

                    flt_u = pkt(6)*65536 + pkt(7)*256 + pkt(8);
                    if pkt(6) >= 128, flt_v = flt_u - 16777216; else, flt_v = flt_u; end

                    newDs (end+1, 1) = ds_v;
                    newFlt(end+1, 1) = flt_v;

                    S.parseState = 0;
                end
            end
        end

        S.rxBuf = uint8([]);

        if isempty(newDs), return; end

        nNew = numel(newDs);
        nIdx = (S.frameCount + 1 : S.frameCount + nNew).';

        S.dsVec      = [S.dsVec;  newDs ];
        S.fltVec     = [S.fltVec; newFlt];
        S.nVec       = [S.nVec;   nIdx  ];
        S.frameCount = S.frameCount + nNew;

        if numel(S.nVec) > S.maxPoints
            k0       = numel(S.nVec) - S.maxPoints + 1;
            S.dsVec  = S.dsVec (k0:end);
            S.fltVec = S.fltVec(k0:end);
            S.nVec   = S.nVec  (k0:end);
        end

        tVec = S.nVec / S.fs;
        set(hDs,  'XData', tVec, 'YData', S.dsVec  * S.ds_mV);
        set(hFlt, 'XData', tVec, 'YData', S.fltVec * S.ds_mV);

        updateInfo();
        drawnow limitrate;
    end

    % =========================================================
    % Export
    % =========================================================
    function onExport(~,~)
        if isempty(S.nVec), logMsg("No hay datos para exportar."); return; end
        [file, path] = uiputfile('*.mat', 'Guardar datos', 'geophone_data.mat');
        if isequal(file, 0), logMsg("Export cancelado."); return; end
        data = struct('n', S.nVec, 'ds', S.dsVec, 'flt', S.fltVec, ...
            'frameCount', S.frameCount, 'fs', S.fs, ...
            'timestamp', datestr(now));
        save(fullfile(path, file), '-struct', 'data');
        logMsg("Export OK: " + string(fullfile(path, file)));
    end

    % =========================================================
    % Cerrar
    % =========================================================
    function onClose(~,~)
        try %#ok<ALIGN>
            stopStreamTimer();
            if S.isConnected && ~isempty(S.sp)
                try flush(S.sp); catch, end
                try delete(S.sp); catch, end
            end
        catch, end
        if S.logFid > 0, try fclose(S.logFid); catch, end; S.logFid = -1; end
        delete(fig);
    end

end
