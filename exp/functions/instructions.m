function instructions(cfg,randomization_block)
Screen('TextSize',cfg.win,30); % Set text size for instructions
RestrictKeysForKbCheck([37]); % Restrict responses to top mid button on button box 
KbQueueStart(cfg.ix_responseDevice);

%% P300
% Experiment Instructions
Screen('TextFont',cfg.win,char('Roboto Mono')); % Set text font

if cfg.do_P300
    if randomization_block.block(1)==1
        fprintf('Experiment instructions\n');
        letters = 'A':'E';
        while ~any(KbEventAvail(cfg.ix_responseDevice),[37])
            for i=1:2
                if i==1
                    % Present "animation" of experiment in top right corner of screen during instructions
                    exampleLetter = [letters(randi(numel(letters)))];
                    Screen('TextSize',cfg.win,120); % Make letters A-E bigger
                    DrawFormattedText2(exampleLetter,'win',cfg.win,'sx',cfg.width*0.9,'sy',cfg.height*0.1,'xalign','center','yalign','center','xlayout','center');
                    Screen('TextSize',cfg.win,30); % Reset text size for instructions
                    draw_fixationdot(cfg,cfg.P300.dotSize,0,0,cfg.width*0.897,cfg.height*0.1) % Fixation cross
                    % Instructions for experiment
                    if cfg.engInst
                        DrawFormattedText2(['<u>P300 experiment<u>\n(10 blocks with 120 trials each)\n\n\nDescription:\n\nThroughout this experiment you will see a stream of letters (ABCDE).\n\nYour task is to respond to the letter that was displayed by pressing either the <color=0072BD>blue<color=0> or <color=EDB120>yellow<color=0> button,\ndepending on the assignment given at the beginning of each block.\n\n\nInstructions:\n\nYou can take pauses between blocks if required.\n\nPress the <color=0072BD>blue<color=0> button with your left index finger and the <color=EDB120>yellow<color=0> button with your right index finger.\n\nMaintain fixation on the cross in the screen center.\n\nRespond as quickly and accurately as possible.\n\n\n\n...\n> Press any button to start the experiment.'],'win',cfg.win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
                    elseif cfg.gerInst
                        DrawFormattedText2(['<u>P300 Experiment<u>\n(10 Bl??cke mit je 120 Versuchen)\n\n\nBeschreibung:\n\nW??hrend des Experiments ist eine Abfolge von Buchstaben (ABCDE) zu sehen.\n\nDie Aufgabe ist, auf den dargestellten Buchstaben durch Dr??cken des <color=0072BD>blauen<color=0> oder <color=EDB120>gelben<color=0> Knopfes\nzu reagieren, abh??ngig von der Zuordnung die am Anfang des Blocks gegeben wird.\n\n\nInstruktionen:\n\nZwischen Bl??cken kannst du Pausen machen, wenn ben??tigt.\n\nDr??cke den <color=0072BD>blauen<color=0> Knopf mit dem linken Zeigefinger und den <color=EDB120>gelben<color=0> Knopf mit dem rechten Zeigefinger.\n\nFixiere w??hrend des Experiments das Kreuz in der Mitte des Bildschirms.\n\nAntworte so genau und so schnell wie m??glich.\n\n\n\n...\n> Dr??cke einen Knopf um das Experiment zu starten.'],'win',cfg.win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
                    end
                    WaitSecs(0.2);
                elseif i==2
                    % "Animation"
                    Screen('FillRect', cfg.win, cfg.background);
                    draw_fixationdot(cfg,cfg.P300.dotSize,0,0,cfg.width*0.897,cfg.height*0.1) % Fixation cross
                    % Instructions
                    if cfg.engInst
                        DrawFormattedText2(['<u>P300 experiment<u>\n(10 blocks with 120 trials each)\n\n\nDescription:\n\nThroughout this experiment you will see a stream of letters (ABCDE).\n\nYour task is to respond to the letter that was displayed by pressing either the <color=0072BD>blue<color=0> or <color=EDB120>yellow<color=0> button,\ndepending on the assignment given at the beginning of each block.\n\n\nInstructions:\n\nYou can take pauses between blocks if required.\n\nPress the <color=0072BD>blue<color=0> button with your left index finger and the <color=EDB120>yellow<color=0> button with your right index finger.\n\nMaintain fixation on the cross in the screen center.\n\nRespond as quickly and accurately as possible.\n\n\n\n...\n> Press any button to start the experiment.'],'win',cfg.win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
                    elseif cfg.gerInst
                        DrawFormattedText2(['<u>P300 Experiment<u>\n(10 Bl??cke mit je 120 Versuchen)\n\n\nBeschreibung:\n\nW??hrend des Experiments ist eine Abfolge von Buchstaben (ABCDE) zu sehen.\n\nDie Aufgabe ist, auf den dargestellten Buchstaben durch Dr??cken des <color=0072BD>blauen<color=0> oder <color=EDB120>gelben<color=0> Knopfes\nzu reagieren, abh??ngig von der Zuordnung die am Anfang des Blocks gegeben wird.\n\n\nInstruktionen:\n\nZwischen Bl??cken kannst du Pausen machen, wenn ben??tigt.\n\nDr??cke den <color=0072BD>blauen<color=0> Knopf mit dem linken Zeigefinger und den <color=EDB120>gelben<color=0> Knopf mit dem rechten Zeigefinger.\n\nFixiere w??hrend des Experiments das Kreuz in der Mitte des Bildschirms.\n\nAntworte so genau und so schnell wie m??glich.\n\n\n\n...\n> Dr??cke einen Knopf um das Experiment zu starten.'],'win',cfg.win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
                    end
                    WaitSecs(0.5);
                end
                Screen('Flip',cfg.win);
            end
        end
    end
    KbQueueFlush(cfg.ix_responseDevice,3); % Don't record buttonpresses during instructions
    KbQueueStop(cfg.ix_responseDevice);
    WaitSecs(.75); % Would otherwise jump next KbWait occasionally
    
    % Block instructions
    % Determine target and corresponding response (left vs. right) for block
    currTarget = cfg.P300.symbols(randomization_block.stimulus(find(contains(randomization_block.condition,'target'),1)));
    targetResponse = randomization_block.targetResponse(1);
    Screen('TextSize',cfg.win,80);
    % Draw letters on left/right side with corresponding color on button box
    if strcmp(targetResponse,'right')
        DrawFormattedText2(['<color=0072BD>',setdiff(cfg.P300.symbols,currTarget)],'win',cfg.win,'sx',1/3*cfg.rect(3),'sy','center','xalign','center','yalign','center','xlayout','center');
        DrawFormattedText2(['<color=EDB120>',currTarget],'win',cfg.win,'sx',2/3*cfg.rect(3),'sy','center','xalign','center','yalign','center','xlayout','center');
    elseif strcmp(targetResponse,'left')
        DrawFormattedText2(['<color=0072BD>',currTarget],'win',cfg.win,'sx',1/3*cfg.rect(3),'sy','center','xalign','center','yalign','center','xlayout','center');
        DrawFormattedText2(['<color=EDB120>',setdiff(cfg.P300.symbols,currTarget)],'win',cfg.win,'sx',2/3*cfg.rect(3),'sy','center','xalign','center','yalign','center','xlayout','center');
    end
    % Instructions for block
    Screen('TextSize',cfg.win,40);
    if cfg.engInst
        DrawFormattedText2(['Press the <color=0072BD>blue<color=0> or <color=EDB120>yellow<color=0> button\n for these letters:'],'win',cfg.win,'sx','center','sy',1/5*cfg.rect(4),'xalign','center','yalign','center','xlayout','center');
        DrawFormattedText2(['> Press <color=77AC30>green<color=0> to start block ',num2str(randomization_block.block(1)),' of ',num2str(cfg.P300.numBlocks),'.'],'win',cfg.win,'sx','center','sy',4/5*cfg.rect(4),'xalign','center','yalign','center','xlayout','center');
    elseif cfg.gerInst
        DrawFormattedText2(['Dr??cke den <color=0072BD>blauen<color=0> oder <color=EDB120>gelben<color=0> Knopf\nf??r diese Buchstaben:'],'win',cfg.win,'sx','center','sy',1/5*cfg.rect(4),'xalign','center','yalign','center','xlayout','center');
        DrawFormattedText2(['> Dr??cke den <color=77AC30>gr??nen<color=0> Knopf um Block ',num2str(randomization_block.block(1)),' von ',num2str(cfg.P300.numBlocks),' zu starten.'],'win',cfg.win,'sx','center','sy',4/5*cfg.rect(4),'xalign','center','yalign','center','xlayout','center');
    end
    draw_fixationdot(cfg,cfg.P300.dotSize) % Fixation cross
    Screen('Flip',cfg.win);
    fprintf('Block instructions\n');
end

%% StimDur
% Experiment Instructions
Screen('TextSize',cfg.win,30);
if cfg.do_stimDur
    if randomization_block.block(1)==1
        fprintf('Experiment instructions\n');
        while ~KbEventAvail(cfg.ix_responseDevice)
            % Flicker dot in "animation" every 1 s
            flicker = mod(GetSecs,1)<cfg.stimDur.targetsDuration;
            if flicker
                colorInside = cfg.stimDur.targetColor*cfg.Lmax_rgb;
            else
                colorInside = 0;
            end
            % Instructions for experiment
            if cfg.engInst
                DrawFormattedText2(['<u>Stimulus duration experiment<u>\n(6 blocks with 120 trials)\n\nDescription:\n\nDuring this experiment faces will be presented, either\nwithout or with small breaks in between.\n\nYour task is to fixate the cross in the screen center and press the <color=EDB120>yellow<color=0> button, as soon\nas you see a red dot flickering in the center of the cross.\n\n\nInstructions:\n\nYou can take pauses between blocks if required.\n\nPress the <color=EDB120>yellow<color=0> button with your right index finger.\n\nMaintain fixation on the cross in the screen center.\n\nRespond as quickly as possible.\n\n\n...\n> Press any button to start the experiment.'],'win',cfg.win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
            elseif cfg.gerInst
                DrawFormattedText2(['<u>Stimulus-Dauer Experiment<u>\n(6 Bl??cke mit je 120 Versuchen)\n\nBeschreibung:\n\nW??hrend des Experiments ist eine Abfolge von Gesichtern zu sehen, entweder ohne oder mit kurzen Pausen.\n\nDie Aufgabe ist, durchgehend das Kreuz in der Bildschirmmitte zu fixieren und\nden <color=EDB120>gelben<color=0> Knopf zu dr??cken, wenn in der Mitte des Kreuzes ein\nroter Punkt flickert.\n\n\nInstruktionen:\n\nDu kannst zwischen Bl??cken Pausen machen, wenn ben??tigt.\n\nDr??cke den <color=EDB120>gelben<color=0> Knopf mit dem rechten Zeigefinger.\n\nFixiere w??hrend des gesamten Experiments das Kreuz in der Mitte des Bildschirms.\n\nReagiere so schnell wie m??glich.\n\n\n\n...\n> Dr??cke einen Knopf um das Experiment zu starten.'],'win',cfg.win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
            end
            % Present "animation" of experiment during instructions
            Screen('DrawTexture',cfg.win,cfg.stimDur.stimTex(3),[],OffsetRect(CenterRect([0 0 384 270],cfg.rect),cfg.width*0.4,cfg.height*0.04));
            draw_fixationdot(cfg,cfg.stimDur.dotSize,0,colorInside,cfg.width*0.9,cfg.height*0.55)
            Screen('Flip',cfg.win);
        end
    end
    KbQueueFlush(cfg.ix_responseDevice,3) % Don't record buttonpresses during instructions
    KbQueueStop(cfg.ix_responseDevice);
    WaitSecs(.75); % Would otherwise jump next KbWait occasionally
    
    % Block instructions
    Screen('TextSize',cfg.win,40);
    if cfg.engInst
        DrawFormattedText2(['Press the <color=EDB120>yellow<color=0> button as soon as you see the red dot flicker.'],'win',cfg.win,'sx','center','sy',2/5*cfg.rect(4),'xalign','center','yalign','center','xlayout','center');
        DrawFormattedText2(['> Press <color=77AC30> green <color=0> to start block ',num2str(randomization_block.block(1)),' of ',num2str(cfg.stimDur.numBlocks),' .'],'win',cfg.win,'sx','center','sy',4/5*cfg.rect(4),'xalign','center','yalign','center','xlayout','center');
    elseif cfg.gerInst
                DrawFormattedText2(['Dr??cke den <color=EDB120>gelben<color=0> Knopf, sobald der rote Punkt flickert.'],'win',cfg.win,'sx','center','sy',2/5*cfg.rect(4),'xalign','center','yalign','center','xlayout','center');
        DrawFormattedText2(['> Dr??cke den <color=77AC30>gr??nen<color=0> Knopf um Block ',num2str(randomization_block.block(1)),' von ',num2str(cfg.stimDur.numBlocks),' zu starten.'],'win',cfg.win,'sx','center','sy',4/5*cfg.rect(4),'xalign','center','yalign','center','xlayout','center');
    end
    draw_fixationdot(cfg,cfg.stimDur.dotSize) % Fixation cross
    Screen('Flip',cfg.win);
    fprintf('Block instructions\n');
end
%#ok<*NBRAK2>