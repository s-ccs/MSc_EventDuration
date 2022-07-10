function save_events(outFile,responses,randomization_block,cfg,stimtimings,expectedtimings,blockOnOff)

persistent safe

%% Save results

% P300
if cfg.do_P300
    % Save .mat file
    try
        save(outFile,'responses','randomization_block','cfg','stimtimings','expectedtimings');
    catch
        disp('Could not save outFile - may not exist');
    end

    % Set columns of events.tsv file
    if (randomization_block.block(1)==1)
        safe = struct('eventName',[],'time',[],'duration',[],'reactionTime',[],'condition',[],'stimulus',[],'response',[],'keycode',[],'targetResponse',[],'ITI',[],'trial',[],'block',[],'subject',[]);
    end

    % StimOnsets
    for trialNum=1:cfg.P300.numTrials
        eventName = {'stimOnset'};
        stimOnset = round(stimtimings(trialNum,1),4);
        % Calculate duration
        duration = round(stimtimings(trialNum,2)-stimtimings(trialNum,1),4);
        safe.eventName      = [safe.eventName      eventName];
        safe.time           = [safe.time           stimOnset];
        safe.duration       = [safe.duration       duration];
        safe.reactionTime   = [safe.reactionTime   NaN];
        safe.condition      = [safe.condition      {randomization_block.condition{trialNum}}]; %#ok<*CCAT1>
        safe.stimulus       = [safe.stimulus       {cfg.P300.symbols(randomization_block.stimulus(trialNum))}];
        safe.response       = [safe.response       {'NaN'}];
        safe.keycode        = [safe.keycode        NaN];
        safe.targetResponse = [safe.targetResponse randomization_block.targetResponse(trialNum)];
        safe.ITI            = [safe.ITI            NaN];
        safe.trial          = [safe.trial          stimtimings(trialNum,3)];
        safe.block          = [safe.block          stimtimings(trialNum,4)];
        safe.subject        = [safe.subject        randomization_block.subject(trialNum)];
    end

    % StimOffsets
    for trialNum=1:cfg.P300.numTrials
        eventName = {'stimOffset'};
        stimOffset = round(stimtimings(trialNum,2),4);
        % Calculate duration
        if trialNum==cfg.P300.numTrials
            duration = round(blockOnOff(1,2)-stimtimings(trialNum,2),4);
        else
            duration = round(stimtimings(trialNum+1,1)-stimtimings(trialNum,2),4);
        end
        safe.eventName      = [safe.eventName      eventName];
        safe.time           = [safe.time           stimOffset];
        safe.duration       = [safe.duration       duration];
        safe.reactionTime   = [safe.reactionTime   NaN];
        safe.condition      = [safe.condition      {randomization_block.condition{trialNum}}];
        safe.stimulus       = [safe.stimulus       {cfg.P300.symbols(randomization_block.stimulus(trialNum))}];
        safe.response       = [safe.response       {'NaN'}];
        safe.keycode        = [safe.keycode        NaN];
        safe.targetResponse = [safe.targetResponse randomization_block.targetResponse(trialNum)];
        safe.ITI            = [safe.ITI            randomization_block.ITI(trialNum)];
        safe.trial          = [safe.trial          stimtimings(trialNum,3)];
        safe.block          = [safe.block          stimtimings(trialNum,4)];
        safe.subject        = [safe.subject        randomization_block.subject(trialNum)];
    end

    % Responses
    for responseNum=1:length(responses)
        eventName = {'buttonpress'};
        timeResponse = round(getfield(responses,{responseNum},'TimeMinusStart'),4);
        % Calculate reaction time
        stimOnset = stimtimings(:,1);
        [~,ix_stimOnset] = max(stimOnset(stimOnset<timeResponse));
        reactionTime = round(timeResponse - stimtimings(ix_stimOnset,1),4);
        % Determine whether response was correct or false
        targetResponse = randomization_block.targetResponse(trialNum);
        if (targetResponse=="right" && getfield(responses,{responseNum},'Keycode')==12 && strcmp(getfield(responses,{responseNum},'condition'),'target'))...
                || (targetResponse=="right" && getfield(responses,{responseNum},'Keycode')==11 && strcmp(getfield(responses,{responseNum},'condition'),'distractor'))...
                || (targetResponse=="left" && getfield(responses,{responseNum},'Keycode')==11 && strcmp(getfield(responses,{responseNum},'condition'),'target'))...
                || (targetResponse=="left" && getfield(responses,{responseNum},'Keycode')==12 && strcmp(getfield(responses,{responseNum},'condition'),'distractor'))
            response = {'correct'};
        else
            response = {'false'};
        end
        safe.eventName      = [safe.eventName      eventName];
        safe.time           = [safe.time           timeResponse];
        safe.duration       = [safe.duration       NaN];
        safe.reactionTime   = [safe.reactionTime   reactionTime];
        safe.condition      = [safe.condition      getfield(responses,{responseNum},'condition')];
        safe.stimulus       = [safe.stimulus       {getfield(responses,{responseNum},'stimulus')}];
        safe.response       = [safe.response       response];
        safe.keycode        = [safe.keycode        getfield(responses,{responseNum},'Keycode')];
        safe.targetResponse = [safe.targetResponse targetResponse];
        safe.ITI            = [safe.ITI            NaN];
        safe.trial          = [safe.trial          getfield(responses,{responseNum},'trialNumber')];
        safe.block          = [safe.block          getfield(responses,{responseNum},'block')];
        safe.subject        = [safe.subject        randomization_block.subject(trialNum)];
    end

    % StimDur
elseif cfg.do_stimDur
    % Save .mat file
    try
        save(outFile,'responses','randomization_block','cfg','stimtimings','expectedtimings');
    catch
        disp('Could not save outFile - may not exist');
    end

    if (randomization_block.block(1)==1)
        safe = struct('eventName',[],'time',[],'duration',[],'reactionTime',[],'stimulus',[],'keycode',[],'stimDur',[],'flickerDot',[],'ITI',[],'trial',[],'block',[],'subject',[]);
    end

    % StimOnsets
    for trialNum=1:cfg.stimDur.numTrials
        eventName = {'stimOnset'};
        stimOnset = round(stimtimings(trialNum,1),4);
        % Calculate duration
        if mod(randomization_block.block(1),2)==0
            duration = round(stimtimings(trialNum,2)-stimtimings(trialNum,1),4);
            safe.ITI        = [safe.ITI            {'NaN'}];
        elseif mod(randomization_block.block(1),2)~=0
            % Odd-numbered blocks don't contain blanks
            safe.ITI        = [safe.ITI            {'no blanks'}];
            % Duration is stimOnset to stimOnset of next stimulus if no blanks are between trials
            if trialNum < cfg.stimDur.numTrials
                duration = round(stimtimings(trialNum+1,1)-stimtimings(trialNum,1),4);
            else
                duration = round(stimtimings(trialNum,2)-stimtimings(trialNum,1),4);
            end
        end
        safe.eventName      = [safe.eventName      eventName];
        safe.time           = [safe.time           stimOnset];
        safe.duration       = [safe.duration       duration];
        safe.reactionTime   = [safe.reactionTime   NaN];
        safe.stimulus       = [safe.stimulus       randomization_block.stimulus(trialNum)];
        safe.keycode        = [safe.keycode        NaN];
        safe.stimDur        = [safe.stimDur        randomization_block.stimDur(trialNum)];
        safe.flickerDot     = [safe.flickerDot     NaN];
        safe.trial          = [safe.trial          stimtimings(trialNum,5)];
        safe.block          = [safe.block          stimtimings(trialNum,6)];
        safe.subject        = [safe.subject        randomization_block.subject(trialNum)];
    end

    % StimOffsets
    for trialNum=1:cfg.stimDur.numTrials
        % No stimOffsets for blocks without blanks except for last stimulus, since
        % next stimOnset is automatically also stimOffset of previous stimulus
        if ~stimtimings(trialNum,2)
            continue
        elseif trialNum < cfg.stimDur.numTrials
            duration  = round(stimtimings(trialNum+1,1)-stimtimings(trialNum,2),4);
        else
            duration  = NaN;
        end
        eventName  = {'stimOffset'};
        stimOffset = round(stimtimings(trialNum,2),4);
        if mod(randomization_block.block(1),2)==0
            safe.ITI        = [safe.ITI            randomization_block.ITI(trialNum)];
            safe.duration   = [safe.duration       duration];
        elseif mod(randomization_block.block(1),2)~=0
            safe.ITI        = [safe.ITI            {'no blanks'}];
            safe.duration   = [safe.duration       NaN];
        end
        safe.eventName      = [safe.eventName      eventName];
        safe.time           = [safe.time           stimOffset];
        safe.reactionTime   = [safe.reactionTime   NaN];
        safe.stimulus       = [safe.stimulus       randomization_block.stimulus(trialNum)];
        safe.keycode        = [safe.keycode        NaN];
        safe.stimDur        = [safe.stimDur        NaN];
        safe.flickerDot     = [safe.flickerDot     NaN];
        safe.trial          = [safe.trial          stimtimings(trialNum,5)];
        safe.block          = [safe.block          stimtimings(trialNum,6)];
        safe.subject        = [safe.subject        randomization_block.subject(trialNum)];
    end

    % TargetOnsets
    for trialNum=1:cfg.stimDur.numTrials
        if ~stimtimings(trialNum,3)
            continue
        end
        eventName = {'targetOnset'};
        targetOnset = round(stimtimings(trialNum,3),4);
        duration  = round(stimtimings(trialNum,4)-stimtimings(trialNum,3),4);
        if mod(randomization_block.block(1),2)==0
            safe.ITI        = [safe.ITI            {'NaN'}];
        elseif mod(randomization_block.block(1),2)~=0
            safe.ITI        = [safe.ITI            {'no blanks'}];
        end
        if randomization_block.flickerDot(trialNum)~=0
            safe.flickerDot = [safe.flickerDot     randomization_block.flickerDot(trialNum)];
        else
            safe.flickerDot = [safe.flickerDot     NaN];
        end
        safe.eventName      = [safe.eventName      eventName];
        safe.time           = [safe.time           targetOnset];
        safe.duration       = [safe.duration       duration];
        safe.reactionTime   = [safe.reactionTime   NaN];
        safe.stimulus       = [safe.stimulus       randomization_block.stimulus(trialNum)];
        safe.keycode        = [safe.keycode        NaN];
        safe.stimDur        = [safe.stimDur        NaN];
        safe.trial          = [safe.trial          stimtimings(trialNum,5)];
        safe.block          = [safe.block          stimtimings(trialNum,6)];
        safe.subject        = [safe.subject        randomization_block.subject(trialNum)];
    end

    % TargetOffsets
    for trialNum=1:cfg.stimDur.numTrials
        if ~stimtimings(trialNum,4)
            continue
        end
        eventName = {'targetOffset'};
        targetOffset = round(stimtimings(trialNum,4),4);
        if mod(randomization_block.block(1),2)==0
            safe.ITI        = [safe.ITI            {'NaN'}];
        elseif mod(randomization_block.block(1),2)~=0
            safe.ITI        = [safe.ITI            {'no blanks'}];
        end
        safe.eventName      = [safe.eventName      eventName];
        safe.time           = [safe.time           targetOffset];
        safe.duration       = [safe.duration       NaN];
        safe.reactionTime   = [safe.reactionTime   NaN];
        safe.stimulus       = [safe.stimulus       randomization_block.stimulus(trialNum)];
        safe.keycode        = [safe.keycode        NaN];
        safe.stimDur        = [safe.stimDur        NaN];
        safe.flickerDot     = [safe.flickerDot     NaN];
        safe.trial          = [safe.trial          stimtimings(trialNum,5)];
        safe.block          = [safe.block          stimtimings(trialNum,6)];
        safe.subject        = [safe.subject        randomization_block.subject(trialNum)];
    end

    % Responses
    for responseNum=1:length(responses)
        eventName = {'buttonpress'};
        timeResponse = round(getfield(responses,{responseNum},'TimeMinusStart'),4);
        % Calculate reaction time
        targetOnset = stimtimings(:,3);
        [~,ix_targetOnset] = max(targetOnset(targetOnset<timeResponse));
        reactionTime = round(timeResponse - stimtimings(ix_targetOnset,3),4);
        % Remove RT for responses before first targetOnset
        if reactionTime == timeResponse
            reactionTime = NaN;
        end
        % Only even numbered blocks have ITIs
        if mod(randomization_block.block(1),2)==0
            safe.ITI        = [safe.ITI            {'NaN'}];
        elseif mod(randomization_block.block(1),2)~=0
            safe.ITI        = [safe.ITI            {'no blanks'}];
        end
        safe.eventName      = [safe.eventName      eventName];
        safe.time           = [safe.time           timeResponse];
        safe.duration       = [safe.duration       NaN];
        safe.reactionTime   = [safe.reactionTime   reactionTime];
        safe.stimulus       = [safe.stimulus       getfield(responses,{responseNum},'stimulus')];
        safe.keycode        = [safe.keycode        getfield(responses,{responseNum},'Keycode')];
        safe.stimDur        = [safe.stimDur        NaN];
        safe.flickerDot     = [safe.flickerDot     NaN];
        safe.trial          = [safe.trial          getfield(responses,{responseNum},'trialNumber')];
        safe.block          = [safe.block          getfield(responses,{responseNum},'block')];
        safe.subject        = [safe.subject        randomization_block.subject(trialNum)];
    end
end

% Add entries for block start and end
if true
    % Block start
    eventName = {'blockStart'};
    blockStart = round(blockOnOff(1),4);
    if cfg.do_P300
        safe.condition  = [safe.condition      {'NaN'}];
        safe.response   = [safe.response       {'NaN'}];
        safe.targetResponse = [safe.targetResponse {'NaN'}];
        safe.ITI        = [safe.ITI            NaN];
        safe.stimulus       = [safe.stimulus       {'NaN'}];
    elseif cfg.do_stimDur
        safe.stimDur    = [safe.stimDur        NaN];
        safe.flickerDot = [safe.flickerDot     NaN];
        safe.ITI        = [safe.ITI            {'NaN'}];
        safe.stimulus   = [safe.stimulus       NaN];
    end
    safe.eventName      = [safe.eventName      eventName];
    safe.time           = [safe.time           blockStart];
    safe.duration       = [safe.duration       NaN];
    safe.reactionTime   = [safe.reactionTime   NaN];
    safe.keycode        = [safe.keycode        NaN];
    safe.trial          = [safe.trial          NaN];
    safe.block          = [safe.block          randomization_block.block(end)];
    safe.subject        = [safe.subject        randomization_block.subject(1)];

    % Block end
    eventName = {'blockEnd'};
    blockEnd = round(blockOnOff(2),4);
    if cfg.do_P300
        safe.condition  = [safe.condition      {'NaN'}];
        safe.response   = [safe.response       {'NaN'}];
        safe.targetResponse = [safe.targetResponse {'NaN'}];
        safe.ITI        = [safe.ITI            NaN];
        safe.stimulus       = [safe.stimulus       {'NaN'}];
    elseif cfg.do_stimDur
        safe.stimDur    = [safe.stimDur        NaN];
        safe.flickerDot = [safe.flickerDot     NaN];
        safe.ITI        = [safe.ITI            {'NaN'}];
        safe.stimulus   = [safe.stimulus       NaN];
    end
    safe.eventName      = [safe.eventName      eventName];
    safe.time           = [safe.time           blockEnd];
    safe.duration       = [safe.duration       NaN];
    safe.reactionTime   = [safe.reactionTime   NaN];
    safe.keycode        = [safe.keycode        NaN];
    safe.trial          = [safe.trial          NaN];
    safe.block          = [safe.block          randomization_block.block(end)];
    safe.subject        = [safe.subject        randomization_block.subject(1)];
end

%% Export events file
% P300
if cfg.do_P300 && (randomization_block.block(1)==cfg.P300.numBlocks)
    % Transpose all fields
    for fn = fieldnames(safe)'
        safe.(fn{1})  = safe.(fn{1})';
    end

    % Convert to table
    safe = struct2table(safe);

    % Sort events table for time then blocks
    safe = sortrows(sortrows(safe,2),12);
    % Correct condition, stimulus, and trial for buttonpresses
    for i = 1:size(safe)
        if strcmp(safe.eventName(i),'buttonpress')
            a = find(strcmp(safe.eventName(1:i),'stimOnset'),1,"last");
            b = find(strcmp(safe.eventName(1:i),'stimOffset'),1,"last");
            if b > a
                safe.condition(i) = safe.condition(b);
                safe.stimulus(i) = safe.stimulus(b);
                safe.trial(i) = safe.trial(b);
            end
        end
    end
    % Display results
    disp(safe);

    % Write events.tsv file
    writetable(safe,cfg.P300.behavioral_filepath_tsv,'FileType','text','Delimiter','\t');
end

% stimDur
if cfg.do_stimDur && (randomization_block.block(1)==cfg.stimDur.numBlocks)
    % Transpose all fields
    for fn = fieldnames(safe)'
        safe.(fn{1})  = safe.(fn{1})';
    end
    % Convert to table
    safe = struct2table(safe);

    % Sort events table for time then blocks, and write events file
    safe = sortrows(sortrows(safe,2),11);
    % Correct stimulus and trial for buttonpresses
    for i = 1:size(safe)
        if strcmp(safe.eventName(i),'buttonpress')
            a = find(strcmp(safe.eventName(1:i),'stimOnset'),1,"last");
            safe.stimulus(i) = safe.stimulus(a);
            safe.trial(i) = safe.trial(a);
        end
    end
    % Display results
    disp(safe);

    % Write events.tsv file
    writetable(safe,cfg.stimDur.behavioral_filepath_tsv,'FileType','text','Delimiter','\t');
end
