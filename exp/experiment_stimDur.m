function experiment_stimDur(cfg,randomization_block)

params = cfg.stimDur;
ntrials = length(randomization_block.trial);

% Set up outFile
outFile = setup_outFile(cfg);

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
fprintf(['Starting block ',num2str(randomization_block.block(1)),' of ',num2str(cfg.stimDur.numBlocks),'.\n'])
draw_fixationdot(cfg,params.dotSize) % Start with fixation cross
startTime = Screen('Flip',cfg.win); % Store time at which block started
expectedTime = 0; % This will record what the expected event duration should be
send_trigger('blockStart',expectedTime,cfg); % Send lsl trigger for block start
blockOnOff(1) = expectedTime; % Store time at which blocks start

% Wait 3 seconds after instructions before first stimulus
WaitSecs(3);
expectedTime = expectedTime + 3;

% Start trial press queue
RestrictKeysForKbCheck([]); % Reenable all keys on button box
KbQueueStart(cfg.ix_responseDevice); % Start response queue

% Present stimuli
for trialNum = 1:ntrials
    % Current stimulus to be displayed
    currStim = randomization_block.stimulus(trialNum);
    
    % Save timings
    expectedtimings(trialNum,1) = expectedTime;
    
    % Show the stimulus
    Screen('FillRect',cfg.win,cfg.background); % Draw background
    Screen ('DrawTexture',cfg.win,currStim); % Draw stimulus (face image)
    draw_fixationdot(cfg,cfg.stimDur.dotSize); % Draw fixation dot
    stimOnset = Screen('Flip',cfg.win,startTime+expectedTime-cfg.halfifi,1)-startTime;
    send_trigger('stimOnset',stimOnset,cfg); % Send lsl trigger for stimOnset
    
    % Flicker
    if randomization_block.flickerDot(trialNum) ~= 0
        % Flicker on (red)
        % Flicker gets their own expectedTime to not disturb others
        expectedTime_flicker = expectedTime+randomization_block.flickerDot(trialNum);
        Screen ('DrawTexture',cfg.win,currStim);
        draw_fixationdot(cfg,params.dotSize,0,params.targetColor*cfg.Lmax_rgb);
        targetOnset = Screen('Flip',cfg.win,startTime+expectedTime_flicker-cfg.halfifi)-startTime;
        send_trigger('targetOnset',targetOnset,cfg); % Send LSL trigger for flicker start
        expectedtimings(trialNum,3) = expectedTime_flicker;
        
        % Flicker off (reset to normal color)
        expectedTime_flicker = expectedTime_flicker+params.targetsDuration;
        Screen ('DrawTexture',cfg.win,currStim);
        draw_fixationdot(cfg,params.dotSize);
        targetOffset = Screen('Flip',cfg.win,startTime+expectedTime_flicker-cfg.halfifi)-startTime;
        send_trigger('targetOffset',targetOffset,cfg); % % Send LSL trigger for flicker end
        
        % Save timings
        expectedtimings(trialNum,4) = expectedTime_flicker;
        stimtimings(trialNum,3) = targetOnset;
        stimtimings(trialNum,4) = targetOffset;
    end
    
    % How long should the stimulus be on?
    expectedTime = expectedTime+randomization_block.stimDur(trialNum);
    
    % Flip for ITI if block contains blanks (--> even numbered blocks)
    if mod(randomization_block.block(1),2)==0 || (trialNum==ntrials)
        Screen('FillRect',cfg.win,cfg.background);
        draw_fixationdot(cfg,params.dotSize);
        stimOffset = Screen('Flip',cfg.win,startTime+expectedTime-cfg.halfifi,1)-startTime;
        send_trigger('stimOffset',stimOffset,cfg); % Send LSL trigger for stimOffset
        % Save timing
        stimtimings(trialNum,2) = stimOffset;
        % Length of ITI
        if mod(randomization_block.block(1),2)==0
            expectedTime = expectedTime + randomization_block.ITI(trialNum);
        elseif mod(randomization_block.block(1),2)~=0 % Leave 2s at end of blocks without blanks for last response
            expectedTime = expectedTime + 2;
        end
    end
    
    % Leave time to read out response to last stimulus of block
    if trialNum == length(randomization_block.trial)
        WaitSecs(2);
    end

    % Read button presses
    while true
        if ~KbEventAvail(cfg.ix_responseDevice)
            break
        end
        evt = KbEventGet(cfg.ix_responseDevice);
        if evt.Pressed==1 % Don't record key releases
            send_trigger('buttonpress',evt.Time-startTime,cfg); % Send lsl trigger for response
            evt.TimeMinusStart = evt.Time-startTime;
            evt.subject = randomization_block.subject(1);
            evt.block = randomization_block.block(1);
            evt.trialNumber = trialNum;
            evt.stimulus = randomization_block.stimulus(trialNum);
            responses = [responses evt];
        end
    end

    % Send lsl trigger for block end
    if trialNum == length(randomization_block.trial)
        expectedTime = expectedTime + 2;
        Screen('FillRect',cfg.win,cfg.background);
        endBlock = Screen('Flip',cfg.win,startTime+expectedTime-cfg.halfifi,1)-startTime;
        send_trigger('blockEnd',endBlock,cfg);
        blockOnOff(2) = endBlock; % Store time at which blocks end
    end
    
    % Save timings and further relevant information
    stimtimings(trialNum,1) = stimOnset;
    expectedtimings(trialNum,2) = expectedTime;
    stimtimings(trialNum,5) = trialNum;
    stimtimings(trialNum,6) = randomization_block.block(trialNum);

    % Safe quit mechanism (hold q to quit)
    [keyPr,~,key,~] = KbCheck;
    % && instead of & causes crashes here, for some reason
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

% Call function to save results
% First dump everything to workspace just in case something goes wrong
assignin('base','responses',responses);
% Save results
save_events(outFile,responses,randomization_block,cfg,stimtimings,expectedtimings,blockOnOff);

%#ok<*AGROW>
end
