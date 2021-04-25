function pobs(filename, hdr,sigHdr, sigCell, flowChan, SpO2Channel, snoreChan, ribChan, abdChan)

% function [] = obsVcentral(filename)
%
% This function will attempt to score obstructiveness/centralness of a
% breath.
%
%
%  Input:a
%   filename - edffilename (e.g. 080221ih-d)
%
%  Output:
%   []
%
%
%  Run in windows to have the breath probabilities automatically added to
%  the breath table.
%
%
% Global settings
%
%diaryFile = datestr(clock,'mm-DD-YYYY-HH-MM-SS');
%diary(['log_',diaryFile])
%
% Minerva criteria for end of hypopnea
% 1) 2 successive breaths where the average inspiratory flow is >0.6x, >0.75x of moving average (of breaths outside of hypopneas)
% 2) 1 large breath where the average inspiratory flow > 1.5x that of breaths within the hypopnea AND the average inspiratory flow > 0.75x of moving average (of breaths outside of hypopneas)
%
% Changes:
%   v3: Removed manual breath table calculations.
%   v6:
%
%
% Ankit Parekh
% Nov, 2020
% Icahn School of Medicine at Mount Sinai


fprintf('Starting...........');
rng('default')
dB = @(x) 20 * log10(abs(x));
phenotyping = 0;
PlotFigs = 1;  % Flag to set printing to on or off
useLowPass = 0; % LowPass vs. CNC_FLSA for SPO2
peakProminence = 3; % Ignore sat. dips less than 3%
createEDF = 0;  % Add additional channels to EDF for O/C
createBRETable = 1; % Add O/C scores to breath table
addJitter = 1;  % Add random jitter to scatter plot
plotSeverity = 0.85; % For any plotting, plot breaths below this amp.
debugPlots = 0;
Stats = 0;
imputeApneas = 0;
runDORIS = 0;
runBreathAnalyzer = 0;

% Blue/Yellow colormap for plots
cmap = [];
cmap(1,:) = [0.9290 0.6940 0.1250];   %// color first row - red
cmap(2,:) = [0.9 0.9 0.9];   %// color 25th row - green
cmap(3,:) = [0 0.4470 0.7410];   %// color 50th row - blue
%cmap(3,:) = [66,28,82]./255;   %// color 50th row - blue
[X,Y] = meshgrid([1:3],[1:20]);  %// mesh of indices
cmap = interp2(X([1,10,20],:),Y([1,10,20],:),cmap,X,Y); %// interpolate colormap


% Set up evtFilename and breFilename
breFilename = [filename(1:end-4), '.BRE'];
edfFilename = [filename(1:end-4), '.edf'];


orgSigHdr = sigHdr;
fsFlow = sigHdr(flowChan,:).samples_in_record;
recStarttime = datetime(hdr.recording_starttime,'format','HH.mm.ss');
recStartDate = datetime(hdr.recording_startdate,'Format','dd.MM.yy');
recStartDateTime = datetime([hdr.recording_startdate, ' ',hdr.recording_starttime],'Format','dd.MM.yy HH.mm.ss');

% Breath declipper (yet to decide on a threshold)
if runDORIS
    clippedSig = detectClipping(sigCell{flowChan});
    fprintf('Percent Signal Clipped: %2.2f',nnz(isnan(clippedSig))./length(clippedSig)*100);
    
    % Fix flow signal
    [sigCell{flowChan},~,~] = drago_filt(clippedSig, 1e-1, 1e-13, 15);
    
    % Write to edf
    blockEdfWrite([filename(1:end-4),'.edf'],hdr, orgSigHdr, sigCell)
    fprintf('Wrote new edf file with fixed Flow');
    runBreathAnalyzer = 1;
end

% Run breath analyzer if requested
% In development
if runBreathAnalyzer && ispc
    
    curDir = pwd;
    MinervaDir = 'C:\Program Files (x86)\Minerva Sleep Program\Minerva 6.0.0';
    cd(MinervaDir)
    
    sysCommand = ['minerva_cl.exe ',char(34),filename(1:end-4),'.edf',char(34)...
        ' [respiratory.detector] -breath_detector type=nyu calibration=auto channel_id=', flowChan-1];
    
    [status, result] = system(sysCommand);
    cd(curDir)
end


% Impute apneas
if imputeApneas
    if ispc
        py = 'python';
    else
        py = 'python3';
    end
    
    command = [py, ' impute_breaths_apnea_v2.py ',filename(1:end-4)];
    
    try
        [status, result] = system(command);
        if ~status
            fprintf('\n===Imputed Apnea Breaths...')
        end
    catch
        fprintf('\n===Error Imputing breaths...')
    end
else
    fprintf('\n===Apnea imputation not requested...')
end


% Read in the breath Table
fid = fopen(breFilename);
raw = fread(fid, inf);
jsonStr = char(raw');
fclose(fid);

try
    rawData = jsondecode(jsonStr);
    
    % Create a text file for the header
    
    % Now the data is in rawData
    
    if strcmp(breFilename(end-3:end),'.BRE')
        % In case of a cell structure
        
        %dt = [rawData.Data{1:end}];
        %T = struct2table(rawData.Data);
        %file_to_write = ['C:\Users\pareka02\Documents\Events\breath-',filename(end-12:end-4),'.xlsx'];
        
        T = [];
        
        if iscell(rawData.Data)
            T = struct2table(rawData.Data{1},'AsArray',1);
            for j = 2:length(rawData.Data)
                T_temp = struct2table(rawData.Data{j},'AsArray',1);
                T_temp_missing = setdiff(T.Properties.VariableNames, T_temp.Properties.VariableNames);
                T_missing = setdiff(T_temp.Properties.VariableNames,  T.Properties.VariableNames);
                
                if ~isempty(T_missing)
                    T = [T array2table(nan(height(T), numel(T_missing)), 'VariableNames', T_missing)];
                    
                end
                
                if ~isempty(T_temp_missing)
                    T_temp = [T_temp array2table(nan(height(T_temp), numel(T_temp_missing)), 'VariableNames', T_temp_missing)];
                    
                end
                T = [T; T_temp];
                
            end
        else
            T = struct2table(rawData.Data);
        end
        
        % In case of auto breath table, remove normalized flow
        if nnz(ismember(T.Properties.VariableNames,'Normalized_Flow'))
            T.Normalized_Flow = [];
        end
        breTable = T;
        fprintf('Breath Table read in successfully...');
    end
catch
    fprintf('Error while reading in the breath table...');
    
end

apneaTable = breTable(breTable.BreathId == 0,:);
breTable = breTable(breTable.BreathId > 0,:);
% Start assigning scores based on criteria above (see function header)
numBreaths = height(breTable);
brScores = table(breTable.BreathId, NaN*zeros(size(breTable.BreathId)),...
    NaN*zeros(size(breTable.BreathId)), 'VariableNames',{'BreathID', 'Obstructive','Central'});

% Initialize the scores as 0
brScores.Central = zeros(height(breTable),1);
brScores.Obstructive = zeros(height(breTable),1);

fprintf('\nStarting Breath-by-Breath Analysis on %d of breaths',height(breTable));
fprintf('\n===============OPTIONS=============');
fprintf('\nPlot breaths that are < %d%% of normal in amplitude',plotSeverity * 100);

% FL classification to be used as a score for O/C
% For O
brScores.Obstructive(breTable.BreathId(breTable.BrClass == 3)) = 5;
brScores.Obstructive(breTable.BreathId(breTable.BrClass == 0 | breTable.BrClass == 1)) = -2;
brScores.Obstructive(breTable.BreathId(breTable.BrClass == 2)) = 2;

% For C
brScores.Central(breTable.BreathId(breTable.BrClass == 3)) = -5;
brScores.Central(breTable.BreathId(breTable.BrClass == 0 | breTable.BrClass == 1)) = 3;
brScores.Central(breTable.BreathId(breTable.BrClass == 2)) = 0;

if PlotFigs
    X = brScores.Obstructive(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    Y = brScores.Central(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    
    
    rng('default')
    X = X + addJitter * 0.5 * randn(size(X));
    Y = Y + addJitter * 0.5 * randn(size(Y));
    ctr = mode([X,Y]);
    
    hh = hist3([X,Y], [20 20]);
    
    %%%%%%%%%% DEbug/Test from here
    set(0,'defaultlinemarkersize',4,'defaultaxesfontsize',11)
    % Dscatter
    scatter( X,Y,'ok','MarkerFaceColor',[0.8 0.8 0.8],'MarkerEdgeColor',[0.8 0.8 0.8]);
    hold( 'on')
    dscatter( X,Y,'plottype','contour')
    colormap( parula);
    c = colorbar();
    
    caxis( [0 0.5])
    c.Ticks = 0:0.1:0.5;
    c.TickLabels = 0:10:50;
    xlim( [-20 20])
    ylim( [-20 20])
    xline( 0); yline(0);
    c.Label.String = 'Percentage of Small Breaths (%)';
    c.FontSize = 11;
    xlabel( 'Obstructive Scores')
    ylabel( 'Central Scores')
    text( 10,18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,-18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,18, sprintf('Definitely \nNot Obstructive'),'FontSize',12, 'HorizontalAlignment','Center')
    text( 10,-18, sprintf('Definitely \nObstructive'),'FontSize',12, 'HorizontalAlignment','Center')
end

% From now on, have to add/subtract to/from the old scores
% FL > 1 on adjacent breaths (for now use 2 adjacent breaths)

% Store the flow signal temporarily

flowSig = sigCell{flowChan};
breTable.Clipped = zeros(height(breTable),1);


for j = 3:numBreaths-3
    
    % Check for clipping
    if breTable.FlowAvgMid3rdPercentNormal(j) > 1 && ...
            skewness(flowSig(breTable.ElapsedTime(j):breTable.ElapsedTime(j) + round(breTable.Ti(j)*fsFlow))) < -1.3
        breTable.Clipped(j) = 1;
        
    end
    
    if (breTable.BrClass(j-1) > 1 && breTable.BreathId(j-2) > 1)
        brScores.Obstructive(j-2:j) = brScores.Obstructive(j-2:j) + 3;
        brScores.Central(j-2:j) = brScores.Central(j-2:j) - 1;
        
    elseif (breTable.BrClass(j-1) > 1 && breTable.BreathId(j+1) > 1)
        brScores.Obstructive(j-1:j+1) = brScores.Obstructive(j-1:j+1) + 3;
        brScores.Central(j-1:j+1) = brScores.Central(j-1:j+1) - 1;
    else
        brScores.Obstructive(j-2:j) = brScores.Obstructive(j-2:j) - 1;
        %brScores.Central(j-2:j) = brScores.Central(j-2:j) + 1;
    end
end
% Warn about clipping
fprintf('\n===============WARNING=============');
fprintf('\nPercentage of Breaths Clipped (Inspiratory): %3.0f%%',round(nnz(breTable.Clipped)/height(breTable)*100));

if PlotFigs
    X = brScores.Obstructive(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    Y = brScores.Central(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    
    
    rng('default')
    X = X + addJitter * 0.5 * randn(size(X));
    Y = Y + addJitter * 0.5 * randn(size(Y));
    ctr = mode([X,Y]);
    
    hh = hist3([X,Y], [20 20]);
    
    
    scatter( X,Y,'ok','MarkerFaceColor',[0.8 0.8 0.8],'MarkerEdgeColor',[0.8 0.8 0.8]);
    hold( 'on')
    dscatter(X,Y,'plottype','contour')
    colormap( parula);
    c = colorbar();
    
    caxis( [0 0.5])
    c.Ticks = 0:0.1:0.5;
    c.TickLabels = 0:10:50;
    xlim( [-20 20])
    ylim( [-20 20])
    xline( 0); yline(0);
    c.Label.String = 'Percentage of Small Breaths (%)';
    c.FontSize = 11;
    xlabel( 'Obstructive Scores')
    ylabel( 'Central Scores')
    text( 10,18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,-18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,18, sprintf('Definitely \nNot Obstructive'),'FontSize',12, 'HorizontalAlignment','Center')
    text( 10,-18, sprintf('Definitely \nObstructive'),'FontSize',12, 'HorizontalAlignment','Center')
end



% Minerva Version
centCond = 0;
obsCond = 0;
j = 3;
while j < numBreaths - 3
    if breTable.FlowAvgMid3rdPercentNormal(j) < plotSeverity
        keepGoing = 1;
        k = j + 1;
        while keepGoing && k < numBreaths-3
            obsTest = ((breTable.FlowAvgMid3rdPercentNormal(k)/breTable.FlowAvgMid3rdPercentNormal(k-1)) >= 1.5) ...
                && (breTable.FlowAvgMid3rdPercentNormal(k) > 0.75);
            
            centTest = ( (breTable.FlowAvgMid3rdPercentNormal(k) > 0.65) ...
                && (breTable.FlowAvgMid3rdPercentNormal(k) > 0.75));
            
            
            if obsTest && centTest
                % If obstructive and central condition met, give preference
                % to obstructive
                
                brScores.Obstructive(j:k-1) = brScores.Obstructive(j:k-1) + 3;
                brScores.Central(j:k-1) = brScores.Central(j:k-1) - 1;
                obsCond = obsCond + 1;
                keepGoing = 0;
                j = k + 1;
                
            elseif centTest && ~obsTest
                brScores.Obstructive(j:k-1) = brScores.Obstructive(j:k-1) - 1;
                brScores.Central(j:k-1) = brScores.Central(j:k-1) + 2;
                centCond = centCond + 1;
                keepGoing = 0;
                j = k + 1;
                
            elseif obsTest && ~centTest
                brScores.Obstructive(j:k-1) = brScores.Obstructive(j:k-1) + 3;
                brScores.Central(j:k-1) = brScores.Central(j:k-1) - 1;
                obsCond = obsCond + 1;
                keepGoing = 0;
                j = k + 1;
                
            elseif ~(obsTest || centTest) && breTable.FlowAvgMid3rdPercentNormal(k) > plotSeverity
                keepGoing = 0;
                j = k + 1;
            end
            k = k + 1;
        end
        % k is probably the end of the event now and j is the start, k-1 is
        % the last breath in the event,
    end
    j = j + 1;
end

fprintf('\n==Debug: Sudden Termination on %d events',obsCond)

if PlotFigs
    X = brScores.Obstructive(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    Y = brScores.Central(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    
    
    rng('default')
    X = X + addJitter * 0.5 * randn(size(X));
    Y = Y + addJitter * 0.5 * randn(size(Y));
    ctr = mode([X,Y]);
    
    hh = hist3([X,Y], [20 20]);
    
    
    scatter( X,Y,'ok','MarkerFaceColor',[0.8 0.8 0.8],'MarkerEdgeColor',[0.8 0.8 0.8]);
    hold( 'on')
    dscatter( X,Y,'plottype','contour')
    colormap( parula);
    c = colorbar();
    
    caxis( [0 0.5])
    c.Ticks = 0:0.1:0.5;
    c.TickLabels = 0:10:50;
    xlim( [-20 20])
    ylim( [-20 20])
    xline( 0); yline(0);
    c.Label.String = 'Percentage of Small Breaths (%)';
    c.FontSize = 11;
    xlabel( 'Obstructive Scores')
    ylabel( 'Central Scores')
    text( 10,18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,-18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,18, sprintf('Definitely \nNot Obstructive'),'FontSize',12, 'HorizontalAlignment','Center')
    text( 10,-18, sprintf('Definitely \nObstructive'),'FontSize',12, 'HorizontalAlignment','Center')
end



% 5. Ti breath / Ti Baseline > 110

cond5 = (breTable.Ti ./ breTable.TiAvgNormal) >= 1.1;

brScores.Obstructive(cond5) = brScores.Obstructive(cond5) + 3;
brScores.Obstructive(~cond5) = brScores.Obstructive(~cond5) - 1;
brScores.Central(cond5) = brScores.Central(cond5) - 1;
brScores.Central(~cond5) = brScores.Central(~cond5) + 1;



if PlotFigs
    X = brScores.Obstructive(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    Y = brScores.Central(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    
    
    rng('default')
    X = X + addJitter * 0.5 * randn(size(X));
    Y = Y + addJitter * 0.5 * randn(size(Y));
    ctr = mode([X,Y]);
    
    hh = hist3([X,Y], [20 20]);
    
    
    scatter( X,Y,'ok','MarkerFaceColor',[0.8 0.8 0.8],'MarkerEdgeColor',[0.8 0.8 0.8]);
    hold( 'on')
    dscatter( X,Y,'plottype','contour')
    colormap( parula);
    c = colorbar();
    
    caxis( [0 0.5])
    c.Ticks = 0:0.1:0.5;
    c.TickLabels = 0:10:50;
    xlim( [-20 20])
    ylim( [-20 20])
    xline( 0); yline(0);
    c.Label.String = 'Percentage of Small Breaths (%)';
    c.FontSize = 11;
    xlabel( 'Obstructive Scores')
    ylabel( 'Central Scores')
    text( 10,18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,-18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,18, sprintf('Definitely \nNot Obstructive'),'FontSize',12, 'HorizontalAlignment','Center')
    text( 10,-18, sprintf('Definitely \nObstructive'),'FontSize',12, 'HorizontalAlignment','Center')
end



% In development SpO2

try
    fprintf('\n===Warning. Assuming SpO2 Channel = %d ===',SpO2Channel)
catch ME
    if contains(ME.identifier, 'UndefinedFunction')
        fprintf('\n==ERROR: Cannot find SpO2 channel')
    end
end

fsSpO2 = sigHdr(SpO2Channel,:).samples_in_record;

if useLowPass
    SpO2Freq = 0.75;
    fprintf('\n===SpO2 Analysis. Using LowPass filter fc = %2.2f',SpO2Freq)
    [B,A] = butter(2, SpO2Freq/(fsSpO2/2));
    sig = filtfilt(B,A,sigCell{SpO2Channel});
else
    fprintf('\n===SpO2 Analysis. Using CNC_FLSA Algorithm')
    lam0 = 0.5;
    lam1 = 5;
    a0 = 0.1;
    a1 = 0.2;
    Nit = 5;
    pen = 'atan';
    [sig, ~] = CNC_FLSA( sigCell{SpO2Channel}, lam0, lam1, a0, a1, Nit, pen);
end

% Remove Invalid periods of SpO2
sig = remove_invalid_SpO2(sig, fsSpO2, 56,100);

% Breath by Breath histogram of SpO2
hSpO2 = NaN*zeros(numBreaths,1);
for j = 3:numBreaths-3
    hSpO2(j) = nanmean(sig(round(breTable.ElapsedTime(j)/fsFlow*fsSpO2):round((breTable.ElapsedTime(j)/fsFlow+breTable.Ttot(j))*fsSpO2)));
end


% SpO2 ratio a/b (a = distance from peak to trough, b = trough to next
% peak)

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

%
% [troughSpO2,locTroughSpO2] = findpeaks(-1*filtSpO2, 'MinPeakProminence',peakProminence);
% troughSpO2 = -1*troughSpO2;

% Findpeaks is buggy. Use trough locations to find peaks in custom way
[dips] = findPeaksFromTrough(sig,dips,fsSpO2, peakProminence);


%             figure(3), clf;
%             ax(1) = subplot(2,1,1);
%             AUC = SpO2_AUC(filename, hdr, sigHdr, sigCell);
%
%             ax(2) = subplot(2,1,2);
%             plot([0:length(flowSig)-1]/fsFlow * fsSpO2, flowSig/1000+105, 'k')
%             linkaxes(ax,'x')


ratSpO2 = [];
for j = 1:height(dips)
    
    ratSpO2(j) = (dips.rightLoc(j) - dips.locTrough(j)) ./ ...
        (dips.locTrough(j) - dips.leftLoc(j));
    
    % Search for the preceding event based on flow
    % amplitudes/ventilation?
    [~, idx] = min(abs(breTable.ElapsedTime - dips.rightLoc(j)/fsSpO2*fsFlow));
    if idx < 10
        continue
    end
    keepGoingBack = 1;
    brStartIndx = idx-1;
    brEndIndx = idx;
    brEvtEndIndx = NaN;
    
    
    % Start of event is behind the dip
    while keepGoingBack
        if (breTable.FlowAvgMid3rdPercentNormal(brEndIndx)./ breTable.FlowAvgMid3rdPercentNormal(brStartIndx)) * 100 > 130
            % Implies that its possibly the end of an event
            brEvtEndIndx = brEndIndx;
            keepGoingBack = 0;
            
        elseif abs(brStartIndx - idx) > 30
            keepGoingBack = 0;
            
        else
            brEndIndx = brStartIndx;
            brStartIndx = brStartIndx - 1;
        end
        
    end
    
    
    
    % Now need to find the start of event
    
    brEvtStartIndx = NaN;
    keepGoingBack = 1;
    brEndIndx = brEvtEndIndx;
    brStartIndx = brEndIndx - 1;
    while keepGoingBack && ~isnan(brEvtEndIndx)
        if (breTable.FlowAvgMid3rdPercentNormal(brStartIndx)./ breTable.FlowAvgMid3rdPercentNormal(brEndIndx)) * 100 > 130
            %Implies that we found start of event
            brEvtStartIndx = brEndIndx;
            
            % Make sure that this is indeed the start of an event and not
            % just a transient breath
            
            if (breTable.FlowAvgMid3rdPercentNormal(brStartIndx-1)./ breTable.FlowAvgMid3rdPercentNormal(brEndIndx-1)) * 100 < 100
                brEndIndx = brStartIndx;
                brStartIndx = brStartIndx - 1;
                keepGoingBack = 1;
            else
                keepGoingBack = 0;
            end
            
        elseif abs(brStartIndx - brEvtEndIndx) > 30
            keepGoingBack  = 0;
        else
            brEndIndx = brStartIndx;
            brStartIndx = brStartIndx - 1;
        end
        
    end
    
    if brEvtEndIndx - brEvtStartIndx >= 1
        % Ignore anything that is 2 breaths long ???
        % Assign the scores obs + 3
        if ratSpO2(j) < 0.55
            
            brScores.Obstructive(brEvtStartIndx:brEvtEndIndx) =...
                brScores.Obstructive(brEvtStartIndx:brEvtEndIndx) + 3;
            brScores.Central(brEvtStartIndx:brEvtEndIndx) =...
                brScores.Central(brEvtStartIndx:brEvtEndIndx) - 3;
            
            breTable.SatRatio(brEvtStartIndx:brEvtEndIndx) = 3;
            
        elseif ratSpO2(j) > 0.75 && ratSpO2(j) < 3
            
            brScores.Obstructive(brEvtStartIndx:brEvtEndIndx) =...
                brScores.Obstructive(brEvtStartIndx:brEvtEndIndx) - 3;
            brScores.Central(brEvtStartIndx:brEvtEndIndx) =...
                brScores.Central(brEvtStartIndx:brEvtEndIndx) + 3;
            
            breTable.SatRatio(brEvtStartIndx:brEvtEndIndx) = -3;
            
            
        elseif ratSpO2(j) > 5 || ratSpO2(j) < 0.2
            % Do nothing and don't score these as O/C. They are artifacts
            ratSpO2(j) = NaN;
        end
        
    end
    
end


if PlotFigs
    X = brScores.Obstructive(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    Y = brScores.Central(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    
    
    rng('default')
    X = X + addJitter * 0.5 * randn(size(X));
    Y = Y + addJitter * 0.5 * randn(size(Y));
    ctr = mode([X,Y]);
    
    hh = hist3([X,Y], [20 20]);
    
    
    scatter( X,Y,'ok','MarkerFaceColor',[0.8 0.8 0.8],'MarkerEdgeColor',[0.8 0.8 0.8]);
    hold( 'on')
    dscatter( X,Y,'plottype','contour')
    colormap( parula);
    c = colorbar();
    
    caxis( [0 0.5])
    c.Ticks = 0:0.1:0.5;
    c.TickLabels = 0:10:50;
    xlim( [-20 20])
    ylim( [-20 20])
    xline( 0); yline(0);
    c.Label.String = 'Percentage of Small Breaths (%)';
    c.FontSize = 11;
    xlabel( 'Obstructive Scores')
    ylabel( 'Central Scores')
    text( 10,18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,-18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,18, sprintf('Definitely \nNot Obstructive'),'FontSize',12, 'HorizontalAlignment','Center')
    text( 10,-18, sprintf('Definitely \nObstructive'),'FontSize',12, 'HorizontalAlignment','Center')
end


% USe ratSpO2 to decide a new features
% 1. If ratio of asymm / symm < 1, then give FL=0/1 breaths a score of +2

% Periodic breathing using STFT + Soft thresholding
yy = breTable.FlowAvgMid3rdPercentNormal;
windowLength = 4;% Window length in seconds
R = windowLength; M = 2; K = 1; Nfft = 2*windowLength;
N = length(yy);
[AH, A, ~] = MakeTransforms('STFT',N,[R M K Nfft]);
As = A(yy);
n = 0:N-1;
figure(10), clf;

ax(1) = subplot(3,1,1);
plot(n, yy,'k');
box off
title('Flow')

ax(2) = subplot(3,1,2);
tt = R/M * ( (0:size(As, 2)) - 1 );    % tt : time axis for STDCT
imagesc(tt, [0 fsFlow/2], dB(As(1:Nfft/2+1, :)), max(dB(As(:))) + [-40 0])
axis xy
colormap(jet)
ylim([0 4]);
c = colorbar('location','North','Color',[1 1 1]);
c.Label.String = 'Magnitude dB';

csr_thresh = 0;
AHy = AH(soft(As,(max(real(As(:))))/3));
bin_csr = [0 Tgr(AHy) > csr_thresh];

% Discard all peaks detected that are less than 4 breaths
j = 2;
while j < length(bin_csr)
    % If breath before
    if bin_csr(j) && breTable.BrClass(j-1) >=2
        k = j;
        while bin_csr(k) && k < length(bin_csr)
            k = k + 1;
        end
        bin_csr(j:k) = 0;
        
    end
    
    if bin_csr(j)
        startCSR = j;
        k = startCSR;
        while bin_csr(k) && k < length(bin_csr)
            k = k + 1;
        end
        % If less than four breaths, skip ( = 0)
        % If any of the breaths are clipped, skip ( = 0)
        if abs(k - startCSR) < 4 || sum(breTable.Clipped(startCSR:k)) >= 1
            bin_csr(startCSR:k) = 0;
        else
            j = k+1;
        end
    else
        j = j + 1;
    end
    
    
    
end

% Do not add scores to flow limited breaths
bin_csr(breTable.BrClass >=2) = 0;

ax(3) = subplot(3,1,3)
plot(n, bin_csr, 'k')
ylim([-1 2])
linkaxes(ax, 'x')

%Identify breaths during bin_csr > 0 | Do this only if central is
%suspected
%if (nnz(ratSpO2 < 0.55) / nnz(ratSpO2 > 0.75)) < 0.6
%cond = breTable.BreathId(breTable.BrClass == 0 | breTable.BrClass == 1);
%brScores.Central(cond) = brScores.Central(cond) + 2;

fprintf('==Adding spectogram CSR analysis...\n')
brScores.Central(logical(bin_csr)) = brScores.Central(logical(bin_csr)) + 3;
brScores.Obstructive(logical(bin_csr)) = brScores.Obstructive(logical(bin_csr)) -1;
%end

if PlotFigs
    X = brScores.Obstructive(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    Y = brScores.Central(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    
    
    rng('default')
    X = X + addJitter * 0.5 * randn(size(X));
    Y = Y + addJitter * 0.5 * randn(size(Y));
    ctr = mode([X,Y]);
    
    hh = hist3([X,Y], [20 20]);
    
    scatter( X,Y,'ok','MarkerFaceColor',[0.8 0.8 0.8],'MarkerEdgeColor',[0.8 0.8 0.8]);
    hold( 'on')
    dscatter( X,Y,'plottype','contour')
    colormap( parula);
    c = colorbar();
    
    caxis( [0 0.5])
    c.Ticks = 0:0.1:0.5;
    c.TickLabels = 0:10:50;
    xlim( [-20 20])
    ylim( [-20 20])
    xline( 0); yline(0);
    c.Label.String = 'Percentage of Small Breaths (%)';
    c.FontSize = 11;
    xlabel( 'Obstructive Scores')
    ylabel( 'Central Scores')
    text( 10,18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,-18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,18, sprintf('Definitely \nNot Obstructive'),'FontSize',12, 'HorizontalAlignment','Center')
    text( 10,-18, sprintf('Definitely \nObstructive'),'FontSize',12, 'HorizontalAlignment','Center')
end

% Snore. presence on FL = obs. absence = do nothing
try
    fprintf('\n===Warning. Assuming Snore Channel = %d ===',snoreChan)
    fsSnore = sigHdr(snoreChan,:).samples_in_record;
    snorEnvelope = abs(hilbert(sigCell{snoreChan}));
    snoreThresh = 0.6;
    snoreCounter = 0;
    for j = 3:numBreaths-3
        % If snoring is present, score obs + 3 else do nothing
        if breTable.FlowAvgMid3rdPercentNormal(j) < plotSeverity && mad(zscore(snorEnvelope(round(breTable.ElapsedTime(j)/fsFlow*fsSnore):floor((breTable.ElapsedTime(j)/fsFlow + breTable.Ti(j))*fsSnore)))) > snoreThresh
            snoreCounter = snoreCounter + 1;
            brScores.Obstructive(j) = brScores.Obstructive(j) + 2;
            brScores.Central(j) = brScores.Central(j) - 1;
        else
            brScores.Central(j) = brScores.Central(j) + 2;
        end
        
    end
    fprintf('\nInspiratory Snoring present on %d small breaths',snoreCounter)
catch ME
    if contains(ME.identifier, 'UndefinedFunction')
        fprintf('\n==ERROR: Cannot find Snore channel.Skipping Snore Analysis...')
    end
end

if PlotFigs
    X = brScores.Obstructive(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    Y = brScores.Central(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    
    
    rng('default')
    X = X + addJitter * 0.5 * randn(size(X));
    Y = Y + addJitter * 0.5 * randn(size(Y));
    ctr = mode([X,Y]);
    
    hh = hist3([X,Y], [20 20]);
    
    
    scatter( X,Y,'ok','MarkerFaceColor',[0.8 0.8 0.8],'MarkerEdgeColor',[0.8 0.8 0.8]);
    hold( 'on')
    dscatter( X,Y,'plottype','contour')
    colormap( parula);
    c = colorbar();
    
    caxis( [0 0.5])
    c.Ticks = 0:0.1:0.5;
    c.TickLabels = 0:10:50;
    xlim( [-20 20])
    ylim( [-20 20])
    xline( 0); yline(0);
    c.Label.String = 'Percentage of Small Breaths (%)';
    c.FontSize = 11;
    xlabel( 'Obstructive Scores')
    ylabel( 'Central Scores')
    text( 10,18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,-18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,18, sprintf('Definitely \nNot Obstructive'),'FontSize',12, 'HorizontalAlignment','Center')
    text( 10,-18, sprintf('Definitely \nObstructive'),'FontSize',12, 'HorizontalAlignment','Center')
end

% In development - Belt/Effort
% 1. Central Apnea
% 2. Paradox Breathing

try
    fprintf('\n===Warning: Assuming Rib/Thor channel = %d ===',ribChan)
    fprintf('\n===Warning: Assuming Abdo channel = %d ===',abdChan)
catch ME
    if contains(ME.identifier, 'UndefinedFunction')
        fprintf('\n==ERROR: Cannot find one of the channel.')
    end
end

%1. Central Apnea breaths? no effort breaths?
%a. remove invalid signal?
abdSig = sigCell{abdChan};
ribSig = sigCell{ribChan};
fsRib = sigHdr(ribChan,:).samples_in_record;
fsAbd = sigHdr(abdChan,:).samples_in_record;

% Remove Invalid periods of Rib/ABD
if fsRib == fsSpO2  && fsAbd == fsSpO2
    ribSig(isnan(sig)) = NaN;
    abdSig(isnan(sig)) = NaN;
else
    fprintf("\n Cannot remove Invalid Rib/Abd...")
end

[aA, aB] = butter(2, 1/(fsAbd/2));

% Signal to noise ratio estimate for Rib/Abd


%1b. effort is less than 10% of the average mad
breTable.Effort = zeros(height(breTable),1);
paradoxCount = 0;
inphaseCount = 0;
fprintf('\n===Warning. Inspiratory Positive assumed. Check Direction')
for j = 3:numBreaths-3
    % Scan through each breath and see if the effort is minimal
    abdSeg = (abdSig(floor(breTable.ElapsedTime(j)/fsFlow*fsAbd):ceil((breTable.ElapsedTime(j)/fsFlow + breTable.Ti(j))*fsAbd)));
    ribSeg = (ribSig(floor(breTable.ElapsedTime(j)/fsFlow*fsRib):ceil((breTable.ElapsedTime(j)/fsFlow + breTable.Ti(j))*fsRib)));
    Y = hilbert(ribSeg - mean(ribSeg));
    X = hilbert(abdSeg - mean(abdSeg));
    py = (unwrap(angle(Y)));
    px = (unwrap(angle(X)));
    [~, peakY] = max(-1*ribSeg);
    [~, peakX] = max(-1*abdSeg);
    phdiff = abs(py(peakY) - px(peakX));
    breTable.Effort(j) = phdiff;
    
    %     if (phdiff > 0.8 && phdiff < 3.7) || ((phdiff-2*pi) > 0.8 && (phdiff-2*pi) < 3.7)
    %         brScores.Obstructive(j) = brScores.Obstructive(j) + 1;
    %         brScores.Central(j) = brScores.Central(j) - 1;
    %         if breTable.FlowAvgMid3rdPercentNormal(j) < plotSeverity
    %             paradoxCount = paradoxCount + 1;
    %         end
    %     elseif phdiff < 0.4 || (phdiff-2*pi) < 0.4
    %         brScores.Central(j) = brScores.Central(j) + 2;
    %         inphaseCount = inphaseCount + 1;
    %     end
end

% Now that breaths' phase has been calculated. Check difference in phase
% from small to big breaths
outphaseCount = 0;
inphaseCount = 0;
j = 3;
while j < numBreaths - 3
    if breTable.FlowAvgMid3rdPercentNormal(j) < plotSeverity
        % Breath is small
        % Find end of this event
        k = j+1;
        keepGoing = 1;
        while keepGoing && k < numBreaths - 3
            if breTable.FlowAvgMid3rdPercentNormal(k) < plotSeverity
                % this breath is also small, keep going
                k = k + 1;
            else
                keepGoing = 0;
            end
        end
        
        if ~(((breTable.Effort(j) > 0.8 && breTable.Effort(j) < 3.7) || ...
                ((breTable.Effort(j)-2*pi) > 0.8 && (breTable.Effort(j)-2*pi) < 3.7)) ...
                && ...
                ((breTable.Effort(k) > 0.8 && breTable.Effort(k) < 3.7) || ...
                ((breTable.Effort(k)-2*pi) > 0.8 && (breTable.Effort(k)-2*pi) < 3.7))) ...
                || ...
                ~( (breTable.Effort(j) < 0.4 || (breTable.Effort(j)-2*pi) < 0.4) ...
                && ...
                (breTable.Effort(k) < 0.4 || (breTable.Effort(k)-2*pi) < 0.4))
            
            
            % If j and k have different phase for effort,
            brScores.Obstructive(j:k-1) = brScores.Obstructive(j:k-1) + 1;
            brScores.Central(j:k-1) = brScores.Central(j:k-1) - 1;
            outphaseCount = outphaseCount + k-j;
        else
            brScores.Central(j:k-1) = brScores.Central(j:k-1) + 2;
            brScores.Obstructive(j:k-1) = brScores.Obstructive(j:k-1) - 1;
            inphaseCount = inphaseCount + k-j;
        end
        j = k+1;
    end
    j = j + 1;
end


fprintf('\nParadox observed on %d of small breaths',outphaseCount)
fprintf('\nBreaths with almost in-phase effort: %d',inphaseCount)

if PlotFigs
    X = brScores.Obstructive(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    Y = brScores.Central(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    
    
    rng('default')
    X = X + addJitter * 0.5 * randn(size(X));
    Y = Y + addJitter * 0.5 * randn(size(Y));
    ctr = mode([X,Y]);
    
    hh = hist3([X,Y], [20 20]);
    
    
    scatter( X,Y,'ok','MarkerFaceColor',[0.8 0.8 0.8],'MarkerEdgeColor',[0.8 0.8 0.8]);
    hold( 'on')
    dscatter( X,Y,'plottype','contour')
    colormap( parula);
    c = colorbar();
    
    caxis( [0 0.5])
    c.Ticks = 0:0.1:0.5;
    c.TickLabels = 0:10:50;
    xlim( [-20 20])
    ylim( [-20 20])
    xline( 0); yline(0);
    c.Label.String = 'Percentage of Small Breaths (%)';
    c.FontSize = 11;
    xlabel( 'Obstructive Scores')
    ylabel( 'Central Scores')
    text( 10,18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,-18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,18, sprintf('Definitely \nNot Obstructive'),'FontSize',12, 'HorizontalAlignment','Center')
    text( 10,-18, sprintf('Definitely \nObstructive'),'FontSize',12, 'HorizontalAlignment','Center')
end

% Merge the non apnea scores first
breTable.Obstructive = brScores.Obstructive;
breTable.Central = brScores.Central;

apneaTable.Clipped = zeros(height(apneaTable),1);
apneaTable.Effort = zeros(height(apneaTable),1);
apneaTable.SatRatio = zeros(height(apneaTable),1);
apneaTable.Obstructive = zeros(height(apneaTable),1);
apneaTable.Central = zeros(height(apneaTable),1);

% In development
% Mixed Apnea / Apneas
for j = 1:height(apneaTable)
    
    % Get a baseline effort oscillations
    % Get max - min of two previous breaths
    evtStart = find(breTable.ElapsedTime < apneaTable.ElapsedTime(j), 1,'last');
    
    preAbd = mean([max((abdSig(floor(breTable.ElapsedTime(evtStart-2)/fsFlow*fsAbd):ceil((breTable.ElapsedTime(evtStart-2)/fsFlow + breTable.Ttot(evtStart-2))*fsAbd)))) - ...
        min((abdSig(floor(breTable.ElapsedTime(evtStart-2)/fsFlow*fsAbd):ceil((breTable.ElapsedTime(evtStart-2)/fsFlow + breTable.Ttot(evtStart-2))*fsAbd)))) ...
        max((abdSig(floor(breTable.ElapsedTime(evtStart-1)/fsFlow*fsAbd):ceil((breTable.ElapsedTime(evtStart-1)/fsFlow + breTable.Ttot(evtStart - 1))*fsAbd)))) - ...
        min((abdSig(floor(breTable.ElapsedTime(evtStart - 1)/fsFlow*fsAbd):ceil((breTable.ElapsedTime(evtStart-1)/fsFlow + breTable.Ttot(evtStart-1))*fsAbd))))]);
    
    preRib = mean([max((ribSig(floor(breTable.ElapsedTime(evtStart-2)/fsFlow*fsRib):ceil((breTable.ElapsedTime(evtStart-2)/fsFlow + breTable.Ttot(evtStart-2))*fsRib)))) - ...
        min((ribSig(floor(breTable.ElapsedTime(evtStart-2)/fsFlow*fsRib):ceil((breTable.ElapsedTime(evtStart-2)/fsFlow + breTable.Ttot(evtStart-2))*fsRib)))) ...
        max((ribSig(floor(breTable.ElapsedTime(evtStart-1)/fsFlow*fsRib):ceil((breTable.ElapsedTime(evtStart-1)/fsFlow + breTable.Ttot(evtStart-1))*fsRib)))) - ...
        min((ribSig(floor(breTable.ElapsedTime(evtStart-1)/fsFlow*fsRib):ceil((breTable.ElapsedTime(evtStart-1)/fsFlow + breTable.Ttot(evtStart-1))*fsRib))))]);
    
    % Get current effort
    
    abdSeg = (abdSig(floor(apneaTable.ElapsedTime(j)/fsFlow*fsAbd):ceil((apneaTable.ElapsedTime(j)/fsFlow + apneaTable.Ttot(j))*fsAbd)));
    ribSeg = (ribSig(floor(apneaTable.ElapsedTime(j)/fsFlow*fsRib):ceil((apneaTable.ElapsedTime(j)/fsFlow + apneaTable.Ttot(j))*fsRib)));
    
    if (max(abdSeg) - min(abdSeg) > 0.3*preAbd) || (max(ribSeg) - min(ribSeg) > 0.3*preRib)
        % Effort maybe reduced but is present
        apneaTable.Obstructive(j) = 15;
        apneaTable.Central(j) = -10;
    else
        apneaTable.Obstructive(j)=  -10;
        apneaTable.Central(j) = 15;
    end
    
    %         for k = 1:num_breaths_imputed-1
    %             % Add a temp row between for the imputed breath
    % %             tempTbl = breTable(j,:);
    % %             tempTbl.ElapsedTime = floor((k-1)*dur_breath_imputed*fsFlow + breTable.ElapsedTime(j));
    % %             tempTbl.Ti = dur_breath_imputed/2;
    % %             tempTbl.Ttot = dur_breath_imputed;
    % %             tempTbl.BreathId = j + k-1;
    % %
    % %             tempBrScores = brScores(j,:);
    % %             tempBrScores.BreathID = j + k-1;
    % %
    % %             breTable = [breTable(1:j+k-2,:); tempTbl; breTable(j+ k-1:end,:)];
    % %             brScores = [brScores(1:j+k-2,:); tempBrScores; brScores(j+ k-1:end,:)];
    % %             breTable.BreathId(:,:) = 1:height(breTable);
    % %             brScores.BreathID(:,:) = 1:height(brScores);
    %
    %             % For each imputed breath
    %
    %
    %         end
    
    
end

breTable = [breTable; apneaTable];

if PlotFigs
    X = breTable.Obstructive(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    Y = breTable.Central(breTable.FlowAvgMid3rdPercentNormal <= plotSeverity);
    
    
    rng('default')
    X = X + addJitter * 0.5 * randn(size(X));
    Y = Y + addJitter * 0.5 * randn(size(Y));
    ctr = mode([X,Y]);
    
    hh = hist3([X,Y], [20 20]);
    
    
    scatter( X,Y,'ok','MarkerFaceColor',[0.8 0.8 0.8],'MarkerEdgeColor',[0.8 0.8 0.8]);
    hold( 'on')
    dscatter( X,Y,'plottype','contour')
    colormap( parula);
    c = colorbar();
    
    caxis( [0 0.5])
    c.Ticks = 0:0.1:0.5;
    c.TickLabels = 0:10:50;
    xlim( [-20 20])
    ylim( [-20 20])
    xline( 0); yline(0);
    c.Label.String = 'Percentage of Small Breaths (%)';
    c.FontSize = 11;
    xlabel( 'Obstructive Scores')
    ylabel( 'Central Scores')
    text( 10,18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,-18, 'Ambiguous ','FontSize',12, 'HorizontalAlignment','Center')
    text( -10,18, sprintf('Definitely \nNot Obstructive'),'FontSize',12, 'HorizontalAlignment','Center')
    text( 10,-18, sprintf('Definitely \nObstructive'),'FontSize',12, 'HorizontalAlignment','Center')
end

% Write the breTable to new excel file.
% Convert scores to probabilities
load B_v7_full.mat
breTable = sortrows(breTable, 'ElapsedTime');
est_p = mnrval(B, [breTable.Obstructive, breTable.Central],'model','ordinal');
breTable.pobs = est_p(:,2);

figure(1), clf, hold on;
hist_est = est_p(breTable.FlowAvgMid3rdPercentNormal < 0.85, 2);
h = histcounts(hist_est, 20,'Normalization','Probability')
for i = 2:numel(h)
    bar( i, h(i), 'facecolor',cmap(i,:),'edgecolor',[1 1 1])
end
xl2 = xline(10); xl2.LineWidth = 2; xl2.Color = [0.7 0.7 0.7]; xl2.LineStyle = '--';
xl = xline(median(est_p(breTable.FlowAvgMid3rdPercentNormal < 0.85,2)) * 20); xl.Color = [0.4 0.4 0.4];
xlim([0 21]); ylim([0 0.5])
set(gca, 'XTick',0:5:20,'XTickLabel',0:0.25:1,'YTick',0:0.1:0.5,'YTickLabel',0:10:50)

xlabel('Overnight Probability of Obstruction')
ylabel('Percentage of Small Breaths (%)')
colormap(cmap)
text( 5,0.45,'<---- Likely Central','HorizontalAlignment','Center')
text( 15,0.45,'Likely Obstructive ---->','HorizontalAlignment','Center')

c = colorbar;
c.Label.String = 'Probability of Obstruction';
writetable(breTable, [filename,'_obs_cen.xlsx'])
fprintf('\nNew Breath Table written to file')


if debugPlots
    % Create empty channels
    obsChannel = zeros(size(flowSig));
    centChannel = obsChannel;
    satRatioChannel = zeros(size(sigCell{SpO2Channel}));
    ribValChannel = zeros(size(sigCell{ribChan}));
    for j = 3:numBreaths-3
        obsChannel(breTable(j,:).ElapsedTime: breTable(j,:).ElapsedTime + floor(breTable(j,:).Ttot*fsFlow))= brScores(j,:).Obstructive;
        centChannel(breTable(j,:).ElapsedTime: breTable(j,:).ElapsedTime + floor(breTable(j,:).Ttot*fsFlow))= brScores(j,:).Central;
        satRatioChannel(floor(breTable(j,:).ElapsedTime/fsFlow*fsSpO2): floor((breTable(j,:).ElapsedTime + floor(breTable(j,:).Ttot))/fsFlow*fsSpO2)) = breTable(j,:).SatRatio;
        ribValChannel(floor(breTable(j,:).ElapsedTime/fsFlow*fsRib): floor((breTable(j,:).ElapsedTime + floor(breTable(j,:).Ttot))/fsFlow*fsRib)) = breTable(j,:).Effort;
    end
    
    
    if PlotFigs
        figure(4), clf;
        plot([0:length(satRatioChannel)-1]/fsSpO2, satRatioChannel + 100)
        hold on
        plot([0:length(flowSig)-1]/fsFlow, flowSig/1000+100)
        plot([0:length(sig)-1]/fsSpO2, sig,'k');
        plot(dips.locTrough/fsSpO2, sig(dips.locTrough), 'or')
        plot(dips.leftLoc/fsSpO2, sig(dips.leftLoc),'xr')
        plot(dips.rightLoc/fsSpO2, sig(dips.rightLoc),'xg')
        
        figure(5), clf;
        eff = ribValChannel;
        eff(eff < 1  | eff > 5) = NaN;
        N = length(eff);
        n = 0:N-1;
        indx_eff = ~isnan(eff);
        plot(n(indx_eff)/fsRib, eff(indx_eff)*500, 'ok')
        hold on
        plot([0:length(sigCell{ribChan})-1]/fsRib, sigCell{ribChan}+105)
        plot([0:length(sigCell{abdChan})-1]/fsAbd, sigCell{abdChan}+108)
        plot([0:length(flowSig)-1]/fsFlow, flowSig/1000+100)
        title('Effort')
    end
end


if createEDF
    head = hdr;
    chans = size(sigCell,2);
    newData = sigCell;
    % Obs. channel
    newData{chans + 1} = obsChannel;
    newSignalHeader = sigHdr;
    newSignalHeader(:,chans+1) = sigHdr(:,flowChan);
    newSignalHeader(:,chans+1).signal_labels = 'OBS';
    newSignalHeader(:,chans+1).transducer_type = 'UNKNOWN';
    newSignalHeader(:,chans+1).physical_dimension = 'AU';
    
    % Cent. Channel
    newData{chans + 2} = centChannel;
    newSignalHeader(:,chans+2) = sigHdr(:,flowChan);
    newSignalHeader(:,chans+2).signal_labels = 'CENT';
    newSignalHeader(:,chans+2).transducer_type = 'UNKNOWN';
    newSignalHeader(:,chans+2).physical_dimension = 'AU';
    
    % SpO2 Ratio channel
    newData{chans + 3} = satRatioChannel;
    newSignalHeader(:,chans+3) = sigHdr(:,SpO2Channel);
    newSignalHeader(:,chans+3).signal_labels = 'SATRATIO';
    newSignalHeader(:,chans+3).transducer_type = 'UNKNOWN';
    newSignalHeader(:,chans+3).physical_dimension = 'AU';
    
    newData = newData';
    head.num_signals = length(newData);
    head.num_header_bytes = head.num_signals*256 + 256;
    
    blockEdfWrite([filename,'-obs-cent.edf'],head, newSignalHeader, newData);
    
    fprintf('\nNew EDF file written with Obs. and Cent. channels')
    
end

if createBRETable
    if ispc
        py = 'python';
    else
        py = 'python3';
    end
    
    command = [py,' breath_table_csv_to_json.py ',filename(1:end-4)];
    
    try
        system(command)
    catch
        fprintf('\n===Error adding scores to Breath Table...')
    end
end


if Stats
    Y = [
        brScores.Obstructive(breTable.Evt == 1);
        brScores.Obstructive(breTable.Evt == 2);
        brScores.Obstructive(breTable.Evt == 3);
        brScores.Obstructive(breTable.Evt == 4);
        brScores.Obstructive(breTable.Evt == 5);
        brScores.Obstructive(breTable.Evt == 6);
        brScores.Obstructive(breTable.Evt == 7);
        ];
    
    X = [
        ones(size(brScores.Obstructive(breTable.Evt == 1)));
        2*ones(size(brScores.Obstructive(breTable.Evt == 2)));
        3*ones(size(brScores.Obstructive(breTable.Evt == 3)));
        4*ones(size(brScores.Obstructive(breTable.Evt == 4)));
        5*ones(size(brScores.Obstructive(breTable.Evt == 5)));
        6*ones(size(brScores.Obstructive(breTable.Evt == 6)));
        7*ones(size(brScores.Obstructive(breTable.Evt == 7)));
        ];
    
    Z = [
        brScores.Central(breTable.Evt == 1);
        brScores.Central(breTable.Evt == 2);
        brScores.Central(breTable.Evt == 3);
        brScores.Central(breTable.Evt == 4);
        brScores.Central(breTable.Evt == 5);
        brScores.Central(breTable.Evt == 6);
        brScores.Central(breTable.Evt == 7);
        ];
    
    W = [
        ones(size(brScores.Central(breTable.Evt == 1)));
        2*ones(size(brScores.Central(breTable.Evt == 2)));
        3*ones(size(brScores.Central(breTable.Evt == 3)));
        4*ones(size(brScores.Central(breTable.Evt == 4)));
        5*ones(size(brScores.Central(breTable.Evt == 5)));
        6*ones(size(brScores.Central(breTable.Evt == 6)));
        7*ones(size(brScores.Central(breTable.Evt == 7)));
        ];
end

return
w = warning ('on','all');
fprintf('\n===================================\n')
end
