function safeQuit(cfg)

% Close window
Screen('Close');
Screen('Closeall');
clear Screen; % disable PsychDebugWindowConfiguration (alternative: close all)

% Close lsl stream
if cfg.use_lsl
    cfg.outlet.delete();
end

disp('Quit safely');
end