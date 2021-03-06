function [nPixels, nPixelsUnrounded] = degrees2pixels(degrees, distFromScreen_inCm, pixels_perCm, screenNumber)
% Converts degrees to pixels, given distance from screen in centimeters
% and pixels per centimeter. Result is rounded by default. Use
% nPixelsUnrounded to get the unrounded result of the calculation.

% Default value for distance from screen is 60 cm.
% If not specified, pixels per cm is measured using Screen('Resolution', 
% screenNumber) and Screen('DisplaySize', screenNumber). Default for
% screenNumber is max(Screen('Screens')).
if ~exist('distFromScreen_inCm','var') || isempty(distFromScreen_inCm)
    distFromScreen_inCm = 60;
end

% Figure out pixels per cm if not specified
if ~exist('pixels_perCm','var') || isempty(pixels_perCm)

    if ~exist('screenNumber','var') || isempty(screenNumber)
        screenNumber = max(Screen('Screens'));
    end
    
    resolution = Screen('Resolution',screenNumber);
    widthOfScreen_inPixels = resolution.width;
    heightOfScreen_inPixels = resolution.height;
    
    [widthOfScreen_inMm, heightOfScreen_inMm] = Screen('DisplaySize',screenNumber);
    widthOfScreen_inCm = widthOfScreen_inMm / 10;
    
    % Note: pixels per cm can also be calculated using the height of screen
    % in pixels and cm, which may give a slightly different value
    pixels_perCm = widthOfScreen_inPixels / widthOfScreen_inCm;
end

% Convert degrees to centimeters
sizeOnScreen_inCm = 2 * distFromScreen_inCm * tan((degrees/2) * (pi/180));

% Convert centimeters to pixels
nPixelsUnrounded = sizeOnScreen_inCm * pixels_perCm;
nPixels = round(nPixelsUnrounded);