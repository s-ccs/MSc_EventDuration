function experiment_P300(cfg,randomization_block)
%--------------------------------------------------------------------------


%% XXX Put the following things into a function to be called by stimDur as well!

subjectid = randomization_block.subject(1);
blockid = randomization_block.block(1);
task = randomization_block.task{1};

outFile = cfg.(task).behavioral_filepath;
if ~exist(fileparts(outFile),'dir')
    mkdir(fileparts(outFile))
end

fLog = fopen([outFile(1:end-3),'tsv'],'w');
if fLog == -1
    error('could not open logfile')
end

% print Header
% XXX Adjust fLog to actual needs
fprintf(fLog,'%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n','onset','message','duration','condition','stimulus','ITI','trial','block','subject');

Screen('FillRect', cfg.win, cfg.background);

%--------------------------------------------------------------------------
% Generate stimulus textures
Screen('DrawText',cfg.win,'Generating textures...', 100, 100);
Screen('Flip',cfg.win);
params = cfg.P300;

% XXX for stimDur we would load the textures here (in case of faces)
% cfg = setup_stimuli(cfg,params); % adapt must be a struct of cfg, e.g. cfg.adapt must exist with necessary information

%--------------------------------------------------------------------------
% Set up queue for recording button presses
% XXX Check if KB Queue works with timestamps
setup_kbqueue(cfg);
responses = [];

%--------------------------------------------------------------------------
ntrials = length(randomization_block.trial);

% XXX Only for StimDur
%trialDistractor_dot = setup_distractortimings(params,ntrials,params.trialLength); % only when the stimulus is shown, but not in the first and last second

%--------------------------------------------------------------------------


%% Instructions

% % XXX Adapt the instructions; do this much later.
% clicks = 0;
% Screen('FillRect',cfg.win,cfg.background);
% 
% fprintf('Showing Instructions: waiting for mouse click (waiting for ScanTrigger after this)')
% 
% while ~any(clicks)
%     introtex = cfg.stimTex(1);
%     
%     flicker = mod(GetSecs,1)<cfg.stimDur.targetsDuration; % flicker every 1s
%     
%     
%     if flicker
%         colorInside = 255*cfg.sustained.targetsColor;
%     else
%         colorInside = 0;
%     end
%     instructions = 'Look at the fixation dot in the centre of the screen at all times\n\n\n\n Press a key if the FIXATION DOT flickers \n\n\n\n Run length: 5 minutes';
%     Screen('DrawText',cfg.win,'Waiting for mouse click...', 100, 100);
%     
%     
%     Screen('DrawTexture',cfg.win,introtex,[],OffsetRect(CenterRect([0 0, 0.5*cfg.stimsize],cfg.rect),cfg.width/4,0));
%     
%     
%     
%     [~,~,~] = DrawFormattedText(cfg.win, instructions, 'left', 'center'); % requesting 3 arguments disables clipping ;)
%     draw_fixationdot(cfg,cfg.stimDur.dotSize,0,colorInside,cfg.width/4*3,cfg.height/2)
%     
%     Screen('Flip',cfg.win);
%     
%     
%     [~,~,clicks] = GetMouse();
%     %     clicks
%     
% end
% fprintf(' ... click\n')

%--------------------------------------------------------------------------
%% MAIN TRIAL LOOP

% Begin presenting stimuli
draw_fixationdot(cfg,params.dotSize) % Start with fixation cross
startTime = Screen('Flip',cfg.win); % Store time at which experiment started
expectedTime = 0; % This will record what the expected event duration should be

% Start trial press queue 
KbQueueStart(cfg.ix_responseDevice); 

tic
for trialNum = 1:ntrials
    % Current stimulus to be displayed
    currStim = cfg.P300.symbols(randomization_block.stimulus(trialNum));
    
    % Wait 3 seconds before first stimulus
    if trialNum==1
        WaitSecs(3);
        expectedTime = expectedTime + 3;
    end
    
    % expectedTime = 0;
    expectedTime_start = expectedTime;
    expectedtimings(1,trialNum) = expectedTime;
    drawingtime = 2*cfg.halfifi;
    
    % Show the stimulus
    Screen('FillRect',cfg.win,cfg.background);
    Screen('TextSize',cfg.win,cfg.P300.stimSize);
    [x,y] = RectCenter(cfg.rect);
    stimRect = CenterRectOnPoint([0 0 500 500],x,y);
    %tic
    %Screen('DrawText',cfg.win,currStim,x,y);
    DrawFormattedText2(currStim,'win',cfg.win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center','winRect',stimRect);
    % Alternative: Screen('DrawText',cfg.win,currStim,x,y);
    %tall(trialNum) = toc;
    stimOnset = Screen('Flip', cfg.win, startTime + expectedTime - cfg.halfifi,1) - startTime;
    add_log_entry('stimOnset',stimOnset,cfg,fLog,randomization_block,trialNum) % also sends trigger
    
    % Prepare Inter-trial interval
    % draw a gray background on top of the stimulus
    Screen('FillRect',cfg.win,cfg.background);
    % return to fixation after stimulus presentation time
    draw_fixationdot(cfg,params.dotSize)
    
    % Read out all the button presses
    while true
        if ~KbEventAvail(cfg.ix_responseDevice)
            break
        end
        evt = KbEventGet(cfg.ix_responseDevice);
        if evt.Pressed==1 % don't record key releases
            add_log_entry('buttonpress',evt.Time-startTime,cfg,fLog,randomization_block,trialNum);
            evt.blockNumber = trialNum;
            evt.TimeMinusStart = evt.Time - startTime;
            % evt.trialDistractor_stimulus = trialDistractor_stimulus{blockNum};
            % evt.trialDistractor_dot = trialDistractor_dot{blockNum};
            evt.subject = randomization_block.subject(1);
            evt.block = randomization_block.block(1);
            responses = [responses evt];
        end
    end
    
    % How long should the stimulus be on?
    % Empty Queue - otherwise responses during ITI would result in skip of
    % stimulus
    KbQueueFlush(cfg.ix_responseDevice,2);
    % Either as long as maximally specified (cfg.P300.stimulusDuration)...
    expectedTime = expectedTime + cfg.P300.stimulusDuration;
    % ... or until reaction
    t0 = GetSecs;
    t1 = t0;
    while((t1-t0)<cfg.P300.stimulusDuration)
        if KbEventAvail(cfg.ix_responseDevice)
            expectedTime = (expectedTime-cfg.P300.stimulusDuration) + (t1-t0);
            break
        else
            t1 = GetSecs;
        end
    end
    
    % Flip for ITI
    stimOffset = Screen('Flip', cfg.win, startTime + expectedTime - cfg.halfifi,1)- startTime;
    add_log_entry('stimOffset',stimOffset,cfg,fLog,randomization_block,trialNum,stimOnset)
    % Length of ITI
    expectedTime = expectedTime + randomization_block.ITI(trialNum);
    
    % save for some kind of stimulus timing check
    stimtimings(1,trialNum) = stimOnset;
    stimtimings(2,trialNum) = stimOffset;
    expectedtimings(2,trialNum) = expectedTime;
    
    % Read out button presses after last reponse
    if trialNum==ntrials
        while true
            if ~KbEventAvail(cfg.ix_responseDevice)
                break
            end
            evt = KbEventGet(cfg.ix_responseDevice);
            if evt.Pressed==1 % don't record key releases
                add_log_entry('buttonpress',evt.Time-startTime,cfg,fLog,randomization_block,trialNum);
                evt.blockNumber = trialNum;
                evt.TimeMinusStart = evt.Time - startTime;
                % evt.trialDistractor_stimulus = trialDistractor_stimulus{blockNum};
                % evt.trialDistractor_dot = trialDistractor_dot{blockNum};
                evt.subject = randomization_block.subject(1);
                evt.block = randomization_block.block(1);
                responses = [responses evt];
            end
        end
    end

    % Safe quit mechanism (hold q to quit)
    [keyPr,~,key,~] = KbCheck;
    % && instead of & causes crashes here, for some reason
    key = find(key);
    if keyPr == 1 && strcmp(KbName(key(1)),'q')
        save_and_quit(outFile,responses, randomization_block,cfg,stimtimings,expectedtimings,trialDistractor_stimulus,trialDistractor_dot);
        return
    end
end  % END OF TRIAL LOOP

%disp(tall)
endTime = Screen('Flip', cfg.win, startTime + expectedTime - cfg.halfifi);

KbQueueStop(cfg.ix_responseDevice);	% Stop delivering events to the queue

disp(['Time elapsed was ',num2str(endTime - startTime),' seconds']);
disp(['(Should be ',num2str(expectedTime),' seconds)']);

% -----------------------------------------------------------------
% call function to save results, close window and clean up
% First dump everything to workspace just in case something goes wrong
assignin('base', 'responses', responses);
% Save results
save_and_quit(outFile,responses,randomization_block,cfg,stimtimings,expectedtimings);

%stimDur:
%save_and_quit(outFile,responses, randomization_block,cfg,stimtimings,expectedtimings,trialDistractor_stimulus,trialDistractor_dot);


end
