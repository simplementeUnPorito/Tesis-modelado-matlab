function [cleaned, info] = cancelar_armonicos_linea_ls(signals, time, fs, sweep, options)
%CANCELAR_ARMONICOS_LINEA_LS Resta ruido de red mediante regresión sinusoidal.
%
% Es el equivalente MATLAB del harmonicNotch del master ESP. La diferencia
% para mediciones con sweep es que los cruces del estímulo por 50*N se
% excluyen del ajuste. El modelo se estima fuera de esos cruces y se resta
% luego de toda la captura.

arguments
    signals (:,:) double
    time (:,1) double
    fs (1,1) double {mustBePositive}
    sweep struct
    options.F0 (1,1) double {mustBePositive} = 50
    options.Harmonics (1,1) double {mustBeInteger,mustBePositive} = 12
    options.SearchHz (1,1) double {mustBeNonnegative} = 2
    options.GuardRelative (1,1) double {mustBeNonnegative} = 0.04
    options.GuardHz (1,1) double {mustBeNonnegative} = 0.4
    options.GuardCycles (1,1) double {mustBeNonnegative} = 3
    options.MinFrequencyHz (1,1) double {mustBeNonnegative} = 0
    options.MaxFrequencyHz (1,1) double {mustBePositive} = Inf
    options.MinimumFundamentalCycles (1,1) double {mustBeNonnegative} = 2
    options.MinimumSearchCycles (1,1) double {mustBeNonnegative} = 50
end

assert(size(signals,1) == numel(time), 'signals y time deben tener igual longitud.');
signals = signals-mean(signals,1);
cleaned = signals;

info = struct('estimatedF0Hz',NaN, 'frequenciesHz',[], ...
    'removedRmsV',zeros(1,size(signals,2)), 'fitFraction',1, ...
    'coefficients',zeros(0,size(signals,2)));

recordDuration = max(time)-min(time);
maxHarmonic = min(options.Harmonics, floor((fs/2-eps)/options.F0));
if maxHarmonic < 1 || size(signals,1) < 16 || ...
        recordDuration*options.F0 < options.MinimumFundamentalCycles
    return;
end
nominalFrequencies = (1:maxHarmonic)*options.F0;
if ~any(nominalFrequencies >= options.MinFrequencyHz & ...
        nominalFrequencies <= options.MaxFrequencyHz)
    return;
end

if options.SearchHz > 0 && ...
        recordDuration*options.F0 >= options.MinimumSearchCycles
    coarse = linspace(max(0.1,options.F0-options.SearchHz), ...
        min(fs/2-eps,options.F0+options.SearchHz), 81);
    scores = -inf(size(coarse));
    for k = 1:numel(coarse)
        scores(k) = candidateScore(coarse(k), signals, time, fs, sweep, options);
    end
    [~, best] = max(scores);
    coarseStep = coarse(min(2,end))-coarse(1);
    fine = linspace(max(coarse(1),coarse(best)-coarseStep), ...
        min(coarse(end),coarse(best)+coarseStep), 21);
    fineScores = -inf(size(fine));
    for k = 1:numel(fine)
        fineScores(k) = candidateScore(fine(k), signals, time, fs, sweep, options);
    end
    [~, bestFine] = max(fineScores);
    lineF0 = fine(bestFine);
else
    lineF0 = options.F0;
end

[lineModel, coefficients, frequencies, fitFractions] = ...
    fitLineModel(lineF0, signals, time, fs, sweep, options);
if isempty(frequencies)
    return;
end
cleaned = signals-lineModel;

info.estimatedF0Hz = lineF0;
info.frequenciesHz = frequencies;
info.removedRmsV = sqrt(mean(lineModel.^2,1));
info.fitFraction = mean(fitFractions);
info.coefficients = coefficients;
end

function score = candidateScore(f0, signals, time, fs, sweep, options)
[model, ~, frequencies] = fitLineModel(f0,signals,time,fs,sweep,options);
if isempty(frequencies)
    score = -inf;
    return;
end
score = sum(model.^2,'all');
end

function [lineModel, coefficients, frequencies, fitFractions] = ...
        fitLineModel(f0, signals, time, fs, sweep, options)
harmonics = (1:options.Harmonics).';
frequencies = harmonics*f0;
frequencies = frequencies(frequencies < fs/2 & ...
    frequencies >= options.MinFrequencyHz & frequencies <= options.MaxFrequencyHz);
if isempty(frequencies)
    lineModel = [];
    coefficients = zeros(0,size(signals,2));
    fitFractions = 1;
    return;
end

signalFrequency = repmat(sweep.fStartHz,size(time));
active = time >= 0 & time <= sweep.durationS;
signalFrequency(active) = sweep.fStartHz * ...
    (sweep.fStopHz/sweep.fStartHz).^(time(active)/sweep.durationS);

lineModel = zeros(size(signals));
coefficients = zeros(2*numel(frequencies),size(signals,2));
fitFractions = ones(numel(frequencies),1);
for k = 1:numel(frequencies)
    angle = 2*pi*frequencies(k)*time;
    basis = [cos(angle),sin(angle)];
    chirpGuard = options.GuardCycles*log(sweep.fStopHz/sweep.fStartHz)/sweep.durationS;
    guard = max([options.GuardHz, options.GuardRelative*frequencies(k), chirpGuard]);
    fitMask = abs(signalFrequency-frequencies(k)) > guard;
    if nnz(fitMask) <= 4
        frequencies = [];
        lineModel = [];
        coefficients = zeros(0,size(signals,2));
        fitFractions = 1;
        return;
    end
    rows = (2*k-1):(2*k);
    coefficients(rows,:) = basis(fitMask,:) \ signals(fitMask,:);
    lineModel = lineModel+basis*coefficients(rows,:);
    fitFractions(k) = mean(fitMask);
end
end
