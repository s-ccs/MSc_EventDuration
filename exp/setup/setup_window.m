function cfg = setup_window(cfg,whichScreen)
% Open window and set font

if cfg.debug
        [cfg.win, cfg.rect] = Screen('OpenWindow',whichScreen,[],[1550 430 2550 1430]);
else
        [cfg.win, cfg.rect] = Screen('OpenWindow',whichScreen);
end

cfg.width = cfg.rect(3);
cfg.height = cfg.rect(4);

if ~cfg.debug
    Priority(1); % Set priority
    fprintf('Set Priority to 1\n')
    HideCursor(cfg.win);
end

KbName('UnifyKeyNames')

Screen('DrawText',cfg.win,'Estimating monitor flip interval...', 100, 100);
Screen('DrawText',cfg.win,'(This may take up to 20s)', 100, 120);
Screen('Flip',cfg.win);
ifi = Screen('GetFlipInterval', cfg.win, 100, 0.00005, 20); % inter flip (~frame) interval = 1/monitor refresh rate 
cfg.halfifi = ifi/2;


