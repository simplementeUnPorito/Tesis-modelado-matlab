function diagnostic = verificar_calibracion_potenciometro(resultsOrCache, outputRoot, showFigure)
%VERIFICAR_CALIBRACION_POTENCIOMETRO Estima el cursor por captura.
%   diagnostic = verificar_calibracion_potenciometro(results)
%   diagnostic = verificar_calibracion_potenciometro(cacheFile, outputRoot, true)
%
% Usa exclusivamente las FRF procesadas BP/PGA y CH3/PGA que pertenecen a
% la misma captura. La estimación es diagnóstica: si el residuo complejo es
% alto, no debe interpretarse como una medición del potenciómetro.

scriptDir=fileparts(mfilename('fullpath'));
if nargin<1 || isempty(resultsOrCache)
    resultsOrCache=fullfile(scriptDir,'resultados','00_cache','analisis_circuito.mat');
end
if isstruct(resultsOrCache)
    results=resultsOrCache;
else
    loaded=load(char(resultsOrCache),'results');
    results=loaded.results;
end
if nargin<2 || isempty(outputRoot)
    outputRoot=results.outputFolders.tables;
end
if nargin<3,showFigure=true;end
if ~isfolder(outputRoot),mkdir(outputRoot);end

bp=results.processedByCapture.BP;
comp=results.processedByCapture.COMP;
cfg=results.config;
c=results.ideal.compensation;
bpKeys=bp.band+"|"+bp.capture;
compKeys=comp.band+"|"+comp.capture;
keys=intersect(unique(bpKeys),unique(compKeys),'stable');
potGrid=linspace(0,c.RbpPotMaximumOhm,401).';

rows=repmat(emptyRow(),0,1);
curves=NaN(numel(potGrid),numel(keys));
labels=strings(numel(keys),1);
for k=1:numel(keys)
    key=keys(k);separator=strfind(key,"|");
    band=extractBefore(key,separator(1));capture=extractAfter(key,separator(1));
    b=selectRows(bp,bpKeys==key);q=selectRows(comp,compKeys==key);
    [f,hComp,hBp,weights,medianCoherence]=pairedData(b,q,cfg);
    row=emptyRow();row.Band=band;row.Capture=capture;
    row.Points=numel(f);row.MedianCombinedCoherence=medianCoherence;
    if ~isempty(f)
        row.MinFrequencyHz=min(f);row.MaxFrequencyHz=max(f);
        for j=1:numel(potGrid)
            curves(j,k)=objective(c.RbpFixedOhm+potGrid(j), ...
                f,hComp,hBp,weights,cfg,c.RuOhm);
        end
        [minimum,index]=min(curves(:,k));
        lower=max(0,potGrid(max(1,index-1)));
        upper=min(c.RbpPotMaximumOhm,potGrid(min(numel(potGrid),index+1)));
        [pot,value]=fminbnd(@(x)objective(c.RbpFixedOhm+x, ...
            f,hComp,hBp,weights,cfg,c.RuOhm),lower,upper, ...
            optimset('Display','off','TolX',0.01));
        row.EstimatedPotOhm=pot;
        row.EstimatedRbpTotalOhm=c.RbpFixedOhm+pot;
        row.RelativeComplexResidual=sqrt(value);
        row.OffsetFromTargetOhm=pot-c.RequiredPotOhm;
        row.DiagnosticReliable=row.Points>=8 && ...
            row.RelativeComplexResidual<=0.35;
        if minimum<value,curves(index,k)=minimum;end
    end
    rows(end+1,1)=row; %#ok<AGROW>
    labels(k)=band+" / "+capture;
end
diagnostic=struct2table(rows);
writetable(diagnostic,fullfile(outputRoot,'calibracion_pot_por_captura.csv'));

fig=figure('Visible',onOff(showFigure),'Color','w','Position',[100 100 1250 720]);
ax=axes(fig);hold(ax,'on');
for k=1:numel(keys)
    if rows(k).Points>=8 && any(isfinite(curves(:,k)))
        semilogy(ax,potGrid,sqrt(curves(:,k)),'LineWidth',1.1, ...
            'DisplayName',labels(k));
    end
end
xline(ax,c.RequiredPotOhm,'r--',sprintf('Objetivo %.2f Ohm',c.RequiredPotOhm), ...
    'LineWidth',1.5,'DisplayName','Ajuste objetivo');
xline(ax,c.NullPotOhm,'k:',sprintf('Nulo %.2f Ohm',c.NullPotOhm), ...
    'LineWidth',1.2,'DisplayName','Cancelación nula');
yline(ax,0.35,'--','Umbral diagnóstico 0.35', ...
    'Color',[0.4 0.4 0.4],'HandleVisibility','off');
grid(ax,'on');xlabel(ax,'Resistencia cursor-extremo (Ohm)');
ylabel(ax,'Residuo complejo relativo');
title(ax,'Diagnóstico del potenciómetro por captura (BP/PGA y CH3/PGA)');
legend(ax,'Location','eastoutside','Interpreter','none');
base=fullfile(outputRoot,'calibracion_pot_por_captura');
exportgraphics(fig,[base '.png'],'Resolution',180);savefig(fig,[base '.fig']);
if showFigure,drawnow;else,close(fig);end

fprintf('\nCalibración del potenciómetro por captura\n');
disp(diagnostic);
fprintf(['Una fila sólo se marca confiable con al menos 8 puntos y residuo ' ...
    'complejo relativo <= 0.35. Si no, medir el pot con multímetro.\n']);
end

function [f,hComp,hBp,weights,medianCoherence]=pairedData(bp,comp,cfg)
mask=comp.f>=0.5 & comp.f<=200 & comp.coherence>=max(0.8,cfg.minFitCoherence);
f=comp.f(mask);hComp=comp.response(mask);compCoherence=comp.coherence(mask);
if isempty(f),hBp=[];weights=[];medianCoherence=NaN;return;end
[bpFrequency,uniqueIndex]=unique(bp.f,'stable');
bpResponse=bp.response(uniqueIndex);bpCoherence=bp.coherence(uniqueIndex);
hBp=interp1(log(bpFrequency),bpResponse,log(f),'linear',NaN);
coherenceBp=interp1(log(bpFrequency),bpCoherence,log(f),'linear',NaN);
valid=isfinite(hBp)&isfinite(coherenceBp)&coherenceBp>=max(0.8,cfg.minFitCoherence);
f=f(valid);hComp=hComp(valid);hBp=hBp(valid);
compCoherence=compCoherence(valid);coherenceBp=coherenceBp(valid);
weights=compCoherence.^2.*coherenceBp.^2;
if isempty(weights),medianCoherence=NaN;else
    medianCoherence=median(sqrt(compCoherence.*coherenceBp));
end
end

function value=objective(rbp,f,hComp,hBp,weights,cfg,ru)
s=1i*2*pi*f;
op=cfg.opamp;
A=op.OpenLoopGain./(1+s/(2*pi*op.DominantPoleHz));
zf=27e3./(1+s*27e3*15e-9);
noiseGain=1+zf.*(1/ru+1/rbp+1/op.InputResistanceOhm+s*op.InputCapacitanceF);
outputDivider=30e3/(30e3+op.OutputResistanceOhm);
hSum=(-zf).*outputDivider./(1+noiseGain./A);
prediction=hSum.*(1/ru+hBp/rbp);
value=sum(weights.*abs(hComp-prediction).^2)/ ...
    max(eps,sum(weights.*abs(hComp).^2));
end

function out=selectRows(in,mask)
fields=fieldnames(in);out=struct();
for k=1:numel(fields),out.(fields{k})=in.(fields{k})(mask);end
end

function row=emptyRow()
row=struct('Band',"",'Capture',"",'Points',0, ...
    'MinFrequencyHz',NaN,'MaxFrequencyHz',NaN, ...
    'MedianCombinedCoherence',NaN,'EstimatedPotOhm',NaN, ...
    'EstimatedRbpTotalOhm',NaN,'OffsetFromTargetOhm',NaN, ...
    'RelativeComplexResidual',NaN,'DiagnosticReliable',false);
end

function value=onOff(condition)
if condition,value='on';else,value='off';end
end
