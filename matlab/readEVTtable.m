function T = readEVTtable(evtFilename)
fid = fopen(evtFilename);
raw = fread(fid, inf);
jsonStr = char(raw');
fclose(fid);
phenotyping = 0;
convertStartTimeToActualTime = 0;

fprintf('\n===Current Settings:')
fprintf('\nPhenotyping=%d',phenotyping)
fprintf('\nConvertToActualStartTime=%d',convertStartTimeToActualTime)

% Read in the event Table
if strcmp(evtFilename(end-3:end),'.EVT')
    rawData = jsondecode(jsonStr);
    try
        % If it is an event table
        T = [];
        if isfield(rawData.Data{1}, 'Channel_Id')
            rawData.Data{1} = rmfield(rawData.Data{1}, 'Channel_Id');
        end
            
        if isa(rawData.Data{1}.AutoScored, 'char') && contains(rawData.Data{1}.AutoScored, 'false')
            rawData.Data{1}.AutoScored = 0;
        elseif isa(rawData.Data{1}.AutoScored, 'char') && contains(rawData.Data{1}.AutoScored, 'true')
            rawData.Data{1}.AutoScored = 1;
        end
        
        T = struct2table(rawData.Data{1});
        
        for j = 2:length(rawData.Data)
            
            if isfield(rawData.Data{j}, 'Channel_Id')
                rawData.Data{j} = rmfield(rawData.Data{j}, 'Channel_Id');
            end
            
            if isa(rawData.Data{j}.AutoScored, 'char') && contains(rawData.Data{j}.AutoScored, 'false')
                rawData.Data{j}.AutoScored = 0;
            elseif isa(rawData.Data{1}.AutoScored, 'char') && contains(rawData.Data{j}.AutoScored, 'true')
                rawData.Data{j}.AutoScored = 1;
            end
            
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
        
        indx = find(T.Type == 14);
        type(indx,1:10) = repmat(char('Annotation'), length(indx), 1);
        
        indx = find(T.Type == 6);
        type(indx,1:12) = repmat(char('Leg Movement'), length(indx), 1);
        class(indx, 1:12) = repmat(char('Leg Movement'), length(indx), 1);
        
        
        indx = find(T.Classification == 1 & T.Type == 1);
        class(indx, 1:10) = repmat(char('Obs. Apnea'), length(indx), 1);
        
        indx = find(T.Classification == 6 | T.Type == 14);
        class(indx, 1:16) = repmat(char('Pressure Invalid'), length(indx), 1);
        
        indx = find(T.Classification == 4 & T.Type == 1);
        class(indx, 1:14) = repmat(char('Cnt. Flow <50%'), length(indx), 1);
        
        
        indx = find(T.Classification == 1 & T.Type == 10);
        class(indx, 1:12) = repmat(char('ASDA Arousal'), length(indx), 1);
        
        indx = find(T.Classification == 2 & T.Type == 1);
        class(indx, 1:10) = repmat(char('Cnt. Appea'), length(indx), 1);
        
        indx = find(T.Classification == 3 & T.Type == 1);
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
        
        if convertStartTimeToActualTime
            
            studyStartTime = datestr(rawData.Header.study_time, 'HH:MM:SS');
            T.StartTime = timeofday(datetime(studyStartTime) + seconds(T.StartTime));
        end
        
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
        end
        
        fprintf('\nEvent Table read in successfully...')
    catch
        fprintf('\nError while reading in Event Table...')
    end
    
    try 
        T = struct2table(rawData.Data);
        fprintf('\nEvent Table read in successfully (Part 2)...')
    catch 
        fprintf('\nError while reading in Event Table (Part 2)...')
    end
    
    
end