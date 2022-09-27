function varargout = setup_randomization_generate(cfg,subject,task,numBlocks,numTrials)

if nargin == 0
    error('No args provided to randomization');
end

% Check that numBlocks is divisible by 10
if cfg.do_P300
    assert(ceil(numBlocks/5) == floor(numBlocks/5))
end

% Reset the random seed to make the randomization repeatable
rng(subject)

% Create distracter lists
P300distracterList = randperm(numBlocks);
distracterResponseList = randperm(numBlocks);

% Without this loop half of the P300 blocks would contain only distractors
if task == "P300"
    for i = 1:(numBlocks/length(cfg.P300.symbols))-1
        for j = 1:numBlocks
            if P300distracterList(j)>length(cfg.P300.symbols)
                P300distracterList(j)=P300distracterList(j)-length(cfg.P300.symbols);
            end
        end
    end
end

% Define columns for events file
if task == "P300"
    randomization = struct('condition',[],'stimulus',[],'ITI',[],'trial',[],'distracterResponse',[],'block',[],'subject',[],'task',[]);
elseif task == "stimDur"
    randomization = struct('stimulus',[],'stimDur',[],'ITI',[],'flickerDot',[],'trial',[],'block',[],'subject',[],'task',[]);
end

% Randomization
for blockNum = 1:numBlocks
    if task == "P300"
        % Stimuli (=letters)
        stimulus = repmat(1:length(cfg.P300.symbols),1,numTrials/length(cfg.P300.symbols));
        
        % Conditions
        condition_dict = {'distractor','distracter'};
        condition = (P300distracterList(blockNum)==stimulus);
        rand_shuffle = randperm(numTrials);
        
        % Left vs right response to distracter
        distracterResponse_dict = {'left','right'};
        if mod(distracterResponseList(blockNum),2)==0
            distracterResponse = repmat(distracterResponse_dict(1),1,numTrials);
        else
            distracterResponse = repmat(distracterResponse_dict(2),1,numTrials);
        end
        
        % Inter-trial intervals (0.7-2.5 s)
        ITI = randsample((0.7+(0:0.01:1.8)),numTrials,true,(0.1.^(0:0.01:1.8)));
%       Check distribution:
%         ITI = randsample((0.7+(0:0.01:1.8)),1e8,true,(0.1.^(0:0.01:1.8)));
%         histogram(ITI,1000)
        
        % Concatenate
        randomization.condition      = [randomization.condition      condition_dict(condition(rand_shuffle)+1)];
        randomization.distracterResponse = [randomization.distracterResponse distracterResponse];
        randomization.trial          = [randomization.trial          1:numTrials];
        randomization.block          = [randomization.block          repmat(blockNum,1,numTrials)];
        randomization.ITI            = [randomization.ITI            ITI];
        
    elseif task == "stimDur"
        % Face stimuli
        stimulus = datasample(cfg.stimDur.stimTex,numTrials);
        rand_shuffle = randperm(numTrials);

        % Inter-trial intervals (0.8-2.5 s)
        ITI = randsample((0.8+(0:0.01:1.7)),numTrials,true,(0.1.^(0:0.01:1.7)));
        if mod(blockNum,2)==0
            randomization.ITI      = [randomization.ITI        ITI];
        elseif mod(blockNum,2)~=0 % odd-numbered blocks don't have ITI's
            randomization.ITI      = [randomization.ITI        NaN(1,numTrials)];
        end
        
        % Stimulus duration (i.e. time from stimOnset(face) to stimOffset (if with blanks) 
        % or to next stimOnset (if without blanks))
        pd = makedist('Loguniform','Lower',0.1,'Upper',1.5);
        x = (0.1:0.01:1.5);
        y = pdf(pd,x);
        stimDur = randsample(x,numTrials,true,y);
%       Visualisation of stimDur distribution
%         stimDur = randsample(x,1e8,true,y);
%         figure(),histogram(stimDur);
%         figure(),scatter(x,y);
%         xline(mean(stimDur),'b');
%         xline(median(stimDur),'y');

        % Concatenate (put it here bcs required for setup_flickertimings())
        randomization.stimDur = [randomization.stimDur stimDur];
        randomization.trial   = [randomization.trial   1:numTrials];
        randomization.block   = [randomization.block   repmat(blockNum,1,numTrials)];

        % Flicker timings
        flicker_dot = setup_flickertimings(cfg.stimDur,numTrials,randomization,blockNum);
        flicker_dot = round(flicker_dot.whenInTrial(1:end),4);
        randomization.flickerDot = [randomization.flickerDot flicker_dot];
    end

    % Concatenate
    randomization.stimulus = [randomization.stimulus   stimulus(rand_shuffle)];
    randomization.subject  = [randomization.subject    repmat(subject,1,numTrials)];
    randomization.task     = [randomization.task       repmat({task},1,numTrials)];
end

% Make sure that length of randomization equals number of trials of experiment
assert(unique(structfun(@length,randomization)) == numBlocks * numTrials)

% Transpose all fields
for fn = fieldnames(randomization)'
    randomization.(fn{1})  = randomization.(fn{1})';
end
% Convert to table
randomization = struct2table(randomization);

%--------------------------------------------------------------------------
% Prevent subsequent distracters in P300 experiment:
% If two subsequent distracters occur, the second distracter trial gets swapped 
% with the trial following it.
% Elseif this occurs at the end of a block, the last distracter gets put to a
% random place within the block and everything is sorted again.
if cfg.do_P300
    while any(ismember(diff(find(ismember(randomization.condition,'distracter'))),1))
        for i = 1:length(randomization.condition)-1 % -1 to prevent indexing error
            if strcmp(randomization.condition(i),'distracter') && strcmp(randomization.condition(i+1),'distracter')...
                    && (mod(i+1,cfg.P300.numTrials)~=0)  % don't swap trials between blocks
                flip = randomization(i+1,:);
                randomization(i+1,:) = randomization(i+2,:);
                randomization(i+2,:) = flip(1,:);
                % Correct trial numbers
                flip_tr = randomization.trial(i+1,:);
                randomization.trial(i+1,:) = randomization.trial(i+2,:);
                randomization.trial(i+2,:) = flip_tr(1,:);
            elseif strcmp(randomization.condition(i),'distracter') && strcmp(randomization.condition(i+1),'distracter')...
                    && mod(i+1,cfg.P300.numTrials)==0 % prevent subsequent distracters at end of block
                flip_rand = round(1+(i-1).*rand(1,1));
                flip = randomization(i-flip_rand,:);
                randomization(i-flip_rand,:) = randomization(i+1,:);
                randomization(i+1,:) = flip(1,:);
                % Correct trial numbers
                flip_tr = randomization.trial(i-flip_rand,:);
                randomization.trial(i-flip_rand,:) = randomization.trial(i+1,:);
                randomization.trial(i+1,:) = flip_tr(1,:);
            end
        end
    end
end
%--------------------------------------------------------------------------

% Save randomization
dirname = fileparts(cfg.(task).randomization_filepath);
if ~exist(dirname,'dir')
    mkdir(dirname)  % Generate dir if it doesn't exist
end
% Write randomization.tsv file
writetable(randomization,cfg.(task).randomization_filepath,'FileType','text','Delimiter','\t');
if nargout == 1
    varargout{1} = randomization;
end
end