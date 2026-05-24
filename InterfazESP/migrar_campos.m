% migrar_campos.m
% Agrega campos de metadata estructurada a todos los .mat en datos\.
%
% Campos nuevos por medición:
%   distancia        (double, NaN si no se puede parsear)
%   unidad           (char,   ''  si no se puede parsear)
%   ganancia_pga     (double, NaN si no se puede parsear)
%   tipo_dato        (char,   ''  — 'crudo' | 'filtrado hardware')
%   secuencia_inicio_s (double, NaN — para marcar_secuencia.m)
%   periodo_estimado_s (double, NaN — para marcar_secuencia.m)
%
% Parser de observ:
%   distancia  ← patrón "(\d+(?:\.\d+)?)\s*pasos"
%   pga        ← patrón "PGA\s*(\d+)"
%   tipo_dato  ← patrón "(crudo|filtrado\s*hardware|filtrado\s*hw)"
%
% Corre en modo DRY-RUN por defecto (muestra cambios sin guardar).
% Confirmar con 's' para guardar.

clc;

scriptDir = fileparts(mfilename('fullpath'));
datosDir  = fullfile(scriptDir, 'datos');

archivos = dir(fullfile(datosDir, '*.mat'));
if isempty(archivos)
    fprintf('No hay .mat en %s\n', datosDir); return
end

% Orden de campos de muestras (consistente para MATLAB struct arrays)
CAMPOS_ORDEN = {'raw_V','filtered','fs','filtCmd','filtB','dcRemove', ...
    'punta','timestamp','observ', ...
    'distancia','unidad','ganancia_pga','tipo_dato', ...
    'secuencia_inicio_s','periodo_estimado_s'};

fprintf('=== MIGRAR CAMPOS ===\n');
fprintf('Directorio: %s\n\n', datosDir);

% =========================================================================
%% Análisis (dry-run)
% =========================================================================
cambios_total = 0;
for af = 1:numel(archivos)
    fname = archivos(af).name;
    fpath = fullfile(datosDir, fname);
    d = load(fpath);
    if ~isfield(d,'muestras'), continue; end
    N = numel(d.muestras);
    fprintf('--- %s  (%d mediciones) ---\n', fname, N);
    for i = 1:N
        m   = d.muestras(i);
        obs = '';
        if isfield(m,'observ'), obs = m.observ; end

        [dist, und, pga, tipo] = parsearObserv(obs);

        campos_nuevos = {'distancia','unidad','ganancia_pga','tipo_dato', ...
            'secuencia_inicio_s','periodo_estimado_s'};
        vals_nuevos   = {dist, und, pga, tipo, NaN, NaN};

        linea = sprintf('  #%d', i);
        if isfield(m,'punta') && ~isempty(m.punta)
            linea = [linea sprintf('  punta=%-6s', m.punta)]; %#ok<AGROW>
        end
        linea = [linea sprintf('  obs="%s"', obs)]; %#ok<AGROW>

        parts = {};
        for ci = 1:numel(campos_nuevos)
            cn = campos_nuevos{ci};
            vn = vals_nuevos{ci};
            ya_existe = isfield(m, cn);
            if isnumeric(vn)
                if ~isnan(vn)
                    parts{end+1} = sprintf('%s=%.4g', cn, vn); %#ok<AGROW>
                elseif ~ya_existe
                    parts{end+1} = sprintf('%s=NaN', cn); %#ok<AGROW>
                end
            elseif ischar(vn) && ~isempty(vn)
                parts{end+1} = sprintf('%s="%s"', cn, vn); %#ok<AGROW>
            elseif ~ya_existe
                parts{end+1} = sprintf('%s=""', cn); %#ok<AGROW>
            end
        end
        if ~isempty(parts)
            fprintf('%s\n    → %s\n', linea, strjoin(parts, '  '));
            cambios_total = cambios_total + 1;
        else
            fprintf('%s  (sin cambios nuevos)\n', linea);
        end
    end
    fprintf('\n');
end

fprintf('Total mediciones con cambios: %d\n', cambios_total);
fprintf('\nEscribir ''s'' para guardar, cualquier otra cosa cancela.\n');
resp = strtrim(input('Guardar? [s/N]: ', 's'));
if ~strcmpi(resp, 's')
    fprintf('Cancelado. No se modificó nada.\n');
    return
end

% =========================================================================
%% Guardar
% =========================================================================
fprintf('\nGuardando...\n');
for af = 1:numel(archivos)
    fname = archivos(af).name;
    fpath = fullfile(datosDir, fname);
    d = load(fpath);
    if ~isfield(d,'muestras'), continue; end
    N = numel(d.muestras);

    nuevas = [];
    for i = 1:N
        m   = d.muestras(i);
        obs = '';
        if isfield(m,'observ'), obs = m.observ; end

        [dist, und, pga, tipo] = parsearObserv(obs);

        % Rellenar campos que faltan
        if ~isfield(m,'distancia'),          m.distancia          = dist;  end
        if ~isfield(m,'unidad'),             m.unidad             = und;   end
        if ~isfield(m,'ganancia_pga'),       m.ganancia_pga       = pga;   end
        if ~isfield(m,'tipo_dato'),          m.tipo_dato          = tipo;  end
        if ~isfield(m,'secuencia_inicio_s'), m.secuencia_inicio_s = NaN;   end
        if ~isfield(m,'periodo_estimado_s'), m.periodo_estimado_s = NaN;   end

        % Compat: si viene raw_mV convertir a raw_V
        if isfield(m,'raw_mV') && ~isfield(m,'raw_V')
            m.raw_V = double(m.raw_mV(:))' / 1000;
            m = rmfield(m, 'raw_mV');
        end

        % Reconstruir con orden de campos consistente
        m_nuevo = struct();
        for ci = 1:numel(CAMPOS_ORDEN)
            cn = CAMPOS_ORDEN{ci};
            if isfield(m, cn)
                m_nuevo.(cn) = m.(cn);
            else
                % Campo esperado pero no presente: valor por defecto
                switch cn
                    case {'distancia','ganancia_pga','secuencia_inicio_s','periodo_estimado_s'}
                        m_nuevo.(cn) = NaN;
                    case {'unidad','tipo_dato','filtCmd','punta','timestamp','observ'}
                        m_nuevo.(cn) = '';
                    case 'dcRemove'
                        m_nuevo.(cn) = false;
                    case {'fs'}
                        m_nuevo.(cn) = 0;
                    case {'raw_V','filtered','filtB'}
                        m_nuevo.(cn) = [];
                end
            end
        end

        if isempty(nuevas)
            nuevas = m_nuevo;
        else
            nuevas(end+1) = m_nuevo; %#ok<AGROW>
        end
    end

    d.muestras = nuevas;
    save(fpath, '-struct', 'd');
    fprintf('  Guardado: %s  (%d mediciones)\n', fname, N);
end
fprintf('\nMigración completada.\n');

% =========================================================================
%% Funciones locales
% =========================================================================
function [dist, und, pga, tipo] = parsearObserv(obs)
    dist = NaN;
    und  = '';
    pga  = NaN;
    tipo = '';
    if isempty(obs), return; end

    tok = regexpi(obs, '(\d+(?:\.\d+)?)\s*pasos', 'tokens', 'once');
    if ~isempty(tok)
        dist = str2double(tok{1});
        und  = 'pasos';
    end

    tok = regexpi(obs, 'PGA\s*(\d+)', 'tokens', 'once');
    if ~isempty(tok)
        pga = str2double(tok{1});
    end

    tok = regexpi(obs, '(crudo|filtrado\s*hardware|filtrado\s*hw)', 'tokens', 'once');
    if ~isempty(tok)
        tipo = lower(strtrim(regexprep(tok{1}, '\s+', ' ')));
        tipo = strrep(tipo, 'filtrado hw', 'filtrado hardware');
    end
end
