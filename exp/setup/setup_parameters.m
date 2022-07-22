function cfg = setup_parameters(cfg)
assert(isstruct(cfg));

% Button box
KbName('UnifyKeyNames')      % Switch to MacOS-X naming scheme (universal thus portable)
cfg.keys = [11 12 13 14 37]; % Button box keycodes [lt rt lb rb mt]
cfg.ix_responseDevice = 14;  % Index of button box

% Screen environment
cfg.computer_environment = 'stimPC';
cfg = setup_environment(cfg);

%% P300
if cfg.do_P300
    cfg.P300 = struct();
    cfg.P300.numBlocks = 10;            % Number of blocks: 10
    cfg.P300.numTrials = 120;           % Number of trials per block: 120
    cfg.P300.stimulusDuration = 0.2;    % in s
    cfg.P300.stimSize = 2.5;            % Stimulus diameter in degrees of visual angle
    cfg.P300.dotSize = 1.5*[0.25 0.06]; % Size of fixation dot in pixels
    cfg.P300.symbols = ['A','B','C','D','E']; % Letters A-E will be used as stimuli
end

%% stimDur
if cfg.do_stimDur
    cfg.stimDur.numBlocks = 6;
    cfg.stimDur.numTrials = 120;
    cfg.stimDur.targetColor = [1,0,0];      % Color of flickering dot - red
    cfg.stimDur.dotSize = 1.5*[0.25 0.06];  % Size of fixation dot in pixels
    cfg.stimDur.targetsPerTrial = 0.1;      % Flicker probability is 10 % --> 1 flicker per 10 trials
    cfg.stimDur.targetsTimeDelta = 4;       % in s --> flickers have to be at least 5s apart
    cfg.stimDur.targetsDuration = 0.1;      % Flicker for 100ms
end

