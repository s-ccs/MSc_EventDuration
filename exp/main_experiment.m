%% Main experimental script
% MScThesis by Martin Geiger in 2022
% 2 Experiments: P300 & stimDur (= stimulus duration)

%% Setup
close all; clear all; clc;
tic; % Start stopwatch timer

% Initialise paths1
cd ~/projects/2022-MScGeiger/MSc_EventDuration/exp/;
addpath(genpath('.'));
addpath(genpath('/usr/share/psychtoolbox-3/'));
cfg = struct(); % Initialise cfg

% Setup Lsl
addpath(genpath('/home/stimulus/projects/2021-timingTest/EEG-trigger-check/lib/liblsl-Matlab/'));
disp('Loading library...');
lib = lsl_loadlib();
cfg.info = lsl_streaminfo(lib,'LSL_Markers_Matlab','Markers',1,0,'cf_string','myuniquesourceid23444');
cfg.outlet = lsl_outlet(cfg.info);

% Setup parallelport (LPT)
delete(instrfindall) % closes all serial connects
cfg.s = serial('/dev/ttyACM0','BaudRate', 1000000, 'DataBits', 8);
% Open port for communication
fopen(cfg.s);
fprintf(cfg.s,"SET DATA_MODE WRITE\n");

% Check which experiment(s) to run, in debug mode or with participant,
% ger or eng instructions, use LSL or not
% 1 = true --> do
% 0 = false --> don't do
cfg.do_P300    = 1;
cfg.do_stimDur = 0;
cfg.engInst    = 1; % English instructions
cfg.gerInst    = 0; % German instructions
cfg.debug      = 0;
cfg.use_lsl    = 1; % lsl markers
cfg.use_lpt    = 1; % eegoSports markers

% Setup parameters
fprintf('Setting up parameters \n')
cfg = setup_parameters(cfg);

%% Debug
if cfg.debug
    input('!!!DEBUGMODE ACTIVATED!!! - continue with enter')
    Screen('Preference', 'SkipSyncTests', 2)
    PsychDebugWindowConfiguration;
end

%% Subject ID
if cfg.debug
    SID = 99;
else
    SID = input('Enter subject ID:'); % Ask for manual input of SID
end
assert(isnumeric(SID));

%% Setup screen
cfg.whichScreen = max(Screen('Screens')); % Screen ID: 0=WQHD, 1=390Hz
if cfg.debug
    cfg.whichScreen = 0;
end
fprintf('Starting Screen\n')
cfg = setup_window(cfg,cfg.whichScreen); % Opens psychtoolbox on specified screen

% Draw 'Loading task...' so participants don't get confused if this takes some time
Screen('TextSize',cfg.win,50);             % Set text size
Screen('FillRect',cfg.win,cfg.background); % Set background color
if cfg.engInst
    DrawFormattedText2(['Loading task...'],'win',cfg.win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
elseif cfg.gerInst
    DrawFormattedText2(['Lade Experiment...'],'win',cfg.win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
end
Screen('Flip',cfg.win);

%% Load face stimuli for stimDur experiment
if cfg.do_stimDur
    cfg = setup_stimuli(cfg);
end

%% Randomization
randomization = struct();
try
    % Declare paths where to save data
    if cfg.do_P300
        task = {'P300'};
        task1 = {'Oddball'};
    elseif cfg.do_stimDur
        task = {'stimDur'};
        task1 = {'Duration'};
    end
    cfg.(task{1}).randomization_filepath = fullfile('../..','data',sprintf('sub-%03i',SID),'ses-001','beh',sprintf('sub-%03i_task-%s_randomization.tsv',SID,task1{1}));
    cfg.(task{1}).behavioral_filepath_mat = fullfile('../..','data',sprintf('sub-%03i',SID),'ses-001','beh',sprintf('sub-%03i_task-%s_events.mat',SID,task1{1}));
    cfg.(task{1}).behavioral_filepath_tsv = fullfile('../..','data',sprintf('sub-%03i',SID),'ses-001','beh',sprintf('sub-%03i_task-%s_events.tsv',SID,task1{1}));

    if cfg.debug
        error % force randomization regen
    end

    % Load randomization
    randomization.(task{1}) = struct2table(tdfread(fullfile('../..','data',sprintf('sub-%03i',SID),'ses-001','beh',sprintf('sub-%03i_task-%s_randomization.tsv',SID,task1{1}))));
    if cfg.do_P300
        randomization.P300.condition = cellstr(randomization.Oddball.condition);
        randomization.P300.targetResponse = cellstr(randomization.Oddball.targetResponse);
    end
    randomization.(task{1}).task = cellstr(randomization.(task{1}).task);
    fprintf('Loading Randomization from disk\n')

catch
    % Generate randomization
    fprintf('Generating Randomization\n')
    if cfg.do_P300
        randomization.P300 = setup_randomization_generate(cfg,SID,'P300',cfg.P300.numBlocks,cfg.P300.numTrials);
    elseif cfg.do_stimDur
        randomization.stimDur = setup_randomization_generate(cfg,SID,'stimDur',cfg.stimDur.numBlocks,cfg.stimDur.numTrials);
    end
end

%% Do P300 Task
if cfg.do_P300
    fprintf('Starting with P300 Task \n')
    numBlocks = cfg.P300.numBlocks;
    for curBlock = 1:numBlocks
        % Run block
        experiment_P300(cfg,slice_randomization(randomization.P300,SID,curBlock));
        % Between blocks: draw number of next block
        if curBlock < max(numBlocks)
            if cfg.engInst
                text = ['Moving on to block ', num2str(curBlock+1),' of ', num2str(max(numBlocks)),'...'];
            elseif cfg.gerInst
                text = ['Gehe zu Block ', num2str(curBlock+1),' von ', num2str(max(numBlocks)),'...'];
            end
            DrawFormattedText(cfg.win,text,'center','center');
            Screen('Flip',cfg.win);
            % Option to quit experiment between blocks
            stopExec = waitQKey(cfg);
            if stopExec
                return
            end
        end
    end
end

%% Do StimDur Task
if cfg.do_stimDur
    fprintf('Starting with stimDur Task \n')
    numBlocks = cfg.stimDur.numBlocks;
    for curBlock = 1:numBlocks
        % Run block
        experiment_stimDur(cfg,slice_randomization(randomization.stimDur,SID,curBlock));
        % Between blocks: draw number of next block
        if curBlock < max(numBlocks)
            if cfg.engInst
                text = ['Moving on to block ',num2str(curBlock+1),' of ',num2str(max(numBlocks)),'...'];
            elseif cfg.gerInst
                text = ['Gehe zu Block ',num2str(curBlock+1),' von ',num2str(max(numBlocks)),'...'];
            end
            DrawFormattedText(cfg.win, text,'center','center');
            Screen('Flip',cfg.win);
            % Option to quit experiment between blocks
            stopExec = waitQKey(cfg);
            if stopExec
                return
            end
        end
    end
end

%% End experiment
% Draw 'Task finished' as information for subject
Screen('TextSize',cfg.win,50);
Screen('FillRect',cfg.win,cfg.background);
if cfg.engInst
    DrawFormattedText2(['Task finished.\n\nWait for experimenter.'],'win',cfg.win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
elseif cfg.gerInst
    DrawFormattedText2(['Aufgabe beendet.\n\nWarte auf Versuchsleiter.'],'win',cfg.win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
end
Screen('Flip',cfg.win);
WaitSecs(3);

% Close window and lsl stream
safeQuit(cfg);

toc; % Stop stopwatch timer

% Get a green script :)
%#ok<*CLALL>
%#ok<*NBRAK>
%#ok<*LTARG>
%#ok<*SERIAL>