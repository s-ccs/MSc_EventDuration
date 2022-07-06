function flicker_dot = setup_flickertimings(params,ntrial,randomization,blockNum)
assert(all(isfield(params,{'targetsPerTrial','targetsTimeDelta'})))

% How often should the dot flicker?
totalFlicker = floor(params.targetsPerTrial*ntrial);
if blockNum==1
    flickertime  = sum(randomization.stimDur());
elseif blockNum>1
    flickertime  = sum(randomization.stimDur(1+ntrial*(blockNum-1):ntrial+ntrial*(blockNum-1)));
end
% Generate flickertimings and make sure they're separated by at least
% targetsTimeDelta
flickertimings = sort(rand(totalFlicker,1)*flickertime);
while any(diff(flickertimings)<params.targetsTimeDelta)
    flickertimings = sort(rand(totalFlicker,1)*flickertime);
end

% Determine in which trials and when in these trials the dot flickers
trialFlicker.whichTrial = zeros(1,blockNum*ntrial);
trialFlicker.whenInTrial = zeros(1,blockNum*ntrial);
trialFlicker = struct2table(trialFlicker);
for i=1:length(flickertimings)
    for j=1+ntrial*(blockNum-1):length(randomization.stimDur)
        if (sum(randomization.stimDur(1+ntrial*(blockNum-1):j))>flickertimings(i))
            % Make sure stimDur is long enough for 100 ms flicker
            if ((sum(randomization.stimDur(1+ntrial*(blockNum-1):j))-flickertimings(i))>params.targetsDuration) && (j==1)
                trialFlicker.whichTrial(j) = randomization.trial(j);
                trialFlicker.whenInTrial(j) = flickertimings(i);
                break
            elseif ((sum(randomization.stimDur(1+ntrial*(blockNum-1):j))-flickertimings(i))>params.targetsDuration)...
                    || (j==length(randomization.stimDur))
                trialFlicker.whichTrial(j) = randomization.trial(j);
                trialFlicker.whenInTrial(j) = flickertimings(i)-sum(randomization.stimDur(1+ntrial*(blockNum-1):j-1));
                break
            elseif ((sum(randomization.stimDur(1+ntrial*(blockNum-1):j))-flickertimings(i))<params.targetsDuration)
                % Remaining stimDur of trial is too short for 100 ms flicker:
                % If stimDur is >200ms (i.e. there is enough time in this trial),
                % flicker 100 ms earlier than it should
                if randomization.stimDur(j)>0.2
                    trialFlicker.whichTrial(j) = randomization.trial(j);
                    trialFlicker.whenInTrial(j) = flickertimings(i)-sum(randomization.stimDur(1+ntrial*(blockNum-1):j-1))-0.1;
                    break
                else % Current trial is too short to flicker earlier without causing missed flips:
                    % Push it to next stimOnset. (Will flicker ~15 ms later due to script/psychtoolbox delays however.)
                    trialFlicker.whichTrial(j+1) = randomization.trial(j+1);
                    trialFlicker.whenInTrial(j+1) = 0.001;
                    break
                end
            end
        end
    end
end

flicker_dot.whichTrial = trialFlicker.whichTrial(1+ntrial*(blockNum-1):length(trialFlicker.whichTrial));
flicker_dot.whenInTrial = trialFlicker.whenInTrial(1+ntrial*(blockNum-1):length(trialFlicker.whenInTrial));

if blockNum == params.numBlocks
    fprintf('Found flickertimings\n');
end
