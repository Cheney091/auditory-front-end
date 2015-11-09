% Test script for MOC - DRNL feedback function

clear all
close all
clc

%% test signal
% sinusoid with some onset/offset ramps
% pasted from MAP1_14h test codes to potentially test against the MAP
% implementation
sampleRate = 44100;
fs = sampleRate;             % trying to unify the input characteristics
toneFrequency= [520 3980];           % (Hz)
toneDuration = 0.05;                 % trying to unify the input characteristics
beginSilence=0.05;
endSilence=0;
rampDuration=.0025;              % raised cosine ramp (seconds)
leveldBSPL= 0:10:90;   
% mocFactordB = 0;
% mocFactor = 10.^(mocFactordB/20);

% Chunk size in samples (for online processing)
chunkSize = sampleRate * 20E-3;    

% calibration factor (see Jepsen et al. 2008)
dBSPLCal = 100;         % signal amplitude 1 should correspond to max SPL 100 dB
ampCal = 1;             % signal amplitude to correspond to dBSPLRef
pRef = 2e-5;            % reference sound pressure (p0)
pCal = pRef*10^(dBSPLCal/20);
calibrationFactor = ampCal*10.^((leveldBSPL-dBSPLCal)/20);
levelPressure = pRef*10.^(leveldBSPL/20);

% define 20-ms onset sample after ramp completed 
%  allowing 5-ms response delay
onsetPTR1=round((rampDuration+ beginSilence +0.005)*sampleRate);
onsetPTR2=round((rampDuration+ beginSilence +0.005 + 0.020)*sampleRate);
% last half 
lastHalfPTR1=round((beginSilence+toneDuration/2)*sampleRate);
lastHalfPTR2=round((beginSilence+toneDuration-rampDuration)*sampleRate);
% output window
outputWindowStart = round((beginSilence)*sampleRate);
outputWindowEnd = round((beginSilence+toneDuration)*sampleRate);

dt = 1/sampleRate; % seconds
toneTime = dt: dt: toneDuration;
totalTime = dt:dt:beginSilence+toneDuration+endSilence;

% calculate ramp factor
if rampDuration>0.5*toneDuration, rampDuration=toneDuration/2; end
rampTime=dt:dt:rampDuration;
ramp=[0.5*(1+cos(2*pi*rampTime/(2*rampDuration)+pi)) ...
    ones(1,length(toneTime)-length(rampTime))];
ramp_temp = repmat(ramp, [length(leveldBSPL), 1]);  % to be multiplied to inputSignal

% derive silence parts
intialSilence= zeros(1,round(beginSilence/dt));
finalSilence= zeros(1,round(endSilence/dt));

% Online processing parameters
% Number of chunks in the signal - use inputSignal to calculate the signal
% length
n_chunks = ceil(length(totalTime)/chunkSize);

% Zero-pad the signal for online vs. offline direct comparison
finalSilence = [finalSilence zeros(1, n_chunks*chunkSize-length(totalTime))];
% Now the lengths of finalSilence section and totalTime have changed
totalTime = (1:length(toneTime)+length(intialSilence)+length(finalSilence))/sampleRate;

inputSignalMatrix = zeros(length(leveldBSPL), ...
    length(totalTime), ...
    length(toneFrequency));

noisyInputSignalMatrix = zeros(length(leveldBSPL), ...
    length(totalTime), ...
    length(toneFrequency));

% Use pink noise to add to the input signal (Brown et al., JASA 2010)
pinkNoise = pinknoise(length(totalTime));

% Band pass filter - this needs Signal Processing Toolbox
bpFilt = designfilt('bandpassiir','FilterOrder',20, ...
         'HalfPowerFrequency1',100,'HalfPowerFrequency2',22000, ...
         'SampleRate',fs);
pinkNoiseFiltered = filter(bpFilt,pinkNoise);

% Set pink noise amplitude SNR dB below the ear signal
pinkNoiseScaled = setdbspl(pinkNoiseFiltered, 27);

for ii=1:length(toneFrequency)
    inputSignal=sin(2*pi*toneFrequency(ii)'*toneTime) .* sqrt(2);      % amplitude -1~+1 -> sqrt(2)
    % "input amplitude of 1 corresponds to a maximum SPL of 100 dB"
    % --> RMS OF 1 NOW CORRESPONDS TO 100 dB SPL! 
    % calibration: calculate difference between input level dB SPL and the
    % given SPL for calibration (100 dB)
    inputSignal = calibrationFactor'*inputSignal;
    % % "signal amplitude is scaled in pascals in prior to OME"
    % inputSignal = levelPressure'*inputSignal;
    
    % apply ramp
    inputSignal=inputSignal.*ramp_temp;
    ramp_temp=fliplr(ramp_temp);
    inputSignal=inputSignal.*ramp_temp;
    % add silence
    inputSignal= [repmat(intialSilence, [length(leveldBSPL), 1]) ...
        inputSignal repmat(finalSilence, [length(leveldBSPL), 1])]; %#ok<AGROW>
    
    % Obtain the dboffset currently used
    dboffset=dbspl(1);

    % Switch signal to the correct scaling
    inputSignal=gaindb(inputSignal, dboffset-100);
    
    inputSignalMatrix(:, :, ii) = inputSignal;
    noisyInputSignalMatrix(:, :, ii) = inputSignal + ...
        repmat(pinkNoiseScaled, [length(leveldBSPL), 1]);
end


% matrix to store output (I/O function)
ioFunctionMatrix = zeros(length(toneFrequency), length(leveldBSPL));
ioFunctionMatrix_moc = zeros(length(toneFrequency), length(leveldBSPL));

% (AN firing rate-level function)
rateLevelFunctionMatrix = zeros(length(toneFrequency), length(leveldBSPL));
rateLevelFunctionMatrix_noisy = zeros(length(toneFrequency), length(leveldBSPL));

% (MOC activity-level function)
mocLevelFunctionMatrix = zeros(length(toneFrequency), length(leveldBSPL));

request = 'ratemap';
request_moc = 'moc';

% Introduce outer ear filter (imported from AMT)
oe_fir = headphonefilter(fs);

% for ii=1:length(mocFactor)
    for jj=1:length(toneFrequency)

        % Convert input to stapes output, through outer-middle ear filters
        xME = filter(oe_fir, 1, inputSignalMatrix(:, :, jj).');
        xME_noisy = filter(oe_fir, 1, noisyInputSignalMatrix(:, :, jj).');

        % parameter structure for testing on-freq stimulation
        param_struct = genParStruct('pp_bLevelScaling', true, ...
            'pp_bMiddleEarFiltering', true, ...
            'fb_type', 'drnl', 'fb_cfHz', toneFrequency(jj));
        param_struct_moc = genParStruct('pp_bLevelScaling', true, ...
            'pp_bMiddleEarFiltering', true, ...
            'fb_type', 'drnl', 'fb_cfHz', toneFrequency(jj), ...
            'rm_wSizeSec', 10E-3, 'rm_hSizeSec', 5E-3, ...
            'rm_decaySec', 5E-3);

    %     % parameter structure for testing different stimulation freq at single CF
    %     param_struct = genParStruct('drnl_cfHz', 4000);
    
        for kk=1:length(leveldBSPL)
            dObj = dataObject(xME(:, kk), fs);
            dObj_noisy = dataObject(xME_noisy(:, kk), fs);
            dObj_moc = dataObject(xME(:, kk), fs);
            
            mObj = manager(dObj, request, param_struct);
            mObj_noisy = manager(dObj_noisy, request, param_struct);
            mObj_moc = manager(dObj_moc, request_moc, param_struct_moc);
                       
            mObj.processSignal();
            mObj_noisy.processSignal();
            
            % MOC processor will work only in online (chunk-based) mode
            for nn = 1:n_chunks

                % Read a new chunk of signal
                chunk = xME((nn-1)*chunkSize+1:nn*chunkSize, kk);

                % Request processing for the chunk
                mObj_moc.processChunk(chunk,1);

            end

            % DRNL maximum output
            bmOut = dObj.filterbank{1}.Data(:);
            bmOutMax = max(bmOut);
            bmOutMaxdB = 20*log10(bmOutMax);
            
            % ratemap maximum output
            anOut = dObj.ratemap{1}.Data(:);
            anOutMax = max(anOut);
            anOutMaxdB = 20*log10(anOutMax);
%             anOutOffsetMean = mean(anOut(outputWindowStart:outputWindowEnd));
            
            % DRNL maximum output, with MOC working
            bmOut_moc = dObj_moc.filterbank{1}.Data(:);
            bmOutMax_moc = max(bmOut_moc);
            bmOutMaxdB_moc = 20*log10(bmOutMax_moc);

            % ratemap maximum output, with MOC working
            anOut_moc = dObj_moc.ratemap{1}.Data(:);
            anOutMax_moc = max(anOut_moc);
            anOutMaxdB_moc = 20*log10(anOutMax_moc);
%             anOutOffsetMean_moc = mean(anOut_moc(outputWindowStart:outputWindowEnd));
            
            % MOC maximum output
            mocOut = dObj_moc.moc{1}.Data(:);
            mocOutMax = max(mocOut);

            % Input vs DRNL maximum output
            ioFunctionMatrix(jj, kk) = bmOutMaxdB;
            ioFunctionMatrix_moc(jj, kk) = bmOutMaxdB_moc;

            % Input vs ratemap maximum output
            rateLevelFunctionMatrix(jj, kk) = anOutMaxdB;
                        
            % Input vs MOC attenuation output
            mocLevelFunctionMatrix(jj, kk) = mocOutMax;
            
%             dObj.time{1}.plot;
%             figure; plot(bmOut);
%             figure; plot(bmOut_moc);
%             figure; plot(anOut);
%             figure; plot(anOut_moc);
%            
%             clear dObj mObj out
        end
        clear xME xME_noisy param_struct
    end
% end


figure;
% % set(gcf,'DefaultAxesColorOrder',[0 0 0], ...
% %     'DefaultAxesLineStyleOrder','-o|--s|:x|-.*');
plot(leveldBSPL, ioFunctionMatrix);
xlabel('Input tone level (dB SPL)');
ylabel('DRNL output (dB re 1 m/s)');
% title(sprintf('Input-output characteristics of  DRNL filterbank\nfor on-frequency stimulation at various CFs'));
% legendCell=cellstr(num2str(toneFrequency', '%-dHz'));
% legend(legendCell, 'Location', 'NorthWest');

figure;
plot(leveldBSPL, ioFunctionMatrix_moc);



figure;
plot(leveldBSPL, rateLevelFunctionMatrix);
% set(gca, 'FontSize', 12);
xlabel('Input tone level (dB SPL)', 'FontSize', 13);
% ylabel(sprintf('Auditory nerve model output\n(Adaptation loop Model Unit)'), 'FontSize', 13);
% title(sprintf('Rate-level characteristics of AN using DRNL filterbank\nfor on-frequency stimulation at %d Hz', toneFrequency), 'FontSize', 13);
% legendCell=cellstr(num2str(mocFactordB', 'MOC factor = %-d dB'));
% legend(legendCell, 'Location', 'NorthWest', 'FontSize', 10);
% 
% figure;
% plot(leveldBSPL, rateLevelFunctionMatrix_noisy, '-x');
% set(gca, 'FontSize', 12);
% xlabel('Input tone level (dB SPL)', 'FontSize', 13);
% ylabel(sprintf('Auditory nerve model output\n(Adaptation loop Model Unit)'), 'FontSize', 13);
% title(sprintf('Rate-level characteristics of AN using DRNL filterbank\nfor on-frequency stimulation at %d Hz (noisy background)', toneFrequency), 'FontSize', 13);
% legendCell=cellstr(num2str(mocFactordB', 'MOC factor = %-d dB'));
% legend(legendCell, 'Location', 'NorthWest', 'FontSize', 10);

figure;
plot(leveldBSPL, mocLevelFunctionMatrix, '-x');



