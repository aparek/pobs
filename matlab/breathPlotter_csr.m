function [y, curResults] = breathPlotter_csr(filename)
% function [Y, Results] = breathPlotter()
%
% This function will plot the breath curve individualized
%
% Ankit Parekh
% Last Edit: 7/18/19
% Version: 2

figure(1), clf;
figure(2), clf;
curResults = [];
breFilename = [filename, '.BRE'];
fid = fopen(breFilename);
raw = fread(fid, inf);
jsonStr = char(raw');
fclose(fid);

try
    rawData = jsondecode(jsonStr);
    
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
        
        
    elseif strcmp(filename(end-3:end),'.EVT')
        % If it is an event table
        T = [];
        T = struct2table(rawData.Data{1});
        for j = 2:length(rawData.Data)
            T_temp = struct2table(rawData.Data{j});
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
        file_to_write = ['C:\Users\pareka02\Documents\Original Data\eventFiles\',filename(end-13:end-4),'-events.xlsx'];
        
        
        % Cleanup the table
        % 1. Change classification
        % 2. Change Start time units
        
        % (Arousal -> Type = 10, Respiratory -> Type = 1)
        
        type = char(zeros(length(T.Type),20));
        class = char(zeros(length(T.Type),20));
        
        indx = find(T.Type == 9);
        type(indx,1:7) = repmat(char('Invalid'), length(indx), 1);
        class(indx, 1:7) = repmat(char('Invalid'), length(indx), 1);
        
        indx = find(T.Type == 10);
        type(indx,1:7) = repmat(char('Arousal'), length(indx), 1);
        class(indx, 1:12) = repmat(char('ASDA Arousal'), length(indx), 1);
        
        indx = find(T.Type == 1);
        type(indx,1:11) = repmat(char('Respiratory'), length(indx), 1);
        
        indx = find(T.Type == 6);
        type(indx,1:12) = repmat(char('Leg Movement'), length(indx), 1);
        class(indx, 1:12) = repmat(char('Leg Movement'), length(indx), 1);
        
        
        indx = find(T.Classification == 1 & T.Type == 1);
        class(indx, 1:10) = repmat(char('Obs. Apnea'), length(indx), 1);
        
        indx = find(T.Classification == 4 & T.Type == 1);
        class(indx, 1:14) = repmat(char('Cnt. Flow <50%'), length(indx), 1);
        
        
        indx = find(T.Classification == 1 & T.Type == 10);
        class(indx, 1:12) = repmat(char('ASDA Arousal'), length(indx), 1);
        
        indx = find(T.Classification == 2);
        class(indx, 1:10) = repmat(char('Cnt. Appea'), length(indx), 1);
        
        indx = find(T.Classification == 3);
        class(indx, 1:14) = repmat(char('Obs. Flow <50%'), length(indx), 1);
        
        indx = find(T.Classification == 6 | T.Classification == 8);
        class(indx, 1:14) = repmat(char('Obs. Flow <70%'), length(indx), 1);
        
        indx = find(T.Classification == 5);
        class(indx, 1:14) = repmat(char('Obs. Flow <70%'), length(indx), 1);
        
        indx = find(T.Classification == 7);
        class(indx, 1:14) = repmat(char('Cnt. Flow <70%'), length(indx), 1);
        
        indx = find(T.Classification == 9);
        class(indx, 1:12) = repmat(char('Sustained FL'), length(indx), 1);
        
        T.Classification = class;
        T.Type = type;
        
        studyStartTime = datestr(rawData.Header.study_time, 'HH:MM:SS');
        T.StartTime = timeofday(datetime(studyStartTime) + seconds(T.StartTime));
        
        % Re arrange Columns for Phenotyping analyses
        if phenotyping
            
            T2 = table(T.EventId, T.StartTime, T.Duration, T.Channel,...
                T.Type, T.Classification);
            T2.Properties.VariableNames{1} = T.Properties.VariableNames{5};
            T2.Properties.VariableNames{2} = T.Properties.VariableNames{18};
            T2.Properties.VariableNames{3} = T.Properties.VariableNames{4};
            T2.Properties.VariableNames{4} = T.Properties.VariableNames{2};
            T2.Properties.VariableNames{5} = T.Properties.VariableNames{19};
            T2.Properties.VariableNames{6} = T.Properties.VariableNames{3};
        else
            T2 = T;
        end
        
    end
    T2 = T; % Save the old table
    % T.Ttot > 20 was used earlier. Changed 7/26/2019
    T.FlowAvgMid3rdPercentNormal(T.Ttot > 35,:) = NaN;
    
    % In case apneas are skipped, impute them
    % Ignore the first 10% of the study and the last 10%
    fs = T.Frequency(1);
    
    % Do the folloowing if the calibration is not nyu
    %         cnt = 0;
    %         for j = round(0.2*size(T,1)):round(0.8*size(T,1))
    %             T_temp = [];
    %             % Check if there is an apnea missed
    %             if ((T.ElapsedTime(j+1) - (T.ElapsedTime(j) + T.Ttot(j)))/fs ) > 10
    %                 % Check to see if we didn't discard it earlier
    %                 if ~isnan(T.FlowAvgMid3rdPercentNormal(j))
    %                     % This is an apnea
    %                     cnt = cnt + 1;
    %                     T_temp = [T_temp; array2table(999*ones(1,size(T,2)),'variablenames',T.Properties.VariableNames)];
    %                     T_temp.Ttot = 20;
    %                     T = [T; T_temp];
    %                 end
    %             end
    %         end
    
    %        fprintf('Subject %d had %d apneas missed by Minerva added back.\n',i,cnt)
    
    % Add apnea breaths
    
    % First discard breaths that may be identified
    % during nasal cannula misplacement, removal etc.
    
    
    cnt = 0;
    for j = 20:size(T,1)
        if T.Ttot(j) > 10 && ~isnan(T.FlowAvgMid3rdPercentNormal(j))
            T_temp = [];
            % This is an apnea breath
            % Extract previous 20 breaths and exclude T.Ttot > 4
            resprate = mean(T.RespRate(T.Ttot(j-19:j) < 4));
            
            % Sometimes during the end of breath table, NAN
            % might occur in resprate
            if isnan(resprate)
                resprate = 20;
            end
            
            durbreaths = floor(60/resprate);
            numbreaths = floor(T.Ttot(j)/durbreaths);
            % Add these many breaths (int)
            T_temp = [T_temp; array2table(999*ones(numbreaths,size(T,2)),'variablenames',T.Properties.VariableNames)];
            T_temp.BreathId = size(T,1) + (1:numbreaths)';
            T_temp.Ttot = ones(numbreaths,1) * durbreaths;
            T_temp.FlowAvgMid3rdPercentNormal = zeros(numbreaths,1);
            T = [T; T_temp];
            cnt = cnt + numbreaths;
        end
    end
    
    fprintf('%d Breaths added.\n',cnt)
    fprintf('==============================\n')
    
    % compute the cdf for breath table
    
    % Perform sanity checks for the Breaths
    % 1. Exclude breaths where flow %nl is negative
    % 2. Exclude Breaths that have Ttot > 3
    % 3. Exclude Flow > 400 or something??
    %T.FlowAvgPercentNormal(T.FlowAvgPercentNormal > 1) = T.FlowAvgPercentNormal(T.FlowAvgPercentNormal > 1)*3;
    T.FlowAvgMid3rdPercentNormal(T.FlowAvgMid3rdPercentNormal < 0) = NaN;
    %T.FlowAvgPercentNormal(T.FlowAvgPercentNormal > 1.2) = NaN;
    %T.FlowAvgPercentNormal(T.Ttot > 5) = NaN;
    
    y = T.FlowAvgMid3rdPercentNormal(T.FlowAvgMid3rdPercentNormal < 2 & T.BrClass == 1) * 100;
    y2 = T.FlowAvgMid3rdPercentNormal(T.FlowAvgMid3rdPercentNormal < 2) * 100;
    set(0,'defaultaxesfontsize',12);
    
    
    %         subplot(2,1,1)
    %         nbins = 0:5:200;
    %         [hist_norm,~] = histcounts(y,nbins);
    %         mm = hist_norm./sum(hist_norm)*100;
    %         mm = [0;mm(:)];
    %         plot(nbins,mm,'k','linewidth',1)
    %         hold on;
    %         set(gca,'XTick',[0:20:120, 150,200],'XGrid','on')
    %         xline(80); xline(120);
    %         box off
    %         grid off
    %         ylabel(sprintf('Relative breaths\n(%% of total breaths)'))
    %         xlabel('Amplitude (%)')
    %         xtickangle(45)
    %
    
    figure(1), clf;
    newbins = 0:2.5:200;
    nbins = 0:5:200;
    [hist1,~] = histcounts(y2,nbins);
    [hist2,~] = histcounts(y,nbins);
    hist2 = hist2 ./ sum(hist1) * 100;
    hist1 = hist1 ./ sum(hist1) * 100;
    b = bar(newbins(2:2:end),hist1);
    b.FaceColor = 'b';
    b.FaceAlpha = 0.15;
    b.EdgeColor = 'k';
    b.LineWidth = 1;
    
    hold on
    b2 = bar(newbins(2:2:end),hist2);
    b2.FaceColor = 'k';
    b2.FaceAlpha = 0.25;
    b2.EdgeColor = 'k';
    b2.LineWidth = 1;
    xlabel('Amplitude (%)')
    set(gca, 'XTick', [0 20 50 70 130 150 200])
    ylim([0 10])
    ylabel(sprintf('Relative breaths\n(%% of total breaths)'))
    grid on
    title(sprintf('%s\nBreaths = %d',filename, height(T)),'interpreter','none')  
    
%     figure(1)
%     nbins = 0:5:200;
%     hist = histogram(y, nbins);
%     hold on
%     hist2 = histogram(y2,nbins);
%     hist.EdgeColor = 'k';
%     hist.LineWidth = 1;
%     hist.FaceColor = [1 1 1];
%     hist.Normalization = 'probability';
%     hist2.Normalization = 'probability';
%     %hist.DisplayStyle = 'stairs';
%     hold on;
%     set(gca,'XTick',[0:20:200])
%     box off
%     grid off
%     ylabel(sprintf('Relative breaths\n(%% of total breaths)'))
%     xlabel('Amplitude (%)')
%     xtickangle(45)
%     xlim([0 200])
%     ytix = get(gca, 'YTick');
%     xline(70); xline(130);
%     %set(gca,'YTickLabels',ytix*100)
%     %shading histogram
%     
    shadingNew = 0;
    
    if shadingNew
        [hist_counts,~] = histcounts(y,nbins);
        histCounts = hist_counts'/sum(hist_counts) * 100;
        % 0-20
        for k = 1:20/5
            fill([5*(k-1) 5*k 5*k 5*(k-1)],...
                [0 0 histCounts(k) histCounts(k) ],...
                'r','facealpha',0.5,'Edgecolor',[1 1 1]*0.75,'LineStyle','none')
        end
        
        % 60-80
        for k = 55/5:70/5
            fill([5*(k-1) 5*k 5*k 5*(k-1)],...
                [0 0 histCounts(k) histCounts(k) ],...
                'b','facealpha',0.5,'Edgecolor',[1 1 1]*0.75,'LineStyle','none')
        end
        
        % 60-80
        for k = 75/5:130/5
            fill([5*(k-1) 5*k 5*k 5*(k-1)],...
                [0 0 histCounts(k) histCounts(k) ],...
                'g','facealpha',0.5,'Edgecolor',[1 1 1]*0.75,'LineStyle','none')
        end
        
        % 60-80
        for k = 135/5:200/5
            fill([5*(k-1) 5*k 5*k 5*(k-1)],...
                [0 0 histCounts(k) histCounts(k) ],...
                'y','facealpha',0.5,'Edgecolor',[1 1 1]*0.75,'LineStyle','none')
        end
    end
    
    shading = 0;
    
    if shading
        % 0-20
        bound = [ mm(1:25/5); zeros(size(mm(1:25/5),1),1)]
        x_bound = nbins(1:25/5);
        x_bound = [x_bound, fliplr(x_bound)];
        fill(x_bound, bound, 'r','facealpha',0.2);
        
        %60-80
        bound = [ mm(65/5:85/5); zeros(size(mm(65/5:85/5),1),1)]
        x_bound = nbins(65/5:85/5);
        x_bound = [x_bound, fliplr(x_bound)];
        fill(x_bound, bound, 'b','facealpha',0.2);
        
        %80-120
        bound = [ mm(85/5:125/5); zeros(size(mm(85/5:125/5),1),1)]
        x_bound = nbins(85/5:125/5);
        x_bound = [x_bound, fliplr(x_bound)];
        fill(x_bound, bound, 'g','facealpha',0.2);
        
        %120 and above
        bound = [ mm(125/5:205/5); zeros(size(mm(125/5:205/5),1),1)]
        x_bound = nbins(125/5:205/5);
        x_bound = [x_bound, fliplr(x_bound)];
        fill(x_bound, bound, 'y','facealpha',0.2);
        
    end
    
    figure(2)
    [h,stats] = cdfplot(y);
    
    h.LineWidth = 2;
    
    h.Color = 'k';
    xlim([0 200])
    set(gca, 'XTick',0:20:200,'XTickLabel',0:20:200);
    hold on;
    box off
    grid off
    xlabel('Amplitude (%)')
    ylabel('Cumulative Breaths (%)')
    set(gca,'YTick',0:0.2:1, 'YTickLabel',0:20:100)
    title('')
    xtickangle(45)
    [x_cdf,y_cdf] = ecdf(y);
    xline(70);
    xline(130);
    
    try
        load('normal95.mat'); load('normalMean.mat');
        X = linspace(0,1,40);
        figure(2)
        patch([ySEM'+ meanY, fliplr(meanY-(ySEM'))],[X, fliplr(X)],1,...
            'facecolor','black',...
            'edgecolor','none',...
            'facealpha',0.5)
    catch
        fprintf('Could not load and print shaded normal region\n')
    end
    
    % mark the 50% flow value
    [~,idx] = min(abs(y_cdf - 50));
    val50 = x_cdf(idx);
    %plot(y_cdf(idx), val50,'o-r')
    
    [~,idx] = min(abs(y_cdf - 20));
    val20 = x_cdf(idx);
    %plot(y_cdf(idx), val20,'o-k')
    
    [~,idx] = min(abs(y_cdf - 70));
    val70 = x_cdf(idx);
    %plot(y_cdf(idx), val75,'o-k')
    
    [~,idx] = min(abs(y_cdf - 100));
    val100 = x_cdf(idx);
    %plot(y_cdf(idx), val100,'o-k')
    
    [~,idx] = min(abs(y_cdf - 130));
    val130 = x_cdf(idx);
    %plot(y_cdf(idx), val130,'o-k')
    
    % 0 val
    %plot(y_cdf(1),x_cdf(2),'o-k')
    
    % Shaded areas
    shading = 0;
    
    if shading
        
        % More than 120
        
        %val120 is the value where the curve crosses 120
        [~,idx] = min(abs(y_cdf-120));
        val120 = x_cdf(idx);
        bound = [x_cdf(y_cdf>=130)' val130*ones(size(x_cdf(y_cdf>=130),1),1)'];
        x_bound = linspace(130,200,size(x_cdf(y_cdf>=130),1));
        x_bound = [y_cdf(y_cdf >= 130)' fliplr(y_cdf(y_cdf >= 130)')];
        fill(x_bound, bound, 'y','facealpha',0.5)
        polyarea(x_bound, bound)*100/size(T,1)
        
        
        % 80-120
        [~,idx] = min(abs(y_cdf-80));
        val80 = x_cdf(idx);
        bound = [x_cdf(y_cdf<=130 & y_cdf>=70)' val70*ones(size(x_cdf(y_cdf<=130 & y_cdf>=70),1),1)'];
        x_bound = linspace(0,20,size(x_cdf(y_cdf<=130 & y_cdf>=70),1));
        x_bound = [y_cdf(y_cdf<=130 & y_cdf>=70)' fliplr(y_cdf(y_cdf<=130 & y_cdf>=70)')];
        fill(x_bound, bound, 'g','facealpha',0.5)
        polyarea(x_bound, bound)*100/size(T,1)
        
        % More than 0 but < 20
        bound = [x_cdf(y_cdf<=20)' 0*ones(size(x_cdf(y_cdf<=20),1),1)'];
        x_bound = linspace(0,20,size(x_cdf(y_cdf<=20),1));
        x_bound = [y_cdf(y_cdf <= 20)' fliplr(y_cdf(y_cdf <=20)')];
        fill(x_bound, bound, 'r','facealpha',0.5)
        polyarea(x_bound, bound)*100/size(T,1)
        
        
        
    end
    
    VariableNames = {'Val0','Val20','Val50','Val70','Val100','Val130','Val200'};
    curResults = table(0, val20, val50,val70,val100,val130,1,'VariableNames',VariableNames);
    
    % Add areas in figure 1
    figure(1)
    text(10,9,sprintf('%.0f%%',ceil(abs(val20) * 100)),'FontSize',12,'HorizontalAlignment','Center','color','r')
    text(60,9,sprintf('%.0f%%',abs(val70-val50) * 100),'FontSize',12,'HorizontalAlignment','Center','color','r')
    text(100,9,sprintf('%.0f%%',abs(val130-val70) * 100),'FontSize',12,'HorizontalAlignment','Center','color','r')
    text(165,9,sprintf('%.0f%%',abs(1-val130) * 100),'FontSize',12,'HorizontalAlignment','Center','color','r')
    
    %         hypnogram = 0;
    %
    %         if hypnogram
    %             hypFile = [filename(1:end-4), '_hyp.txt'];
    %             hypno = load(hypFile, 'r');
    %             T_epoch = hypno(ceil(T.ElapsedTime(T.ElapsedTime > 999,:)/(fs*30)),2);
    %             T.Stage = [T_epoch; NaN*ones(abs(size(T_epoch,1)-size(T,1)),1)];
    %         end
    %
    %         figure(3), clf;
    %
    %         % Plot for non-REM vs. REM
    %         y_NREM = T.FlowAvgPercentNormal(T.Stage == 1 | T.Stage == 2 | T.Stage == 3) * 100;
    %         y_REM = T.FlowAvgPercentNormal(T.Stage == 5) * 100;
    %         y_NREM = y_NREM(y_NREM < 120);
    %         y_REM = y_REM(y_REM < 120);
    %
    %         cdfplot(y_NREM); hold on; cdfplot(y_REM);
    %         grid on
    %         legend('Non-REM','REM')
    %         box off
    %pause
    
catch
    fprintf('\n File: %s has problems!',filename);
end

