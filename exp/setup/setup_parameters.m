function cfg = setup_parameters(cfg)

assert(isstruct(cfg));

% Response box
KbName('UnifyKeyNames') % switch to MacOS-X naming scheme (universal thus portable)
cfg.keys = [11 12]; % response box [lt rt]
% cfg.keys = [11 12 13 14 37]; % response box [lt rt lb rb mt]

%% P300

cfg.P300 = struct();
cfg.P300.numBlocks = 5;             % Number of blocks
cfg.P300.numTrials = 60;            % Number of trials in a block
cfg.P300.symbols = ['A','B','C','D','E'];
cfg.P300.stimSize = 100;             % Diameter in degrees
cfg.P300.distractorColor = [0,0,0];
cfg.P300.targetColor = [1,1,1];
cfg.P300.stimulusDuration = 1;      % in s (maximal acceptable response window in ERP CORE)
cfg.P300.ITI = 1;                   % inter trial interval in s - randomized later
%cfg.P300.trialLength = cfg.P300.stimulusDuration + cfg.P300.ITI;
cfg.P300.dotSize = 1.5*[0.25 0.06]; % Size of fixation dot in pixels
% cfg.P300.increment = 0.25;        % Increment to increase thresholds by
cfg.ix_responseDevice = 11;

%% stimDur

cfg.stimDur = cfg.P300;                                                         % YYY definitely need to change this
cfg.stimDur.orientation = [45 135];

%cfg.stimDur.stimBlockLength = round(16/cfg.TR)*cfg.TR; %
%cfg.stimDur.offBlockLength = round(14/cfg.TR)*cfg.TR; %

cfg.stimDur.targetsPerTrial = 1.5;  % on average we will have 1.5 flicker per Trial
cfg.stimDur.targetsTimeDelta = 2;   % s - flicker have to be at least distance of 2s
cfg.stimDur.targetsColor = 0.4;     % percent
cfg.stimDur.targetsDuration = 0.1;  % flicker for 100ms

% screen environment
cfg = setup_environment(cfg);

