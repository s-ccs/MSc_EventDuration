% Fully automated data analysis pipeline: BIDS Tools / EEGLAB / LIMO EEG
%
% The analysis runs on Wakeman and Henson 2015 data, curated and available at
% https://openneuro.org/datasets/ds002718
%
% This code is the companion of https://www.frontiersin.org/articles/10.3389/fnins.2020.610388/full
% Pernet CR, Martinez-Cancino R, Truong D, Makeig S and Delorme A (2021) From BIDS-Formatted EEG Data
% to Sensor-Space Group Results: A Fully Reproducible Workflow With EEGLAB and LIMO EEG. Frontiers in
% Neuroscience 14:610388. doi: 10.3389/fnins.2020.610388
%
% Arnaud Delorme & Cyril Pernet
%
% Changed to be used on manyPipeline data and subsequent Unfold analysis. I.e. no epoching done.
%
% René Skukies
% Benedikt Ehinger
%
% Adapted to be used on MSc_EventDuration data.
%
% Martin Geiger

close all; clear; clc;

% Start EEGLAB
addpath '/home/geiger/MATLAB_Add-Ons/Collections/EEGLAB'
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% Install plugins
plugin_askinstall('bva-io','pop_loadbv',1)
plugin_askinstall('iclabel','pop_iclabel',1)
plugin_askinstall('clean_rawdata','pop_clean_rawdata',1)
plugin_askinstall('amica','pop_amica',1)
plugin_askinstall('firfilt','',1)
plugin_askinstall('dipfit','',1)
plugin_askinstall('BIDS-matlab-tools','pop_importbids',1)
plugin_askinstall('viewprops','pop_prop_extended',1)
% Additionally required - installed manually: zapline, unfold
run('~/unfold/init_unfold.m')

% Control structures
cfg = struct();
cfg.amica = 1; % 0 for infomax. amica works now in reasonable time, no need for infomax
cfg.recalculate_ica = 1;
cfg.srate = 256; % Downsample to
cfg.reimport = 1;

% Paths
cfg.filepath_in  = '/store/data/MSc_EventDuration'; % Path to BIDS files
cfg.filepath_out = '/store/data/non-bids/MSc_EventDuration/bids';
addpath './functions'
addpath './tmp'

% Subjects
subjectsOddball  = [4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41];
subjectsDuration = [1 2 3 4 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 27 28 29 30 31 32 33 34 35 37 38 39 40 41];
cfg.subjectList = {EEG.subject};

% Call BIDS tool BIDS
if cfg.reimport
    for switchTask = 1
        if switchTask == 1
            task = 'Oddball';
            subjects = subjectsOddball;
        elseif switchTask == 2
            task = 'Duration';
            subjects = subjectsDuration;
        end
        for i = subjects(1:end)
            filename = sprintf('sub-%03i_ses-001_task-%s_run-001_eeg.set',i,task);
            EEG = pop_loadset('filepath',[cfg.filepath_in,sprintf('/sub-%03i/ses-001/eeg/',i)],'filename',filename);
            % Remove channel 65 (sample number)
            EEG.data(65,:) = [];
            EEG.chanlocs(:,65) = [];
            EEG.nbchan=64;
            % Add columns that are missing since I couldn't load it with pop_importbids
            EEG.subject = sprintf('sub-%03i',i);
            EEG.session = 1;
            EEG.task = task;
            % Load better events
            tsv = tdfread(fullfile(cfg.filepath_in,sprintf('sub-%03i/ses-001/eeg/sub-%03i_ses-001_task-%s_run-001_events.tsv',i,i,task)));
            EEG.event = struct2table(tsv);
            EEG.event = renamevars(EEG.event,["sample","trial_type"],["latency","type"]); % Rename variables
            EEG.event = struct2table(table2struct(EEG.event)); % Strange but doesn't work otherwise.
            EEG.event.type = deblank(EEG.event.type);
            if switchTask == 1
                EEG.event.condition = deblank(EEG.event.condition);
                EEG.event.target_response = deblank(EEG.event.target_response);
            end
            EEG.event = table2struct(EEG.event);
            % Copy to ALLEEG
            ALLEEG = [ALLEEG;EEG];
        end
    end
end
ALLEEG          = pop_select(ALLEEG, 'nochannel',{'VEOG','HEOG'});
CURRENTSTUDY    = 1;
EEG             = ALLEEG;
CURRENTSET      = 1:length(EEG);

%% Chanlocs
for s=1:size(EEG,1)
    % Loading standard file
    EEG(s) = pop_chanedit(EEG(s), 'lookup','Standard-10-5-Cap385.sfp');
    EEG(s).urchanlocs = EEG(s).chanlocs;
end

%% Downsample to 256 Hz
EEG = pop_resample(EEG,cfg.srate);

%% Remove 50 Hz line noise and unidentified 8 Hz noise and their harmonics
for s = 1:length(EEG)
    EEG(s) = clean_data_with_zapline_plus_eeglab_wrapper(EEG(s),struct('noisefreqs',[8,50]));
end

%% Remove bad channels
rng(1) % Fix random

EEG = pop_clean_rawdata( EEG,'FlatlineCriterion',5,'ChannelCriterion',0.8,...
    'LineNoiseCriterion',4,'Highpass',[0.25 0.75] ,...
    'BurstCriterion','off','WindowCriterion','off','BurstRejection','off',...
    'Distance','Euclidian','WindowCriterionTolerances','off' );

%% Rereference using average reference
EEG = pop_reref( EEG,[],'interpchan',['off']);

%% Remove large spikes
EEG_clean = EEG;

for s = 1:size(EEG,1)
    winRej = uf_continuousArtifactDetect(EEG(s),'amplitudeThreshold',1000);
    EEG_clean(s) = eeg_eegrej( EEG(s), winRej );
    EEG_clean(s).etc.crap_winrej = winRej;
end

% Compare cleaned data to the original:
% vis_artifacts(EEG_clean(1),EEG(1));

%% Run ICA and flag artifactual components using IClabel
% If you load the data again, don't forget to run the cfg. bits from above
if cfg.recalculate_ica
    for switchTask = 1
        if switchTask == 1
            task = 'Oddball';
            subjects = subjectsOddball;
        elseif switchTask == 2
            task = 'Duration';
            subjects = subjectsDuration;
        end
        
        for sub = subjects(1:end)
            for i = 1:size(EEG,1)
                if isequal(EEG_clean(i).subject,sprintf('sub-%03i',sub)) && isequal(EEG_clean(i).task,task)
                    s = i;
                end
            end
            
            % Filter temporary at 1.5 Hz
            EEGica = EEG_clean(s);
            EEGica = pop_eegfiltnew(EEGica, 'locutoff',1.5);
            
            % Run amica
            outdir= fullfile(cfg.filepath_out, 'derivatives','ica',cfg.subjectList{s});
            
            if ~exist(outdir, 'dir')
                mkdir(outdir);
            end
            
            if cfg.amica
                % Define parameters
                numprocs    = 1;    % 2 is to use t-mux in a parallel implementation
                max_threads = 1;    % Number of threads
                num_models  = 1;    % Number of models of mixture ICA
                max_iter    = 1000; % Max number of learning steps
                
                outdir = fullfile(outdir,'amica',filesep);
                if ~exist(outdir, 'dir'); mkdir(outdir);end
                
                % Todo Use AMICA, with automatic data rejection
                ccs_runamica15(double(EEGica.data), ...
                    'num_models',num_models, 'outdir',outdir, ...
                    'numprocs', numprocs, 'max_threads', max_threads, ...
                    'max_iter',max_iter, 'do_reject', 1, 'pcakeep',size(EEGica.data,1)-1,'tmpdir','/home/geiger/2022-MSc_EventDuration/experiments_matlab/PreProcessing/tmp/');
            else
                % Infomax
                EEGica = pop_runica(EEGica, 'icatype', 'runica', 'extended', 1, 'pca', size(EEGica.data,1)-1);
                
                ICA = struct;
                ICA.icawinv = EEGica.icawinv;
                ICA.icaweights = EEGica.icaweights;
                ICA.icasphere = EEGica.icasphere;
                
                outdir = fullfile(outdir, 'infomax');
                if ~exist(outdir, 'dir'); mkdir(outdir);end
                save(fullfile(outdir,sprintf('sub-%03i_task-%s_desc-infomax_ica.mat',sub,task)),'ICA')
            end
        end
    end
    error('stop for now and wait for the ICAs :-)')
end
%% Load ICA and ICLabel

for s = 1:length(EEG)
    if cfg.amica
        outdir= char(fullfile(cfg.filepath_out, 'derivatives','ica',cfg.subjectList{s},'amica',filesep));
        mods = loadmodout15(outdir);
        if ~isfield(mods,'A')
            error('no ICA found?')
        end
    else
        outdir= char(fullfile(cfg.filepath_out, 'derivatives','ica',cfg.subjectList{s},'infomax',filesep));
        tmp= load(fullfile(outdir,sprintf('%s_desc-infomax_ica.mat',cfg.subjectList{s})));
        mods = tmp.ICA;
    end
    
    % Load individual ICA model into EEG structure
    bad_comps_outdir= char(fullfile(cfg.filepath_out, 'derivatives','ica',cfg.subjectList{s},'independent_components',filesep));
    EEG(s) = add_ica(EEG(s),mods,0,bad_comps_outdir);
    EEG_clean(s) = add_ica(EEG_clean(s),mods,cfg.recalculate_ica,bad_comps_outdir);
end

%% Output ICA reports
for s = 1:size(EEG,1)
    IC = EEG(s).etc.ICLabel ;
    
    nIC = size(IC.classifications,1);
    labels = IC.classes(2:end);
    text = sprintf("For subject %s, our ICA decomposition yields %i components. ",cfg.subjectList{s},nIC);
    text = strjoin([text,"From those, we rejected a total of %i components, with"]);
    badTotal = 0;
    for k = 1:length(labels)
        nbad = sum(IC.classifications(:,k+1)>=0.8);
        text = strjoin([text,sprintf("%i being %s;",nbad,labels{k})]);
        badTotal = badTotal+nbad;
    end
    text = sprintf(text,badTotal);
    
    saveTo = sprintf(fullfile(cfg.filepath_out,'derivatives/ica/%s/removed_ICA_components/%s_task-%s_badIC.txt'),cfg.subjectList{s},cfg.subjectList{s},task);
    try mkdir(fileparts(saveTo));end
    fileID = fopen(saveTo,'a');
    
    fprintf(fileID,text);
    fclose(fileID);
end

%% Continuous ASR rejection
% reset seed
rng(1)
% replace the above rawdata with uf_artifacexcludeASR
for s=1:size(EEG,1)
    disp(["subject " num2str(s)])
    EEG(s).uf_winrej = uf_continuousArtifactDetectASR(EEG(s),'channel',find({EEG(s).chanlocs.type} == "EEG"),'cutoff',20,'tolerance',1e-5);
    
    fPath = fullfile(cfg.filepath_out,'derivatives','ASRcleaning',cfg.subjectList{s});
    if ~exist(fPath,'dir');mkdir(fPath);end
    writematrix(EEG(s).uf_winrej,fullfile(fPath,[cfg.subjectList{s} '_desc-ASRCleaningTimes.tsv']),'Delimiter','tab','FileType','text')
end

%% Interpolate Bad Channel
for s=1:size(EEG,1)
    EEG(s) = pop_interp(EEG(s), EEG(s).urchanlocs, 'spherical');
end

%% Highpass-Filter data
EEG = pop_eegfiltnew(EEG, 'locutoff',0.1);

% Checkset and save data
EEG = eeg_checkset(EEG);

%% Update path
for s = 1:size(EEG,2)
    EEG(s).filepath = fullfile(cfg.filepath_out,'derivatives/preprocessed/',cfg.subjectList{s},'eeg');
    if ~exist(EEG(s).filepath,'dir')
        mkdir(EEG(s).filepath);
    end
end
EEG = pop_saveset(EEG, 'savemode', 'resave');

 %#ok<*NBRAK> 
 %#ok<*ASGLU>
 %#ok<*AGROW>
 %#ok<*TRYNC>