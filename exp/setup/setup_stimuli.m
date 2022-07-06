function cfg = setup_stimuli(cfg)

assert(isfield(cfg,'win'))
addpath('../lib');

%% Subset CFD to images of neutral faces with uniform white background
% Only needs to be done once...afterwards faces are loaded from the here 
% created subset in the next section.

% % Load images
% addpath('/home/stimulus/projects/2022-MScGeiger/facePictures/CFD Version 3.0/Images/CFD');
% % Get a list of all .jpg files with neutral faces (marked by 'N') in all subfolders
% fileList = dir('../../facePictures/CFD Version 3.0/Images/CFD/**/*N.jpg');
% getNames = struct2cell(fileList)';
% fileNames = string(getNames(:,1));
% for k = 1:length(fileList)
%     a=1;
%     % Load image
%     image = imread(fullfile(fileList(k).folder, fileList(k).name));
%     % Remove image if it doesn't have a white background
%     for i=1:0.75*size(image,1)
%         if (image(i,1)~=255) || (image(i,size(image,2))~=255) || (image(1,ceil(i/3))~=255)
%             removedImages(k) = fileNames(k); %#ok<AGROW>
%             a=0;
%             break
%         end
%     end
% % Copy picture to subset folder if it should be used
%     if a
%         cd(char(getNames(k,2)))
%         copyfile(fileList(k).name,'../../../../../MSc_EventDuration/lib/CFD_subset');
%     end
% end
% cd '../../../../../MSc_EventDuration/exp'
% % Write a table of which images have been removed
% removedImages = rmmissing(removedImages);
% removedImages = table(removedImages');
% writetable(removedImages,'../lib/CFD_subset/removedImages.tsv','FileType','text','Delimiter','\t');

%% Load face images

% Get a list of files in the subset folder
fileList = dir('../lib/CFD_subset/*N.jpg');
for k = 1 : length(fileList)
    % Load image
    image = imread(fullfile(fileList(k).folder, fileList(k).name));
    % Scale image to 756x1076
    image = imresize(image, [cfg.rect(4) ((cfg.rect(4)/size(image,1))*size(image,2))]*0.7);
    % Make texture
    cfg.stimDur.stimTex(k)=Screen('MakeTexture',10,image);
end

% Preload textures into VRAM
Screen('PreloadTextures',cfg.win,cfg.stimDur.stimTex);
fprintf('%d textures Preloaded \n',length(cfg.stimDur.stimTex));

fprintf('Processed %d images.\n', k);
end