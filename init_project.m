function project_root = init_project()
%INIT_PROJECT Configura el path del proyecto Tesis para MATLAB.
%
% Agrega al path:
%   - src/matlab
%   - third_party/MASW-Matlab-code
%
% Devuelve:
%   project_root -> ruta absoluta a la raíz del proyecto

    % Ruta absoluta de este archivo
    this_file = mfilename('fullpath');
    this_dir  = fileparts(this_file);

    % this_dir = .../Tesis/src/matlab
    % subir dos niveles hasta .../Tesis
    project_root = fileparts(fileparts(this_dir));

    matlab_src = fullfile(project_root, 'src', 'matlab');
    masw_path  = fullfile(project_root, 'third_party', 'MASW-Matlab-code');

    % Verificaciones mínimas
    if ~isfolder(matlab_src)
        error('init_project:MissingFolder', ...
            'No existe la carpeta MATLAB esperada: %s', matlab_src);
    end

    if ~isfolder(masw_path)
        warning('init_project:MissingThirdParty', ...
            'No existe la carpeta third_party esperada: %s', masw_path);
    end

    % Agregar paths evitando duplicación innecesaria
    addpath(genpath(matlab_src));

    if isfolder(masw_path)
        addpath(genpath(masw_path));
    end

    fprintf('Proyecto inicializado correctamente.\n');
    fprintf('Root: %s\n', project_root);
    fprintf('MATLAB src: %s\n', matlab_src);

    if isfolder(masw_path)
        fprintf('Third party: %s\n', masw_path);
    end
end
