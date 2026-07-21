function results = analizar_sweeps_circuito(dataRoot, outputRoot, showFigures)
%ANALIZAR_SWEEPS_CIRCUITO Identificación de BP, compensador, LP y cadena completa.
%
% CH1=PGA, CH2=BP, CH3=compensador y CH4=LP.
% Se conserva la escala registrada por el osciloscopio, sin conversión ×2.

scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(fileparts(scriptDir)));
if nargin < 1 || isempty(dataRoot) || strlength(string(dataRoot)) == 0
    dataRoot = fullfile(projectRoot,'Crudos','Osciloscopio');
end
if nargin < 2 || isempty(outputRoot) || strlength(string(outputRoot)) == 0
    outputRoot = fullfile(scriptDir,'resultados');
end
dataRoot = char(dataRoot);
outputRoot = char(outputRoot);
assert(isfolder(dataRoot),'No existe %s.',dataRoot);
if ~isfolder(outputRoot), mkdir(outputRoot); end
dataRoot = normalizeExistingPath(dataRoot);
outputRoot = normalizeExistingPath(outputRoot);
folders = prepareResultFolders(outputRoot);

cfg = defaultConfig();
cfg.saturationOverrideFile = fullfile(scriptDir,'saturation_overrides.csv');
if nargin >= 3 && ~isempty(showFigures)
    cfg.showFigures = logical(showFigures);
end
captures = discoverCaptures(dataRoot);
assert(~isempty(captures),'No se encontraron capturas nuevas *to* con cuatro canales.');
[cacheKey,cacheFile] = analysisCacheKey(captures,cfg,scriptDir,dataRoot,folders.cache);
if isfile(cacheFile)
    cached = load(cacheFile,'results');
    if isfield(cached,'results') && isfield(cached.results,'cacheKey') && ...
            strcmp(cached.results.cacheKey,cacheKey) && cacheArtifactsPresent(folders,captures)
        results = cached.results;
        results.config.showFigures = cfg.showFigures;
        fprintf('Cache vigente: se reutiliza %s\n',cacheFile);
        disp(results.summary);
        if cfg.showFigures,openCachedFigures(outputRoot);end
        return;
    end
end
[missingExpected, unexpected] = auditExpectedBands(captures,cfg);
if ~isempty(missingExpected)
    warning('Faltan bandas esperadas: %s',strjoin(missingExpected,', '));
end
clearGeneratedArtifacts(folders);
saturationOverrides = readSaturationOverrides(cfg.saturationOverrideFile);

stageNames = {'BP','COMP','LP','LP_PGA'};
rawFrf = emptyRaw(stageNames);
processedFrf = emptyRaw(stageNames);
healthRows = repmat(emptyHealthRow(),0,1);
processingRows = repmat(emptyProcessingRow(),0,1);
saturationRows = repmat(emptySaturationRow(),0,1);
usageRows = repmat(emptyUsageRow(),0,1);

fprintf('Capturas nuevas encontradas: %d\n',numel(captures));
for k = 1:numel(captures)
    cap = readCapture(captures(k),cfg,saturationOverrides);
    healthRows(end+1,1) = cap.health; %#ok<AGROW>
    saturationRows = [saturationRows;cap.saturationRows]; %#ok<AGROW>

    rawScaled = cfg.signalScale*cap.signals;
    rawCentered = rawScaled-mean(rawScaled,1);
    [bandpassed,bandpassLow,bandpassHigh] = applySweepBandpass( ...
        rawCentered,cap.fs,cap.fStart,cap.fStop,cfg);

    sweep = struct('fStartHz',cap.fStart,'fStopHz',cap.fStop, ...
        'durationS',cap.sweepDuration);
    if cfg.lineCancellationEnabled
        [processed,lineInfo] = cancelar_armonicos_linea_ls( ...
            bandpassed,cap.time,cap.fs,sweep, ...
            F0=cfg.lineF0,Harmonics=cfg.lineHarmonics, ...
            SearchHz=cfg.lineSearchHz,GuardRelative=cfg.lineGuardRelative, ...
            GuardHz=cfg.lineGuardHz,GuardCycles=cfg.lineGuardCycles, ...
            MinFrequencyHz=bandpassLow,MaxFrequencyHz=bandpassHigh, ...
            MinimumFundamentalCycles=cfg.lineMinimumFundamentalCycles, ...
            MinimumSearchCycles=cfg.lineMinimumSearchCycles);
    else
        processed = bandpassed;
        lineInfo = struct('estimatedF0Hz',NaN,'frequenciesHz',[], ...
            'removedRmsV',zeros(1,4),'fitFraction',1);
    end

    plotOscilloscopeCapture(cap,rawScaled,processed,cfg,folders.oscilloscope);

    for channel = 1:4
        row = emptyProcessingRow();
        row.Band = string(cap.band);
        row.Capture = string(cap.captureId);
        row.Channel = channel;
        row.AppliedSignalScale = cfg.signalScale;
        row.BandpassLowHz = bandpassLow;
        row.BandpassHighHz = bandpassHigh;
        row.EstimatedLineF0Hz = lineInfo.estimatedF0Hz;
        row.RemovedHarmonicsHz = strjoin(compose('%.4g',lineInfo.frequenciesHz),';');
        row.RemovedLineRmsV = lineInfo.removedRmsV(channel);
        row.LineFitFraction = lineInfo.fitFraction;
        row.RawRmsV = sqrt(mean(rawCentered(:,channel).^2));
        row.ProcessedRmsV = sqrt(mean(processed(:,channel).^2));
        row.PeakAmplitudeV = max(abs(rawCentered(:,channel)));
        row.ConservativeSlewDemandVPerS = 2*pi*cap.fStop*row.PeakAmplitudeV;
        row.SlewMarginToModel = cfg.opamp.SlewRateVPerS/ ...
            max(eps,row.ConservativeSlewDemandVPerS);
        row.SlewMarginToDataSheetMinimum = cfg.opamp.DataSheetMinimumSlewRateVPerS/ ...
            max(eps,row.ConservativeSlewDemandVPerS);
        processingRows(end+1,1) = row; %#ok<AGROW>
    end

    saturatedChannels=find(cap.channelSaturated);
    if isempty(saturatedChannels)
        saturatedText='ninguno';
    else
        saturatedText=char(join(compose('CH%d',saturatedChannels),','));
    end
    fprintf('%-32s %-18s fs=%-9.4g Hz  saturados=%s  línea=%7.3f Hz\n', ...
        cap.band,cap.captureId,cap.fs,saturatedText,lineInfo.estimatedF0Hz);

    rawInputs = stageInputs(rawCentered,cfg);
    processedInputs = stageInputs(processed,cfg);
    rawOutputs = {rawCentered(:,2),rawCentered(:,3),rawCentered(:,4),rawCentered(:,4)};
    processedOutputs = {processed(:,2),processed(:,3),processed(:,4),processed(:,4)};
    [stageUsable,stageReasons] = captureStageUsability(cap.channelSaturated,stageNames);

    for s = 1:numel(stageNames)
        usage = emptyUsageRow();
        usage.Band = string(cap.band);
        usage.Capture = string(cap.captureId);
        usage.Stage = string(stageNames{s});
        usage.Used = stageUsable(s);
        usage.ExclusionReason = stageReasons(s);
        usageRows(end+1,1) = usage; %#ok<AGROW>
        if ~stageUsable(s),continue;end
        estRaw = estimateKnownSweepFrf(cap.time,rawInputs{s},rawOutputs{s}, ...
            cap.fStart,cap.fStop,cap.sweepDuration,cfg);
        estProcessed = estimateKnownSweepFrf(cap.time,processedInputs{s},processedOutputs{s}, ...
            cap.fStart,cap.fStop,cap.sweepDuration,cfg);
        estRaw = labelEstimate(estRaw,cap);
        estProcessed = labelEstimate(estProcessed,cap);
        rawFrf.(stageNames{s}) = appendEstimate(rawFrf.(stageNames{s}),estRaw);
        processedFrf.(stageNames{s}) = appendEstimate(processedFrf.(stageNames{s}),estProcessed);
    end
    plotPreprocessing(cap,rawCentered,processed,lineInfo,cfg,folders.preprocessing);
end

healthTable = struct2table(healthRows);
processingTable = struct2table(processingRows);
saturationTable = struct2table(saturationRows);
usageTable = struct2table(usageRows);
gainRecommendationTable=measurementGainRecommendation(saturationTable,cfg);
writetable(healthTable,fullfile(folders.tables,'salud_capturas.csv'));
writetable(processingTable,fullfile(folders.tables,'preprocesamiento.csv'));
writetable(saturationTable,fullfile(folders.tables,'saturacion_canales.csv'));
writetable(usageTable,fullfile(folders.tables,'uso_capturas_por_etapa.csv'));
writetable(gainRecommendationTable, ...
    fullfile(folders.tables,'ganancia_medicion_recomendada.csv'));

ideal = idealModels(cfg);
monteCarlo = createMonteCarloSamples(cfg);
writetable(toleranceTable(cfg),fullfile(folders.tables,'configuracion_tolerancias.csv'));
writetable(opAmpParameterTable(cfg),fullfile(folders.tables,'modelo_operacional_psoc.csv'));
writetable(slewRateLimitTable(cfg),fullfile(folders.tables,'limite_slew_rate.csv'));
writetable(compensationParameterTable(ideal), ...
    fullfile(folders.tables,'parametros_compensador.csv'));
orders = struct('BP',[2 1],'COMP',[3 2],'LP',[2 0],'LP_PGA',[5 2]);
fitRanges = struct('BP',[0.2 5e4],'COMP',[0.2 5e3], ...
    'LP',[10 1.2e3],'LP_PGA',[0.2 1.2e3]);
summaryRows = repmat(emptySummaryRow(),0,1);

for s = 1:numel(stageNames)
    name = stageNames{s};
    rawStitched = stitchFrf(rawFrf.(name),cfg);
    stitched = stitchFrf(processedFrf.(name),cfg);
    inRange = stitched.f >= fitRanges.(name)(1) & stitched.f <= fitRanges.(name)(2);
    minimumCoherence=cfg.minFitCoherence;
    minimumPoints=cfg.minFitPoints;
    fitMask = inRange & stitched.coherence >= minimumCoherence;
    if nnz(fitMask) < minimumPoints
        candidates = find(inRange);
        [~,idx] = sort(stitched.coherence(candidates),'descend');
        chosen = candidates(idx(1:min(minimumPoints,numel(idx))));
        fitMask = false(size(inRange));
        fitMask(chosen) = true;
        warning('%s: se usaron los %d puntos de mejor coherencia.',name,nnz(fitMask));
    end

    model = fitContinuousModel(stitched,fitMask,orders.(name));
    metrics = stageMetrics(name,stitched,rawStitched,fitMask,model,ideal,monteCarlo);
    summaryRows(end+1,1) = metrics; %#ok<AGROW>
    results.frfRaw.(name) = rawStitched;
    results.frfProcessed.(name) = stitched;
    results.models.(name) = model;
    results.fitMasks.(name) = fitMask;
    plotStage(name,rawStitched,stitched,model,ideal,monteCarlo,cfg, ...
        stageOutputFolder(name,folders));
end

% Respuesta compuesta con el geófono nominal. No constituye una quinta
% medición: propaga la FRF medida LP/PGA a través de Hgeo nominal.
rawGeo = multiplyFrf(results.frfRaw.LP_PGA,ideal.GEOPHONE);
processedGeo = multiplyFrf(results.frfProcessed.LP_PGA,ideal.GEOPHONE);
geoModel = minreal(results.models.LP_PGA*ideal.GEOPHONE,1e-7);
geoMask = results.fitMasks.LP_PGA;
summaryRows(end+1,1) = stageMetrics('GEO_LP',processedGeo,rawGeo, ...
    geoMask,geoModel,ideal,monteCarlo); %#ok<AGROW>
results.frfRaw.GEO_LP = rawGeo;
results.frfProcessed.GEO_LP = processedGeo;
results.models.GEO_LP = geoModel;
results.fitMasks.GEO_LP = geoMask;
plotStage('GEO_LP',rawGeo,processedGeo,geoModel,ideal,monteCarlo,cfg,folders.chainGeo);
results.chains.PGA_to_ADC.measuredRaw=results.frfRaw.LP_PGA;
results.chains.PGA_to_ADC.measuredProcessed=results.frfProcessed.LP_PGA;
results.chains.PGA_to_ADC.tfest=results.models.LP_PGA;
results.chains.PGA_to_ADC.nominalPsoc=ideal.LP_PGA;
results.chains.GEO_to_ADC.calculatedRaw=rawGeo;
results.chains.GEO_to_ADC.calculatedProcessed=processedGeo;
results.chains.GEO_to_ADC.tfest=geoModel;
results.chains.GEO_to_ADC.nominalPsoc=ideal.GEO_LP;

results.rawByCapture = rawFrf;
results.processedByCapture = processedFrf;
results.ideal = ideal;
results.opAmpParameters = opAmpParameterTable(cfg);
results.slewRateLimits = slewRateLimitTable(cfg);
results.monteCarlo = monteCarlo;
results.captureHealth = healthTable;
results.processing = processingTable;
results.saturation = saturationTable;
results.captureUse = usageTable;
results.gainRecommendations = gainRecommendationTable;
results.summary = struct2table(summaryRows);
results.config = cfg;
results.dataRoot = dataRoot;
results.outputRoot = outputRoot;
results.outputFolders = folders;
results.missingExpectedBands = missingExpected;
results.unexpectedBands = unexpected;
results.cacheKey = cacheKey;
results.cacheVersion = 5;

writetable(results.summary,fullfile(folders.tables,'resumen_identificacion.csv'));
writeReport(results,fullfile(folders.tables,'informe_identificacion.txt'));
save(cacheFile,'results');
fprintf('\nResultados: %s\n',outputRoot);
disp(results.summary);
end

function cfg = defaultConfig()
cfg.signalScale = 1;
cfg.showFigures = true;
cfg.opamp.SlewRateVPerS = 4.3e6;
cfg.opamp.InputResistanceOhm = 35e6;
cfg.opamp.OutputResistanceOhm = 20;
cfg.opamp.OpenLoopGain = 10^(90/20);
cfg.opamp.GainBandwidthHz = 8e6;
cfg.opamp.DominantPoleHz = cfg.opamp.GainBandwidthHz/cfg.opamp.OpenLoopGain;
cfg.opamp.InputCapacitanceF = 18e-12;
cfg.opamp.DataSheetMinimumGainBandwidthHz = 3e6;
cfg.opamp.DataSheetMinimumSlewRateVPerS = 3e6;
cfg.opamp.InputNoiseDensityVPerSqrtHz = 45e-9;
cfg.opamp.InputOffsetMaxV = 3e-3;
cfg.WP_U = 1/7.5e3;
cfg.WP_BP = 1/8.2e3;
cfg.bandpassEnabled = true;
cfg.bandpassOrder = 4;
cfg.bandpassLowFactor = 0.5;
cfg.bandpassHighFactor = 1.5;
cfg.lineCancellationEnabled = true;
cfg.lineF0 = 50;
cfg.lineHarmonics = 12;
cfg.lineSearchHz = 2;
cfg.lineGuardRelative = 0.04;
cfg.lineGuardHz = 0.4;
cfg.lineGuardCycles = 3;
cfg.lineMinimumFundamentalCycles = 2;
cfg.lineMinimumSearchCycles = 50;
cfg.pointsPerDecade = 20;
cfg.stitchPointsPerDecade = 16;
cfg.edgeFraction = 0.04;
cfg.sweepEdgeWeightFloor = 0.05;
cfg.minSamplesPerBin = 8;
cfg.minInputEnvelope = 0.10;
cfg.minMissingRun = 8;
cfg.minSegmentSamples = 200;
cfg.minFitCoherence = 0.75;
cfg.minFitPoints = 12;
cfg.saturation.enabled = true;
cfg.saturation.absoluteVoltageThresholdV = 2.3;
cfg.saturation.minimumSamples = 1;
cfg.saturation.activeEdgeFraction = 0.05;
cfg.saturation.recommendedTargetV = 2.0;
cfg.monteCarloSamples = 4000;
cfg.monteCarloSeed = 2909;
cfg.monteCarloFrequencyChunkSize = 48;
cfg.tolerance.resistorMinus = 0.01;
cfg.tolerance.resistorPlus = 0.01;
cfg.tolerance.ceramicMinus = 0.20;
cfg.tolerance.ceramicPlus = 0.20;
cfg.tolerance.electrolyticMinus = 0.40;
cfg.tolerance.electrolyticPlus = 0.10;
cfg.expectedBands = [0.1 1;0.5 5;2.5 25;10 100;50 500;250 2500;1e3 1e4;5e3 5e4;2e4 2e5];
end

function folders=prepareResultFolders(outputRoot)
folders.cache=fullfile(outputRoot,'00_cache');
folders.oscilloscope=fullfile(outputRoot,'01_osciloscopio_tiempo');
folders.preprocessing=fullfile(outputRoot,'02_preprocesamiento_espectral');
folders.identificationRoot=fullfile(outputRoot,'03_identificacion_etapas');
folders.bp=fullfile(folders.identificationRoot,'BP');
folders.comp=fullfile(folders.identificationRoot,'COMPENSADOR_PGA');
folders.lp=fullfile(folders.identificationRoot,'LP');
folders.chainRoot=fullfile(outputRoot,'04_cadena_adc');
folders.chainPga=fullfile(folders.chainRoot,'PGA_a_ADC');
folders.chainGeo=fullfile(folders.chainRoot,'GEO_a_ADC');
folders.tables=fullfile(outputRoot,'05_tablas_reportes');
names=fieldnames(folders);
for k=1:numel(names)
    folder=folders.(names{k});
    if ~isfolder(folder),mkdir(folder);end
end
end

function folder=stageOutputFolder(name,folders)
switch name
    case 'BP',folder=folders.bp;
    case 'COMP',folder=folders.comp;
    case 'LP',folder=folders.lp;
    case 'LP_PGA',folder=folders.chainPga;
    otherwise,error('Carpeta no definida para %s.',name);
end
end

function [key,cacheFile]=analysisCacheKey(captures,cfg,scriptDir,dataRoot,cacheFolder)
cacheFile=fullfile(cacheFolder,'analisis_circuito.mat');
digest=java.security.MessageDigest.getInstance('SHA-256');
cacheConfig=rmfield(cfg,'showFigures');
updateDigest(digest,['cache-v5|' char(dataRoot) '|' jsonencode(cacheConfig)]);
dependencies={fullfile(scriptDir,'analizar_sweeps_circuito.m'), ...
    fullfile(scriptDir,'cancelar_armonicos_linea_ls.m')};
if isfile(cfg.saturationOverrideFile)
    dependencies{end+1}=cfg.saturationOverrideFile;
end
for k=1:numel(captures)
    updateDigest(digest,sprintf('|%s|%.17g|%.17g|%.17g',captures(k).band, ...
        captures(k).fStart,captures(k).fStop,captures(k).sweepDuration));
    dependencies=[dependencies,captures(k).files]; %#ok<AGROW>
end
for k=1:numel(dependencies)
    filename=dependencies{k};
    updateDigest(digest,['|' filename '|']);
    fid=fopen(filename,'r');
    assert(fid>=0,'No se pudo abrir para cache: %s',filename);
    cleanup=onCleanup(@()fclose(fid));
    while ~feof(fid)
        bytes=fread(fid,1024*1024,'*uint8');
        if ~isempty(bytes),digest.update(typecast(bytes(:),'int8'));end
    end
    clear cleanup
end
bytes=typecast(digest.digest(),'uint8');
key=lower(reshape(dec2hex(bytes,2).',1,[]));
end

function updateDigest(digest,text)
bytes=unicode2native(char(text),'UTF-8');
digest.update(typecast(uint8(bytes(:)),'int8'));
end

function pathOut=normalizeExistingPath(pathIn)
[ok,attributes]=fileattrib(pathIn);
assert(ok,'No se pudo normalizar la ruta %s.',pathIn);
pathOut=attributes.Name;
end

function clearGeneratedArtifacts(folders)
targets={folders.oscilloscope,folders.preprocessing,folders.bp,folders.comp, ...
    folders.lp,folders.chainPga,folders.chainGeo,folders.tables, ...
    fullfile(folders.identificationRoot,'SUM')};
patterns={'*.fig','*.png','*.csv','*.txt'};
for t=1:numel(targets)
    if ~isfolder(targets{t}),continue;end
    for p=1:numel(patterns)
        files=dir(fullfile(targets{t},patterns{p}));
        for k=1:numel(files),delete(fullfile(files(k).folder,files(k).name));end
    end
end
legacySum=fullfile(folders.identificationRoot,'SUM');
if isfolder(legacySum)
    entries=dir(legacySum);
    entries=entries(~ismember({entries.name},{'.','..'}));
    if isempty(entries),rmdir(legacySum);end
end
end

function present=cacheArtifactsPresent(folders,captures)
tableFiles={'resumen_identificacion.csv','preprocesamiento.csv','salud_capturas.csv', ...
    'configuracion_tolerancias.csv','modelo_operacional_psoc.csv', ...
    'limite_slew_rate.csv','informe_identificacion.txt', ...
    'saturacion_canales.csv','uso_capturas_por_etapa.csv', ...
    'ganancia_medicion_recomendada.csv','parametros_compensador.csv'};
tablesPresent=all(cellfun(@(name)isfile(fullfile(folders.tables,name)),tableFiles));
plotsPresent=plotPairExists(folders.bp,'identificacion_bp') && ...
    plotPairExists(folders.comp,'compensador_pga') && ...
    plotPairExists(folders.lp,'identificacion_lp') && ...
    plotPairExists(folders.chainPga,'cadena_pga_adc') && ...
    plotPairExists(folders.chainGeo,'cadena_geo_adc');
present=tablesPresent && plotsPresent && ...
    numel(dir(fullfile(folders.oscilloscope,'*.fig')))==numel(captures) && ...
    numel(dir(fullfile(folders.preprocessing,'*.fig')))==numel(captures);
end

function present=plotPairExists(folder,baseName)
present=isfile(fullfile(folder,[baseName '.png'])) && ...
    isfile(fullfile(folder,[baseName '.fig']));
end

function openCachedFigures(outputRoot)
files=dir(fullfile(outputRoot,'**','*.fig'));
[~,order]=sort({files.name});files=files(order);
fprintf('Abriendo %d figuras interactivas desde la cache...\n',numel(files));
for k=1:numel(files),openfig(fullfile(files(k).folder,files(k).name),'new','visible');end
drawnow;
end

function captures = discoverCaptures(dataRoot)
bandFolders = dir(fullfile(dataRoot,'*to*'));
bandFolders = bandFolders([bandFolders.isdir]);
captures = repmat(struct('band','', 'folder','', 'captureId','', 'files',{{}}, ...
    'fStart',NaN,'fStop',NaN,'sweepDuration',NaN),0,1);
for b = 1:numel(bandFolders)
    [fStart,fStop,sweepDuration] = parseBandFolder(bandFolders(b).name);
    if ~all(isfinite([fStart fStop sweepDuration])), continue; end
    bandRoot=fullfile(bandFolders(b).folder,bandFolders(b).name);
    ch1 = dir(fullfile(bandRoot,'**','*CH1.CSV'));
    for k = 1:numel(ch1)
        filePrefix = extractBefore(string(ch1(k).name),'CH1.CSV');
        relativeFolder=regexprep(char(erase(string(ch1(k).folder),string(bandRoot))), ...
            '^[\\/]+|[\\/]+$','');
        if isempty(relativeFolder),relativeFolder='root';end
        captureId=regexprep(sprintf('%s_%s',relativeFolder,filePrefix),'[\\/]+','_');
        files = cell(1,4);
        complete = true;
        for channel = 1:4
            files{channel} = fullfile(ch1(k).folder,sprintf('%sCH%d.CSV',filePrefix,channel));
            complete = complete && isfile(files{channel});
        end
        if ~complete
            warning('Se omite %s/%s: faltan canales.',bandFolders(b).name,captureId);
            continue;
        end
        row = struct('band',bandFolders(b).name,'folder',ch1(k).folder, ...
            'captureId',captureId,'files',{files},'fStart',fStart, ...
            'fStop',fStop,'sweepDuration',sweepDuration);
        captures(end+1,1) = row; %#ok<AGROW>
    end
end
if ~isempty(captures)
    [~,idx] = sortrows([[captures.fStart].' [captures.fStop].']);
    captures = captures(idx);
end
end

function [missing,unexpected] = auditExpectedBands(captures,cfg)
actual = [[captures.fStart].' [captures.fStop].'];
missing = strings(0,1);
for k = 1:size(cfg.expectedBands,1)
    if ~any(all(abs(actual-cfg.expectedBands(k,:)) <= max(1e-12,1e-9*cfg.expectedBands(k,:)),2))
        missing(end+1,1) = sprintf('%g-%g Hz',cfg.expectedBands(k,1),cfg.expectedBands(k,2)); %#ok<AGROW>
    end
end
unexpected = strings(0,1);
for k = 1:size(actual,1)
    if ~any(all(abs(cfg.expectedBands-actual(k,:)) <= max(1e-12,1e-9*actual(k,:)),2))
        unexpected(end+1,1) = sprintf('%g-%g Hz',actual(k,1),actual(k,2)); %#ok<AGROW>
    end
end
end

function cap = readCapture(info,cfg,overrides)
time = [];
signals = [];
meta = repmat(struct('verticalScale',NaN,'verticalOffset',NaN,'probeAttenuation',NaN),1,4);
for channel = 1:4
    [t,y,meta(channel)] = readTekCsv(info.files{channel});
    if channel == 1
        time = t;
        signals = zeros(numel(t),4);
    else
        assert(numel(t)==numel(time) && max(abs(t-time)) < 1e-8*max(1,max(time)-min(time)), ...
            'Los tiempos no coinciden en %s.',info.band);
    end
    signals(:,channel) = y;
end

atFloor = true(size(time));
for channel = 1:4
    floorValue = -5.12*meta(channel).verticalScale-meta(channel).verticalOffset;
    atFloor = atFloor & abs(signals(:,channel)-floorValue) <= meta(channel).verticalScale*1e-6;
end
missing = keepLongRuns(atFloor,cfg.minMissingRun);
runs = logicalRuns(~missing);
runs = runs((runs(:,2)-runs(:,1)+1)>=cfg.minSegmentSamples,:);
assert(~isempty(runs),'No hay segmento válido en %s.',info.band);
[~,best] = max(runs(:,2)-runs(:,1));
idx = (runs(best,1):runs(best,2)).';
time = time(idx);
signals = signals(idx,:);

dt = median(diff(time));
fs=1/dt;
channelSaturated=false(1,4);
saturationRows=repmat(emptySaturationRow(),0,1);
saturationAny=false(size(time));
for channel=1:4
    diagnostic=detectChannelSaturation(signals(:,channel),time, ...
        info.sweepDuration,cfg.saturation);
    [diagnostic.FinalSaturated,diagnostic.DecisionSource,diagnostic.Reason]= ...
        applySaturationOverride(diagnostic,overrides,info.band,info.captureId,channel);
    channelSaturated(channel)=diagnostic.FinalSaturated;
    saturationAny=saturationAny|diagnostic.SaturationMask;
    saturationRow=emptySaturationRow();
    saturationRow.Band=string(info.band);
    saturationRow.Capture=string(info.captureId);
    saturationRow.Channel=channel;
    saturationRow.PeakToPeakV=diagnostic.PeakToPeakV;
    saturationRow.PositivePeakV=diagnostic.PositivePeakV;
    saturationRow.NegativePeakV=diagnostic.NegativePeakV;
    saturationRow.MaximumAbsoluteV=diagnostic.MaximumAbsoluteV;
    saturationRow.ThresholdV=diagnostic.ThresholdV;
    saturationRow.SamplesAtOrBeyondThreshold=diagnostic.SamplesAtOrBeyondThreshold;
    saturationRow.ThresholdFraction=diagnostic.ThresholdFraction;
    saturationRow.AutoSaturated=diagnostic.AutoSaturated;
    saturationRow.FinalSaturated=diagnostic.FinalSaturated;
    saturationRow.DecisionSource=diagnostic.DecisionSource;
    saturationRow.Reason=diagnostic.Reason;
    saturationRows(end+1,1)=saturationRow; %#ok<AGROW>
end
row = emptyHealthRow();
row.Band = string(info.band);
row.Capture = string(info.captureId);
row.StartFrequencyHz = info.fStart;
row.StopFrequencyHz = info.fStop;
row.SweepDurationS = info.sweepDuration;
row.SampleRateHz = fs;
row.RecordDurationS = time(end)-time(1);
row.ValidFraction = numel(idx)/numel(missing);
row.InvalidCodeFraction = mean(missing);
row.SaturationFraction = mean(saturationAny);
row.ProbeAttenuation = meta(1).probeAttenuation;
row.AnySaturation=any(channelSaturated);
if any(channelSaturated)
    row.SaturatedChannels=join(compose('CH%d',find(channelSaturated)),';');
else
    row.SaturatedChannels="";
end

cap = struct('band',info.band,'captureId',info.captureId,'fStart',info.fStart, ...
    'fStop',info.fStop,'sweepDuration',info.sweepDuration,'time',time, ...
    'signals',signals,'fs',fs,'health',row,'channelSaturated',channelSaturated, ...
    'saturationRows',saturationRows);
end

function overrides=readSaturationOverrides(filename)
required={'Band','Capture','Channel','Decision','Note'};
if ~isfile(filename)
    overrides=table(strings(0,1),strings(0,1),zeros(0,1),strings(0,1),strings(0,1), ...
        'VariableNames',required);
    return;
end
overrides=readtable(filename,'TextType','string');
assert(all(ismember(required,overrides.Properties.VariableNames)), ...
    'saturation_overrides.csv debe contener: %s.',strjoin(required,', '));
overrides=overrides(:,required);
overrides.Band=strip(string(overrides.Band));
overrides.Capture=strip(string(overrides.Capture));
if ~isnumeric(overrides.Channel)
    overrides.Channel=str2double(string(overrides.Channel));
end
overrides.Decision=upper(strip(string(overrides.Decision)));
overrides.Note=string(overrides.Note);
valid=ismember(overrides.Decision,["AUTO","SATURATED","VALID"]);
assert(all(valid),'Decision admite solamente AUTO, SATURATED o VALID.');
end

function diagnostic=detectChannelSaturation(signal,time,duration,cfg)
yFull=signal(:);
active=time>=cfg.activeEdgeFraction*duration & ...
    time<=(1-cfg.activeEdgeFraction)*duration;
y=yFull(active);
assert(~isempty(y),'No hay muestras activas para detectar saturación.');
thresholdActive=abs(y)>=cfg.absoluteVoltageThresholdV;
saturationMask=false(size(yFull));saturationMask(active)=thresholdActive;
autoSaturated=cfg.enabled&&nnz(thresholdActive)>=cfg.minimumSamples;
if autoSaturated
    reason=sprintf('|V| >= %.4g V durante el sweep',cfg.absoluteVoltageThresholdV);
else
    reason=sprintf('|V| < %.4g V durante el sweep',cfg.absoluteVoltageThresholdV);
end
diagnostic=struct('PeakToPeakV',max(y)-min(y),'PositivePeakV',max(y), ...
    'NegativePeakV',min(y),'MaximumAbsoluteV',max(abs(y)), ...
    'ThresholdV',cfg.absoluteVoltageThresholdV,'SaturationMask',saturationMask, ...
    'SamplesAtOrBeyondThreshold',nnz(thresholdActive), ...
    'ThresholdFraction',mean(thresholdActive), ...
    'AutoSaturated',autoSaturated,'FinalSaturated',autoSaturated, ...
    'DecisionSource',"automático",'Reason',reason);
end

function [saturated,source,reason]=applySaturationOverride(diagnostic,overrides,band,capture,channel)
saturated=diagnostic.AutoSaturated;source="automático";reason=diagnostic.Reason;
match=overrides.Band==string(band)&overrides.Capture==string(capture)& ...
    overrides.Channel==channel&overrides.Decision~="AUTO";
if ~any(match),return;end
index=find(match,1,'last');decision=overrides.Decision(index);source="override CSV";
if decision=="SATURATED"
    saturated=true;reason="forzado SATURATED: "+overrides.Note(index);
else
    saturated=false;reason="forzado VALID: "+overrides.Note(index);
end
end

function [time,signal,meta] = readTekCsv(filename)
A = readmatrix(filename,'Delimiter',',');
valid = size(A,2)>=5 && any(isfinite(A(:,4)) & isfinite(A(:,5)));
assert(valid,'CSV Tektronix no reconocido: %s',filename);
rows = isfinite(A(:,4)) & isfinite(A(:,5));
time = A(rows,4);
signal = A(rows,5);
text = fileread(filename);
meta.verticalScale = metadataNumber(text,'Vertical Scale');
meta.verticalOffset = metadataNumber(text,'Vertical Offset');
meta.probeAttenuation = metadataNumber(text,'Probe Atten');
end

function value = metadataNumber(text,label)
token = regexp(text,[regexptranslate('escape',label) ',([^,\r\n]+)'],'tokens','once');
if isempty(token), value=NaN; else, value=str2double(token{1}); end
end

function [processed,low,high] = applySweepBandpass(signals,fs,fStart,fStop,cfg)
df = fs/size(signals,1);
low = max(cfg.bandpassLowFactor*fStart,df/4);
high = min(cfg.bandpassHighFactor*fStop,0.45*fs);
if ~cfg.bandpassEnabled
    processed = signals;
    low = 0;
    high = fs/2;
    return;
end
assert(0 < low && low < high && high < fs/2,'Banda Butterworth inválida.');
[z,p,k] = butter(cfg.bandpassOrder,[low high]/(fs/2),'bandpass');
[sos,g] = zp2sos(z,p,k);
processed = zeros(size(signals));
for channel = 1:size(signals,2)
    processed(:,channel) = filtfilt(sos,g,signals(:,channel));
end
end

function inputs = stageInputs(signals,~)
% El compensador se verifica directamente respecto de PGA: CH3/CH1.
inputs = {signals(:,1),signals(:,1),signals(:,3),signals(:,1)};
end

function [usable,reasons]=captureStageUsability(channelSaturated,stageNames)
dependencies=struct('BP',[1 2],'COMP',[1 2 3],'LP',[1 2 3 4], ...
    'LP_PGA',[1 2 3 4]);
usable=false(1,numel(stageNames));reasons=strings(1,numel(stageNames));
for k=1:numel(stageNames)
    required=dependencies.(stageNames{k});
    saturated=required(channelSaturated(required));
    usable(k)=isempty(saturated);
    if usable(k)
        reasons(k)="usada";
    else
        reasons(k)="descartada por saturación de "+join("CH"+saturated,',');
    end
end
end

function est = estimateKnownSweepFrf(time,inputSignal,outputSignal,fStart,fStop,sweepDuration,cfg)
u = inputSignal(:)-mean(inputSignal);
y = outputSignal(:)-mean(outputSignal);
ua = hilbert(u);
ya = hilbert(y);
active = time >= cfg.edgeFraction*sweepDuration & ...
    time <= (1-cfg.edgeFraction)*sweepDuration;
frequency = NaN(size(time));
frequency(active) = fStart*(fStop/fStart).^(time(active)/sweepDuration);
logProgress = NaN(size(time));
logProgress(active)=log(frequency(active)/fStart)/log(fStop/fStart);
sweepReliability=cfg.sweepEdgeWeightFloor+ ...
    (1-cfg.sweepEdgeWeightFloor)*sin(pi*logProgress).^2;
threshold = cfg.minInputEnvelope*median(abs(ua(active)));
active = active & abs(ua)>=threshold;

nBins = max(4,ceil(cfg.pointsPerDecade*log10(fStop/fStart)));
edges = logspace(log10(fStart),log10(fStop),nBins+1);
f = NaN(nBins,1); response = NaN(nBins,1); coherence = NaN(nBins,1);
excitation = NaN(nBins,1); sweepWeight = NaN(nBins,1);
uRms = sqrt(mean(abs(ua(active)).^2));
for k = 1:nBins
    mask = active & frequency>=edges(k) & frequency<edges(k+1);
    if nnz(mask)<cfg.minSamplesPerBin, continue; end
    cross = sum(ya(mask).*conj(ua(mask)));
    pu = sum(abs(ua(mask)).^2);
    py = sum(abs(ya(mask)).^2);
    f(k) = sum(frequency(mask).*abs(ua(mask)).^2)/pu;
    response(k) = cross/pu;
    coherence(k) = min(1,abs(cross)^2/max(eps,pu*py));
    excitation(k) = median(abs(ua(mask)))/max(eps,uRms);
    sweepWeight(k) = sum(abs(ua(mask)).^2.*sweepReliability(mask))/pu;
end
keep = isfinite(f) & isfinite(response) & isfinite(coherence);
est = struct('f',f(keep),'response',response(keep),'coherence',coherence(keep), ...
    'excitation',excitation(keep),'sweepWeight',sweepWeight(keep), ...
    'band',strings(nnz(keep),1),'capture',strings(nnz(keep),1));
end

function est = labelEstimate(est,cap)
est.band(:) = string(cap.band);
est.capture(:) = string(cap.captureId);
end

function stitched = stitchFrf(raw,cfg)
valid = isfinite(raw.f) & isfinite(raw.response) & raw.f>0 & ...
    raw.excitation>=cfg.minInputEnvelope & isfinite(raw.sweepWeight);
f=raw.f(valid); h=raw.response(valid); c=raw.coherence(valid);
e=raw.excitation(valid); sw=raw.sweepWeight(valid);
assert(~isempty(f),'No hay puntos espectrales válidos.');
nBins=max(4,ceil(cfg.stitchPointsPerDecade*log10(max(f)/min(f))));
edges=logspace(log10(min(f)),log10(max(f)),nBins+1);
of=NaN(nBins,1); oh=NaN(nBins,1); oc=NaN(nBins,1); spread=NaN(nBins,1); count=zeros(nBins,1);
for k=1:nBins
    mask=f>=edges(k)&f<edges(k+1);
    if ~any(mask),continue;end
    w=max(.02,c(mask)).^2.*min(2,e(mask)).*sw(mask);
    of(k)=exp(sum(w.*log(f(mask)))/sum(w));
    oh(k)=sum(w.*h(mask))/sum(w);
    oc(k)=sum(w.*c(mask))/sum(w);
    spread(k)=sqrt(sum(w.*(20*log10(abs(h(mask)./oh(k)))).^2)/sum(w));
    count(k)=nnz(mask);
end
keep=isfinite(of)&isfinite(oh);
stitched=struct('f',of(keep),'response',oh(keep),'coherence',oc(keep), ...
    'spreadDb',spread(keep),'count',count(keep));
end

function model = fitContinuousModel(stitched,mask,order)
data=idfrd(reshape(stitched.response(mask),1,1,[]),2*pi*stitched.f(mask),0);
options=tfestOptions('Display','off'); options.EnforceStability=true;
model=tfest(data,order(1),order(2),options);
end

function ideal = idealModels(cfg)
RinBp=43e3;RfBp=43e3;CinBp=680e-6;CfBp=177e-12;
RsumFeedback=27e3;Csum=15e-9;
R1=30e3;R2=150e3;R3=12e3;C1=47e-9;C2=3.3e-9;
Ru=7.5e3;Rbp=8.2e3;wpU=1/Ru;wpBp=1/Rbp;

% Referencias antiguas con amplificador operacional matemáticamente ideal.
ideal.BP_OPAMP_IDEAL=makeBp(RinBp,RfBp,CinBp,CfBp);
ideal.SUM_OPAMP_IDEAL=tf(-RsumFeedback,[RsumFeedback*Csum 1]);
ideal.LP_OPAMP_IDEAL=tf(-(R2/R1), ...
    [R2*R3*C1*C2,C2*(R2+R3+R2*R3/R1),1]);
bpA2=RinBp*RfBp*CinBp*CfBp;
bpA1=RinBp*CinBp+RfBp*CfBp;
compensationW0=sqrt(1/bpA2);
compensationZeta1=bpA1/(2*sqrt(bpA2));
compensationZeta0=0.25;
compensationGain=-RsumFeedback/Ru;
antiAlias=tf(1,[RsumFeedback*Csum 1]);
compensationShape=tf([1 2*compensationZeta0*compensationW0 compensationW0^2], ...
    [1 2*compensationZeta1*compensationW0 compensationW0^2]);
ideal.COMP_TARGET=minreal(compensationGain*compensationShape*antiAlias,1e-9);
ideal.COMP=ideal.COMP_TARGET;
ideal.COMP_OPAMP_IDEAL=minreal(ideal.SUM_OPAMP_IDEAL* ...
    (wpU+wpBp*ideal.BP_OPAMP_IDEAL),1e-9);
ideal.LP_PGA_OPAMP_IDEAL=minreal(ideal.LP_OPAMP_IDEAL* ...
    ideal.SUM_OPAMP_IDEAL*(wpU+wpBp*ideal.BP_OPAMP_IDEAL),1e-9);

% PSoC 5LP en modo High: A(s) de un polo, Rin y Rout finitos. La carga
% del BP es la rama de 8.2 k del sumador y la del SUM se aproxima por R1 LP.
ideal.BP=makeBpNonideal(RinBp,RfBp,CinBp,CfBp,Rbp,cfg.opamp);
ideal.SUM=makeSumNonideal(RsumFeedback,Csum,Ru,Rbp,R1,cfg.opamp);
ideal.LP=makeMfbLowpassNonideal(R1,R2,R3,C1,C2,cfg.opamp);
ideal.COMP_CIRCUIT=minreal(ideal.SUM*(wpU+wpBp*ideal.BP),1e-9);
ideal.LP_PGA=minreal(ideal.LP*ideal.SUM*(wpU+wpBp*ideal.BP),1e-9);

% Curva conservadora de dinámica AC con el GBW mínimo especificado (3 MHz).
psocMinimum=cfg.opamp;
psocMinimum.GainBandwidthHz=cfg.opamp.DataSheetMinimumGainBandwidthHz;
psocMinimum.DominantPoleHz=psocMinimum.GainBandwidthHz/psocMinimum.OpenLoopGain;
ideal.BP_PSOC_MIN=makeBpNonideal(RinBp,RfBp,CinBp,CfBp,Rbp,psocMinimum);
ideal.SUM_PSOC_MIN=makeSumNonideal(RsumFeedback,Csum,Ru,Rbp,R1,psocMinimum);
ideal.LP_PSOC_MIN=makeMfbLowpassNonideal(R1,R2,R3,C1,C2,psocMinimum);
ideal.COMP_PSOC_MIN=minreal(ideal.SUM_PSOC_MIN* ...
    (wpU+wpBp*ideal.BP_PSOC_MIN),1e-9);
ideal.LP_PGA_PSOC_MIN=minreal(ideal.LP_PSOC_MIN*ideal.SUM_PSOC_MIN* ...
    (wpU+wpBp*ideal.BP_PSOC_MIN),1e-9);
bpNumeratorCoefficient=RfBp*CinBp/bpA2;
realizedZeta=compensationZeta1-(Ru/Rbp)* ...
    bpNumeratorCoefficient/(2*compensationW0);
requiredRbp=Ru*bpNumeratorCoefficient/ ...
    (2*compensationW0*(compensationZeta1-compensationZeta0));
ideal.compensation=struct('Zeta0',compensationZeta0, ...
    'Zeta1',compensationZeta1,'RealizedZeta',realizedZeta, ...
    'W0RadPerS',compensationW0,'F0Hz',compensationW0/(2*pi), ...
    'GainVPerV',compensationGain, ...
    'AntiAliasPoleHz',1/(2*pi*RsumFeedback*Csum), ...
    'RequiredRbpOhm',requiredRbp,'InstalledRbpOhm',Rbp);
zeta=0.25;w0=2*pi*10;
ideal.GEOPHONE=tf([zeta*w0 0],[1 zeta*w0 w0^2]);
ideal.GEO_LP=minreal(ideal.GEOPHONE*ideal.LP_PGA,1e-9);
ideal.GEO_LP_OPAMP_IDEAL=minreal(ideal.GEOPHONE*ideal.LP_PGA_OPAMP_IDEAL,1e-9);
ideal.GEO_LP_PSOC_MIN=minreal(ideal.GEOPHONE*ideal.LP_PGA_PSOC_MIN,1e-9);
end

function model=makeBp(Rin,Rf,Cin,Cf)
model=tf([-Rf*Cin 0],[Rin*Rf*Cin*Cf,Rin*Cin+Rf*Cf,1]);
end

function model=makeBpNonideal(Rin,Rf,Cin,Cf,Rload,opamp)
s=tf('s');
A=opAmpOpenLoop(opamp);
yin=s*Cin/(1+s*Rin*Cin);
yf=1/Rf+s*Cf;
yamp=1/opamp.InputResistanceOhm+s*opamp.InputCapacitanceF;
yload=1/Rload;
a11=yin+yf+yamp;
a12=-yf;
a21=A/opamp.OutputResistanceOhm-yf;
a22=1/opamp.OutputResistanceOhm+yf+yload;
model=minreal((-a21*yin)/(a11*a22-a12*a21),1e-8);
end

function model=makeSumNonideal(Rfeedback,Csum,Ru,Rbp,Rload,opamp)
s=tf('s');
zf=Rfeedback/(1+s*Rfeedback*Csum);
A=opAmpOpenLoop(opamp);
noiseGain=1+zf*(1/Ru+1/Rbp+1/opamp.InputResistanceOhm+ ...
    s*opamp.InputCapacitanceF);
outputDivider=Rload/(Rload+opamp.OutputResistanceOhm);
model=minreal((-zf)*outputDivider/(1+noiseGain/A),1e-8);
end

function model=makeMfbLowpassNonideal(R1,R2,R3,C1,C2,opamp)
% C1 va del nodo intermedio a masa y C2 del inversor a la salida. Esta
% asignación reproduce exactamente la ecuación nominal suministrada.
s=tf('s');
A=opAmpOpenLoop(opamp);
a=1/R1+1/R2+1/R3+s*C1;
b=-1/R3;
c=-1/R2;
d=-1/R3;
e=1/R3+s*C2+1/opamp.InputResistanceOhm+s*opamp.InputCapacitanceF;
f=-s*C2;
g=-1/R2;
h=-s*C2+A/opamp.OutputResistanceOhm;
i=1/R2+s*C2+1/opamp.OutputResistanceOhm;
determinant=a*(e*i-f*h)-b*(d*i-f*g)+c*(d*h-e*g);
model=minreal((1/R1)*(d*h-e*g)/determinant,1e-8);
end

function A=opAmpOpenLoop(opamp)
A=tf(opamp.OpenLoopGain,[1/(2*pi*opamp.DominantPoleHz) 1]);
end

function row=stageMetrics(name,processed,raw,mask,model,ideal,monteCarlo)
f=processed.f(mask);h=processed.response(mask);hm=responseAt(model,f);
[fitMag,fitPhase]=responseErrors(h,hm);
row=emptySummaryRow(); row.Stage=string(name);row.PointsUsed=nnz(mask);
row.MinFrequencyHz=min(f);row.MaxFrequencyHz=max(f);row.MedianCoherence=median(processed.coherence(mask));
row.TfestMagnitudeRmseDb=fitMag;row.TfestPhaseRmseDeg=fitPhase;
poles=pole(model);pf=sort(abs(poles)/(2*pi));row.IdentifiedF1Hz=pf(1);
if numel(pf)>1,row.IdentifiedF2Hz=pf(end);end
if numel(poles)==2&&any(abs(imag(poles))>0),row.IdentifiedQ=abs(poles(1))/max(eps,-2*real(poles(1)));end

rawAt=interp1(log(raw.f),raw.response,log(f),'linear',NaN);
[row.FilterChangeMagnitudeRmseDb,row.FilterChangePhaseRmseDeg]=responseErrors(h,rawAt);
[row.PsocMinimumMagnitudeRmseDb,row.PsocMinimumPhaseRmseDeg]= ...
    responseErrors(h,responseAt(ideal.([name '_PSOC_MIN']),f));
row.PsocMinimumReference="PSoC 5LP, GBW mínimo 3 MHz";
switch name
    case 'BP'
        row.SignalDefinition="CH2(BP) / CH1(PGA)";
        [row.IdealMagnitudeRmseDb,row.IdealPhaseRmseDeg]=responseErrors(h,responseAt(ideal.BP,f));
        [row.OpAmpIdealMagnitudeRmseDb,row.OpAmpIdealPhaseRmseDeg]= ...
            responseErrors(h,responseAt(ideal.BP_OPAMP_IDEAL,f));
        row.IdealReference="BP nominal + PSoC High";
        row.OpAmpIdealReference="BP con operacional ideal";
        row.IdentificationStatus="parcial: polo inferior fuera de banda; alta frecuencia no ideal";
    case 'COMP'
        row.SignalDefinition="CH3(compensador) / CH1(PGA)";
        [row.IdealMagnitudeRmseDb,row.IdealPhaseRmseDeg]= ...
            responseErrors(h,responseAt(ideal.COMP_TARGET,f));
        [row.OpAmpIdealMagnitudeRmseDb,row.OpAmpIdealPhaseRmseDeg]= ...
            responseErrors(h,responseAt(ideal.COMP_OPAMP_IDEAL,f));
        [row.AlternativeMagnitudeRmseDb,row.AlternativePhaseRmseDeg]= ...
            responseErrors(h,responseAt(ideal.COMP_CIRCUIT,f));
        row.IdealReference="-3.6*Hcompensate/(1+s*27k*15n)";
        row.OpAmpIdealReference="componentes actuales, operacional ideal";
        row.AlternativeReference="componentes actuales, PSoC High";
        row.IdentificationStatus=sprintf( ...
            'objetivo zeta0=%.4g; componentes actuales producen zeta=%.5g', ...
            ideal.compensation.Zeta0,ideal.compensation.RealizedZeta);
    case 'LP'
        row.SignalDefinition="CH4(ADC/LP) / CH3(compensador)";
        [row.IdealMagnitudeRmseDb,row.IdealPhaseRmseDeg]=responseErrors(h,responseAt(ideal.LP,f));
        [row.OpAmpIdealMagnitudeRmseDb,row.OpAmpIdealPhaseRmseDeg]= ...
            responseErrors(h,responseAt(ideal.LP_OPAMP_IDEAL,f));
        row.IdealReference="MFB nominal + PSoC High";
        row.OpAmpIdealReference="MFB con operacional ideal";
        row.IdentificationStatus="confiable en la banda útil seleccionada";
    case 'LP_PGA'
        row.SignalDefinition="Cadena PGA->ADC medida directamente: CH4/CH1";
        [row.IdealMagnitudeRmseDb,row.IdealPhaseRmseDeg]=responseErrors(h,responseAt(ideal.LP_PGA,f));
        [row.OpAmpIdealMagnitudeRmseDb,row.OpAmpIdealPhaseRmseDeg]= ...
            responseErrors(h,responseAt(ideal.LP_PGA_OPAMP_IDEAL,f));
        row.IdealReference="Hlp*Hsum*(1/7.5k + Hbp/8.2k), PSoC High";
        row.OpAmpIdealReference="Cadena PGA->ADC con operacionales ideales";
        row.IdentifiedF1Hz=NaN;row.IdentifiedF2Hz=NaN;
        row.IdentificationStatus="confiable en banda útil; dinámica subsónica no observable";
    case 'GEO_LP'
        row.SignalDefinition="Cadena GEO->ADC calculada: Hgeo nominal * CH4/CH1";
        [row.IdealMagnitudeRmseDb,row.IdealPhaseRmseDeg]=responseErrors(h,responseAt(ideal.GEO_LP,f));
        [row.OpAmpIdealMagnitudeRmseDb,row.OpAmpIdealPhaseRmseDeg]= ...
            responseErrors(h,responseAt(ideal.GEO_LP_OPAMP_IDEAL,f));
        row.IdealReference="Hgeo*Hlp*Hsum*(1/7.5k + Hbp/8.2k), PSoC High";
        row.OpAmpIdealReference="Cadena GEO->ADC con operacionales ideales";
        row.IdentifiedF1Hz=NaN;row.IdentifiedF2Hz=NaN;
        row.IdentificationStatus="calculada con Hgeo nominal; no es una quinta medición";
end

envelope=toleranceEnvelope(monteCarlo,name,f,ideal);
measuredMagnitude=20*log10(abs(h));
measuredPhase=alignPhase(unwrap(angle(h))*180/pi,envelope.nominalPhaseDeg);
row.MagnitudeInsideMonteCarloPercent=100*mean(measuredMagnitude>=envelope.magnitudeMinDb & ...
    measuredMagnitude<=envelope.magnitudeMaxDb);
row.PhaseInsideMonteCarloPercent=100*mean(measuredPhase>=envelope.phaseMinDeg & ...
    measuredPhase<=envelope.phaseMaxDeg);
end

function [mag,phase]=responseErrors(a,b)
valid=isfinite(a)&isfinite(b)&abs(a)>0&abs(b)>0;
if ~any(valid),mag=NaN;phase=NaN;return;end
mag=sqrt(mean((20*log10(abs(a(valid)./b(valid)))).^2));
phase=sqrt(mean((angle(a(valid).*conj(b(valid)))*180/pi).^2));
end

function h=responseAt(model,f)
h=squeeze(freqresp(model,2*pi*f));h=h(:);
end

function out=multiplyFrf(in,model)
out=in;
out.response=in.response.*responseAt(model,in.f);
end

function plotStage(name,raw,processed,model,ideal,monteCarlo,cfg,outputRoot)
f=processed.f;h=processed.response;gridF=logspace(log10(min(f)),log10(max(f)),900).';hm=responseAt(model,gridF);
envelope=toleranceEnvelope(monteCarlo,name,gridF,ideal);
fig=figure('Visible',onOff(cfg.showFigures),'Color','w','Position',[100 100 1100 820]);
layout=tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
nexttile;fill([gridF;flipud(gridF)],[envelope.magnitudeMinDb;flipud(envelope.magnitudeMaxDb)], ...
    [0.55 0.78 1],'FaceAlpha',0.28,'EdgeColor','none', ...
    'DisplayName',sprintf('Monte Carlo min-max (N=%d)',monteCarlo.sampleCount));
set(gca,'XScale','log');hold on;
semilogx(gridF,envelope.magnitudeMinDb,'Color',[0.35 0.65 0.92], ...
    'LineWidth',0.7,'HandleVisibility','off');
semilogx(gridF,envelope.magnitudeMaxDb,'Color',[0.35 0.65 0.92], ...
    'LineWidth',0.7,'HandleVisibility','off');
semilogx(raw.f,20*log10(abs(raw.response)),'.','Color',[.7 .7 .7],'DisplayName','Cruda');
semilogx(f,20*log10(abs(h)),'ko','MarkerSize',4,'DisplayName','Procesada');
semilogx(gridF,20*log10(abs(hm)),'LineWidth',1.6,'DisplayName','tfest');plotIdeal(name,ideal,gridF,false,[]);
grid on;ylabel('Magnitud (dB)');legend('Location','best');
nexttile;rawPhase=unwrap(angle(raw.response))*180/pi;procPhase=unwrap(angle(h))*180/pi;
phaseShift=360*round((median(procPhase)-median(envelope.nominalPhaseDeg))/360);
phaseMin=envelope.phaseMinDeg+phaseShift;phaseMax=envelope.phaseMaxDeg+phaseShift;
fill([gridF;flipud(gridF)],[phaseMin;flipud(phaseMax)], ...
    [0.55 0.78 1],'FaceAlpha',0.28,'EdgeColor','none','DisplayName','Monte Carlo min-max');
set(gca,'XScale','log');hold on;
semilogx(gridF,phaseMin,'Color',[0.35 0.65 0.92], ...
    'LineWidth',0.7,'HandleVisibility','off');
semilogx(gridF,phaseMax,'Color',[0.35 0.65 0.92], ...
    'LineWidth',0.7,'HandleVisibility','off');
semilogx(raw.f,rawPhase,'.','Color',[.7 .7 .7],'DisplayName','Cruda');
semilogx(f,procPhase,'ko','MarkerSize',4,'DisplayName','Procesada');
semilogx(gridF,alignPhase(unwrap(angle(hm))*180/pi,procPhase),'LineWidth',1.6,'DisplayName','tfest');
plotIdeal(name,ideal,gridF,true,procPhase);grid on;ylabel('Fase (grados)');
coherenceThreshold=cfg.minFitCoherence;
nexttile;semilogx(f,processed.coherence,'o-');hold on;
yline(coherenceThreshold,'--','Umbral');grid on;ylim([0 1.05]);
ylabel('Coherencia local');xlabel('Frecuencia (Hz)');
[displayName,baseName]=stagePresentation(name);
if strcmp(name,'COMP')
    title(layout,sprintf('%s: medición, tfest, Hcompensate, componentes y tolerancias', ...
        displayName),'Interpreter','none');
else
    title(layout,sprintf('%s: medición, tfest, PSoC High, ideal y tolerancias', ...
        displayName),'Interpreter','none');
end
base=fullfile(outputRoot,baseName);
exportgraphics(fig,[base '.png'],'Resolution',180);savefig(fig,[base '.fig']);
if cfg.showFigures,drawnow;else,close(fig);end
end

function [displayName,baseName]=stagePresentation(name)
switch name
    case 'BP'
        displayName='Etapa BP (CH2/CH1)';baseName='identificacion_bp';
    case 'COMP'
        displayName='Compensador con antialias (CH3/PGA)';baseName='compensador_pga';
    case 'LP'
        displayName='Etapa LP (CH4/CH3)';baseName='identificacion_lp';
    case 'LP_PGA'
        displayName='Cadena completa PGA -> ADC (CH4/CH1)';baseName='cadena_pga_adc';
    case 'GEO_LP'
        displayName='Cadena completa GEO -> ADC (Hgeo * CH4/CH1)';baseName='cadena_geo_adc';
    otherwise
        error('Presentación no definida para %s.',name);
end
end

function monteCarlo=createMonteCarloSamples(cfg)
state=rng;cleanup=onCleanup(@()rng(state)); %#ok<NASGU>
rng(cfg.monteCarloSeed,'twister');n=cfg.monteCarloSamples;t=cfg.tolerance;
monteCarlo.sampleCount=n;monteCarlo.seed=cfg.monteCarloSeed;
monteCarlo.opamp=cfg.opamp;
monteCarlo.frequencyChunkSize=cfg.monteCarloFrequencyChunkSize;
monteCarlo.RinBp=sampleComponent(43e3,n,t.resistorMinus,t.resistorPlus);
monteCarlo.RfBp=sampleComponent(43e3,n,t.resistorMinus,t.resistorPlus);
monteCarlo.CinBp=sampleComponent(680e-6,n,t.electrolyticMinus,t.electrolyticPlus);
monteCarlo.CfBp150=sampleComponent(150e-12,n,t.ceramicMinus,t.ceramicPlus);
monteCarlo.CfBp27=sampleComponent(27e-12,n,t.ceramicMinus,t.ceramicPlus);
monteCarlo.RsumFeedback=sampleComponent(27e3,n,t.resistorMinus,t.resistorPlus);
monteCarlo.Csum=sampleComponent(15e-9,n,t.ceramicMinus,t.ceramicPlus);
monteCarlo.R1Lp=sampleComponent(30e3,n,t.resistorMinus,t.resistorPlus);
monteCarlo.R2Lp=sampleComponent(150e3,n,t.resistorMinus,t.resistorPlus);
monteCarlo.R3Lp=sampleComponent(12e3,n,t.resistorMinus,t.resistorPlus);
monteCarlo.C1Lp=sampleComponent(47e-9,n,t.ceramicMinus,t.ceramicPlus);
monteCarlo.C2Lp=sampleComponent(3.3e-9,n,t.ceramicMinus,t.ceramicPlus);
monteCarlo.RwpU=sampleComponent(7.5e3,n,t.resistorMinus,t.resistorPlus);
monteCarlo.RwpBp=sampleComponent(8.2e3,n,t.resistorMinus,t.resistorPlus);
end

function values=sampleComponent(nominal,count,minusTolerance,plusTolerance)
relative=-minusTolerance+(minusTolerance+plusTolerance)*rand(count,1);
values=nominal*(1+relative);
end

function response=monteCarloResponse(monteCarlo,name,f)
s=1i*2*pi*reshape(f,1,[]);
switch name
    case 'BP'
        response=bpNonidealResponse(monteCarlo,s);
    case 'COMP'
        hBp=bpNonidealResponse(monteCarlo,s);
        hSum=sumNonidealResponse(monteCarlo,s);
        response=hSum.*(1./monteCarlo.RwpU+hBp./monteCarlo.RwpBp);
    case 'LP'
        response=lpNonidealResponse(monteCarlo,s);
    case {'LP_PGA','GEO_LP'}
        hBp=bpNonidealResponse(monteCarlo,s);
        hSum=sumNonidealResponse(monteCarlo,s);
        hLp=lpNonidealResponse(monteCarlo,s);
        response=hLp.*hSum.*(1./monteCarlo.RwpU+hBp./monteCarlo.RwpBp);
        if strcmp(name,'GEO_LP')
            zeta=0.25;w0=2*pi*10;
            hGeo=(zeta*w0*s)./(s.^2+zeta*w0*s+w0^2);
            response=response.*hGeo;
        end
    otherwise
        error('Etapa Monte Carlo desconocida: %s',name);
end
end

function response=bpNonidealResponse(mc,s)
op=mc.opamp;
A=op.OpenLoopGain./(1+s/(2*pi*op.DominantPoleHz));
cf=mc.CfBp150+mc.CfBp27;
yin=s.*mc.CinBp./(1+s.*mc.RinBp.*mc.CinBp);
yf=1./mc.RfBp+s.*cf;
yamp=1/op.InputResistanceOhm+s*op.InputCapacitanceF;
a11=yin+yf+yamp;
a21=A/op.OutputResistanceOhm-yf;
a22=1/op.OutputResistanceOhm+yf+1./mc.RwpBp;
response=(-a21.*yin)./(a11.*a22+yf.*a21);
end

function response=sumNonidealResponse(mc,s)
op=mc.opamp;
A=op.OpenLoopGain./(1+s/(2*pi*op.DominantPoleHz));
zf=mc.RsumFeedback./(1+s.*mc.RsumFeedback.*mc.Csum);
noiseGain=1+zf.*(1./mc.RwpU+1./mc.RwpBp+ ...
    1/op.InputResistanceOhm+s*op.InputCapacitanceF);
outputDivider=mc.R1Lp./(mc.R1Lp+op.OutputResistanceOhm);
response=(-zf).*outputDivider./(1+noiseGain./A);
end

function response=lpNonidealResponse(mc,s)
op=mc.opamp;
A=op.OpenLoopGain./(1+s/(2*pi*op.DominantPoleHz));
a=1./mc.R1Lp+1./mc.R2Lp+1./mc.R3Lp+s.*mc.C1Lp;
b=-1./mc.R3Lp;
c=-1./mc.R2Lp;
d=b;
e=1./mc.R3Lp+s.*mc.C2Lp+1/op.InputResistanceOhm+ ...
    s*op.InputCapacitanceF;
f=-s.*mc.C2Lp;
g=c;
h=-s.*mc.C2Lp+A/op.OutputResistanceOhm;
i=1./mc.R2Lp+s.*mc.C2Lp+1/op.OutputResistanceOhm;
determinant=a.*(e.*i-f.*h)-b.*(d.*i-f.*g)+c.*(d.*h-e.*g);
response=(1./mc.R1Lp).*(d.*h-e.*g)./determinant;
end

function envelope=toleranceEnvelope(monteCarlo,name,f,ideal)
nominalModel=ideal.(name);
if strcmp(name,'COMP'),nominalModel=ideal.COMP_CIRCUIT;end
nominalPhase=unwrap(angle(responseAt(nominalModel,f)))*180/pi;
nFrequency=numel(f);
envelope.magnitudeMinDb=NaN(nFrequency,1);
envelope.magnitudeMaxDb=NaN(nFrequency,1);
envelope.phaseMinDeg=NaN(nFrequency,1);
envelope.phaseMaxDeg=NaN(nFrequency,1);
for first=1:monteCarlo.frequencyChunkSize:nFrequency
    index=first:min(nFrequency,first+monteCarlo.frequencyChunkSize-1);
    response=monteCarloResponse(monteCarlo,name,f(index));
    magnitude=20*log10(abs(response)+eps);
    phase=unwrap(angle(response),[],2)*180/pi;
    anchor=max(1,round(numel(index)/2));
    phase=phase+360*round((nominalPhase(index(anchor))-phase(:,anchor))/360);
    envelope.magnitudeMinDb(index)=min(magnitude,[],1).';
    envelope.magnitudeMaxDb(index)=max(magnitude,[],1).';
    envelope.phaseMinDeg(index)=min(phase,[],1).';
    envelope.phaseMaxDeg(index)=max(phase,[],1).';
end
envelope.nominalPhaseDeg=nominalPhase;
end

function tableOut=toleranceTable(cfg)
ComponentClass=["Resistencia";"Cerámico <=100 nF";"Electrolítico >100 nF"];
MinusPercent=100*[cfg.tolerance.resistorMinus;cfg.tolerance.ceramicMinus;cfg.tolerance.electrolyticMinus];
PlusPercent=100*[cfg.tolerance.resistorPlus;cfg.tolerance.ceramicPlus;cfg.tolerance.electrolyticPlus];
Distribution=repmat("uniforme independiente",3,1);
Samples=repmat(cfg.monteCarloSamples,3,1);
Seed=repmat(cfg.monteCarloSeed,3,1);
tableOut=table(ComponentClass,MinusPercent,PlusPercent,Distribution,Samples,Seed);
end

function tableOut=compensationParameterTable(ideal)
c=ideal.compensation;
Parameter=["zeta0_objetivo";"zeta1_denominador_BP"; ...
    "zeta_realizada_componentes";"w0";"f0";"ganancia_DC"; ...
    "polo_antialias";"R_BP_instalada";"R_BP_requerida_para_zeta0"];
Value=[c.Zeta0;c.Zeta1;c.RealizedZeta;c.W0RadPerS;c.F0Hz; ...
    c.GainVPerV;c.AntiAliasPoleHz;c.InstalledRbpOhm;c.RequiredRbpOhm];
Unit=["1";"1";"1";"rad/s";"Hz";"V/V";"Hz";"ohm";"ohm"];
Description=["Numerador de Hcompensate";"Calculada del denominador BP nominal"; ...
    "Resultado analítico de 1+(Ru/Rbp)Hbp";"Frecuencia natural BP"; ...
    "Frecuencia natural BP";"-27k/7.5k";"1/(2*pi*27k*15n)"; ...
    "Valor usado en la rama BP";"Valor ideal con componentes nominales"];
tableOut=table(Parameter,Value,Unit,Description);
end

function tableOut=measurementGainRecommendation(saturationTable,cfg)
keys=unique(saturationTable(:,{'Band','Capture'}),'rows','stable');
n=height(keys);maximumAbsolute=NaN(n,4);
recommendedMultiplier=NaN(n,1);multiplierToThreshold=NaN(n,1);
limitingChannel=strings(n,1);
for k=1:n
    rows=saturationTable.Band==keys.Band(k)& ...
        saturationTable.Capture==keys.Capture(k);
    for channel=1:4
        index=find(rows&saturationTable.Channel==channel,1);
        if ~isempty(index),maximumAbsolute(k,channel)=saturationTable.MaximumAbsoluteV(index);end
    end
    [limitingPeak,channel]=max(maximumAbsolute(k,:));
    recommendedMultiplier(k)=cfg.saturation.recommendedTargetV/max(eps,limitingPeak);
    multiplierToThreshold(k)=cfg.saturation.absoluteVoltageThresholdV/max(eps,limitingPeak);
    limitingChannel(k)=sprintf('CH%d',channel);
end
tableOut=table(keys.Band,keys.Capture,maximumAbsolute(:,1),maximumAbsolute(:,2), ...
    maximumAbsolute(:,3),maximumAbsolute(:,4), ...
    repmat(cfg.saturation.recommendedTargetV,n,1),recommendedMultiplier, ...
    multiplierToThreshold,limitingChannel, ...
    'VariableNames',{'Band','Capture','MaximumAbsoluteCH1V','MaximumAbsoluteCH2V', ...
    'MaximumAbsoluteCH3V','MaximumAbsoluteCH4V','RecommendedTargetPeakV', ...
    'RecommendedGeneratorAmplitudeMultiplier','MultiplierToSaturationThreshold', ...
    'LimitingChannel'});
end

function tableOut=opAmpParameterTable(cfg)
op=cfg.opamp;
Parameter=["SR_modelo";"Rin";"Rout";"Ganancia_lazo_abierto"; ...
    "GBW_modelo_High";"Polo_dominante_modelo";"Cin_max_datasheet"; ...
    "GBW_min_datasheet";"SR_min_datasheet";"Ruido_entrada_tipico"; ...
    "Offset_entrada_max"];
Value=[op.SlewRateVPerS;op.InputResistanceOhm;op.OutputResistanceOhm; ...
    op.OpenLoopGain;op.GainBandwidthHz;op.DominantPoleHz; ...
    op.InputCapacitanceF;op.DataSheetMinimumGainBandwidthHz; ...
    op.DataSheetMinimumSlewRateVPerS;op.InputNoiseDensityVPerSqrtHz; ...
    op.InputOffsetMaxV];
Unit=["V/s";"ohm";"ohm";"V/V";"Hz";"Hz";"F";"Hz";"V/s"; ...
    "V/sqrt(Hz)";"V"];
UseInAnalysis=["límite no lineal";"TF";"TF";"TF";"TF PSoC High"; ...
    "TF";"TF, peor caso";"curva conservadora";"límite conservador"; ...
    "documentado, no inyecta ruido sintético"; ...
    "documentado; eliminado al centrar las señales"];
tableOut=table(Parameter,Value,Unit,UseInAnalysis);
end

function tableOut=slewRateLimitTable(cfg)
frequencyHz=logspace(log10(min(cfg.expectedBands(:,1))), ...
    log10(max(cfg.expectedBands(:,2))),240).';
modelMaximumSinePeakV=cfg.opamp.SlewRateVPerS./(2*pi*frequencyHz);
dataSheetMinimumMaximumSinePeakV= ...
    cfg.opamp.DataSheetMinimumSlewRateVPerS./(2*pi*frequencyHz);
tableOut=table(frequencyHz,modelMaximumSinePeakV, ...
    dataSheetMinimumMaximumSinePeakV, ...
    'VariableNames',{'FrequencyHz','ModelMaximumSinePeakV', ...
    'DataSheetMinimumMaximumSinePeakV'});
end

function plotIdeal(name,ideal,f,phasePlot,reference)
if strcmp(name,'COMP')
    psocResponse=responseAt(ideal.COMP_CIRCUIT,f);
    targetResponse=responseAt(ideal.COMP_TARGET,f);
else
    psocResponse=responseAt(ideal.(name),f);
    targetResponse=[];
end
idealResponse=responseAt(ideal.([name '_OPAMP_IDEAL']),f);
minimumResponse=responseAt(ideal.([name '_PSOC_MIN']),f);
if phasePlot
    psocValue=alignPhase(unwrap(angle(psocResponse))*180/pi,reference);
    idealValue=alignPhase(unwrap(angle(idealResponse))*180/pi,reference);
    minimumValue=alignPhase(unwrap(angle(minimumResponse))*180/pi,reference);
    if ~isempty(targetResponse)
        targetValue=alignPhase(unwrap(angle(targetResponse))*180/pi,reference);
    end
else
    psocValue=20*log10(abs(psocResponse));
    idealValue=20*log10(abs(idealResponse));
    minimumValue=20*log10(abs(minimumResponse));
    if ~isempty(targetResponse),targetValue=20*log10(abs(targetResponse));end
end
if ~isempty(targetResponse)
    semilogx(f,targetValue,'k-','LineWidth',1.8, ...
        'DisplayName','Objetivo -3.6·Hcompensate·HAA');
end
semilogx(f,idealValue,':','Color',[0.45 0.2 0.65],'LineWidth',1.35, ...
    'DisplayName','Componentes actuales, operacional ideal');
semilogx(f,minimumValue,'-.','Color',[0.2 0.55 0.25],'LineWidth',1.25, ...
    'DisplayName','Componentes actuales, PSoC 3 MHz');
semilogx(f,psocValue,'--','Color',[0.85 0.25 0.12],'LineWidth',1.5, ...
    'DisplayName','Componentes actuales, PSoC High');
end

function phase=alignPhase(phase,reference)
if ~isempty(reference),phase=phase+360*round((median(reference)-median(phase))/360);end
end

function plotOscilloscopeCapture(cap,rawSignals,processed,cfg,outputRoot)
% La cruda conserva offset y escala CSV; la procesada está centrada y filtrada.
t=cap.time-cap.time(1);
duration=max(t);
if duration>=1
    scale=1;unit='s';
elseif duration>=1e-3
    scale=1e3;unit='ms';
else
    scale=1e6;unit='us';
end
channelNames={'CH1 · PGA','CH2 · BP','CH3 · COMPENSADOR','CH4 · LP'};
colors=[0.93 0.69 0.13;0.12 0.47 0.71;0.84 0.15 0.16;0.20 0.63 0.17];
fig=figure('Visible',onOff(cfg.showFigures),'Color','w','Position',[80 60 1250 880]);
layout=tiledlayout(fig,4,1,'TileSpacing','compact','Padding','compact');
for channel=1:4
    nexttile;
    rawColor=0.58*colors(channel,:)+0.42*[1 1 1];
    plot(t*scale,rawSignals(:,channel),'Color',rawColor,'LineWidth',0.75, ...
        'DisplayName','Cruda CSV');hold on;
    plot(t*scale,processed(:,channel),'Color',colors(channel,:),'LineWidth',1.05, ...
        'DisplayName','Procesada');
    grid on;ylabel(sprintf('CH%d (V)',channel));
    if cap.channelSaturated(channel)
        title([channelNames{channel} ' · SATURADO'],'Color',[0.75 0 0]);
    else
        title(channelNames{channel});
    end
    if channel==1,legend('Location','best');end
    if channel<4,set(gca,'XTickLabel',[]);else,xlabel(sprintf('Tiempo (%s)',unit));end
end
title(layout,sprintf('%s · %s · cruda CSV (x1) y procesada',cap.band,cap.captureId), ...
    'Interpreter','none');
safe=regexprep(sprintf('%s_%s',cap.band,cap.captureId),'[^a-zA-Z0-9._-]','_');
base=fullfile(outputRoot,['osciloscopio_' safe]);
exportgraphics(fig,[base '.png'],'Resolution',160);savefig(fig,[base '.fig']);
if cfg.showFigures,drawnow;else,close(fig);end
end

function plotPreprocessing(cap,raw,processed,lineInfo,cfg,outputRoot)
fig=figure('Visible',onOff(cfg.showFigures),'Color','w','Position',[100 100 1200 760]);
layout=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
for channel=1:4
    nexttile;[pr,f]=periodogram(raw(:,channel),hann(numel(cap.time)),max(4096,2^nextpow2(numel(cap.time))),cap.fs,'power');
    [pp,~]=periodogram(processed(:,channel),hann(numel(cap.time)),max(4096,2^nextpow2(numel(cap.time))),cap.fs,'power');
    semilogx(f(2:end),10*log10(pr(2:end)+eps),'Color',[.65 .65 .65],'DisplayName','Cruda');hold on;
    semilogx(f(2:end),10*log10(pp(2:end)+eps),'LineWidth',1,'DisplayName','Procesada');
    xlim([max(f(2),cap.fStart/4),min(cap.fs/2,cap.fStop*2)]);grid on;
    title(sprintf('CH%d · línea removida RMS %.3g V',channel,lineInfo.removedRmsV(channel)));
    xlabel('Hz');ylabel('PSD (dB/Hz)');if channel==1,legend('Location','best');end
end
title(layout,sprintf('%s · %s · Butterworth fase cero + armónicos LS', ...
    cap.band,cap.captureId),'Interpreter','none');
safe=regexprep(sprintf('%s_%s',cap.band,cap.captureId),'[^a-zA-Z0-9._-]','_');
base=fullfile(outputRoot,['preprocesamiento_' safe]);
exportgraphics(fig,[base '.png'],'Resolution',150);savefig(fig,[base '.fig']);
if cfg.showFigures,drawnow;else,close(fig);end
end

function value=onOff(condition)
if condition,value='on';else,value='off';end
end

function writeReport(results,filename)
fid=fopen(filename,'w');cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
if isempty(results.missingExpectedBands),missingText='ninguna';else,missingText=strjoin(results.missingExpectedBands,', ');end
fprintf(fid,'Análisis de sweeps de la cadena analógica\nDatos: %s\nEscala aplicada a las señales: x%.3g (sin conversión diferencial)\n', ...
    results.dataRoot,results.config.signalScale);
fprintf(fid,'Bandas faltantes: %s\n',missingText);
fprintf(fid,'Geófono nominal: zeta=0.25, w0=2*pi*10 rad/s\n');
fprintf(fid,['Cadena completa PGA->ADC: medida directamente como CH4/CH1 y ' ...
    'comparada con Hlp*Hsum*(1/7.5k + Hbp/8.2k).\n']);
fprintf(fid,['Cadena completa GEO->ADC: Hgeo nominal multiplicada por CH4/CH1 y ' ...
    'comparada con Hgeo*Hlp*Hsum*(1/7.5k + Hbp/8.2k).\n']);
c=results.ideal.compensation;
fprintf(fid,['Compensador verificado directamente como CH3/CH1. Objetivo: ' ...
    '(-27k/7.5k)*[(s^2+2*zeta0*w0*s+w0^2)/(s^2+2*zeta1*w0*s+w0^2)]' ...
    '*[1/(1+s*27k*15n)].\n']);
fprintf(fid,['Parámetros: zeta0=%.8g, zeta1=%.8g, w0=%.8g rad/s (%.8g Hz), ' ...
    'ganancia DC=%.8g V/V, polo antialias=%.8g Hz.\n'],c.Zeta0,c.Zeta1, ...
    c.W0RadPerS,c.F0Hz,c.GainVPerV,c.AntiAliasPoleHz);
fprintf(fid,['Con 8.2k instalados la combinación ideal de componentes produce ' ...
    'zeta=%.8g; para zeta0=%.8g se requieren aproximadamente %.8g ohm.\n'], ...
    c.RealizedZeta,c.Zeta0,c.RequiredRbpOhm);
fprintf(fid,['Saturación: cada captura se conserva para las etapas independientes ' ...
    'y se descarta por dependencia si |V| alcanza %.4g V. CH1/CH2 invalidan ' ...
    'BP, COMP, LP y cadena; ' ...
    'CH3 invalida COMP, LP y cadena; CH4 invalida LP y cadena.\n'], ...
    results.config.saturation.absoluteVoltageThresholdV);
op=results.config.opamp;
fprintf(fid,['Operacional PSoC High: A0=%.8g V/V (90 dB), GBW=%.8g Hz, ' ...
    'polo dominante=%.8g Hz, Rin=%.8g ohm, Rout=%.8g ohm, Cin=%.8g F.\n'], ...
    op.OpenLoopGain,op.GainBandwidthHz,op.DominantPoleHz, ...
    op.InputResistanceOhm,op.OutputResistanceOhm,op.InputCapacitanceF);
fprintf(fid,'Referencia conservadora datasheet: GBW mínimo %.8g Hz, SR mínimo %.8g V/s.\n', ...
    op.DataSheetMinimumGainBandwidthHz,op.DataSheetMinimumSlewRateVPerS);
fprintf(fid,['SR del modelo %.8g V/s: se evalúa como límite de gran señal, no ' ...
    'como parte de la TF lineal. Margen conservador mínimo observado: %.5g ' ...
    '(modelo), %.5g (SR mínimo datasheet).\n'],op.SlewRateVPerS, ...
    min(results.processing.SlewMarginToModel), ...
    min(results.processing.SlewMarginToDataSheetMinimum));
fprintf(fid,['Ruido de entrada (45 nV/sqrt(Hz)) y offset máximo (3 mV) quedan ' ...
    'documentados; no se agrega ruido sintético y el offset DC se elimina al centrar.\n']);
fprintf(fid,'Monte Carlo: %d muestras, semilla %d. R -%.3g/+%.3g %%; cerámicos -%.3g/+%.3g %%; electrolíticos -%.3g/+%.3g %%.\n', ...
    results.config.monteCarloSamples,results.config.monteCarloSeed, ...
    100*results.config.tolerance.resistorMinus,100*results.config.tolerance.resistorPlus, ...
    100*results.config.tolerance.ceramicMinus,100*results.config.tolerance.ceramicPlus, ...
    100*results.config.tolerance.electrolyticMinus,100*results.config.tolerance.electrolyticPlus);
fprintf(fid,'Nota: todos los CSV informan Probe Atten=1X; verificar que coincida con la sonda física.\n\n');
for name={'BP','COMP','LP','LP_PGA','GEO_LP'}
    sys=tf(results.models.(name{1}));[num,den]=tfdata(sys,'v');
    fprintf(fid,'===== %s =====\nNumerador: %s\nDenominador: %s\n',name{1},mat2str(num,10),mat2str(den,10));
    p=pole(sys);fprintf(fid,'Polos rad/s:\n');fprintf(fid,'  %.9g %+.9gj\n',[real(p),imag(p)].');fprintf(fid,'\n');
end
end

function raw=emptyRaw(names)
empty=struct('f',[],'response',[],'coherence',[],'excitation',[], ...
    'sweepWeight',[],'band',strings(0,1),'capture',strings(0,1));
for k=1:numel(names),raw.(names{k})=empty;end
end

function out=appendEstimate(out,in)
fields=fieldnames(out);for k=1:numel(fields),out.(fields{k})=[out.(fields{k});in.(fields{k})];end
end

function row=emptyHealthRow()
row=struct('Band',"",'Capture',"",'StartFrequencyHz',NaN,'StopFrequencyHz',NaN, ...
    'SweepDurationS',NaN,'SampleRateHz',NaN,'RecordDurationS',NaN, ...
    'ValidFraction',NaN,'InvalidCodeFraction',NaN,'SaturationFraction',NaN, ...
    'ProbeAttenuation',NaN,'AnySaturation',false,'SaturatedChannels',"");
end

function row=emptySaturationRow()
row=struct('Band',"",'Capture',"",'Channel',0,'PeakToPeakV',NaN, ...
    'PositivePeakV',NaN,'NegativePeakV',NaN,'MaximumAbsoluteV',NaN, ...
    'ThresholdV',NaN,'SamplesAtOrBeyondThreshold',0,'ThresholdFraction',NaN, ...
    'AutoSaturated',false, ...
    'FinalSaturated',false,'DecisionSource',"",'Reason',"");
end

function row=emptyUsageRow()
row=struct('Band',"",'Capture',"",'Stage',"",'Used',false, ...
    'ExclusionReason',"");
end

function row=emptyProcessingRow()
row=struct('Band',"",'Capture',"",'Channel',0,'AppliedSignalScale',NaN, ...
    'BandpassLowHz',NaN,'BandpassHighHz',NaN,'EstimatedLineF0Hz',NaN, ...
    'RemovedHarmonicsHz',"", ...
    'RemovedLineRmsV',NaN,'LineFitFraction',NaN,'RawRmsV',NaN, ...
    'ProcessedRmsV',NaN,'PeakAmplitudeV',NaN, ...
    'ConservativeSlewDemandVPerS',NaN,'SlewMarginToModel',NaN, ...
    'SlewMarginToDataSheetMinimum',NaN);
end

function row=emptySummaryRow()
row=struct('Stage',"",'SignalDefinition',"",'IdentificationStatus',"", ...
    'PointsUsed',0,'MinFrequencyHz',NaN,'MaxFrequencyHz',NaN, ...
    'MedianCoherence',NaN,'TfestMagnitudeRmseDb',NaN,'TfestPhaseRmseDeg',NaN, ...
    'IdentifiedF1Hz',NaN,'IdentifiedF2Hz',NaN,'IdentifiedQ',NaN, ...
    'FilterChangeMagnitudeRmseDb',NaN,'FilterChangePhaseRmseDeg',NaN, ...
    'IdealMagnitudeRmseDb',NaN,'IdealPhaseRmseDeg',NaN, ...
    'OpAmpIdealMagnitudeRmseDb',NaN,'OpAmpIdealPhaseRmseDeg',NaN, ...
    'PsocMinimumMagnitudeRmseDb',NaN,'PsocMinimumPhaseRmseDeg',NaN, ...
    'AlternativeMagnitudeRmseDb',NaN,'AlternativePhaseRmseDeg',NaN, ...
    'MagnitudeInsideMonteCarloPercent',NaN,'PhaseInsideMonteCarloPercent',NaN, ...
    'IdealReference',"",'OpAmpIdealReference',"", ...
    'PsocMinimumReference',"",'AlternativeReference',"");
end

function selected=keepLongRuns(mask,minLength)
selected=false(size(mask));runs=logicalRuns(mask);
for k=1:size(runs,1),if runs(k,2)-runs(k,1)+1>=minLength,selected(runs(k,1):runs(k,2))=true;end,end
end

function runs=logicalRuns(mask)
edges=diff([false;mask(:);false]);runs=[find(edges==1),find(edges==-1)-1];
end

function [fStart,fStop,duration]=parseBandFolder(name)
parts=split(string(name),'_');fStart=NaN;fStop=NaN;duration=NaN;
if numel(parts)<2,return;end
rangeParts=split(parts(1),'to');if numel(rangeParts)~=2,return;end
fStart=parseFrequency(rangeParts(1));fStop=parseFrequency(rangeParts(2));duration=parseDuration(parts(2));
end

function f=parseFrequency(text)
tok=regexp(char(text),'^([0-9]+(?:\.[0-9]+)?)(m|k|M)?Hz$','tokens','once');
if isempty(tok),f=NaN;return;end
factor=1;if strcmp(tok{2},'m'),factor=1e-3;elseif strcmpi(tok{2},'k'),factor=1e3;elseif strcmp(tok{2},'M'),factor=1e6;end
f=str2double(tok{1})*factor;
end

function t=parseDuration(text)
tok=regexp(char(text),'^([0-9]+(?:\.[0-9]+)?)(s|ms|us)$','tokens','once');
if isempty(tok),t=NaN;return;end
factor=1;if strcmp(tok{2},'ms'),factor=1e-3;elseif strcmp(tok{2},'us'),factor=1e-6;end
t=str2double(tok{1})*factor;
end
