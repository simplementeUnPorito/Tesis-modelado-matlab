model_dir = fileparts(mfilename('fullpath'));
S = load(fullfile(model_dir, 'DesacopleLin.mat'), "LinearAnalysisToolProject");
model = S.LinearAnalysisToolProject.Results(1).Data.Value;
