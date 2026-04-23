function geophone_scope()
% geophone_scope — Interfaz PSoC5 Geophone Filter Testbench
%
% Protocolo RX (PSoC -> PC, 10 bytes, 921600 baud):
%   [0xAA][0x00][sar_hi][sar_lo][ds2][ds1][ds0][flt2][flt1][flt0]
%   sar = int16  big-endian
%   ds  = int24  big-endian signed
%   flt = int24  big-endian signed
%
% Protocolo TX (PC -> PSoC):
%   [0xBB][0x03][fhi][flo][cksum]   freq_dh = Hz*10, uint16 big-endian
%   cksum = 0xBB ^ 0x03 ^ fhi ^ flo
%   PSoC valida checksum solo y responde 'K'/'!'
%
% Uso: geophone_scope()
%
% START habilita la captura. STOP la deshabilita.
% La frecuencia solo se puede cambiar con el stream detenido.
% Log de debug en scope_YYYYMMDD_HHMMSS.log (mismo directorio).

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
    S.pktBuf     = zeros(10, 1, 'uint8');
    S.pktIdx     = 0;

    % Datos acumulados
    S.maxPoints  = 9000;
    S.nVec       = zeros(0, 1);
    S.sarVec     = zeros(0, 1);
    S.dsVec      = zeros(0, 1);
    S.fltVec     = zeros(0, 1);
    S.ch4Vec     = zeros(0, 1);
    S.frameCount = 0;

    % SAR: 12-bit signed ±1.024 V → 0.5 mV/count
    % DS/FLT: 18-bit CFG1 ±6.144 V, CountsPerVolt=21333 → 1000/21333 mV/count
    S.fs        = 3000;
    S.sar_mV    = 0.5;
    S.ds_mV     = 1000.0 / 21333.0;

    % Filtro digital (canal 4)
    S.filt_b       = 1;
    S.filt_a       = 1;
    S.filt_zi      = [];
    S.filt_chan    = 1;       % 1=SAR 2=DelSig 3=DFB
    S.filt_enabled = false;

    % =========================================================
    % UI  (figura 860px de alto para acomodar 4 ejes)
    % =========================================================
    fig = uifigure('Name', 'Geophone Scope — PSoC5', 'Position', [60 40 1240 860]);
    fig.CloseRequestFcn = @onClose;

    % -- 4 ejes (izquierda) -----------------------------------
    ax1 = uiaxes(fig, 'Position', [20 645 840 200]);
    ax1.XGrid = 'on'; ax1.YGrid = 'on';
    ax1.XMinorGrid = 'on'; ax1.YMinorGrid = 'on';
    title(ax1, 'SAR — Entrada  [12-bit, ±1.024 V]');
    ylabel(ax1, 'mV'); xlabel(ax1, 's');
    hSar = plot(ax1, nan, nan, 'Color', [1 1 0]);

    ax2 = uiaxes(fig, 'Position', [20 435 840 200]);
    ax2.XGrid = 'on'; ax2.YGrid = 'on';
    ax2.XMinorGrid = 'on'; ax2.YMinorGrid = 'on';
    title(ax2, 'ADC DelSig — Crudo  [18-bit, ±6.144 V, CFG1]');
    ylabel(ax2, 'mV'); xlabel(ax2, 's');
    hDs = plot(ax2, nan, nan, 'Color', [0 1 1]);

    ax3 = uiaxes(fig, 'Position', [20 225 840 200]);
    ax3.XGrid = 'on'; ax3.YGrid = 'on';
    ax3.XMinorGrid = 'on'; ax3.YMinorGrid = 'on';
    title(ax3, 'Filter DFB — Salida');
    ylabel(ax3, 'mV'); xlabel(ax3, 's');
    hFlt = plot(ax3, nan, nan, 'Color', [1 0 1]);

    ax4 = uiaxes(fig, 'Position', [20 15 840 200]);
    ax4.XGrid = 'on'; ax4.YGrid = 'on';
    ax4.XMinorGrid = 'on'; ax4.YMinorGrid = 'on';
    title(ax4, 'Canal 4 — Filtro Digital (SAR)');
    ylabel(ax4, 'mV'); xlabel(ax4, 's');
    hCh4 = plot(ax4, nan, nan, 'Color', [0 1 0]);

    % -- Panel derecho ----------------------------------------
    RX = 878; RW = 345;

    % Conexion
    pConn = uipanel(fig, 'Title', 'Conexion', 'Position', [RX 760 RW 95]);
    uilabel(pConn,  'Text', 'COM:',  'Position', [10  52 35 22]);
    edtCom  = uieditfield(pConn, 'text',    'Value', 'COM7', 'Position', [50  52 75 22]);
    uilabel(pConn,  'Text', 'Baud:', 'Position', [135 52 38 22]);
    edtBaud = uieditfield(pConn, 'numeric', 'Value', 921600, ...
        'Limits', [1200 2000000], 'Position', [178 52 100 22]);
    btnConn = uibutton(pConn,  'Text', 'Conectar',    'Position', [10  12 100 28], ...
        'ButtonPushedFcn', @onConnectToggle);
    lblStat = uilabel(pConn,   'Text', 'DESCONECTADO','Position', [120 12 210 28]);

    % Stream / frecuencia
    pCtrl = uipanel(fig, 'Title', 'Stream y Frecuencia', 'Position', [RX 638 RW 117]);
    btnStart = uibutton(pCtrl, 'Text', 'START', 'Position', [10  72 95 30], ...
        'ButtonPushedFcn', @onStart);
    btnStop  = uibutton(pCtrl, 'Text', 'STOP',  'Position', [115 72 95 30], ...
        'ButtonPushedFcn', @onStop);
    btnClear = uibutton(pCtrl, 'Text', 'Clear', 'Position', [220 72 105 30], ...
        'ButtonPushedFcn', @onClear);

    uilabel(pCtrl, 'Text', 'Freq VDAC (Hz):', 'Position', [10 32 110 22]);
    edtFreq = uieditfield(pCtrl, 'numeric', 'Value', 1.0, ...
        'Limits', [0.1 300], 'Position', [125 32 90 22]);
    btnSetFreq = uibutton(pCtrl, 'Text', 'Enviar Freq', 'Position', [225 29 100 28], ...
        'ButtonPushedFcn', @onSetFreq);
    uilabel(pCtrl, 'Text', '(solo cuando STOP)', 'Position', [125 10 200 18]);

    % Datos
    pData = uipanel(fig, 'Title', 'Datos', 'Position', [RX 548 RW 85]);
    lblInfo   = uilabel(pData, 'Text', 'n=0', 'Position', [10 48 320 22]);
    btnExport = uibutton(pData, 'Text', 'Export .mat', 'Position', [10 8 120 30], ...
        'ButtonPushedFcn', @onExport);
    uilabel(pData, 'Text', 'Max pts:', 'Position', [145 14 65 18]);
    edtMaxPts = uieditfield(pData, 'numeric', 'Value', S.maxPoints, ...
        'Limits', [100 1000000], 'RoundFractionalValues', 'on', ...
        'Position', [213 11 110 22], 'ValueChangedFcn', @(~,~)onMaxPtsChanged());

    % Filtro digital (canal 4)
    pFilt = uipanel(fig, 'Title', 'Filtro Digital (Canal 4)', ...
        'Position', [RX 325 RW 218]);

    uilabel(pFilt, 'Text', 'Canal fuente:', 'Position', [10 172 90 22]);
    ddChan = uidropdown(pFilt, 'Items', {'SAR', 'DelSig', 'DFB'}, ...
        'Value', 'SAR', 'Position', [105 172 100 22], ...
        'ValueChangedFcn', @(dd,~) onFiltChanChanged(dd));

    uilabel(pFilt, 'Text', 'Comando MATLAB:', 'Position', [10 143 200 22]);
    edtFiltCmd = uieditfield(pFilt, 'text', 'Value', 'b = fir1(40, 0.1)', ...
        'Position', [10 115 315 26]);

    btnDesign = uibutton(pFilt, 'Text', 'Diseñar', 'Position', [10 78 95 28], ...
        'ButtonPushedFcn', @onDesignFilter);
    chkFiltEn = uicheckbox(pFilt, 'Text', 'Habilitar canal 4', 'Value', false, ...
        'Position', [115 82 210 22], ...
        'ValueChangedFcn', @(cb,~) onFiltEnChanged(cb));

    lblFiltStat = uilabel(pFilt, 'Text', 'Sin diseño', ...
        'Position', [10 48 315 22]);
    uilabel(pFilt, 'Text', 'Ej: b=fir1(40,0.1)   [b,a]=butter(4,0.1)', ...
        'Position', [10 8 315 26], 'FontSize', 9, ...
        'FontColor', [0.55 0.55 0.55]);

    % Log
    txtLog = uitextarea(fig, 'Editable', 'off', 'Position', [RX 5 RW 315]);
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

    function logRaw(raw)
        if S.logFid <= 0, return; end
        ts = datestr(now, 'HH:MM:SS.FFF');
        hexStr = strtrim(sprintf('%02X ', raw(:).'));
        fprintf(S.logFid, '[%s] RX tick=%d  bytes=%d  total=%d  hex: %s\n', ...
            ts, S.tickCount, numel(raw), S.totalBytes, hexStr);
    end

    function logPkt(n, sar_v, ds_v, flt_v)
        if S.logFid <= 0, return; end
        ts = datestr(now, 'HH:MM:SS.FFF');
        fprintf(S.logFid, '[%s] PKT#%d  sar=%d  ds=%d  flt=%d\n', ...
            ts, n, sar_v, ds_v, flt_v);
    end

    function logTick(nAvail)
        if S.logFid <= 0, return; end
        if nAvail > 0 || mod(S.tickCount, 50) == 0
            ts = datestr(now, 'HH:MM:SS.FFF');
            fprintf(S.logFid, '[%s] TICK #%d  avail=%d  totalBytes=%d  streamON=%d  parseState=%d\n', ...
                ts, S.tickCount, nAvail, S.totalBytes, S.streamEnabled, S.parseState);
        end
    end

    function updateBtnStates()
        conn    = S.isConnected;
        running = S.streamEnabled;
        btnStart.Enable   = conn && ~running;
        btnStop.Enable    = conn &&  running;
        btnSetFreq.Enable = conn && ~running;
        edtFreq.Enable    = conn && ~running;
        edtCom.Enable     = ~conn;
        edtBaud.Enable    = ~conn;
    end

    function updateInfo()
        try
            tSpan = numel(S.nVec) / S.fs;
            lblInfo.Text = sprintf('muestras=%d  frames=%d  Fs=%d Hz  t=%.2f s', ...
                numel(S.nVec), S.frameCount, S.fs, tSpan);
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
                    fprintf(S.logFid, '=== geophone_scope log — %s ===\n', datestr(now));
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
        S.pktBuf     = zeros(10, 1, 'uint8');
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
        S.nVec = []; S.sarVec = []; S.dsVec = []; S.fltVec = [];
        S.ch4Vec = []; S.frameCount = 0; S.filt_zi = [];
        set(hSar, 'XData', nan, 'YData', nan);
        set(hDs,  'XData', nan, 'YData', nan);
        set(hFlt, 'XData', nan, 'YData', nan);
        set(hCh4, 'XData', nan, 'YData', nan);
        updateInfo();
        logMsg("Datos borrados.");
    end

    % =========================================================
    % Comando frecuencia con checksum XOR
    % Escanea byte a byte: salta paquetes de datos (0xAA + 9 bytes)
    % y busca 'K' (0x4B) o '!' (0x21) entre ellos.
    % =========================================================
    function onSetFreq(~,~)
        if ~S.isConnected,  logMsg("No conectado."); return; end
        if S.streamEnabled, logMsg("Detener stream antes de cambiar la frecuencia."); return; end

        freq_hz = double(edtFreq.Value);
        if ~isfinite(freq_hz) || freq_hz <= 0
            logMsg("Frecuencia invalida."); return;
        end

        freq_dh = max(1, min(65535, round(freq_hz * 10)));
        S.fs = max(1, round(24e6 * double(freq_dh) / 80000));
        hi    = uint8(bitshift(uint16(freq_dh), -8));
        lo    = uint8(bitand(uint16(freq_dh), uint16(255)));
        cksum = bitxor(bitxor(bitxor(uint8(0xBB), uint8(0x03)), hi), lo);
        cmd   = uint8([0xBB, 0x03, hi, lo, cksum]);

        stopStreamTimer();
        try flush(S.sp); catch, end
        pause(0.05);

        MAX_RETRIES = 5;
        TIMEOUT_S   = 0.5;
        ok = false;

        for attempt = 1 : MAX_RETRIES
            try
                write(S.sp, cmd, "uint8");
                logMsg(sprintf("CMD_FREQ intento %d/%d: %.1f Hz  [%s]", ...
                    attempt, MAX_RETRIES, freq_hz, ...
                    strjoin(string(dec2hex(cmd, 2)), ' ')));

                % Escanear bytes: saltar paquetes de datos (0xAA + 9 bytes),
                % buscar 'K'(0x4B) o '!'(0x21).
                t0 = tic;
                rsp = uint8(0);
                skipCount = 0;
                found = false;
                while toc(t0) < TIMEOUT_S
                    if S.sp.NumBytesAvailable > 0
                        b = read(S.sp, 1, "uint8");
                        if skipCount > 0
                            skipCount = skipCount - 1;
                        elseif b == uint8(0xAA)
                            skipCount = 9;  % saltar los 9 bytes restantes del paquete
                        elseif b == uint8('K') || b == uint8('!')
                            rsp = b;
                            found = true;
                            break;
                        end
                    else
                        pause(0.002);
                    end
                end

                if found && rsp == uint8('K')
                    logMsg(sprintf("CMD_FREQ OK: %.1f Hz confirmado.", freq_hz));
                    ok = true;
                    break;
                elseif found && rsp == uint8('!')
                    logMsg(sprintf("CMD_FREQ intento %d: PSoC rechazo checksum, reintentando...", attempt));
                    try flush(S.sp); catch, end
                    pause(0.05);
                else
                    logMsg(sprintf("CMD_FREQ intento %d: timeout sin respuesta.", attempt));
                    try flush(S.sp); catch, end
                    pause(0.1);
                end

            catch e
                logMsg(sprintf("CMD_FREQ intento %d excepcion: %s", attempt, string(e.message)));
                try flush(S.sp); catch, end
                pause(0.1);
            end
        end

        if ~ok
            logMsg("CMD_FREQ FALLO tras " + string(MAX_RETRIES) + " intentos.");
        end

        startStreamTimer();
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
        logRaw(raw);

        if ~S.streamEnabled
            return;
        end

        S.rxBuf = [S.rxBuf; uint8(raw(:))];

        % ---- Parser: HUNT / COLLECT --------------------------
        newSar = zeros(0, 1);
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
                    if S.logFid > 0
                        fprintf(S.logFid, '[%s] HUNT->COLLECT en idx=%d\n', ...
                            datestr(now,'HH:MM:SS.FFF'), i);
                    end
                end
                i = i + 1;

            else
                S.pktIdx           = S.pktIdx + 1;
                S.pktBuf(S.pktIdx) = b;
                i = i + 1;

                if S.pktIdx == 10
                    pkt = double(S.pktBuf);

                    if S.logFid > 0
                        fprintf(S.logFid, '[%s] PKT_RAW: %s\n', ...
                            datestr(now,'HH:MM:SS.FFF'), ...
                            strtrim(sprintf('%02X ', uint8(pkt).')));
                    end

                    if pkt(2) == 1
                        msg = sprintf('HEARTBEAT  total_bytes=%d', S.totalBytes);
                        if S.logFid > 0
                            fprintf(S.logFid, '[%s] *** %s\n', datestr(now,'HH:MM:SS.FFF'), msg);
                        end
                        logMsg(msg);
                        S.parseState = 0;
                        continue;
                    end

                    sar_u = pkt(3)*256 + pkt(4);
                    if sar_u >= 32768, sar_v = sar_u - 65536; else, sar_v = sar_u; end

                    ds_u = pkt(5)*65536 + pkt(6)*256 + pkt(7);
                    if pkt(5) >= 128, ds_v = ds_u - 16777216; else, ds_v = ds_u; end

                    flt_u = pkt(8)*65536 + pkt(9)*256 + pkt(10);
                    if pkt(8) >= 128, flt_v = flt_u - 16777216; else, flt_v = flt_u; end

                    newSar(end+1, 1) = sar_v;
                    newDs (end+1, 1) = ds_v;
                    newFlt(end+1, 1) = flt_v;

                    nTotal = S.frameCount + numel(newSar);
                    if nTotal <= 50 || mod(nTotal, 3000) == 0
                        logPkt(nTotal, sar_v, ds_v, flt_v);
                    end

                    S.parseState = 0;
                end
            end
        end

        S.rxBuf = uint8([]);

        if isempty(newSar), return; end

        % ---- Canal 4: aplicar filtro digital ----
        if S.filt_enabled && ~isempty(S.filt_b)
            switch S.filt_chan
                case 1, xIn = double(newSar) * S.sar_mV;
                case 2, xIn = double(newDs)  * S.ds_mV;
                case 3, xIn = double(newFlt) * S.ds_mV;
                otherwise, xIn = zeros(size(newSar));
            end
            nTaps = max(numel(S.filt_b), numel(S.filt_a));
            if isempty(S.filt_zi) || numel(S.filt_zi) ~= nTaps - 1
                S.filt_zi = zeros(nTaps - 1, 1);
            end
            [yCh4, S.filt_zi] = filter(S.filt_b, S.filt_a, xIn, S.filt_zi);
        else
            yCh4 = zeros(numel(newSar), 1);
        end

        nNew = numel(newSar);
        nIdx = (S.frameCount + 1 : S.frameCount + nNew).';

        S.sarVec     = [S.sarVec; newSar];
        S.dsVec      = [S.dsVec;  newDs ];
        S.fltVec     = [S.fltVec; newFlt];
        S.ch4Vec     = [S.ch4Vec; yCh4  ];
        S.nVec       = [S.nVec;   nIdx  ];
        S.frameCount = S.frameCount + nNew;

        if numel(S.nVec) > S.maxPoints
            k0       = numel(S.nVec) - S.maxPoints + 1;
            S.sarVec = S.sarVec(k0:end);
            S.dsVec  = S.dsVec (k0:end);
            S.fltVec = S.fltVec(k0:end);
            S.ch4Vec = S.ch4Vec(k0:end);
            S.nVec   = S.nVec  (k0:end);
        end

        tVec = S.nVec / S.fs;
        set(hSar, 'XData', tVec, 'YData', S.sarVec * S.sar_mV);
        set(hDs,  'XData', tVec, 'YData', S.dsVec  * S.ds_mV);
        set(hFlt, 'XData', tVec, 'YData', S.fltVec * S.ds_mV);
        set(hCh4, 'XData', tVec, 'YData', S.ch4Vec);

        updateInfo();
        drawnow limitrate;
    end

    % =========================================================
    % Filtro digital — callbacks
    % =========================================================
    function onFiltChanChanged(dd)
        switch dd.Value
            case 'SAR',    S.filt_chan = 1;
            case 'DelSig', S.filt_chan = 2;
            case 'DFB',    S.filt_chan = 3;
        end
        S.filt_zi = [];
        title(ax4, ['Canal 4 — Filtro Digital (' dd.Value ')']);
        logMsg(sprintf('Filtro canal fuente: %s', dd.Value));
    end

    function onDesignFilter(~,~)
        cmd = strtrim(string(edtFiltCmd.Value));
        if cmd == ""
            logMsg("Filtro: comando vacio."); return;
        end
        try
            b = []; a = 1;
            eval(cmd);
            if isempty(b)
                error('El comando no definio ''b''.');
            end
            S.filt_b  = double(b(:).');
            S.filt_a  = double(a(:).');
            S.filt_zi = [];
            nB = numel(S.filt_b); nA = numel(S.filt_a);
            lblFiltStat.Text = sprintf('OK: b=%d taps, a=%d taps', nB, nA);
            logMsg(sprintf('Filtro disenado: b=%d taps, a=%d taps', nB, nA));
        catch e
            logMsg("Filtro ERROR: " + string(e.message));
            lblFiltStat.Text = "Error: " + string(e.message);
        end
    end

    function onFiltEnChanged(cb)
        S.filt_enabled = cb.Value;
        S.filt_zi = [];
        if cb.Value
            logMsg('Filtro canal 4: HABILITADO');
        else
            logMsg('Filtro canal 4: DESHABILITADO');
        end
    end

    % =========================================================
    % Export
    % =========================================================
    function onExport(~,~)
        if isempty(S.nVec), logMsg("No hay datos para exportar."); return; end
        [file, path] = uiputfile('*.mat', 'Guardar datos', 'geophone_data.mat');
        if isequal(file, 0), logMsg("Export cancelado."); return; end
        data = struct('n', S.nVec, 'sar', S.sarVec, 'ds', S.dsVec, ...
            'flt', S.fltVec, 'ch4', S.ch4Vec, ...
            'frameCount', S.frameCount, 'fs', S.fs, ...
            'filt_b', S.filt_b, 'filt_a', S.filt_a, ...
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


