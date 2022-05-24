function varargout = setup_randomization_generate(cfg,subject,task,numBlocks,numTrials)

if nargin == 0
    error
end

% Check that numBlocks is divisible by 10
assert(ceil(numBlocks/5) == floor(numBlocks/5))

% Reset the random seed to make the randomization repeatable.
% Order of distractors and targets remains equal as long as in debug mode,
% because always SID=99.
rng(subject) 

randomization = struct('condition',[],'stimulus',[],'ITI',[],'trial',[],'block',[],'subject',[],'task',[]);

% Creates rvector containing a random permutation of the integers 1:N.
% Number of blocks should be divisible by number of symbols, so each symbol
% is a target equally often.
P300targetList = randperm(numBlocks);

for blockNum = 1:numBlocks
    if task == "P300"
        % Create rvector as long as numTrials/Block, with repeating entries
        % 1-5 (-> 5 = number of symbols!).
        stimulus = repmat(1:5,1,numTrials/5);                                   % Change '5' if number of symbols changes
        % specify conditions
        condition_dict = {'distractor','target'};
        % Puts 1 in rows of 'condition' rvector, in which entries of 
        %'stimulus' rvector equal 'blockNum'th entry in P300target list. 
        % Else 0.
        % e.g.: P300targetList=[4 2 1 5 3]; blockNum=4; stimulus = repmat(1:5,1,3). 
        % Then a 1 is in row 5,10,15 of 'condition' rvector, because 
        % 4th entry (=5) of P300targetList is equal to 5th,10th,15th entry 
        % in 'stimulus'.
        condition = (P300targetList(blockNum) == stimulus); 
        % Create vector as long as numTrials/Block containing all integers
        % 1:numTrials randomly.
        % -> vector of length 60, numbers 1:60 randomly distributed.
        rand_shuffle = randperm(numTrials);

        % randomize inter-trial intervals
        ITI = randsample((0.5+(0:0.01:5)),numTrials,true,(0.1.^(0:0.01:5)));
        % ITI = randsample((0.5+(0:0.01:5)),1e8,true,(0.1.^(0:0.01:5)));
        % histogram(ITI,60)

    elseif task == "stimDur"
        % XXX
    else 
        error("wrong task")
    end
    
    % Concatenate matrices for subsequent blocks.
    % Equal reasoning as next comment. Target will be at every entry of 
    % rand_shuffle divisible by 5. Distractors will be everywhere else.
    randomization.condition = [randomization.condition condition_dict(condition(rand_shuffle)+1)];
    % stimulus(rand_shuffle): each entry from 'stimulus' rvector (l.18) gets
    % drawn into new rvector according to 'rand_shuffle'.
    % e.g.: rand_shuffle = [24 46 10 ...]. Takes values from 24th, 46th, and
    % 32nd row of 'stimulus' vector and puts them into
    % 'randomization.stimulus' at position 1,2,3,... if first run through
    % for loop, 61,62,63,... if 2nd run of foor loop, and so on.
    % rand_shuffle changes every loop iteration, so order of stimuli
    % changes between blocks aswell.
    randomization.stimulus = [randomization.stimulus   stimulus(rand_shuffle)];
    randomization.trial    = [randomization.trial      1:numTrials];
    randomization.ITI      = [randomization.ITI        ITI];
    randomization.block    = [randomization.block      repmat(blockNum,1,numTrials)];
    randomization.subject  = [randomization.subject    repmat(subject,1,numTrials)];
    randomization.task     = [randomization.task       repmat({task},1,numTrials)];
end

% Make sure that length of randomization vectors equals trials of
% experiment.
assert(unique(structfun(@length,randomization)) == numBlocks * numTrials)

% Transpose all fields in order to convert to table.
for fn = fieldnames(randomization)'
   randomization.(fn{1})  = randomization.(fn{1})';
end
randomization = struct2table(randomization);

% Save randomization.
dirname = fileparts(cfg.(task).randomization_filepath);
if ~exist(dirname,'dir')
    mkdir(dirname)  % Generate dir if it doesn't exist.
end 
writetable(randomization,cfg.(task).randomization_filepath,'FileType','text','Delimiter','\t');
if nargout == 1
    varargout{1} = randomization;
end
end