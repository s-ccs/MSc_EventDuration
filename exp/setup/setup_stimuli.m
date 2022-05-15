function cfg = setup_stimuli(cfg,params)
assert(isfield(cfg,'win'))

assert(isstruct(params))

for i = 1:length(params.)
    
    
    
end
cfg.stimTexMask = Screen('MakeTexture', cfg.win, stimMask);

% Preload textures into video memory
Screen('PreloadTextures',cfg.win,cfg.stimTex);
fprintf('Textures Preloaded \n')
end