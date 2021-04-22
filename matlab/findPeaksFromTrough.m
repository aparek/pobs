function [dips] = findPeaksFromTrough(sig, dips, fs, peakProminence)
% function [loc,pk] = findPeaksFromTrough()
%
% This function will find the peaks from the location of Troughs. The
% original MATLAB findpeaks algorithm is buggy. 
% 
% Pseudo algorithm: 
%   Start with the first trough, look for values to the left and the right.
%   If the value on the left are increasing then we are on an incline and
%   keep going until its greater than 2, if the value on right are also
%   increasing, then we are on an incline and keep going until its greater
%   than 2
%   
%   Ankit Parekh (C), 2020. 
%   ankit.parekh@mssm.edu

sig = sig(:);
diffSig = diff(sig);
for i = 1:height(dips)
    
    % Left Peak
    
    idx = dips.locTrough(i);

    % Find the last negative derivative to the left of trough (indicating
    % a start of decline
    
    pkCounter = idx-1;
    negDiffCounter = pkCounter;
    while ~ (diffSig(pkCounter) > (peakProminence-1)/10)
        if diffSig(pkCounter) < 0 
            negDiffCounter = pkCounter; % Keep tab of last negative der.
        end
        pkCounter = pkCounter - 1;
        
        if ~pkCounter % Signalling that we reached start of signal
            break
        end
    end
    dips.leftLoc(i) = negDiffCounter - 1;

    % Find the last positive derivative to the right of trough (indicating
    % a shift from incline to decline.
    
    
    pkCounter = idx + 1;
    posDiffCounter = pkCounter;
    while ~(diffSig(pkCounter) < -0.1)
        
        if diffSig(pkCounter) > 0
            posDiffCounter = pkCounter; % Keep tab of last derivative
        end
        pkCounter = pkCounter + 1;
        
        if pkCounter == length(diffSig) % Signalling that we reached the end of signal
            break
        end
        
    end
    dips.rightLoc(i) = posDiffCounter + 1;
    
    
end


% If left or right peaks were not found, remove those dips



% Add code to clean the peaks/troughs 
% 1. Average of all distances between peak-trough and trough-peak and
% remove outliers ( > 3SD)?

for j = 1:height(dips)
    %Adjust the trough's 
    keepGoingForward = 1;
    idx = dips.locTrough(j);
    while keepGoingForward
        if sig(idx + 1) == sig(idx)
            idx = idx + 1;
        else
            keepGoingForward = 0;
        end
    end
    
    
    % take the midpoint from idx and locTrough(j)
    dips.locTrough(j) = floor((idx - dips.locTrough(j))/2) + dips.locTrough(j);
    %locTrough(j) = idx;
    
    
    % Check to see if miscalculated right/left peaks
    
    if (j ~= height(dips)) && dips.rightLoc(j) > dips.leftLoc(j+1)
        dips.rightLoc(j) = dips.leftLoc(j+1) - 1;
    end
    
    [valMax, pkMax] = max(sig(dips.locTrough(j) : dips.rightLoc(j)-1));
    if valMax > sig(dips.rightLoc(j))
        dips.rightLoc(j) = dips.locTrough(j) + pkMax;
    end
    
    [valMax, pkMax] = max(sig(dips.leftLoc(j) + 1:dips.locTrough(j)));
    if valMax > sig(dips.leftLoc(j))
        dips.leftLoc(j) = dips.leftLoc(j) + 1 + pkMax;
    end
    
%     [tempPk, tempPkloc] = findpeaks(sig(dips.locTrough(j) : dips.rightLoc(j)))
%     if ~isempty(tempPk)
%         [~, pkIdx] = max(tempPk);
%         dips.rightLoc = dips.locTrough(j) + tempPkLoc(pkIdx);
%     end
%     
    % Check to see if we miscalculated left peaks
     
end

% Remove outliers in troughs
meanTrough = mean(dips.trough);
stdTrough = std(dips.trough);
dips2 = dips;
for j = 1:height(dips)
    if (dips.trough(j) > meanTrough + 5*stdTrough) || (dips.trough(j) < meanTrough - 5*stdTrough)
        dips2(j,:) = [];
    end
end

dips = dips2;
%locTrough = locTrough(~isnan(locTrough));
%loc = loc(~isnan(loc));
%pk = pk(~isnan(pk));
%trough = trough(~isnan(trough));








