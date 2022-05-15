function [slice] = slice_randomization(rand,subject,block)

% Example call:
% slice.(fn{1}) = rand.(fn{1}){select};
select = rand.block == block & rand.subject == subject;
if sum(select)==0
    error('something went wrong, empty randomization selection')
end

slice = rand(select,:);
end