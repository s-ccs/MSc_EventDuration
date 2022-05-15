function save_and_quit(outFile,responses,randomization_block,cfg,stimtimings,expectedtimings,trialDistractor_stimulus,trialDistractor_dot)
% Save results

if cfg.do_P300
    try
        save(outFile,'responses','randomization_block','cfg','stimtimings','expectedtimings');
    catch
        disp('Could not save outFile - may not exist');
    end
    
elseif cfg.do_stimDur
    try
        save(outFile,'responses','randomization_block','cfg','stimtimings','expectedtimings','trialDistractor_stimulus','trialDistractor_dot');
    catch
        disp('Could not save outFile - may not exist');
    end
end

end
