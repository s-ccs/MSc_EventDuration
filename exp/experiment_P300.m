function experiment_P300(cfg,randomization_block)

% Set up outFile
outFile = setup_outFile(cfg);

% Calculate stimulus size
[cfg.P300.stimSize,~] = degrees2pixels(cfg.P300.stimSize,cfg.distFromScreen,cfg.pixelsPerCm,cfg.whichScreen);

% Draw background
Screen('FillRect',cfg.win,cfg.background);
Screen('Flip',cfg.win);

% Set up queue for recording button presses
setup_kbqueue(cfg);
responses = [];

%% Instructions
instructions(cfg,randomization_block);
KbWait(cfg.ix_responseDevice); % Wait for participant to read, pause (optional), and start block

%% MAIN TRIAL LOOP
fprintf(['Starting block ',num2str(randomization_block.block(1)),' of ',num2str(cfg.P300.numBlocks),'.\n'])
draw_fixationdot(cfg,cfg.P300.dotSize) % Start with fixation cross
startTime = Screen('Flip',cfg.win); % Store time at which experiment started
Screen('TextSize',cfg.win,cfg.P300.stimSize); % Set stimulus size
expectedTime = 0; % This will record what the expected event duration should be
send_trigger('blockStart',expectedTime,cfg); % Send lsl trigger for block start
blockOnOff(1) = expectedTime; % Store time at which blocks start

% Wait 3 seconds after instructions before first stimulus
WaitSecs(3);
expectedTime = expectedTime + 3;

% Start trial press queue
RestrictKeysForKbCheck([]); % Reenable all keys on button box
KbQueueStart(cfg.ix_responseDevice); % Start response queue
Screen('TextFont',cfg.win,char('Roboto Mono')); % Set stimulus font

% Present stimuli
for trialNum = 1:length(randomization_block.trial)
    % Current stimulus to be displayed
    currStim = cfg.P300.symbols(randomization_block.stimulus(trialNum));
    
    % Save timings
    expectedtimings(trialNum,1) = expectedTime;
    
    % Draw background and fixation dot
    Screen('FillRect',cfg.win,cfg.background);
    draw_fixationdot(cfg,cfg.P300.dotSize)

    % Translate stimuli along x-axis for perfect centering on fixation dot
    if (currStim == 'B') || (currStim == 'D') || (currStim == 'E')
        DrawFormattedText2(currStim,'win',cfg.win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center','transform',{'translate',[11 0]});
    else
        DrawFormattedText2(currStim,'win',cfg.win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center','transform',{'translate',[4 0]});
    end
    
    % Show the stimulus
    stimOnset = Screen('Flip',cfg.win,startTime+expectedTime-cfg.halfifi,1)-startTime;
    send_trigger('stimOnset',stimOnset,cfg); % Send lsl trigger for stimOnset
    
    % Read out all the button presses
    while true
        if ~KbEventAvail(cfg.ix_responseDevice)
            break
        end
        evt = KbEventGet(cfg.ix_responseDevice);
        if evt.Pressed==1 && trialNum ~= 1 % don't record key releases and prevent indexing error (if response to first stimulus of block for whatever reason is <~10 ms)
            send_trigger('buttonpress',evt.Time-startTime,cfg); % Send lsl trigger for response
            evt.TimeMinusStart = evt.Time-startTime;
            evt.subject = randomization_block.subject(1);
            evt.block = randomization_block.block(1);
            evt.trialNumber = trialNum-1;
            evt.stimulus = cfg.P300.symbols(randomization_block.stimulus(trialNum-1));
            evt.condition = randomization_block.condition(trialNum-1);
            responses = [responses evt];
        end
    end
    
    % How long should the stimulus be on?
    expectedTime = expectedTime + cfg.P300.stimulusDuration;
    
    % ITI:
    % Draw a gray background on top of the stimulus
    Screen('FillRect',cfg.win,cfg.background);
    % Return to fixation dot after stimulus presentation time
    draw_fixationdot(cfg,cfg.P300.dotSize)
    stimOffset = Screen('Flip',cfg.win,startTime+expectedTime-cfg.halfifi,1)-startTime;
    send_trigger('stimOffset',stimOffset,cfg) % Send lsl trigger for stimOffset
    % Length of ITI
    expectedTime = expectedTime + randomization_block.ITI(trialNum);
    
    % Read out response to last stimulus of block
    if trialNum == length(randomization_block.trial)
        WaitSecs(randomization_block.ITI(trialNum));
        Screen('FillRect',cfg.win,cfg.background);
        endBlock = Screen('Flip',cfg.win,startTime+expectedTime-cfg.halfifi,1)-startTime;
        send_trigger('blockEnd',endBlock,cfg); % Send lsl trigger for block end
        blockOnOff(2) = endBlock; % Store time at which blocks end
    end
    while true
        if ~KbEventAvail(cfg.ix_responseDevice)
            break
        end
        evt = KbEventGet(cfg.ix_responseDevice);
        if evt.Pressed==1 % Don't record key releases
            send_trigger('buttonpress',evt.Time-startTime,cfg);
            evt.TimeMinusStart = evt.Time-startTime;
            evt.subject = randomization_block.subject(1);
            evt.block = randomization_block.block(1);
            evt.trialNumber = trialNum;
            evt.stimulus = cfg.P300.symbols(randomization_block.stimulus(trialNum));
            evt.condition = randomization_block.condition(trialNum);
            responses = [responses evt];
        end
    end
    
    % Save timings and further relevant information
    stimtimings(trialNum,1) = stimOnset;
    stimtimings(trialNum,2) = stimOffset;
    expectedtimings(trialNum,2) = expectedTime;
    stimtimings(trialNum,3) = trialNum;
    stimtimings(trialNum,4) = randomization_block.block(trialNum);
    
    % Safe quit mechanism (hold q to quit)
    [keyPr,~,key,~] = KbCheck;
    key = find(key);
    if keyPr == 1 && strcmp(KbName(key(1)),'q')
        save_events(outFile,responses,randomization_block,cfg,stimtimings,expectedtimings,blockOnOff);
        return
    end
end % End of trial loop

% Display expected and actual time of block duration
endTime = Screen('Flip',cfg.win,startTime+expectedTime-cfg.halfifi);
disp(['Time elapsed was ',num2str(endTime-startTime),' seconds']);
disp(['(Should be ',num2str(expectedTime),' seconds)']);

% Stop delivering reponses to the queue
KbQueueStop(cfg.ix_responseDevice);

% Reset text size for instructions
Screen('TextSize',cfg.win,50);

% Call function to save results
% First dump everything to workspace just in case something goes wrong
assignin('base','responses',responses);
% Save results
save_events(outFile,responses,randomization_block,cfg,stimtimings,expectedtimings,blockOnOff);

% Get a green script =)
%#ok<*AGROW>
%#ok<*NBRAK>
end
