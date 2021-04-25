function pobs_wrapper_batch(txtFile)
% function pobs_wrapper_batch(txtFile)
%
% This is a wrapper for batch running of POBS
%
% Input:
%       A text file containing list of filenames (with .edf extension)
%       e.g., 
%           abc.edf
%           xyz.edf
%
% No output is returned from this function, however, modified Minerva
% Breathtables are generated in the folder containing the .edf
% View the breath tables in Minerva. 
%
% Contact:
% Ankit Parekh
% ankit.parekh@mssm.edu 

fid = fopen(txtFile);
FileNames = [];

j = 1;
while ~feof(fid)
    FileNames{j} = fgetl(fid);
    j = j + 1;
end
fclose(fid);

for j = 1:length(FileNames)
    
    fprintf('\n======Analyzing %s',FileNames{j});
    fprintf('\nReading in EDF file...')
    [hdr, sigHdr, sigCell] = blockEdfLoad(FileNames{j});
    fprintf('\nRead EDF file...')
    
    sigHdr = struct2table(sigHdr);
    
    flowChanName = 'Nasal Pressure';
    SpO2ChanName = 'SpO2';
    snoreChanName = 'SNORE';
    ribChanName = 'Thor';
    abdChanName = 'Abdo';
    
    flowChan = find(strcmp(sigHdr.signal_labels,flowChanName));
    SpO2Channel = find(strcmp(sigHdr.signal_labels,SpO2ChanName));
    snoreChan = find(strcmp(sigHdr.signal_labels,snoreChanName));
    ribChan = find(strcmp(sigHdr.signal_labels,ribChanName));
    abdChan = find(strcmp(sigHdr.signal_labels,abdChanName));
    
    try
        fprintf('\n===Warning===')
        fprintf('\n===Read Channel Descriptions Below===\n')
        disp(sigHdr([flowChan, ribChan, abdChan, snoreChan, SpO2Channel],:))
        fprintf('\n==============')
    catch ME
        if contains(ME.identifier, 'UndefinedFunction')
            fprintf('\n==ERROR: Cannot find flow channel. Exiting the Program')
            return
        end
    end
    
    fprintf('\n===Running POBS=====')
    pobs(FileNames{j},hdr,sigHdr, sigCell, flowChan, SpO2Channel, snoreChan, ribChan, abdChan);
    fprintf('\n===Finished POBS====');
    
end

end