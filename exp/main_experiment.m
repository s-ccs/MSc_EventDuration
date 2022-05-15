%% Main Experimental script
% MScThesis by Martin Geiger in 2022
% 2 Experiments: P300 & stimDur(Stimulus Duration)


% Comments:
% XXX ToDo by Bene
% YYY ToDo by myself
% ? Question for myself
% ??? Question for René or Bene

% Run through experiment.
%--------------------------------------------------------------------------
close all; clear; clc;
tic;    % Start stopwatch timer

% Initialise paths
cd ~/projects/2022-MScGeiger/MSc_EventDuration/exp/;
addpath(genpath('.'));
addpath(genpath('/usr/share/psychtoolbox-3/'));

cfg = struct();
cfg.do_P300    = 1; % if 0 = false, if 1 = true
cfg.do_stimDur = 0;
cfg.debug = 1; % Check debugmode                                            % set to 0 for experiment
cfg.computer_environment = 'stimPC';

fprintf('Setting up parameters \n')
cfg = setup_parameters(cfg);

%% Debug

if cfg.debug
    input('!!!DEBUGMODE ACTIVATED!!! - continue with enter')
    sca;  % to close psychtoolbox overlay
    Screen('Preference', 'SkipSyncTests', 1)
    PsychDebugWindowConfiguration;
end

%% Subject ID

if cfg.debug
    SID = 99;
else
    SID = input('Enter subject ID:');   % asks for manual input of SID
end
assert(isnumeric(SID))

%% Randomization

randomization = struct();
try
    for task = {'P300','stimDur'}
        cfg.(task{1}).randomization_filepath = fullfile('..','results',sprintf('subj-%03i',SID),'ses-01','beh',sprintf('sub-%03i_task-%s_randomization.tsv',SID,task{1}));
        cfg.(task{1}).behavioral_filepath = fullfile('..','results',sprintf('subj-%03i',SID),'ses-01','beh',sprintf('sub-%03i_task-%s_events.mat',SID,task{1}));
    end

    if cfg.debug
        % force randomization regen
        error
    end
    tmp = readtable(sprintf('randomizations/sub-%03i_task-P300_randomization.tsv',SID));
    randomization.P300 = tmp.randomization;
    %tmp = load(sprintf('randomizations/sub-%03i_task-stimDur_randomization.mat',SID));
    % fill XXX randomization.stimDur
    fprintf('Loading Randomization from disk\n')
    
catch
    fprintf('Generating Randomization\n')
    randomization.P300 = setup_randomization_generate(cfg,SID,'P300',cfg.P300.numBlocks,cfg.P300.numTrials);
    %randomization.stimDur = setup_randomization_generate(cfg,SID,'stimDur',cfg.stimDur.numBlocks,cfg.stimDur.numTrials);
    
    
end

%% Setup Screen

whichScreen = max(Screen('Screens')); % Screen ID: 0=WQHD, 1=390Hz
if cfg.debug
    whichScreen = 0;
end
fprintf('Starting Screen\n')
cfg = setup_window(cfg,whichScreen); % opens psychtoolbox on specified screen

%% Do P300 Task

if cfg.do_P300
    fprintf('Starting with P300 Task \n')
    numBlocks = cfg.P300.numBlocks;
    for curBlock = 1:numBlocks % is a sorted list of runs
        fprintf('Block %i from %i \n',curBlock,numBlocks)
        fprintf('Drawing subject instructions \n')
        
        DrawFormattedText(cfg.win, 'Starting P300 task ...', 'center', 'center');
        fprintf('Starting experiment_adaptation \n')
        
        experiment_P300(cfg,slice_randomization(randomization.P300,SID,curBlock));
        
        
        if curBlock < max(numBlocks)
            text = ['Moving on to run ', num2str(curBlock+1), ' of ', num2str(max(numBlocks)), '...'];
            DrawFormattedText(cfg.win, text, 'center', 'center');
            Screen('Flip',cfg.win);
            waitQKey(cfg)
        end
        toc
    end
    
end

%% Do StimDur Task

if cfg.do_stimDur
    fprintf('Starting with stimDur Task \n')
    numBlocks = cfg.stimDur.numBlocks;
    for curBlock = numBlocks % is a sorted list of runs
        fprintf('Run %i from %i \n',curBlock,length(numBlocks))
        fprintf('Drawing subject instructions \n')
        
        DrawFormattedText(cfg.win, 'Moving on to main task ...', 'center', 'center');
        
        fprintf('Starting experiment_adaptation \n')
        experiment_stimDur(cfg,slice_randomization(randomization,SID,curBlock));
        
        if curBlock < max(numBlocks)
            text = ['Moving on to run ', num2str(curBlock+1), ' of ', num2str(max(numBlocks)), '...'];
            DrawFormattedText(cfg.win, text, 'center', 'center');
            Screen('Flip',cfg.win);
            waitQKey(cfg)
            
        end
        if cfg.writtenCommunication
            communicateWithSubject(cfg.win,'',200,200,cfg.Lmin_rgb,cfg.background);
        end
        toc
    end
    
end

%% -----------------------------------------------------------------
% call function to close window and clean up
toc
safeQuit(cfg);
