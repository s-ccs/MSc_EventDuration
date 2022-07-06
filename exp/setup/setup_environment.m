function cfg = setup_environment(cfg)
assert(isfield(cfg,'computer_environment'))

% Colors
if cfg.do_P300
    cfg.background = 128;
elseif cfg.do_stimDur 
    cfg.background = 255;
end
cfg.Lmin_rgb = 0;
cfg.Lmax_rgb = 255;
% Colors in Matlab are generally 8 bit(2^8=256), so RGB colors are scaled
% to 0-255

% Monitor settings
switch cfg.computer_environment
    case 'stimPC'
        cfg.distFromScreen = 88; % cm
        cfg.pixelsPerCm = 35;
    otherwise
        error('undefined environment')
end
end