function AUC = SpO2_AUC(filename, hdr, sigHdr, sigCell)
% function AUC = SpO2_AUC(filename)
%
% Calculate the area under curve for each of the saturation dips
%
% Ankit A. Parekh (C) 2019.
% Icahn School of Medicine at Mount Sinai
%

fprintf('\n===================================')
useLowPass = 0; % LowPass vs. CNC_FLSA for SPO2
peakProminence = 3; % Ignore sat. dips less than peakProminence%
removeWake = 0; % Remove periods of wake from analysis

% Set up evtFilename and breFilename
evtFilename = [filename,'.EVT'];
edfFilename = [filename, '.edf'];
hypFilename = [filename, '.HYPJSON'];


if nargin < 2
    fprintf('\nReading in EDF file...')
    [hdr, sigHdr, sigCell] = blockEdfLoad(edfFilename);
    fprintf('\nRead EDF file...')
else
    fprintf('\nEDF already passed... \nSkipping to next step...')
end

fprintf('\nReading EVT Table...')
evtTable = readEVTtable(evtFilename);

% Try loading Hypnogram
fprintf('\nRead Hypnogram...') % For now we are not using hypnogram
if removeWake
    try
        
        fid = fopen(hypFilename);
        raw = fread(fid, inf);
        jsonStr = char(raw');
        fclose(fid);
        rawData = jsondecode(jsonStr);
        hyp = downsample(rawData.Data.x10sEpochs,3);
        
    catch
        fprintf('\n-HypJSON or HYP not available')
        try
            hyp = load([filename, '-hyp.txt']);
            hyp = hyp(:,2);
        catch
            fprintf('\n-hyp.txt also not available. Setting removeWake = 0')
            removeWake = 0;
        end
    end
    
end

SpO2ChanName = 'SpO2';
SpO2channel = find(startsWith({sigHdr.signal_labels},SpO2ChanName));
fs = sigHdr.samples_in_record(SpO2channel);

if useLowPass
    SpO2Freq = 0.1;
    fprintf('\n===SpO2 Analysis. Using LowPass filter fc = %2.2f',SpO2Freq)
    [B,A] = butter(2, SpO2Freq/(fs/2));
    sig = filtfilt(B,A,sigCell{SpO2channel});
else
    fprintf('\n===SpO2 Analysis. Using CNC_FLSA Algorithm')
    lam0 = 0.5;
    lam1 = 10;
    a0 = 0.1;
    a1 = 0.2;
    Nit = 5;
    pen = 'atan';
    [sig, ~] = CNC_FLSA(sigCell{SpO2channel}, lam0, lam1, a0, a1, Nit, pen);
end

% Remove Invalid periods of SpO2
for j = 1:height(evtTable)
    try 
        if contains(evtTable.Classification(j,:), 'Invalid')
            sig(round(evtTable.StartTime(j)*fs + 1): round((evtTable.StartTime(j) + evtTable.Duration(j))*fs)) = NaN;
        end
    catch 
        if evtTable.Classification(j) == 1 && evtTable.Type(j) == 9
            sig(round(evtTable.StartTime(j)*fs + 1): round((evtTable.StartTime(j) + evtTable.Duration(j))*fs)) = NaN;
        end
    end
end

if removeWake
    for j = 1:length(hyp)
        if ~hyp(j)
            sig((j-1)*fs*30 + 1:j*fs*30) = NaN;
        end
    end
end

if max(sig(:) > 150)
    sig = rescale(sig, 0, 100);
end

sig(sig < 56) = NaN;            % Sometimes invalid sat is not run properly in Minerva
dips = table();

[troughSpO2,locTroughSpO2] = findpeaks(-1*sig, 'MinPeakProminence',peakProminence);
troughSpO2 = -1*troughSpO2;

dips.trough = troughSpO2;
dips.locTrough = locTroughSpO2;
dips.leftLoc = zeros(size(dips.locTrough));
dips.rightLoc = zeros(size(dips.locTrough));

[dips] = findPeaksFromTrough(sig,dips,fs, peakProminence);

N = length(sig);
n = 0:N-1;
plot(n, sig,'k','linewidth',1)
hold on
plot(dips.locTrough, sig(dips.locTrough), 'or')
plot(dips.leftLoc, sig(dips.leftLoc), 'xr')
plot(dips.rightLoc, sig(dips.rightLoc), 'xg')
AUC = 0;
AUC2 = 0;

for i = 1:height(dips)
    
    if (dips.leftLoc(i) - dips.locTrough(i)) > 240*fs
        fprintf('\nSkipping this SpO2 dip')
        continue
    elseif (dips.rightLoc(i) - dips.locTrough(i)) > 240*fs
        fprintf('\nSkipping this SpO2 dip')
        continue
    end
    
    if sum(isnan(sig(dips.leftLoc(i):dips.rightLoc(i))))
        fprintf('\n===Signal contains NaN in between. Skipping...')
        continue
    end
    
    % Get the x axis
    x_ax = dips.leftLoc(i)-1:dips.rightLoc(i)-1;
    
    % Get the y axis
    lower = sig(dips.leftLoc(i):dips.rightLoc(i));% SpO2 curve between the two peaks
    
    % Get the upper val
    
    %upper = ones(size(x_ax)) * sig(dips.leftLoc(i));
    upper = sig(dips.leftLoc(i)) + ((sig(dips.rightLoc(i)) - sig(dips.leftLoc(i)))./(dips.rightLoc(i) - dips.leftLoc(i))) .* (x_ax - dips.leftLoc(i)); %Line segment connecting the two peaks?
    
    %     if sig(dips.leftLoc(i)) < sig(dips.rightLoc(i))
    %
    %         % Change the x axis accordingly
    %         [idx, loc] = find(sig(1:locPkSpO2(nextPk)) <= pkSpO2(prevPk),1,'last');
    %         x_ax = locPkSpO2(prevPk)-1:idx-1;
    %         lower = sig(locPkSpO2(prevPk):idx);
    %         upper = pkSpO2(prevPk) * ones(size(x_ax));
    %     elseif sig(dips.leftLoc(i)) >= sig(dips.rightLoc(i))
    %         upper = pkSpO2(prevPk) + ((pkSpO2(nextPk) - pkSpO2(prevPk))./(locPkSpO2(nextPk) - locPkSpO2(prevPk))) .* (x_ax - locPkSpO2(prevPk)); %Line segment connecting the two peaks?
    %         % Change the x axis accordingly
    %         [idx, loc] = find(sig(1:locTroughSpO2(i)) <= pkSpO2(nextPk),1,'last');
    %         %x_ax = idx:locPkSpO2(nextPk);
    %         %lower = sig(idx:locPkSpO2(nextPk));
    %         %upper = pkSpO2(nextPk) * ones(size(x_ax));
    %     end
    
    x = [x_ax, fliplr(x_ax)];
    y = [lower', fliplr(upper)];
    fill(x, y, 'k','FaceAlpha',0.25)
    if ~isnan(polyarea(x,y))
        AUC = AUC + polyarea(x,y);
        AUC2 = AUC2 + (trapz(x_ax, upper) - trapz(x_ax, lower));
    end
end

if removeWake
    TST = sum(hyp > 0)*30/(3600);
else
    TST = (length(sig)/fs) / 3600;
end

title(sprintf('AUC (/hr.): %4.2f',AUC/(TST)))
fprintf('\n===AUC (/hr.): %4.2f',AUC/(TST))