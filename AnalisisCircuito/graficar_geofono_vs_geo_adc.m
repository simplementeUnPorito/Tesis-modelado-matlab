%% Normalized geophone and complete GEO-to-ADC responses
% The processed FRF and Monte Carlo population from the latest calibrated
% data set are reused here. The Monte Carlo population and measured complete
% chain share one magnitude normalization reference.

clear;
close all;
clc;

scriptPath = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(fileparts(scriptPath)));
cacheFile = fullfile(scriptPath, 'resultados_tanda_calibrada', ...
    '00_cache', 'analisis_circuito.mat');
outputBase = fullfile(repoRoot, 'docs', 'Propuesta Urucom', ...
    'normalized_geophone_geo_adc_response');

assert(isfile(cacheFile), ...
    'The latest calibration cache was not found: %s', cacheFile);
cache = load(cacheFile, 'results');
assert(isfield(cache, 'results') && isfield(cache.results, 'chains') && ...
    isfield(cache.results.chains, 'PGA_to_ADC') && ...
    isfield(cache.results, 'monteCarlo'), ...
    'The cache does not contain the processed FRF and Monte Carlo data.');

%% SM-24 nominal transfer functions
fn = 10;                    % natural frequency [Hz]
zeta = 0.25;                % nominal damping ratio
G = 28.8;                   % intrinsic sensitivity [V/(m/s)]
wn = 2*pi*fn;
s = tf('s');
denominator = s^2 + 2*zeta*wn*s + wn^2;

% The minus sign affects phase only and is retained from the reference model.
Hvelocity = -G*s^2/denominator;       % V/(m/s)
Hacceleration = Hvelocity/s;          % V/(m/s^2)

%% Complete-chain samples: measured analog pipeline times Hacceleration
pgaAdc = cache.results.chains.PGA_to_ADC.measuredProcessed;
fSamples = pgaAdc.f(:);
hAnalog = pgaAdc.response(:);
localCoherence = pgaAdc.coherence(:);
hAccelerationAtSamples = responseAt(Hacceleration, fSamples);
hGeoAdc = hAnalog .* hAccelerationAtSamples;

valid = isfinite(fSamples) & fSamples > 0 & ...
    isfinite(real(hGeoAdc)) & isfinite(imag(hGeoAdc)) & ...
    isfinite(localCoherence);
fSamples = fSamples(valid);
hGeoAdc = hGeoAdc(valid);
localCoherence = localCoherence(valid);
assert(~isempty(fSamples), 'No valid GEO-to-ADC samples are available.');

%% Continuous responses and normalized Monte Carlo envelopes
fCurve = logspace(log10(min(fSamples)), log10(max(fSamples)), 700).';
hAcceleration = responseAt(Hacceleration, fCurve);
hVelocity = responseAt(Hvelocity, fCurve);
hIdealChain = responseAt(cache.results.ideal.LP_PGA, fCurve) .* hAcceleration;
nominalChainPhase = unwrap(angle(hIdealChain))*180/pi;

fprintf('Calculating the full 0-2 kOhm potentiometer envelope...\n');
magnitudeReferenceDb = max(20*log10(abs(hGeoAdc) + eps));
fullPotEnvelope = fullPotentiometerEnvelope(cache.results.monteCarlo, ...
    fCurve, hAcceleration, magnitudeReferenceDb, nominalChainPhase);

accelerationDb = normalizeMagnitudeDb(hAcceleration);
geoAdcDb = normalizeMagnitudeDb(hGeoAdc);
velocityDb = normalizeMagnitudeDb(hVelocity);
idealChainDb = 20*log10(abs(hIdealChain) + eps) - magnitudeReferenceDb;

accelerationPhase = unwrappedPhaseFromZero(hAcceleration);
velocityPhase = unwrappedPhaseFromZero(hVelocity);
geoAdcPhase = unwrappedPhaseFromZero(hGeoAdc);
idealChainPhase = nominalChainPhase - nominalChainPhase(1);

%% Paper-ready three-panel plot
fig = figure('Color', 'w', 'Position', [100 60 1180 920]);
layout = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

% Magnitude
axMagnitude = nexttile(layout);
yyaxis(axMagnitude, 'left');
hFullPot = drawEnvelope(fCurve, fullPotEnvelope.magnitudeMinDb, ...
    fullPotEnvelope.magnitudeMaxDb, [1.00 0.72 0.32], [0.90 0.48 0.10], ...
    0.22, 'Achievable calibration range (0-2 kOhm potentiometer sweep)');
hold on;
hAccelerationPlot = semilogx(fCurve, accelerationDb, '-', ...
    'Color', [0.00 0.35 0.70], 'LineWidth', 2.1, ...
    'DisplayName', 'Bare geophone, acceleration response');
hGeoAdcPlot = semilogx(fSamples, geoAdcDb, 'o', ...
    'LineStyle', 'none', 'MarkerSize', 4.8, ...
    'MarkerFaceColor', 'none', ...
    'MarkerEdgeColor', [0.15 0.15 0.15], ...
    'DisplayName', 'Measured response using the configuration employed in this work');
hIdealPlot = semilogx(fCurve, idealChainDb, '--', ...
    'Color', [0.90 0.28 0.10], 'LineWidth', 1.8, ...
    'DisplayName', 'Theoretical ideal response');
ylabel({'Normalized acceleration sensitivity (dB)', ...
    'reference: maximum V/(m/s^2)'});
ylim([-250 50]);

yyaxis(axMagnitude, 'right');
hVelocityPlot = semilogx(fCurve, velocityDb, '--', ...
    'Color', [0.10 0.55 0.25], 'LineWidth', 2.1, ...
    'DisplayName', 'Bare geophone, velocity response');
ylabel({'Normalized velocity sensitivity (dB)', ...
    'reference: maximum V/(m/s)'});
ylim([-250 50]);
grid on;
box on;
legend([hFullPot, hGeoAdcPlot, hIdealPlot, hAccelerationPlot, hVelocityPlot], ...
    'Location', 'southwest', ...
    'NumColumns', 2, 'FontSize', 9);

% Phase
axPhase = nexttile(layout);
hFullPotPhase = drawEnvelope(fCurve, fullPotEnvelope.phaseMinDeg, ...
    fullPotEnvelope.phaseMaxDeg, [1.00 0.72 0.32], [0.90 0.48 0.10], ...
    0.22, 'Achievable calibration range (0-2 kOhm potentiometer sweep)');
hold on;
semilogx(fCurve, accelerationPhase, '-', 'Color', [0.00 0.35 0.70], ...
    'LineWidth', 2.1, 'DisplayName', 'Bare geophone, acceleration response');
semilogx(fSamples, geoAdcPhase, 'o', 'LineStyle', 'none', ...
    'MarkerSize', 4.8, 'MarkerFaceColor', 'none', ...
    'MarkerEdgeColor', [0.15 0.15 0.15], ...
    'DisplayName', 'Measured response using the configuration employed in this work');
semilogx(fCurve, idealChainPhase, '--', 'Color', [0.90 0.28 0.10], ...
    'LineWidth', 1.8, ...
    'DisplayName', 'Theoretical ideal response');
semilogx(fCurve, velocityPhase, '--', 'Color', [0.10 0.55 0.25], ...
    'LineWidth', 2.1, 'DisplayName', 'Bare geophone, velocity response');
grid on;
box on;
ylabel('Phase (deg)');
ylim([-600 400]);
yticks(-600:200:400);
legend(hFullPotPhase, 'Location', 'best', 'FontSize', 9);

% Local coherence
axCoherence = nexttile(layout);
semilogx(fSamples, localCoherence, 'o-', 'Color', [0.20 0.55 0.85], ...
    'MarkerSize', 4.2, 'MarkerFaceColor', 'none', ...
    'LineWidth', 0.9, 'DisplayName', 'Local coherence');
hold on;
grid on;
box on;
ylim([0 1.05]);
ylabel('Local coherence');
xlabel('Frequency (Hz)');

linkaxes([axMagnitude, axPhase, axCoherence], 'x');
set([axMagnitude, axPhase, axCoherence], 'XScale', 'log', ...
    'XLim', [1e-2 1e6], 'FontName', 'Times New Roman', ...
    'FontSize', 11, 'LineWidth', 0.9);
axMagnitude.YAxis(1).Color = [0.15 0.15 0.15];
axMagnitude.YAxis(2).Color = [0.10 0.45 0.22];
title(layout, ['Complete GEO-to-ADC Chain: Measurement, Calibration Range, ' ...
    'and Theoretical Response'], ...
    'FontName', 'Times New Roman', 'FontWeight', 'bold');

% Prevent interactive toolbar or data-tip overlays from entering exports.
datacursormode(fig, 'off');
for currentAxes = [axMagnitude, axPhase, axCoherence]
    disableDefaultInteractivity(currentAxes);
    currentAxes.Toolbar.Visible = 'off';
end
delete(findall(fig, 'Type', 'datatip'));
drawnow;

exportgraphics(fig, [outputBase '.png'], 'Resolution', 300);
exportgraphics(fig, [outputBase '.pdf'], 'ContentType', 'vector');
savefig(fig, [outputBase '.fig']);
fprintf('Paper figure saved to:\n  %s.png\n  %s.pdf\n  %s.fig\n', ...
    outputBase, outputBase, outputBase);

function h = responseAt(model, frequencyHz)
    h = squeeze(freqresp(model, 2*pi*frequencyHz));
    h = h(:);
end

function magnitudeDb = normalizeMagnitudeDb(response)
    magnitudeDb = 20*log10(abs(response) + eps);
    finiteValues = isfinite(magnitudeDb);
    assert(any(finiteValues), 'The response contains no finite magnitudes.');
    magnitudeDb = magnitudeDb - max(magnitudeDb(finiteValues));
end

function phaseDeg = unwrappedPhaseFromZero(response)
    phaseDeg = unwrap(angle(response))*180/pi;
    phaseDeg = phaseDeg - phaseDeg(1);
end

function patchHandle = drawEnvelope(frequencyHz, lowerBound, upperBound, ...
        faceColor, edgeColor, faceAlpha, displayName)
    patchHandle = fill([frequencyHz; flipud(frequencyHz)], ...
        [lowerBound; flipud(upperBound)], faceColor, ...
        'FaceAlpha', faceAlpha, 'EdgeColor', 'none', ...
        'DisplayName', displayName);
    set(gca, 'XScale', 'log');
    hold on;
    semilogx(frequencyHz, lowerBound, 'Color', edgeColor, ...
        'LineWidth', 0.65, 'HandleVisibility', 'off');
    semilogx(frequencyHz, upperBound, 'Color', edgeColor, ...
        'LineWidth', 0.65, 'HandleVisibility', 'off');
end

function envelope = fullPotentiometerEnvelope(mc, frequencyHz, hGeophone, ...
        magnitudeReferenceDb, nominalPhase)
    nFrequency = numel(frequencyHz);
    envelope = emptyEnvelope(nFrequency);
    positions = linspace(0, mc.potentiometerMaximumOhm, ...
        mc.potentiometerEnvelopeSteps);
    for index = 1:numel(positions)
        varied = mc;
        varied.RwpBp = varied.RbpFixed + positions(index);
        current = configurationEnvelope(varied, frequencyHz, hGeophone, ...
            magnitudeReferenceDb, nominalPhase);
        envelope.magnitudeMinDb = min(envelope.magnitudeMinDb, ...
            current.magnitudeMinDb);
        envelope.magnitudeMaxDb = max(envelope.magnitudeMaxDb, ...
            current.magnitudeMaxDb);
        envelope.phaseMinDeg = min(envelope.phaseMinDeg, current.phaseMinDeg);
        envelope.phaseMaxDeg = max(envelope.phaseMaxDeg, current.phaseMaxDeg);
    end
end

function envelope = configurationEnvelope(mc, frequencyHz, hGeophone, ...
        magnitudeReferenceDb, nominalPhase)
    nRealizations = numel(mc.RinBp);
    nFrequency = numel(frequencyHz);
    chunkSize = max(mc.frequencyChunkSize, 96);
    envelope = emptyEnvelope(nFrequency);
    for first = 1:chunkSize:nFrequency
        index = first:min(nFrequency, first + chunkSize - 1);
        response = monteCarloAnalogResponse(mc, frequencyHz(index));
        response = response .* reshape(hGeophone(index), 1, []);
        magnitudeDb = 20*log10(abs(response) + eps) - magnitudeReferenceDb;
        phaseDeg = unwrap(angle(response), [], 2)*180/pi;
        anchor = max(1, round(numel(index)/2));
        phaseDeg = phaseDeg + 360*round( ...
            (nominalPhase(index(anchor)) - phaseDeg(:, anchor))/360);
        phaseDeg = phaseDeg - nominalPhase(1);

        envelope.magnitudeMinDb(index) = min(magnitudeDb, [], 1).';
        envelope.magnitudeMaxDb(index) = max(magnitudeDb, [], 1).';
        envelope.phaseMinDeg(index) = min(phaseDeg, [], 1).';
        envelope.phaseMaxDeg(index) = max(phaseDeg, [], 1).';
    end
end

function envelope = emptyEnvelope(nFrequency)
    envelope.magnitudeMinDb = inf(nFrequency, 1);
    envelope.magnitudeMaxDb = -inf(nFrequency, 1);
    envelope.phaseMinDeg = inf(nFrequency, 1);
    envelope.phaseMaxDeg = -inf(nFrequency, 1);
end

function response = monteCarloAnalogResponse(mc, frequencyHz)
    complexFrequency = 1i*2*pi*reshape(frequencyHz, 1, []);
    hBp = bpNonidealResponse(mc, complexFrequency);
    hSum = sumNonidealResponse(mc, complexFrequency);
    hLp = lpNonidealResponse(mc, complexFrequency);
    response = hLp .* hSum .* (1./mc.RwpU + hBp./mc.RwpBp);
end

function response = bpNonidealResponse(mc, complexFrequency)
    op = mc.opamp;
    A = op.OpenLoopGain./(1 + complexFrequency/(2*pi*op.DominantPoleHz));
    feedbackCapacitance = mc.CfBp150 + mc.CfBp27;
    inputAdmittance = complexFrequency.*mc.CinBp ./ ...
        (1 + complexFrequency.*mc.RinBp.*mc.CinBp);
    feedbackAdmittance = 1./mc.RfBp + complexFrequency.*feedbackCapacitance;
    amplifierAdmittance = 1/op.InputResistanceOhm + ...
        complexFrequency*op.InputCapacitanceF;
    a11 = inputAdmittance + feedbackAdmittance + amplifierAdmittance;
    a21 = A/op.OutputResistanceOhm - feedbackAdmittance;
    a22 = 1/op.OutputResistanceOhm + feedbackAdmittance + 1./mc.RwpBp;
    response = (-a21.*inputAdmittance) ./ ...
        (a11.*a22 + feedbackAdmittance.*a21);
end

function response = sumNonidealResponse(mc, complexFrequency)
    op = mc.opamp;
    A = op.OpenLoopGain./(1 + complexFrequency/(2*pi*op.DominantPoleHz));
    feedbackImpedance = mc.RsumFeedback ./ ...
        (1 + complexFrequency.*mc.RsumFeedback.*mc.Csum);
    noiseGain = 1 + feedbackImpedance.*(1./mc.RwpU + 1./mc.RwpBp + ...
        1/op.InputResistanceOhm + complexFrequency*op.InputCapacitanceF);
    outputDivider = mc.R1Lp./(mc.R1Lp + op.OutputResistanceOhm);
    response = (-feedbackImpedance).*outputDivider./(1 + noiseGain./A);
end

function response = lpNonidealResponse(mc, complexFrequency)
    op = mc.opamp;
    A = op.OpenLoopGain./(1 + complexFrequency/(2*pi*op.DominantPoleHz));
    a = 1./mc.R1Lp + 1./mc.R2Lp + 1./mc.R3Lp + ...
        complexFrequency.*mc.C1Lp;
    b = -1./mc.R3Lp;
    c = -1./mc.R2Lp;
    d = b;
    e = 1./mc.R3Lp + complexFrequency.*mc.C2Lp + ...
        1/op.InputResistanceOhm + complexFrequency*op.InputCapacitanceF;
    f = -complexFrequency.*mc.C2Lp;
    g = c;
    h = -complexFrequency.*mc.C2Lp + A/op.OutputResistanceOhm;
    i = 1./mc.R2Lp + complexFrequency.*mc.C2Lp + ...
        1/op.OutputResistanceOhm;
    determinant = a.*(e.*i - f.*h) - b.*(d.*i - f.*g) + ...
        c.*(d.*h - e.*g);
    response = (1./mc.R1Lp).*(d.*h - e.*g)./determinant;
end
