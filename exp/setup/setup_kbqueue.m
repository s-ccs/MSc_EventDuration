function setup_kbqueue(cfg)

ListenChar(0) % In case KbChar was used before, we deactivate it here

keyList = zeros(1,256);
keyList(cfg.keys) = 1;
KbQueueCreate(cfg.ix_responseDevice, keyList); % Create queue

end