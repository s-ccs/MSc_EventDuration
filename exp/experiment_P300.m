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
fprintf(fLog,'%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n','onset','onsetTR','message','subject','trial','block','condition','phase','stimulus');
%fprintf(fLog,'%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n','condition','stimulus','ITI','trial','block','subject','task','stimonset_exp','stimoffset_exp','stimonset_real','stimoffset_real','response');

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
% Start with fixation cross
draw_fixationdot(cfg,params.dotSize)
startTime = Screen('Flip',cfg.win); % Store time at which experiment started
expectedTime = 0; % This will record what the expected event duration should be

% XXX KBqueue!    
KbQueueStart(14); % start trial press queue

tic
for trialNum = 1:ntrials
    % current stimulus to be displayed
    currStim = cfg.P300.symbols(randomization_block.stimulus(trialNum));
  %%
%     expectedTime=0
    expectedTime_start = expectedTime;
    expectedtimings(trialNum,1) = expectedTime;
    drawingtime = 2*cfg.halfifi;

    
    % Show the stimulus
    % XXX Change size, center x/y (CenterRect is your friend)
    % XXX Is this the right function to draw single characters?
    % Screen('DrawText',cfg.win,currStim,[],[]);
    [x,y] = RectCenter(cfg.rect);
    Screen('FillRect',cfg.win,cfg.background);
    Screen('TextSize',cfg.win,cfg.P300.stimSize);
    Screen('DrawText',cfg.win,currStim,x,y);

    stimOnset = Screen('Flip', cfg.win, startTime + expectedTime - cfg.halfifi,1) - startTime;
    add_log_entry('stimOnset',stimOnset) % also sends trigger
    
    % how long should the stimulus be on?
    expectedTime = expectedTime + cfg.P300.stimulusDuration;

    % draw a gray background on top of the stimulus
    Screen('FillRect',cfg.win,cfg.background);
    % return to fixation after stimulus presentation time
    draw_fixationdot(cfg,params.dotSize)
    stimOffset = Screen('Flip', cfg.win, startTime + expectedTime - cfg.halfifi,1)- startTime;
    add_log_entry('stimOffset',stimOffset)

    % save for some kind of stimulus timing check
    stimtimings(trialNum,1) = stimOnset;
    stimtimings(trialNum,2) = stimOffset;
    expectedtimings(trialNum,2) = expectedTime;

    % Inter Trial Interval
    cfg.P300.ITI = randomization_block.ITI(trialNum);
    expectedTime = expectedTime + cfg.P300.ITI;

    % Exit if time is over
    
    
    % at end of trial Read out all the button presses
    while true
        
        % only if we don't have a keyboard
    
        if ~KbEventAvail(14)
            break
        end
        evt = KbEventGet(14);
        
    if evt.Pressed==1 % don't record key releases
        add_log_entry('buttonpress',evt.Time-startTime);

        evt.blockNumber = trialNum;
        evt.TimeMinusStart = evt.Time - startTime;
%       evt.trialDistractor_stimulus = trialDistractor_stimulus{blockNum};
%       evt.trialDistractor_dot = trialDistractor_dot{blockNum};
        evt.subject = randomization_block.subject(1);
        evt.block = randomization_block.block(1);
        responses = [responses evt];
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

endTime = Screen('Flip', cfg.win, startTime + expectedTime - cfg.halfifi);

KbQueueStop(14);	% Stop delivering events to the queue

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

    
%% XXX Move these functions to functions/save_and_quit.m , functions/add_log_entry.m etc.
    
    function add_log_entry(varargin)
        
        %% XXX Add the trigger function in here
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


%         fprintf(fLog,'%s\t%i\t%.3f\t%i\t%i\t%03i\t%s\t%.3f\t%.3f\t%.3f\t%.3f\n',...
%             randomization_block.condition{trialNum},...
%             randomization_block.stimulus(trialNum),...
%             randomization_block.ITI(trialNum),...     
%             randomization_block.trial(trialNum),...
%             randomization_block.block(trialNum),...
%             randomization_block.subject(trialNum),...
%             randomization_block.task(trialNum),...
%             expectedtimings(trialNum,1),...
%             expectedtimings(trialNum,2),...
%             stimtimings(trialNum,1),...
%             stimtimings(trialNum,2));
        
%         fprintf(fLog,'%.3f\t%.3f\t%s\t%03i\t%i\t%i\t%s\t%.3f\t%s\n',time,time_tr,message,...
%             randomization_block.subject(trialNum),...
%             randomization_block.trial(trialNum),...
%             randomization_block.block(trialNum),...
%             randomization_block.condition{trialNum},...
%             params.phases(randomization_block.phase(trialNum)),...
%             randomization_block.stimulus{trialNum});
    end

    function draw_fixationdot_task(cfg,dotSize,targetsColor,distractorTiming_dot,startTime,expectedTime,drawingtime,noflip)
        if nargin == 7
            % in case we are shortly before the stimulus wait, we do not want to
            % flip, that would flip the stimulus as well.
            noflip = 0;
        end
        
        dotDuration= cfg.sustained.targetsDuration;
        
        distractorTiming_dot(distractorTiming_dot<(GetSecs-startTime-dotDuration-0.5*drawingtime)) = [];
        expectedTime = (expectedTime);
        currTime = GetSecs - startTime;
        % 4 cases
        draw_fixationdot(cfg,dotSize,0,0)
        
        if isempty(distractorTiming_dot)
            draw_fixationdot(cfg,dotSize,0,0)
            return
        end
        
        % %fprintf('----------\n')
        k = 1;
        %fprintf('currTime %.3f < distractorTime %.3f & dist+%.2f < expected %.3f \n',currTime,distractorTiming_dot(k),dotDuration,expectedTime)
        % %fprintf('%f > %f & show: %f < %f \n',currTime,distractorTiming_dot(k)+dotDuration,distractorTiming_dot(k)+dotDuration,expectedTime)
        % currTime 43.663 < distractorTime 44.499 & dist+0.10 < expected 44.667
        % I StimOnFlip 44.496428
        % I StimOffFlip 44.596432
        % mask: 3	 44.666667/45.666667
        % ----------
        % currTime 44.597 < distractorTime 44.499 & dist+0.10 < expected 44.667
        % II StimOn
        % II StimOnFlip 44.629722
        % II StimOffFlip 44.672060
        
        % distractorTiming_dot(1) = 44.499
        % expectedTime = 44.667;
        % drawingtime = 0.016;
        % dotDuration = 0.1
        % % currTime = 44.597;
        % currTime = 27.2
        
        % Time for Stim On & Stim Off?
        if ~noflip && (currTime< (distractorTiming_dot(1))) && ((distractorTiming_dot(1)+dotDuration) < expectedTime-drawingtime)
            
            draw_fixationdot(cfg,dotSize,0,targetsColor)
            when = Screen('Flip', cfg.win, startTime+distractorTiming_dot(1) - cfg.halfifi,1);
            add_log_entry('fixCatch',when-startTime)

            %fprintf('I StimOnFlip %f\n',when-startTime)
            draw_fixationdot(cfg,dotSize,0,0)
            
            % only flip if enough time, else let the stimulus flip do the work
            if (distractorTiming_dot(1)+drawingtime+dotDuration)< expectedTime
                
                when = Screen('Flip', cfg.win, startTime+distractorTiming_dot(1)+dotDuration - cfg.halfifi,1);
                %fprintf('I StimOffFlip %f\n',when-startTime)
            end
            
            % Time for Stim On?
        elseif (currTime< (distractorTiming_dot(1)+dotDuration)-drawingtime) && ((distractorTiming_dot(1)) < expectedTime)
            %fprintf('II StimOn \n')
            draw_fixationdot(cfg,dotSize,0,targetsColor)
            
            % only flip if enough time, else let the stimulus flip do the work
            if ~noflip && (distractorTiming_dot(1)+drawingtime)< expectedTime
                
                when = Screen('Flip', cfg.win, startTime+distractorTiming_dot(1) - cfg.halfifi,1);
                add_log_entry('fixCatch',when-startTime)
                %fprintf('II StimOnFlip %f \n',when-startTime)
                
                %         draw_fixationdot(cfg,dotSize,0,0)
            else
                add_log_entry('fixCatchNextStimulus')
            end
            
            % only flip if enough time, else let the stimulus flip do the work
            if (distractorTiming_dot(1)+drawingtime+dotDuration)< expectedTime
                
                draw_fixationdot(cfg,dotSize,0,0)
                
                when = Screen('Flip', cfg.win, startTime+distractorTiming_dot(1)+dotDuration - cfg.halfifi,1);
                %fprintf('II StimOffFlip %f\n',when-startTime)
            end
            
            % Time for Stim Off
        elseif ~noflip && currTime > distractorTiming_dot(1) &&  (distractorTiming_dot(1)+dotDuration) < expectedTime
            %fprintf('III StimnOffFlip \n')
            draw_fixationdot(cfg,dotSize,0,0)
            Screen('Flip', cfg.win, startTime+distractorTiming_dot(1)+dotDuration - cfg.halfifi,1);
            
        else
            %fprintf('IV StimnOff \n')
            draw_fixationdot(cfg,dotSize,0,0)
        end
    end
end
