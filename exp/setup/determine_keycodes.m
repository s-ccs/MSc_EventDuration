% Get index of button box or other devices/keyboards:
devices = PsychHID('Devices',4);

% Button box = 'Teensyduino MilliKey'
% keyCode's :
% top left button:     11
% top mid button:      37
% top right button:    12
% bottom left button:  13
% bottom right button: 14

while (1)
    [keyIsDown, keyTime, keyCode] = KbCheck(11);
    if (keyIsDown), break, end
end

disp(find(keyCode));