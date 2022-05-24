% Get index of response box or other devices/keyboards:
% devices=PsychHID('Devices',4)

% Indices for lab input decives:
% 11: logitech keyboard (standard)
% 14: response box 'Teensyduino MilliKey'
% 21: logitech g213 keyboard

while (1)
    [keyIsDown, keyTime, keyCode] = KbCheck(11);
   if (keyIsDown), break, end
end
    disp(find(keyCode));
    
% keyCode's response box:
% top left button:     11
% top mid button:      37
% top right button:    12
% bottom left button:  13
% bottom right button: 14
