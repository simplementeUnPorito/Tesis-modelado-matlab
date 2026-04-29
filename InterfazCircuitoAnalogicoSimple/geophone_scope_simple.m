function geophone_scope_simple()
% geophone_scope_simple — Interfaz PSoC5 salida FIR Notch (1 canal)
%
% Protocolo RX (5 bytes, UART):
%   Data:      [0x56][0x00][b2][b1][b0]   int24 big-endian signed
%   Heartbeat: [0x56][0x01][0x00][0x00][0x00]
%   ADC: 18-bit, +-6.144V, buf gain=2, Left Bit-23
%   scale = 1000/(21333*2*64) mV/count
%
% Filtro: escribi cualquier comando MATLAB que retorne b, ej:
%   fir1(40, 0.1)
%   firpm(50, [0 0.05 0.1 0.5], [1 1 0 0])
%   firls(60, [0 0.08 0.12 1], [1 1 0 0])
%
% Config persistida en scope_config.mat (mismo directorio).

    scriptDir = fileparts(mfilename('fullpath'));
    cfgFile   = fullfile(scriptDir, 'scope_config.mat');

    % =====================================================================
    % Estado global — defaults
    % =====================================================================
    S            = struct();
    S.sp         = [];
    S.isConnected  = false;
    S.logFid     = -1;
    S.tickCount  = 0;
    S.totalBytes = 0;

    S.streamTimer   = [];
    S.rxBuf         = uint8([]);
    S.streamEnabled = false;

    S.parseState = 0;
    S.pktBuf     = zeros(5, 1, 'uint8');
    S.pktIdx     = 0;

    S.maxPoints  = 9000;
    S.nVec       = zeros(0,1);
    S.notchVec   = zeros(0,1);
    S.filtVec    = zeros(0,1);
    S.frameCount = 0;

    S.fs    = 1020;
    S.scale = 1000.0 / (21333.0 * 2.0 * 64.0);

    S.tWin  = 5000;          % ventana de display en ms (0 = todo)

    S.yAuto = true;  S.yMin = -100; S.yMax = 100;
    S.tAuto = true;  S.tMin = 0;    S.tMax = 5000;

    S.filtCmd = '';          % comando FIR (string)
    S.filtB   = [];          % coeficientes b (vacio = sin filtro)

    S.yRange  = 100;         % semi-rango actual del auto-zoom [mV]

    defCom  = 'COM7';
    defBaud = 115200;

    % =====================================================================
    % Cargar config previa
    % =====================================================================
    if isfile(cfgFile)
        try
            cfg = load(cfgFile);
            flds = {'fs','maxPoints','tWin','filtCmd','filtB','yRange',...
                    'yMin','yMax','yAuto','tMin','tMax','tAuto'};
            for k = 1:numel(flds)
                if isfield(cfg,flds{k}), S.(flds{k}) = cfg.(flds{k}); end
            end
            if isfield(cfg,'com'),  defCom  = cfg.com;  end
            if isfield(cfg,'baud'), defBaud = cfg.baud; end
        catch, end
    end

    % =====================================================================
    % UI  —  layout columna derecha (RX=860, RW=225):
    %   pConn  y=570 h=100
    %   pCtrl  y=490 h=78
    %   pFilt  y=400 h=88
    %   pData  y=295 h=103
    %   pZoom  y=110 h=183
    %   txtLog y=5   h=103
    % =====================================================================
    fig = uifigure('Name','Geophone Scope — FIR Notch','Position',[60 80 1100 680]);
    fig.CloseRequestFcn = @onClose;

    ax1 = uiaxes(fig,'Position',[20 55 820 590]);
    ax1.XGrid='on'; ax1.YGrid='on';
    ax1.XMinorGrid='on'; ax1.YMinorGrid='on';
    title(ax1,'Notch FIR — Salida final');
    ylabel(ax1,'mV'); xlabel(ax1,'tiempo (ms)');
    hNotch = plot(ax1, nan, nan, 'Color',[0 1 0.5]);

    RX=860; RW=225;

    % --- Conexion ---
    pConn = uipanel(fig,'Title','Conexion','Position',[RX 570 RW 100]);
    uilabel(pConn,'Text','COM:', 'Position',[8  70 32 20]);
    edtCom  = uieditfield(pConn,'text','Value',defCom,'Position',[44 68 58 22]);
    uilabel(pConn,'Text','Baud:','Position',[110 70 36 20]);
    edtBaud = uieditfield(pConn,'numeric','Value',defBaud,...
        'Limits',[1200 2000000],'Position',[150 68 60 22]);
    btnConn = uibutton(pConn,'Text','Conectar','Position',[8 36 90 26],...
        'ButtonPushedFcn',@onConnectToggle);
    lblStat = uilabel(pConn,'Text','DESCONECTADO','Position',[106 38 112 20]);

    % --- Stream ---
    pCtrl = uipanel(fig,'Title','Stream','Position',[RX 490 RW 78]);
    btnStart = uibutton(pCtrl,'Text','START','Position',[8 36 83 26],...
        'ButtonPushedFcn',@onStart);
    btnStop  = uibutton(pCtrl,'Text','STOP', 'Position',[100 36 83 26],...
        'ButtonPushedFcn',@onStop);
    btnClear = uibutton(pCtrl,'Text','Clear','Position',[8 6 83 24],...
        'ButtonPushedFcn',@onClear);

    % --- Filtro FIR ---
    pFilt = uipanel(fig,'Title','Filtro FIR MATLAB','Position',[RX 400 RW 88]);
    uilabel(pFilt,'Text','Cmd (retorna b):','Position',[8 58 140 18]);
    edtFiltCmd = uieditfield(pFilt,'text','Value',S.filtCmd,...
        'Position',[8 34 148 24]);
    btnApplyFilt = uibutton(pFilt,'Text','Aplicar','Position',[160 34 52 24],...
        'ButtonPushedFcn',@(~,~)onApplyFilter());
    btnQuitFilt  = uibutton(pFilt,'Text','Quitar FIR','Position',[160 6 52 22],...
        'ButtonPushedFcn',@(~,~)onQuitFilter());
    lblFiltSt = uilabel(pFilt,'Text',filtStatusStr(),...
        'Position',[8 6 148 22],'FontAngle','italic');

    % --- Datos ---
    pData = uipanel(fig,'Title','Datos','Position',[RX 295 RW 103]);
    lblInfo = uilabel(pData,'Text','n=0  t=0 ms',...
        'Position',[8 72 210 20]);
    uilabel(pData,'Text','fs(SPS):','Position',[8 46 52 20]);
    edtFs = uieditfield(pData,'numeric','Value',S.fs,...
        'Limits',[1 100000],'RoundFractionalValues','on',...
        'Position',[63 44 52 22],'ValueChangedFcn',@(~,~)onFsChanged());
    uilabel(pData,'Text','Vent(ms):','Position',[122 46 62 20]);
    edtTWin = uieditfield(pData,'numeric','Value',S.tWin,...
        'Limits',[0 1e8],'RoundFractionalValues','on',...
        'Position',[186 44 22 22],'ValueChangedFcn',@(~,~)onTWinChanged());
    btnExport = uibutton(pData,'Text','Export .mat','Position',[8 14 100 24],...
        'ButtonPushedFcn',@onExport);
    uilabel(pData,'Text','Max pts:','Position',[118 18 54 18]);
    edtMaxPts = uieditfield(pData,'numeric','Value',S.maxPoints,...
        'Limits',[100 1e6],'RoundFractionalValues','on',...
        'Position',[174 14 40 22],'ValueChangedFcn',@(~,~)onMaxPtsChanged());

    % --- Zoom ---
    pZoom = uipanel(fig,'Title','Zoom','Position',[RX 110 RW 183]);
    uilabel(pZoom,'Text','t (ms):','Position',[8 152 46 20]);
    uilabel(pZoom,'Text','min','Position',[58 152 25 20]);
    edtTMin = uieditfield(pZoom,'numeric','Value',S.tMin,...
        'Position',[82 150 56 22]);
    uilabel(pZoom,'Text','max','Position',[142 152 30 20]);
    edtTMax = uieditfield(pZoom,'numeric','Value',S.tMax,...
        'Position',[172 150 40 22]);
    btnApplyT = uibutton(pZoom,'Text','Aplicar t','Position',[8 120 90 26],...
        'ButtonPushedFcn',@(~,~)onApplyTZoom());
    btnTAuto  = uibutton(pZoom,'Text','t Auto',  'Position',[104 120 90 26],...
        'ButtonPushedFcn',@(~,~)onTZoomAuto());

    uilabel(pZoom,'Text','y (mV):','Position',[8 86 48 20]);
    uilabel(pZoom,'Text','min','Position',[58 86 25 20]);
    edtYMin = uieditfield(pZoom,'numeric','Value',S.yMin,...
        'Position',[82 84 56 22]);
    uilabel(pZoom,'Text','max','Position',[142 86 30 20]);
    edtYMax = uieditfield(pZoom,'numeric','Value',S.yMax,...
        'Position',[172 84 40 22]);
    btnApplyY = uibutton(pZoom,'Text','Aplicar y','Position',[8 54 90 26],...
        'ButtonPushedFcn',@(~,~)onApplyYZoom());
    btnYAuto  = uibutton(pZoom,'Text','y Auto',  'Position',[104 54 90 26],...
        'ButtonPushedFcn',@(~,~)onYZoomAuto());

    % Log
    txtLog = uitextarea(fig,'Editable','off','Position',[RX 5 RW 103]);
    txtLog.Value = strings(0,1);

    % Aplicar limites iniciales y feedback visual del modo y Auto
    if ~S.tAuto, try ax1.XLim=[S.tMin S.tMax]; catch, end; end
    if ~S.yAuto
        try ax1.YLim=[S.yMin S.yMax]; catch, end
    else
        btnYAuto.BackgroundColor = [0.55 0.90 0.55];
        btnYAuto.FontWeight = 'bold';
    end
    % Restaurar comando de filtro si habia coeficientes
    if ~isempty(S.filtB)
        edtFiltCmd.Value = S.filtCmd;
        lblFiltSt.Text   = filtStatusStr();
    end

    updateBtnStates();

    % =====================================================================
    % Helpers internos
    % =====================================================================
    function s = filtStatusStr()
        if isempty(S.filtB)
            s = 'Sin filtro activo';
        else
            s = sprintf('FIR N=%d activo', numel(S.filtB)-1);
        end
    end

    function logMsg(msg)
        ts   = string(datestr(now,'HH:MM:SS.FFF'));
        line = "["+ts+"] "+string(msg);
        v = txtLog.Value;
        if ~isstring(v), v=string(v); end
        v(end+1,1) = line;
        if numel(v)>300, v=v(end-299:end); end
        txtLog.Value = v;
        if S.logFid>0, fprintf(S.logFid,'%s\n',char(line)); end
        drawnow limitrate;
    end

    function logTick(nAvail)
        if S.logFid<=0, return; end
        if nAvail>0 || mod(S.tickCount,50)==0
            ts=datestr(now,'HH:MM:SS.FFF');
            fprintf(S.logFid,'[%s] TICK #%d  avail=%d  bytes=%d  ON=%d  ps=%d  pi=%d\n',...
                ts,S.tickCount,nAvail,S.totalBytes,S.streamEnabled,S.parseState,S.pktIdx);
        end
    end

    function logHex(raw)
        if S.logFid<=0, return; end
        n=min(numel(raw),40);
        h=sprintf('%02X ',raw(1:n));
        if numel(raw)>40, h=[h '...']; end
        fprintf(S.logFid,'  RAW[%d]: %s\n',numel(raw),h);
    end

    function logParsed(np)
        if S.logFid<=0||np==0, return; end
        fprintf(S.logFid,'  PARSED: %d\n',np);
    end

    function updateBtnStates()
        c=S.isConnected; r=S.streamEnabled;
        btnStart.Enable = c&&~r;
        btnStop.Enable  = c&& r;
        edtCom.Enable   = ~c;
        edtBaud.Enable  = ~c;
    end

    function updateInfo()
        try
            n=numel(S.nVec);
            lblInfo.Text=sprintf('n=%d  t=%.0f ms  fs=%d SPS',n,n/S.fs*1000,round(S.fs));
        catch, end
    end

    % --- Filtro ---
    function applyFilter()
        if isempty(S.notchVec), S.filtVec=zeros(0,1); return; end
        raw_mV = S.notchVec * S.scale;
        if isempty(S.filtB), S.filtVec=raw_mV; return; end
        minLen = 3*(numel(S.filtB)-1);
        if numel(raw_mV)<max(minLen,4), S.filtVec=raw_mV; return; end
        try
            S.filtVec = filtfilt(S.filtB, 1, raw_mV);
        catch
            S.filtVec = raw_mV;
        end
    end

    % --- Plot ---
    function replot()
        if isempty(S.nVec)||isempty(S.filtVec), return; end
        tms = double(S.nVec)/S.fs*1000.0;
        set(hNotch,'XData',tms,'YData',S.filtVec);
        if ~S.tAuto
            try ax1.XLim=[S.tMin S.tMax]; catch, end
        elseif S.tWin>0 && ~isempty(tms)
            ax1.XLim=[max(0,tms(end)-S.tWin), tms(end)];
        else
            ax1.XLimMode='auto';
        end
        if ~S.yAuto
            try ax1.YLim=[S.yMin S.yMax]; catch, end
        else
            % Auto-zoom suave centrado en 0 con histéresis
            % Expansión inmediata, contracción lenta (tau ≈ 660 ms a 20ms/tick)
            peak = max(abs(S.filtVec));
            if peak < 0.1, peak = 0.1; end
            target = peak * 1.25;
            if target > S.yRange
                S.yRange = target;                           % expansión inmediata
            else
                S.yRange = S.yRange * 0.97 + target * 0.03; % decaimiento suave
            end
            S.yRange = max(S.yRange, 1.0);                   % mínimo 1 mV
            try ax1.YLim = [-S.yRange, S.yRange]; catch, end
        end
    end

    % --- Config ---
    function saveConfig()
        try
            cfg.fs=S.fs; cfg.com=char(edtCom.Value); cfg.baud=double(edtBaud.Value);
            cfg.maxPoints=S.maxPoints; cfg.tWin=S.tWin;
            cfg.filtCmd=S.filtCmd; cfg.filtB=S.filtB;
            cfg.yRange=S.yRange;
            cfg.yMin=S.yMin; cfg.yMax=S.yMax; cfg.yAuto=S.yAuto;
            cfg.tMin=S.tMin; cfg.tMax=S.tMax; cfg.tAuto=S.tAuto;
            save(cfgFile,'-struct','cfg');
        catch, end
    end

    % =====================================================================
    % Callbacks de configuracion
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
        cmd = strtrim(char(edtFiltCmd.Value));
        if isempty(cmd), logMsg("Cmd vacio."); return; end
        try
            b = eval(cmd); %#ok<EVLEQ>
            if ~isnumeric(b)||numel(b)<2
                logMsg("ERROR: el comando debe retornar un vector numerico (b)."); return;
            end
            S.filtB   = b(:).';
            S.filtCmd = cmd;
            applyFilter();
            replot();
            saveConfig();
            lblFiltSt.Text = filtStatusStr();
            logMsg(sprintf('FIR aplicado — N=%d  (cmd: %s)',numel(b)-1,cmd));
        catch e
            logMsg("ERROR filtro: " + string(e.message));
        end
    end

    function onQuitFilter()
        S.filtB   = [];
        S.filtCmd = '';
        applyFilter();
        replot();
        saveConfig();
        lblFiltSt.Text = filtStatusStr();
        logMsg("Filtro FIR desactivado.");
    end

    function onApplyTZoom()
        S.tMin=edtTMin.Value; S.tMax=edtTMax.Value; S.tAuto=false;
        replot(); saveConfig();
    end

    function onApplyYZoom()
        S.yMin=edtYMin.Value; S.yMax=edtYMax.Value; S.yAuto=false;
        btnYAuto.BackgroundColor = [0.94 0.94 0.94];
        btnYAuto.FontWeight = 'normal';
        replot(); saveConfig();
    end

    function onTZoomAuto()
        S.tAuto=true; ax1.XLimMode='auto'; replot(); saveConfig();
    end

    function onYZoomAuto()
        S.yAuto=true;
        % Inicializar yRange al pico actual para evitar salto brusco al activar
        if ~isempty(S.filtVec)
            peak=max(abs(S.filtVec));
            S.yRange=max(peak*1.25, 1.0);
        end
        btnYAuto.BackgroundColor = [0.55 0.90 0.55];
        btnYAuto.FontWeight = 'bold';
        replot(); saveConfig();
    end

    % =====================================================================
    % Conexion
    % =====================================================================
    function onConnectToggle(~,~)
        if ~S.isConnected
            com=strtrim(string(edtCom.Value));
            baud=double(edtBaud.Value);
            if com=="", logMsg("COM vacio."); return; end
            try
                S.sp=serialport(com,baud); S.sp.Timeout=0.05;
                flush(S.sp); pause(0.05);
                S.isConnected=true; S.streamEnabled=false;
                S.rxBuf=uint8([]); S.parseState=0;
                lname=fullfile(scriptDir,sprintf('scope_%s.log',datestr(now,'yyyymmdd_HHMMSS')));
                S.logFid=fopen(lname,'w');
                if S.logFid>0
                    fprintf(S.logFid,'=== geophone_scope_simple — %s ===\n',datestr(now));
                end
                btnConn.Text='Desconectar'; lblStat.Text='CONECTADO: '+com;
                logMsg("Conectado "+com+" @ "+string(baud));
                saveConfig(); startStreamTimer();
            catch e
                S.sp=[]; S.isConnected=false;
                logMsg("Error: "+string(e.message));
            end
        else
            stopStreamTimer();
            try
                if ~isempty(S.sp), try flush(S.sp);catch,end; delete(S.sp); end
            catch,end
            logMsg("Desconectado.");
            if S.logFid>0, try fclose(S.logFid);catch,end; S.logFid=-1; end
            S.sp=[]; S.isConnected=false; S.streamEnabled=false;
            btnConn.Text='Conectar'; lblStat.Text='DESCONECTADO';
            saveConfig();
        end
        updateBtnStates();
    end

    % =====================================================================
    % Start / Stop / Clear
    % =====================================================================
    function onStart(~,~)
        if ~S.isConnected, logMsg("No conectado."); return; end
        S.rxBuf=uint8([]); S.parseState=0;
        S.pktBuf=zeros(5,1,'uint8'); S.pktIdx=0;
        S.streamEnabled=true;
        logMsg("--- Stream ON ---"); updateBtnStates();
    end

    function onStop(~,~)
        S.streamEnabled=false; logMsg("--- Stream OFF ---"); updateBtnStates();
    end

    function onClear(~,~)
        S.notchVec=[]; S.filtVec=[]; S.nVec=[]; S.frameCount=0;
        set(hNotch,'XData',nan,'YData',nan);
        ax1.XLimMode='auto'; ax1.YLimMode='auto';
        updateInfo(); logMsg("Datos borrados.");
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
    % Tick principal — 20 ms
    % =====================================================================
    function onStreamTick(~,~)
        if ~S.isConnected||isempty(S.sp), return; end
        S.tickCount=S.tickCount+1;
        nAvail=S.sp.NumBytesAvailable;
        logTick(nAvail);
        if nAvail<=0, return; end

        try, raw=read(S.sp,nAvail,"uint8");
        catch e
            if S.logFid>0
                fprintf(S.logFid,'[%s] ERR read: %s\n',datestr(now,'HH:MM:SS.FFF'),e.message);
            end; return;
        end
        if isempty(raw), return; end

        S.totalBytes=S.totalBytes+numel(raw);
        logHex(raw);
        if ~S.streamEnabled, return; end

        S.rxBuf=[S.rxBuf; uint8(raw(:))];
        newNotch=zeros(0,1);
        i=1; n=numel(S.rxBuf);

        while i<=n
            b=S.rxBuf(i);
            if S.parseState==0
                if b==uint8(0x56)
                    S.pktBuf(1)=b; S.pktIdx=1; S.parseState=1;
                end
                i=i+1;
            else
                S.pktIdx=S.pktIdx+1;
                S.pktBuf(S.pktIdx)=b;
                i=i+1;
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

        S.rxBuf=uint8([]);
        logParsed(numel(newNotch));
        if isempty(newNotch), return; end

        nNew=numel(newNotch);
        nIdx=(S.frameCount+1:S.frameCount+nNew).';
        S.notchVec=[S.notchVec; newNotch];
        S.nVec    =[S.nVec;     nIdx    ];
        S.frameCount=S.frameCount+nNew;

        if numel(S.nVec)>S.maxPoints
            k0=numel(S.nVec)-S.maxPoints+1;
            S.notchVec=S.notchVec(k0:end);
            S.nVec    =S.nVec    (k0:end);
        end

        applyFilter();
        replot();
        updateInfo();
        drawnow limitrate;
    end

    % =====================================================================
    % Export
    % =====================================================================
    function onExport(~,~)
        if isempty(S.nVec), logMsg("No hay datos."); return; end
        [file,path]=uiputfile('*.mat','Guardar','geophone_data.mat');
        if isequal(file,0), logMsg("Cancelado."); return; end
        data=struct('n',S.nVec,'notch',S.notchVec,'filtered',S.filtVec,...
            'frameCount',S.frameCount,'fs',S.fs,'scale',S.scale,...
            'filtCmd',S.filtCmd,'filtB',S.filtB,'timestamp',datestr(now));
        save(fullfile(path,file),'-struct','data');
        logMsg("Export: "+string(fullfile(path,file)));
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
        saveConfig();
        delete(fig);
    end

end
