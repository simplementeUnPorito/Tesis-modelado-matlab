function results = analizar_barridos_cadena_analogica(dataRoot, outputRoot)
%ANALIZAR_BARRIDOS_CADENA_ANALOGICA Identifica BP, SUM y LP desde CSV Tektronix.
%
% Canales:
%   CH1 = PGA, CH2 = BP, CH3 = SUMMING OPA, CH4 = LP
%
% Transferencias estimadas:
%   BP  = CH2 / CH1
%   SUM = CH3 / (CH2/8.2e3 + CH1/7.5e3)
%   LP  = CH4 / CH3
%
% El programa admite varias capturas por carpeta (F0000, F0001, ...),
% combina las bandas solapadas y ajusta modelos continuos con TFEST.

scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(fileparts(scriptDir)));

if nargin < 1 || strlength(string(dataRoot)) == 0
    dataRoot = fullfile(projectRoot, 'Crudos', 'Osciloscopio');
end
if nargin < 2 || strlength(string(outputRoot)) == 0
    outputRoot = fullfile(scriptDir, 'resultados_barridos');
end

dataRoot = char(dataRoot);
outputRoot = char(outputRoot);
assert(isfolder(dataRoot), 'No existe la carpeta de datos: %s', dataRoot);
if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

cfg = defaultConfig();
captures = discoverCaptures(dataRoot);
assert(~isempty(captures), 'No se encontraron juegos *CH1.CSV ... *CH4.CSV.');

stageNames = {'BP', 'SUM', 'LP'};
raw = emptyRaw(stageNames);
healthRows = repmat(emptyHealthRow(), 0, 1);

fprintf('Procesando %d captura(s) en %s\n\n', numel(captures), dataRoot);
for k = 1:numel(captures)
    cap = readCapture(captures(k), cfg);
    healthRows(end+1, 1) = cap.health; %#ok<AGROW>

    fprintf('%-14s %-7s  fs=%-9.4g Hz  valido=%5.1f %%  recorte=%5.2f %%\n', ...
        cap.band, cap.captureId, cap.fs, 100*cap.health.ValidFraction, ...
        100*cap.health.ClipFraction);

    z = cap.signals - mean(cap.signals, 1);
    inputs = {z(:,1), cfg.WP_BP*z(:,2) + cfg.WP_U*z(:,1), z(:,3)};
    outputs = {z(:,2), z(:,3), z(:,4)};

    for s = 1:numel(stageNames)
        est = estimateChirpFrf(cap.time, inputs{s}, outputs{s}, ...
            cap.fStart, cap.fStop, cfg);
        est.band = repmat(string(cap.band), numel(est.f), 1);
        est.capture = repmat(string(cap.captureId), numel(est.f), 1);
        raw.(stageNames{s}) = appendEstimate(raw.(stageNames{s}), est);
    end
end

healthTable = struct2table(healthRows);
writetable(healthTable, fullfile(outputRoot, 'salud_capturas.csv'));

ideal = idealModels();
orders = struct('BP', [2 1], 'SUM', [1 0], 'LP', [2 0]);
fitRanges = struct('BP', [0 Inf], 'SUM', [0 2e4], 'LP', [0 2e4]);
summaryRows = repmat(emptySummaryRow(), 0, 1);

for s = 1:numel(stageNames)
    name = stageNames{s};
    stitched = stitchFrf(raw.(name), cfg);
    inRange = stitched.f >= fitRanges.(name)(1) & stitched.f <= fitRanges.(name)(2);
    fitMask = inRange & stitched.coherence >= cfg.minFitCoherence;
    if nnz(fitMask) < cfg.minFitPoints
        warning('%s: sólo %d puntos superan el umbral de coherencia; se usarán los mejores.', ...
            name, nnz(fitMask));
        candidates = find(inRange);
        [~, order] = sort(stitched.coherence(candidates), 'descend');
        keep = candidates(order(1:min(cfg.minFitPoints, numel(order))));
        fitMask = false(size(inRange));
        fitMask(keep) = true;
    end

    model = fitContinuousModel(stitched, fitMask, orders.(name));
    metrics = stageMetrics(name, stitched, fitMask, model, ideal);
    summaryRows(end+1, 1) = metrics; %#ok<AGROW>

    results.frf.(name) = stitched;
    results.models.(name) = model;
    plotStage(name, stitched, model, ideal, outputRoot);
end

results.raw = raw;
results.ideal = ideal;
results.captureHealth = healthTable;
results.summary = struct2table(summaryRows);
results.config = cfg;
results.dataRoot = dataRoot;
results.outputRoot = outputRoot;

writetable(results.summary, fullfile(outputRoot, 'resumen_identificacion.csv'));
writeModelReport(results, fullfile(outputRoot, 'modelos_identificados.txt'));
save(fullfile(outputRoot, 'identificacion_cadena_analogica.mat'), 'results');

fprintf('\nResultados guardados en %s\n', outputRoot);
disp(results.summary);
end

function cfg = defaultConfig()
cfg.WP_U = 1/7.5e3;
cfg.WP_BP = 1/8.2e3;
cfg.pointsPerDecade = 18;
cfg.stitchPointsPerDecade = 14;
cfg.edgeFraction = 0.06;
cfg.phaseSmoothSamples = 101;
cfg.minSamplesPerBin = 8;
cfg.minMissingRun = 8;
cfg.minSegmentSamples = 200;
cfg.minInputEnvelope = 0.12;
cfg.minFitCoherence = 0.70;
cfg.minFitPoints = 10;
end

function captures = discoverCaptures(dataRoot)
ch1 = dir(fullfile(dataRoot, '*', '*CH1.CSV'));
captures = repmat(struct('band','', 'captureId','', 'folder','', ...
    'files',{{}}, 'fStart',NaN, 'fStop',NaN), 0, 1);

for k = 1:numel(ch1)
    [~, bandBase, bandExt] = fileparts(ch1(k).folder);
    band = [bandBase bandExt];
    [fStart, fStop] = parseBandName(band);
    if ~isfinite(fStart) || ~isfinite(fStop)
        warning('Se omite la carpeta sin rango reconocible: %s', band);
        continue;
    end

    captureId = extractBefore(string(ch1(k).name), 'CH1.CSV');
    files = cell(1,4);
    complete = true;
    for channel = 1:4
        files{channel} = fullfile(ch1(k).folder, ...
            sprintf('%sCH%d.CSV', captureId, channel));
        complete = complete && isfile(files{channel});
    end
    if ~complete
        warning('Se omite %s/%s porque faltan canales.', band, captureId);
        continue;
    end

    row = struct('band',band, 'captureId',char(captureId), ...
        'folder',ch1(k).folder, 'files',{files}, ...
        'fStart',fStart, 'fStop',fStop);
    captures(end+1,1) = row; %#ok<AGROW>
end

if ~isempty(captures)
    [~, idx] = sortrows([[captures.fStart].', [captures.fStop].']);
    captures = captures(idx);
end
end

function cap = readCapture(info, cfg)
time = [];
signals = [];
meta = repmat(struct('verticalScale',NaN, 'verticalOffset',NaN), 1, 4);

for channel = 1:4
    [t, y, meta(channel)] = readTekCsv(info.files{channel});
    if channel == 1
        time = t;
        signals = zeros(numel(t), 4);
    else
        assert(numel(t) == numel(time) && max(abs(t-time)) < 1e-9*max(1,rangeLocal(time)), ...
            'Los tiempos no coinciden entre canales en %s.', info.folder);
    end
    signals(:,channel) = y;
end

atFloor = true(size(time));
atCeiling = false(size(time));
for channel = 1:4
    scale = meta(channel).verticalScale;
    offset = meta(channel).verticalOffset;
    floorValue = -5.12*scale - offset;
    ceilingValue = 5.08*scale - offset;
    tolerance = max(1e-12, scale*1e-6);
    atFloor = atFloor & abs(signals(:,channel)-floorValue) <= tolerance;
    atCeiling = atCeiling | abs(signals(:,channel)-ceilingValue) <= tolerance;
end

missing = keepLongRuns(atFloor, cfg.minMissingRun);
validRuns = logicalRuns(~missing);
runLengths = validRuns(:,2)-validRuns(:,1)+1;
validRuns = validRuns(runLengths >= cfg.minSegmentSamples,:);
assert(~isempty(validRuns), 'No hay un segmento válido suficientemente largo en %s.', info.folder);
[~, longest] = max(validRuns(:,2)-validRuns(:,1));
idx = (validRuns(longest,1):validRuns(longest,2)).';

time = time(idx);
signals = signals(idx,:);
time = time-time(1);
dt = median(diff(time));

clip = false(size(time));
for channel = 1:4
    scale = meta(channel).verticalScale;
    offset = meta(channel).verticalOffset;
    floorValue = -5.12*scale-offset;
    ceilingValue = 5.08*scale-offset;
    tolerance = max(1e-12, scale*1e-6);
    clip = clip | abs(signals(:,channel)-floorValue) <= tolerance | ...
        abs(signals(:,channel)-ceilingValue) <= tolerance;
end

health = emptyHealthRow();
health.Band = string(info.band);
health.Capture = string(info.captureId);
health.SampleRateHz = 1/dt;
health.DurationS = time(end)-time(1);
health.ValidFraction = numel(idx)/numel(missing);
health.InvalidCodeFraction = mean(missing);
health.DiscardedFraction = 1-health.ValidFraction;
health.ClipFraction = mean(clip | atCeiling(idx));
health.StartFrequencyHz = info.fStart;
health.StopFrequencyHz = info.fStop;

cap = struct('band',info.band, 'captureId',info.captureId, ...
    'fStart',info.fStart, 'fStop',info.fStop, 'time',time, ...
    'signals',signals, 'fs',1/dt, 'health',health);
end

function [time, signal, meta] = readTekCsv(filename)
A = readmatrix(filename, 'Delimiter', ',');
assert(size(A,2) >= 5, 'Formato CSV Tektronix no reconocido: %s', filename);
valid = isfinite(A(:,4)) & isfinite(A(:,5));
time = A(valid,4);
signal = A(valid,5);

rawText = fileread(filename);
meta.verticalScale = readMetadataNumber(rawText, 'Vertical Scale');
meta.verticalOffset = readMetadataNumber(rawText, 'Vertical Offset');
assert(isfinite(meta.verticalScale) && isfinite(meta.verticalOffset), ...
    'No se pudo leer la escala vertical de %s.', filename);
end

function value = readMetadataNumber(rawText, label)
token = regexp(rawText, [regexptranslate('escape', label) ',([^,\r\n]+)'], ...
    'tokens', 'once');
if isempty(token)
    value = NaN;
else
    value = str2double(token{1});
end
end

function est = estimateChirpFrf(time, inputSignal, outputSignal, fStart, fStop, cfg)
u = inputSignal(:)-mean(inputSignal, 'omitnan');
y = outputSignal(:)-mean(outputSignal, 'omitnan');
dt = median(diff(time));

ua = hilbert(u);
ya = hilbert(y);
phase = unwrap(angle(ua));
smoothLength = min(cfg.phaseSmoothSamples, 2*floor((numel(phase)-1)/2)+1);
if mod(smoothLength,2) == 0
    smoothLength = smoothLength-1;
end
smoothLength = max(5, smoothLength);
phase = sgolayfilt(phase, min(3,smoothLength-2), smoothLength);
instantFrequency = gradient(phase, dt)/(2*pi);
instantFrequency = smoothdata(instantFrequency, 'movmedian', ...
    min(31, 2*floor((numel(phase)-1)/2)+1));

edge = ceil(cfg.edgeFraction*numel(u));
usable = true(size(u));
usable(1:edge) = false;
usable(end-edge+1:end) = false;
envelopeThreshold = cfg.minInputEnvelope*median(abs(ua(usable)));
usable = usable & abs(ua) >= envelopeThreshold & ...
    instantFrequency >= 0.75*fStart & instantFrequency <= 1.25*fStop;

decades = log10(fStop/fStart);
nBins = max(4, ceil(cfg.pointsPerDecade*decades));
edges = logspace(log10(fStart), log10(fStop), nBins+1);

f = NaN(nBins,1);
response = NaN(nBins,1);
coherence = NaN(nBins,1);
excitation = NaN(nBins,1);
uRms = sqrt(mean(abs(ua(usable)).^2));

for k = 1:nBins
    mask = usable & instantFrequency >= edges(k) & instantFrequency < edges(k+1);
    if nnz(mask) < cfg.minSamplesPerBin
        continue;
    end
    crossPower = sum(ya(mask).*conj(ua(mask)));
    inputPower = sum(abs(ua(mask)).^2);
    outputPower = sum(abs(ya(mask)).^2);
    f(k) = sum(instantFrequency(mask).*abs(ua(mask)).^2)/inputPower;
    response(k) = crossPower/inputPower;
    coherence(k) = min(1, abs(crossPower)^2/max(eps,inputPower*outputPower));
    excitation(k) = median(abs(ua(mask)))/max(eps,uRms);
end

keep = isfinite(f) & isfinite(response) & isfinite(coherence);
est = struct('f',f(keep), 'response',response(keep), ...
    'coherence',coherence(keep), 'excitation',excitation(keep), ...
    'band',strings(nnz(keep),1), 'capture',strings(nnz(keep),1));
end

function stitched = stitchFrf(raw, cfg)
valid = isfinite(raw.f) & isfinite(raw.response) & raw.f > 0 & ...
    raw.excitation >= cfg.minInputEnvelope;
f = raw.f(valid);
h = raw.response(valid);
c = raw.coherence(valid);
e = raw.excitation(valid);
assert(~isempty(f), 'No quedaron puntos espectrales válidos.');

nBins = max(4, ceil(cfg.stitchPointsPerDecade*log10(max(f)/min(f))));
edges = logspace(log10(min(f)), log10(max(f)), nBins+1);
outF = NaN(nBins,1);
outH = NaN(nBins,1);
outC = NaN(nBins,1);
outSpread = NaN(nBins,1);
outCount = zeros(nBins,1);

for k = 1:nBins
    mask = f >= edges(k) & f < edges(k+1);
    if ~any(mask)
        continue;
    end
    weights = max(0.02,c(mask)).^2 .* min(2,e(mask));
    outF(k) = exp(sum(weights.*log(f(mask)))/sum(weights));
    outH(k) = sum(weights.*h(mask))/sum(weights);
    outC(k) = sum(weights.*c(mask))/sum(weights);
    outSpread(k) = sqrt(sum(weights.*(20*log10(abs(h(mask)./outH(k)))).^2)/sum(weights));
    outCount(k) = nnz(mask);
end

keep = isfinite(outF) & isfinite(outH);
stitched = struct('f',outF(keep), 'response',outH(keep), ...
    'coherence',outC(keep), 'spreadDb',outSpread(keep), ...
    'count',outCount(keep));
end

function model = fitContinuousModel(stitched, mask, order)
frequency = 2*pi*stitched.f(mask);
response = reshape(stitched.response(mask), 1, 1, []);
data = idfrd(response, frequency, 0);
options = tfestOptions('Display', 'off');
options.EnforceStability = true;
model = tfest(data, order(1), order(2), options);
end

function ideal = idealModels()
Rin_bp = 43e3;
Rf_bp = 43e3;
Cf_bp = 177e-12;

ideal.BP_680uF = makeBp(Rin_bp, Rf_bp, 680e-6, Cf_bp);
ideal.BP_680nF = makeBp(Rin_bp, Rf_bp, 680e-9, Cf_bp);
ideal.SUM = tf(12e3, [27e3*15e-9 1]);

R1_lp = 30e3;
R2_lp = 150e3;
R3_lp = 12e3;
C1_lp = 47e-9;
C2_lp = 3.3e-9;
ideal.LP = tf(-(R2_lp/R1_lp), ...
    [R2_lp*R3_lp*C1_lp*C2_lp, ...
     C2_lp*(R2_lp+R3_lp+R2_lp*R3_lp/R1_lp), 1]);
end

function model = makeBp(Rin, Rf, Cin, Cf)
model = tf([-Rf*Cin 0], ...
    [Rin*Rf*Cin*Cf, Rin*Cin+Rf*Cf, 1]);
end

function metrics = stageMetrics(name, stitched, mask, model, ideal)
f = stitched.f(mask);
h = stitched.response(mask);
hm = responseAt(model, f);
[fitMag, fitPhase] = responseErrors(h, hm);

metrics = emptySummaryRow();
metrics.Stage = string(name);
metrics.PointsUsed = nnz(mask);
metrics.MinFrequencyHz = min(f);
metrics.MaxFrequencyHz = max(f);
metrics.MedianCoherence = median(stitched.coherence(mask));
metrics.TfestMagnitudeRmseDb = fitMag;
metrics.TfestPhaseRmseDeg = fitPhase;
poles = pole(model);
poleFrequencies = sort(abs(poles)/(2*pi));
metrics.IdentifiedF1Hz = poleFrequencies(1);
if numel(poleFrequencies) > 1
    metrics.IdentifiedF2Hz = poleFrequencies(end);
end
if numel(poles) == 2 && any(abs(imag(poles)) > 0)
    metrics.IdentifiedQ = abs(poles(1))/max(eps, -2*real(poles(1)));
end

switch name
    case 'BP'
        [metrics.IdealMagnitudeRmseDb, metrics.IdealPhaseRmseDeg] = ...
            responseErrors(h, responseAt(ideal.BP_680uF, f));
        [metrics.AlternativeMagnitudeRmseDb, metrics.AlternativePhaseRmseDeg] = ...
            responseErrors(h, responseAt(ideal.BP_680nF, f));
        metrics.IdealReference = "Cin = 680 uF";
        metrics.AlternativeReference = "Cin = 680 nF";
    case 'SUM'
        [metrics.IdealMagnitudeRmseDb, metrics.IdealPhaseRmseDeg] = ...
            responseErrors(h, responseAt(ideal.SUM, f));
        [metrics.AlternativeMagnitudeRmseDb, metrics.AlternativePhaseRmseDeg] = ...
            responseErrors(h, -responseAt(ideal.SUM, f));
        metrics.IdealReference = "+12k/(405us*s+1)";
        metrics.AlternativeReference = "signo invertido";
    case 'LP'
        [metrics.IdealMagnitudeRmseDb, metrics.IdealPhaseRmseDeg] = ...
            responseErrors(h, responseAt(ideal.LP, f));
        metrics.IdealReference = "MFB nominal";
end
end

function [magRmse, phaseRmse] = responseErrors(measured, reference)
valid = abs(measured) > 0 & abs(reference) > 0;
magError = 20*log10(abs(measured(valid)./reference(valid)));
phaseError = angle(measured(valid).*conj(reference(valid)))*180/pi;
magRmse = sqrt(mean(magError.^2));
phaseRmse = sqrt(mean(phaseError.^2));
end

function h = responseAt(model, frequencyHz)
h = squeeze(freqresp(model, 2*pi*frequencyHz));
h = h(:);
end

function plotStage(name, stitched, model, ideal, outputRoot)
f = stitched.f;
h = stitched.response;
gridF = logspace(log10(min(f)), log10(max(f)), 800).';
hm = responseAt(model, gridF);

fig = figure('Color','w', 'Name',['Identificacion ' name], ...
    'Position',[100 100 1050 800]);
layout = tiledlayout(fig, 3, 1, 'TileSpacing','compact', 'Padding','compact');

nexttile;
semilogx(f, 20*log10(abs(h)), 'ko', 'MarkerSize',4, ...
    'DisplayName','Medición combinada'); hold on;
semilogx(gridF, 20*log10(abs(hm)), 'LineWidth',1.6, 'DisplayName','tfest');
plotIdeals(name, ideal, gridF, false);
grid on; ylabel('Magnitud (dB)'); legend('Location','best');

dataPhase = unwrap(angle(h))*180/pi;
nexttile;
semilogx(f, dataPhase, 'ko', 'MarkerSize',4, 'DisplayName','Medición combinada'); hold on;
modelPhase = alignPhase(unwrap(angle(hm))*180/pi, dataPhase);
semilogx(gridF, modelPhase, 'LineWidth',1.6, 'DisplayName','tfest');
plotIdeals(name, ideal, gridF, true, dataPhase);
grid on; ylabel('Fase (grados)');

nexttile;
semilogx(f, stitched.coherence, 'o-', 'LineWidth',1); hold on;
yline(0.70, '--', 'Umbral de ajuste');
grid on; ylim([0 1.05]); ylabel('Coherencia local'); xlabel('Frecuencia (Hz)');

title(layout, sprintf('%s: medición, modelo identificado e ideal', name));
exportgraphics(fig, fullfile(outputRoot, sprintf('identificacion_%s.png', lower(name))), ...
    'Resolution', 180);
close(fig);
end

function plotIdeals(name, ideal, frequency, phasePlot, dataPhase)
if nargin < 5
    dataPhase = [];
end
switch name
    case 'BP'
        models = {ideal.BP_680uF, ideal.BP_680nF};
        labels = {'Ideal: C_{in}=680 \muF', 'Alternativa: C_{in}=680 nF'};
    case 'SUM'
        models = {ideal.SUM};
        labels = {'Ideal suministrado'};
    otherwise
        models = {ideal.LP};
        labels = {'Ideal nominal'};
end

styles = {'--', ':'};
for k = 1:numel(models)
    response = responseAt(models{k}, frequency);
    if phasePlot
        values = unwrap(angle(response))*180/pi;
        values = alignPhase(values, dataPhase);
    else
        values = 20*log10(abs(response));
    end
    semilogx(frequency, values, styles{k}, 'LineWidth',1.4, ...
        'DisplayName',labels{k});
end
end

function phase = alignPhase(phase, reference)
if isempty(reference)
    return;
end
phase = phase + 360*round((median(reference)-median(phase))/360);
end

function writeModelReport(results, filename)
fid = fopen(filename, 'w');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'Identificación de la cadena analógica\n');
fprintf(fid, 'Datos: %s\n\n', results.dataRoot);
names = {'BP','SUM','LP'};
for k = 1:numel(names)
    fprintf(fid, '===== %s =====\n', names{k});
    continuousModel = tf(results.models.(names{k}));
    [numerator, denominator] = tfdata(continuousModel, 'v');
    fprintf(fid, 'Numerador:   %s\n', mat2str(numerator, 10));
    fprintf(fid, 'Denominador: %s\n', mat2str(denominator, 10));
    poles = pole(continuousModel);
    fprintf(fid, 'Polos (rad/s):\n');
    fprintf(fid, '  %.9g %+.9gj\n', [real(poles), imag(poles)].');
    fprintf(fid, '\n');
end
end

function raw = emptyRaw(names)
empty = struct('f',[], 'response',[], 'coherence',[], 'excitation',[], ...
    'band',strings(0,1), 'capture',strings(0,1));
for k = 1:numel(names)
    raw.(names{k}) = empty;
end
end

function out = appendEstimate(out, in)
fields = fieldnames(out);
for k = 1:numel(fields)
    out.(fields{k}) = [out.(fields{k}); in.(fields{k})];
end
end

function row = emptyHealthRow()
row = struct('Band',"", 'Capture',"", 'StartFrequencyHz',NaN, ...
    'StopFrequencyHz',NaN, 'SampleRateHz',NaN, 'DurationS',NaN, ...
    'ValidFraction',NaN, 'InvalidCodeFraction',NaN, ...
    'DiscardedFraction',NaN, 'ClipFraction',NaN);
end

function row = emptySummaryRow()
row = struct('Stage',"", 'PointsUsed',0, 'MinFrequencyHz',NaN, ...
    'MaxFrequencyHz',NaN, 'MedianCoherence',NaN, ...
    'TfestMagnitudeRmseDb',NaN, 'TfestPhaseRmseDeg',NaN, ...
    'IdentifiedF1Hz',NaN, 'IdentifiedF2Hz',NaN, 'IdentifiedQ',NaN, ...
    'IdealMagnitudeRmseDb',NaN, 'IdealPhaseRmseDeg',NaN, ...
    'AlternativeMagnitudeRmseDb',NaN, 'AlternativePhaseRmseDeg',NaN, ...
    'IdealReference',"", 'AlternativeReference',"");
end

function selected = keepLongRuns(mask, minimumLength)
selected = false(size(mask));
runs = logicalRuns(mask);
for k = 1:size(runs,1)
    if runs(k,2)-runs(k,1)+1 >= minimumLength
        selected(runs(k,1):runs(k,2)) = true;
    end
end
end

function runs = logicalRuns(mask)
edges = diff([false; mask(:); false]);
runs = [find(edges==1), find(edges==-1)-1];
end

function span = rangeLocal(x)
span = max(x)-min(x);
end

function [fStart, fStop] = parseBandName(name)
parts = split(string(name), '_');
if numel(parts) ~= 2
    fStart = NaN;
    fStop = NaN;
    return;
end
fStart = parseFrequency(parts(1));
fStop = parseFrequency(parts(2));
end

function frequency = parseFrequency(text)
token = regexp(char(text), '^([0-9]+(?:\.[0-9]+)?)([mMkK]?)Hz$', ...
    'tokens', 'once', 'ignorecase');
if isempty(token)
    frequency = NaN;
    return;
end
value = str2double(token{1});
switch token{2}
    case {'m','M'}
        if strcmp(token{2}, 'm')
            factor = 1e-3;
        else
            factor = 1e6;
        end
    case {'k','K'}
        factor = 1e3;
    otherwise
        factor = 1;
end
frequency = value*factor;
end
