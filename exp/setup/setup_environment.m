function cfg = setup_environment(cfg)
assert(isfield(cfg,'computer_environment'))

% Colors
cfg.background = 128;                                                       % ?
cfg.Lmin_rgb = 0;
cfg.Lmax_rgb = 255;
% Colors in Matlab are generally 8 bit(2^8=256), so RGB colors are scaled
% to 0-255

% Monitor settings for each environment
switch cfg.computer_environment
    case 'stimPC'
        cfg.distFromScreen = 90; % cm                                       % YYY measure more accurately with test participant
        cfg.pixelsPerCm = 35;
    otherwise
        error('undefined environment')
end

end