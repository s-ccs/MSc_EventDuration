function outFile = setup_outFile(cfg)

% P300
if cfg.do_P300
    outFile = cfg.P300.behavioral_filepath_mat;
    if ~exist(fileparts(outFile),'dir')
        mkdir(fileparts(outFile))
    end
    
% stimDur
elseif cfg.do_stimDur
    outFile = cfg.stimDur.behavioral_filepath_mat;
    if ~exist(fileparts(outFile),'dir')
        mkdir(fileparts(outFile))
    end
end