function validation = validar_compensador_montado(showFigures)
%VALIDAR_COMPENSADOR_MONTADO Valida CH3/PGA sin modificar el análisis principal.
%
% Compara la FRF medida contra:
%   1) circuito montado: BP 43k/43k, 680uF, 177pF; adder 27k/15nF;
%   2) BP corregido: 43k/47k, 680uF, 177pF; mismo adder;
%   3) fila 13 del optimizador, reescalada a la ganancia del adder actual;
%   4) objetivo matemático usado por calculoCompensadorOptimo.py.

if nargin<1 || isempty(showFigures),showFigures=true;end
scriptDir=fileparts(mfilename('fullpath'));
cacheFile=fullfile(scriptDir,'resultados','00_cache','analisis_circuito.mat');
assert(isfile(cacheFile), ...
    'Primero ejecute analizar_sweeps_circuito para generar %s.',cacheFile);
cached=load(cacheFile,'results');
assert(isfield(cached,'results') && isfield(cached.results,'frfProcessed') && ...
    isfield(cached.results.frfProcessed,'COMP'), ...
    'La cache no contiene la FRF directa CH3/PGA.');
results=cached.results;
opamp=results.config.opamp;
models=compensatorModels(opamp);

measured=results.frfProcessed.COMP;
designMask=measured.f>=0.2 & measured.f<=500 & measured.coherence>=0.75;
assert(nnz(designMask)>=12,'No hay suficientes puntos coherentes entre 0.2 y 500 Hz.');
fMeasured=measured.f(designMask);
hMeasured=measured.response(designMask);

references={ ...
    'Montado 43k/43k, 177pF, 27k/15nF',models.asBuilt; ...
    'Corregido 43k/47k, 177pF, 27k/15nF',models.corrected; ...
    'CSV fila 13 reescalado a ganancia actual',models.csvOriginalRescaled; ...
    'Objetivo del optimizador reescalado',models.optimizerTarget};
measurementRows=repmat(emptyMetricRow(),size(references,1),1);
for k=1:size(references,1)
    referenceResponse=responseAt(references{k,2},fMeasured);
    [magRmse,phaseRmse]=responseErrors(hMeasured,referenceResponse);
    measurementRows(k).Reference=string(references{k,1});
    measurementRows(k).PointCount=nnz(designMask);
    measurementRows(k).MinFrequencyHz=min(fMeasured);
    measurementRows(k).MaxFrequencyHz=max(fMeasured);
    measurementRows(k).MedianCoherence=median(measured.coherence(designMask));
    measurementRows(k).MagnitudeRmseDb=magRmse;
    measurementRows(k).PhaseRmseDeg=phaseRmse;
end
measurementTable=struct2table(measurementRows);

theoryFrequency=logspace(-2,log10(500),1200).';
theoryPairs={ ...
    'Montado 43k/43k vs objetivo corregido',models.asBuilt,models.correctedFormulaTarget; ...
    'BP corregido 47k/177pF vs su fórmula',models.corrected,models.correctedFormulaTarget; ...
    'CSV fila 13 reescalado vs objetivo optimizador',models.csvOriginalRescaled,models.optimizerTarget};
theoryRows=repmat(emptyTheoryRow(),size(theoryPairs,1),1);
for k=1:size(theoryPairs,1)
    actual=responseAt(theoryPairs{k,2},theoryFrequency);
    target=responseAt(theoryPairs{k,3},theoryFrequency);
    [magRmse,phaseRmse]=responseErrors(actual,target);
    theoryRows(k).Comparison=string(theoryPairs{k,1});
    theoryRows(k).MagnitudeRmseDb=magRmse;
    theoryRows(k).PhaseRmseDeg=phaseRmse;
end
theoryTable=struct2table(theoryRows);
parameterTable=componentParameterTable(models.parameters);

outputFolder=fullfile(scriptDir,'resultados_validacion_compensador');
if ~isfolder(outputFolder),mkdir(outputFolder);end
writetable(measurementTable,fullfile(outputFolder,'comparacion_medicion_actual.csv'));
writetable(theoryTable,fullfile(outputFolder,'validacion_teorica_diseno.csv'));
writetable(parameterTable,fullfile(outputFolder,'parametros_casos.csv'));

gridFrequency=logspace(-1,log10(500),1000).';
fig=figure('Visible',onOff(showFigures),'Color','w','Position',[80 60 1200 860]);
layout=tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
colors=[0.85 0.20 0.12;0.10 0.45 0.80;0.20 0.60 0.25;0.05 0.05 0.05];
styles={'--','-.',':','-'};

nexttile;
semilogx(fMeasured,20*log10(abs(hMeasured)),'ko','MarkerSize',4, ...
    'DisplayName','Medición CH3/PGA');hold on;
for k=1:size(references,1)
    response=responseAt(references{k,2},gridFrequency);
    semilogx(gridFrequency,20*log10(abs(response)),styles{k}, ...
        'Color',colors(k,:),'LineWidth',1.55,'DisplayName',references{k,1});
end
grid on;ylabel('Magnitud (dB)');legend('Location','best');

nexttile;
measuredPhase=unwrap(angle(hMeasured))*180/pi;
semilogx(fMeasured,measuredPhase,'ko','MarkerSize',4,'DisplayName','Medición CH3/PGA');hold on;
for k=1:size(references,1)
    response=responseAt(references{k,2},gridFrequency);
    phase=alignPhase(unwrap(angle(response))*180/pi,measuredPhase);
    semilogx(gridFrequency,phase,styles{k},'Color',colors(k,:), ...
        'LineWidth',1.55,'DisplayName',references{k,1});
end
grid on;ylabel('Fase (grados)');

nexttile;
semilogx(measured.f,measured.coherence,'o-','Color',[0.12 0.47 0.71]);hold on;
yline(0.75,'--','Umbral');xline(500,':','Fin de banda de diseño');
grid on;ylim([0 1.05]);ylabel('Coherencia');xlabel('Frecuencia (Hz)');
title(layout,['Validación independiente del compensador: medición actual, ' ...
    'circuito montado, corrección y diseño original']);
base=fullfile(outputFolder,'validacion_compensador_montado');
exportgraphics(fig,[base '.png'],'Resolution',180);savefig(fig,[base '.fig']);
if showFigures,drawnow;else,close(fig);end

writeValidationReport(measurementTable,theoryTable,models.parameters, ...
    fullfile(outputFolder,'informe_validacion.txt'));

validation=struct('measurementComparison',measurementTable, ...
    'theoreticalValidation',theoryTable,'parameters',parameterTable, ...
    'models',models,'outputFolder',outputFolder, ...
    'measuredFrequencyHz',fMeasured,'measuredResponse',hMeasured);
fprintf('Validación independiente guardada en %s\n',outputFolder);
disp(measurementTable);
disp(theoryTable);
end

function models=compensatorModels(opamp)
R1=43e3;C1=680e-6;Ru=7.5e3;Rbp=8.2e3;Rload=30e3;
models.asBuilt=makeCompensator(R1,43e3,C1,177e-12,Rbp,Ru,27e3,15e-9,Rload,opamp);
models.corrected=makeCompensator(R1,47e3,C1,177e-12,Rbp,Ru,27e3,15e-9,Rload,opamp);
models.csvOriginal=makeCompensator(R1,47e3,C1,180e-12,Rbp,Ru,6.8e3,53.9e-9,Rload,opamp);
models.csvOriginalRescaled=minreal((27e3/6.8e3)*models.csvOriginal,1e-9);

zeta0=0.25;
[w0Corrected,zetaCorrected]=bpNaturalParameters(R1,47e3,C1,177e-12);
shapeCorrected=tf([1 2*zeta0*w0Corrected w0Corrected^2], ...
    [1 2*zetaCorrected*w0Corrected w0Corrected^2]);
models.correctedFormulaTarget=minreal((-27e3/Ru)*shapeCorrected* ...
    tf(1,[27e3*15e-9 1]),1e-9);

w0Optimizer=2*pi*10;zetaOptimizer=1000;fcOptimizer=435.713;
shapeOptimizer=tf([1 2*zeta0*w0Optimizer w0Optimizer^2], ...
    [1 2*zetaOptimizer*w0Optimizer w0Optimizer^2]);
models.optimizerTarget=minreal(-27e3/Ru*shapeOptimizer* ...
    tf(1,[1/(2*pi*fcOptimizer) 1]),1e-9);

models.parameters=struct( ...
    'asBuilt',shapeParameters('Montado 43k/43k',R1,43e3,C1,177e-12,Ru,Rbp,27e3,15e-9), ...
    'corrected',shapeParameters('Corregido 43k/47k',R1,47e3,C1,177e-12,Ru,Rbp,27e3,15e-9), ...
    'csvOriginal',shapeParameters('CSV fila 13',R1,47e3,C1,180e-12,Ru,Rbp,6.8e3,53.9e-9));
models.parameters.NoiseGainAdderCurrent=1+27e3/Ru+27e3/Rbp;
models.parameters.EstimatedClosedLoopBandwidthHz= ...
    opamp.GainBandwidthHz/models.parameters.NoiseGainAdderCurrent;
end

function model=makeCompensator(R1,R2,C1,C2,Rbp,Ru,Rfeedback,Cfeedback,Rload,opamp)
hBp=makeBpNonideal(R1,R2,C1,C2,Rbp,opamp);
adderImpedance=makeAdderImpedanceNonideal( ...
    Rfeedback,Cfeedback,Ru,Rbp,Rload,opamp);
model=minreal(adderImpedance*(1/Ru+hBp/Rbp),1e-9);
end

function model=makeBpNonideal(Rin,Rf,Cin,Cf,Rload,opamp)
s=tf('s');A=opAmpOpenLoop(opamp);
yin=s*Cin/(1+s*Rin*Cin);yf=1/Rf+s*Cf;
yamp=1/opamp.InputResistanceOhm+s*opamp.InputCapacitanceF;
a11=yin+yf+yamp;a12=-yf;
a21=A/opamp.OutputResistanceOhm-yf;
a22=1/opamp.OutputResistanceOhm+yf+1/Rload;
model=minreal((-a21*yin)/(a11*a22-a12*a21),1e-8);
end

function model=makeAdderImpedanceNonideal(Rfeedback,Cfeedback,Ru,Rbp,Rload,opamp)
s=tf('s');zf=Rfeedback/(1+s*Rfeedback*Cfeedback);A=opAmpOpenLoop(opamp);
noiseGain=1+zf*(1/Ru+1/Rbp+1/opamp.InputResistanceOhm+s*opamp.InputCapacitanceF);
outputDivider=Rload/(Rload+opamp.OutputResistanceOhm);
model=minreal((-zf)*outputDivider/(1+noiseGain/A),1e-8);
end

function A=opAmpOpenLoop(opamp)
A=tf(opamp.OpenLoopGain,[1/(2*pi*opamp.DominantPoleHz) 1]);
end

function [w0,zeta]=bpNaturalParameters(R1,R2,C1,C2)
a2=R1*R2*C1*C2;a1=R1*C1+R2*C2;
w0=sqrt(1/a2);zeta=a1/(2*sqrt(a2));
end

function p=shapeParameters(label,R1,R2,C1,C2,Ru,Rbp,Rfeedback,Cfeedback)
[w0,zeta]=bpNaturalParameters(R1,R2,C1,C2);
peakGain=R2*C1/(R1*C1+R2*C2);
p=struct('Label',string(label),'R1Ohm',R1,'R2Ohm',R2,'C1F',C1,'C2F',C2, ...
    'W0RadPerS',w0,'F0Hz',w0/(2*pi),'ZetaBp',zeta,'BpPeakGain',peakGain, ...
    'ResidualZeta',zeta*(1-(Ru/Rbp)*peakGain), ...
    'RbpRequiredOhm',Ru*peakGain/(1-0.25/zeta), ...
    'AdderGainDirect',-Rfeedback/Ru, ...
    'AdderGainBp',-Rfeedback/Rbp, ...
    'AntiAliasPoleHz',1/(2*pi*Rfeedback*Cfeedback));
end

function tableOut=componentParameterTable(parameters)
cases={parameters.asBuilt,parameters.corrected,parameters.csvOriginal};
rows=repmat(cases{1},numel(cases),1);
for k=1:numel(cases),rows(k)=cases{k};end
tableOut=struct2table(rows);
end

function writeValidationReport(measured,theory,parameters,filename)
fid=fopen(filename,'w');assert(fid>=0,'No se pudo escribir %s.',filename);
cleanup=onCleanup(@()fclose(fid));
asBuilt=measured(1,:);correctedTheory=theory(2,:);originalTheory=theory(3,:);
fprintf(fid,'Validación independiente del compensador CH3/PGA\n\n');
fprintf(fid,['Medición actual vs circuito realmente montado (43k/43k): ' ...
    'RMSE magnitud %.6g dB, fase %.6g grados, coherencia mediana %.6g.\n'], ...
    asBuilt.MagnitudeRmseDb,asBuilt.PhaseRmseDeg,asBuilt.MedianCoherence);
if asBuilt.MagnitudeRmseDb<3 && asBuilt.PhaseRmseDeg<15
    fprintf(fid,['Conclusión de funcionamiento: CH3/PGA es compatible con el ' ...
        'circuito montado; no hay evidencia de una falla gruesa del adder.\n']);
else
    fprintf(fid,['Conclusión de funcionamiento: la medición no queda suficientemente ' ...
        'cerca del circuito montado; revisar implementación.\n']);
end
fprintf(fid,['BP corregido 47k/177pF vs fórmula Hcompensate: %.6g dB y ' ...
    '%.6g grados.\n'],correctedTheory.MagnitudeRmseDb,correctedTheory.PhaseRmseDeg);
fprintf(fid,['Fila 13 del CSV reescalada vs objetivo del optimizador: %.6g dB y ' ...
    '%.6g grados.\n'],originalTheory.MagnitudeRmseDb,originalTheory.PhaseRmseDeg);
fprintf(fid,'Montado: zeta_BP=%.8g, ganancia pico BP=%.8g, zeta residual=%.8g.\n', ...
    parameters.asBuilt.ZetaBp,parameters.asBuilt.BpPeakGain,parameters.asBuilt.ResidualZeta);
fprintf(fid,['Corregido: zeta_BP=%.8g, ganancia pico BP=%.8g, zeta residual=%.8g, ' ...
    'Rbp requerida=%.8g ohm.\n'],parameters.corrected.ZetaBp, ...
    parameters.corrected.BpPeakGain,parameters.corrected.ResidualZeta, ...
    parameters.corrected.RbpRequiredOhm);
fprintf(fid,['Adder actual: ganancia directa %.8g, ganancia rama BP %.8g, ' ...
    'polo antialias %.8g Hz, noise gain %.8g, BW cerrada estimada %.8g Hz.\n'], ...
    parameters.corrected.AdderGainDirect,parameters.corrected.AdderGainBp, ...
    parameters.corrected.AntiAliasPoleHz,parameters.NoiseGainAdderCurrent, ...
    parameters.EstimatedClosedLoopBandwidthHz);
fprintf(fid,['Advertencia de tolerancias: la compensación resta dos ramas casi ' ...
    'iguales. El potenciómetro Rbp de la fila 13 no es opcional si se usan ' ...
    'resistencias de 1%%; debe calibrarse después de cambiar R2 a 47k.\n']);
fprintf(fid,['Advertencia del optimizador Python: usa 8 MHz como polo abierto en ' ...
    'vez de GBW. En 0.01-500 Hz el impacto es pequeño, pero sus predicciones ' ...
    'de alta frecuencia son optimistas. Este validador usa polo=GBW/A0.\n']);
end

function row=emptyMetricRow()
row=struct('Reference',"",'PointCount',0,'MinFrequencyHz',NaN, ...
    'MaxFrequencyHz',NaN,'MedianCoherence',NaN, ...
    'MagnitudeRmseDb',NaN,'PhaseRmseDeg',NaN);
end

function row=emptyTheoryRow()
row=struct('Comparison',"",'MagnitudeRmseDb',NaN,'PhaseRmseDeg',NaN);
end

function h=responseAt(model,f)
h=squeeze(freqresp(model,2*pi*f));h=h(:);
end

function [magnitudeRmseDb,phaseRmseDeg]=responseErrors(actual,reference)
valid=isfinite(actual)&isfinite(reference)&abs(actual)>0&abs(reference)>0;
magnitudeRmseDb=sqrt(mean((20*log10(abs(actual(valid)./reference(valid)))).^2));
phaseRmseDeg=sqrt(mean((angle(actual(valid).*conj(reference(valid)))*180/pi).^2));
end

function phase=alignPhase(phase,reference)
phase=phase+360*round((median(reference)-median(phase))/360);
end

function value=onOff(condition)
if condition,value='on';else,value='off';end
end
