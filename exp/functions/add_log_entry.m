function add_log_entry(varargin)

if nargin <1
    message = '';
else
    message = varargin{1};
end
if nargin < 2
    time = GetSecs-startTime;
else
    time = varargin{2};
end

% Send triggers via LSL
cfg=varargin{3};
if cfg.use_lsl
    triggerNum = sprintf('%s:%.4f',message,time);
    cfg.outlet.push_sample({triggerNum});
end

% Update events file
fLog=varargin{4};
randomization_block=varargin{5};
trialNum=varargin{6};
if nargin<7
    duration=NaN;
    fprintf(fLog,'%.4f\t%s\t%.4f\t%s\t%i\t%.3f\t%i\t%i\t%03i\n',time,message,...
        duration,...
        randomization_block.condition{trialNum},...
        randomization_block.stimulus(trialNum),...
        randomization_block.ITI(trialNum),...
        randomization_block.trial(trialNum),...
        randomization_block.block(trialNum),...
        randomization_block.subject(trialNum));
end
if nargin==7
    duration=varargin{2}-varargin{7}; % equals reaction time unless rt is larger than cfg.P300.stimulusDuration
    fprintf(fLog,'%.4f\t%s\t%.4f\t%s\t%i\t%.3f\t%i\t%i\t%03i\n',time,message,...
        duration,...
        randomization_block.condition{trialNum},...
        randomization_block.stimulus(trialNum),...
        randomization_block.ITI(trialNum),...
        randomization_block.trial(trialNum),...
        randomization_block.block(trialNum),...
        randomization_block.subject(trialNum));
end

end