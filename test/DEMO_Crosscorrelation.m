clear;
close all
clc


%% LOAD SIGNAL
% 
% 
% Load a signal
load('AFE_earSignals_16kHz');

% Create a data object based on parts of the ear signals
dObj = dataObject(earSignals(1:20E3,:),fsHz);


%% PLACE REQUEST AND CONTROL PARAMETERS
% 
% 
% Request cross-corrleation function (CCF)
requests = {'crosscorrelation'};

% Parameters of Gammatone processor
gt_nChannels  = 32;  
gt_lowFreqHz  = 80;
gt_highFreqHz = 8000;

% Parameters of innerhaircell processor
ihc_method    = 'dau';

% Parameters of autocorrelation processor
cc_wSizeSec  = 0.02;
cc_hSizeSec  = 0.01;
cc_wname     = 'hann';

% Parameters 
par = genParStruct('gt_lowFreqHz',gt_lowFreqHz,'gt_highFreqHz',gt_highFreqHz,...
                   'gt_nChannels',gt_nChannels,'ihc_method',ihc_method,...
                   'cc_wSizeSec',cc_wSizeSec,'cc_hSizeSec',cc_hSizeSec,...
                   'cc_wname',cc_wname); 
               

%% PERFORM PROCESSING
% 
% 
% Create a manager
mObj = manager(dObj,requests,par);

% Request processing
mObj.processSignal();


%% PLOT RESULTS
% 
% 
% Plot the CCF of a single frame
frameIdx2Plot = 10;

% Get sample indexes in that frame to limit waveforms plot
wSizeSamples = 0.5 * round((cc_wSizeSec * fsHz * 2));
wStepSamples = round((cc_hSizeSec * fsHz));
samplesIdx = (1:wSizeSamples) + ((frameIdx2Plot-1) * wStepSamples);

lagsMS = dObj.crosscorrelation{1}.lags*1E3;

% Plot the waveforms in that frame
dObj.plot([],[],'bGray',1,'rangeSec',[samplesIdx(1) samplesIdx(end)]/fsHz)
ylim([-0.35 0.35])

% Plot the cross-correlation in that frame
p3 = genParStruct('corPlotZoom',5);
dObj.crosscorrelation{1}.plot([],p3,frameIdx2Plot);


%% SHOW CCF MOVIE
% 
% 
if 0
    h3 = figure;
    % Pause in seconds between two consecutive plots 
    pauseSec = 0.0125;
    dObj.crosscorrelation{1}.plot(h3,p3,1);
    
    % Loop over the number of frames
    for ii = 2 : size(dObj.crosscorrelation{1}.Data(:),1)
        h31=get(h3,'children');
        cla(h31(1)); cla(h31(2));
        
        dObj.crosscorrelation{1}.plot(h3,p3,ii,'noTitle',1);
        pause(pauseSec);
        title(h31(2),['Frame number ',num2str(ii)])
    end
end