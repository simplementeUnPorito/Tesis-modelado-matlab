function monitor_slave(port, baud)
% MONITOR_SLAVE  Lee y muestra el serial del esclavo ESP8266 en tiempo real.
%
%   monitor_slave()          → COM3, 115200
%   monitor_slave('COM4')    → COM4, 115200
%   monitor_slave('COM4', 9600)
%
% Cierra la ventana o presiona Ctrl+C para salir.

if nargin < 1, port = 'COM3'; end
if nargin < 2, baud = 115200; end

LOG_FILE = fullfile(fileparts(mfilename('fullpath')), ...
    sprintf('slave_%s_%s.log', strrep(port,':',''), datestr(now,'yyyymmdd_HHMMSS')));

fprintf('=== Monitor Esclavo ===\n');
fprintf('Puerto : %s @ %d\n', port, baud);
fprintf('Log    : %s\n', LOG_FILE);
fprintf('Cierra la figura o Ctrl+C para salir.\n\n');

% ── Abrir puerto ───────────────────────────────────────────────────────────
s = serialport(port, baud, 'Timeout', 1);
configureTerminator(s, "LF");
flush(s);

% ── Figura con botón Stop ──────────────────────────────────────────────────
fig = figure('Name', sprintf('Slave %s', port), ...
             'NumberTitle', 'off', ...
             'MenuBar',     'none', ...
             'Position',    [100 100 700 500]);
ax  = axes(fig, 'Visible', 'off');           %#ok<NASGU>
txt = uicontrol(fig, 'Style', 'listbox', ...
    'Units',    'normalized', ...
    'Position', [0 0.1 1 0.9], ...
    'FontName', 'Courier New', ...
    'FontSize', 9, ...
    'String',   {}, ...
    'Max',      2);                          % multiselect = scrollable
btnStop = uicontrol(fig, 'Style', 'pushbutton', ...
    'String',   'Detener', ...
    'Units',    'normalized', ...
    'Position', [0.4 0.01 0.2 0.07], ...
    'Callback', @(~,~) close(fig));

lines  = {};
fid    = fopen(LOG_FILE, 'w');
lineBuf = '';
running = true;

cleanObj = onCleanup(@() cleanup(s, fid, LOG_FILE));

% ── Loop principal ─────────────────────────────────────────────────────────
while running && ishandle(fig)
    try
        % Leer todos los bytes disponibles (no bloquea más de Timeout seg)
        nb = s.NumBytesAvailable;
        if nb > 0
            raw = read(s, nb, 'uint8');
            for k = 1:numel(raw)
                c = char(raw(k));
                if c == newline || c == char(13)
                    if ~isempty(strtrim(lineBuf))
                        stamp = datestr(now, 'HH:MM:SS.FFF');
                        msg   = sprintf('[%s] %s', stamp, lineBuf);
                        lines{end+1} = msg;  %#ok<AGROW>
                        fprintf('%s\n', msg);
                        fprintf(fid, '%s\n', msg);
                        % Mantener últimas 500 líneas en el listbox
                        if numel(lines) > 500
                            lines = lines(end-499:end);
                        end
                        set(txt, 'String', lines, 'Value', numel(lines));
                    end
                    lineBuf = '';
                else
                    lineBuf = [lineBuf c];  %#ok<AGROW>
                end
            end
        else
            pause(0.05);
        end
        drawnow limitrate;
    catch ME
        if contains(ME.message, 'closed') || ~ishandle(fig)
            break;
        end
        warning('monitor_slave: %s', ME.message);
        pause(0.1);
    end
end

% ── Limpieza ───────────────────────────────────────────────────────────────
function cleanup(s_, fid_, logf)
    try, delete(s_); catch, end
    try, fclose(fid_); catch, end
    fprintf('\nLog guardado en: %s\n', logf);
end

end
