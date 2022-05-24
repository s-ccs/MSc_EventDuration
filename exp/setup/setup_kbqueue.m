function setup_kbqueue(cfg)
% Keys that we want to listen for, buttons come in as 1-4 (49-52 ascii)

ListenChar(0) % in case KbChar was used before, we deactivate it here

keyList = zeros(1,256);
keyList(cfg.keys) = 1;
KbQueueCreate(cfg.ix_responseDevice, keyList); % Create queue
%KbQueueCreate(11, keyList);                                                % ??? works as well for keyboard
%KbQueueCreate(14, keyList);                                                % ??? doesn't work for response box
%KbQueueCreate(21, keyList);                                                % ??? doesn't work for other keyboard
% If this fails, try KbQueueCreate(1,keyList)

end