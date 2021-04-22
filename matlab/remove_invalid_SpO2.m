function res = remove_invalid_SpO2(sig, fs, lower, upper)
% function res = remove_invalid(sig, lower, upper)
%
% Input:
%       sig = SpO2 signal
%       lower = lowest bound at which signal is still valid
%       upper = highest bound at which signal is still valid
%
% Output:
%       res = SpO2 signal with invalid values removed
%
% Removes invalid parts of the SpO2 signal as designated by the upper and
% lower most valid values of the SpO2 signal.
%
% Ankit A. Parekh (C) 2021.
% Icahn School of Medicine at Mount Sinai
%

fprintf('\n===Removing Invalid Values')
res = sig;
%identifying parts of signal with invalid values
valid_vals = (lower < res);
%removing invalid parts
for j = 1:(length(valid_vals)-1)
    if (valid_vals(j) == 1) && (valid_vals(j+1) == 0)
        NotDone = 1;
        k = j;
        last_valid = 0;
        while NotDone && k < length(sig)
            if res(k-1) - res(k) <= 0
                count = 0;
                check = 1;
                while check
                    if k - count - 1 < 1
                        last_valid = 1;
                        check = 0;
                        NotDone = 0;
                    elseif res(k - count -1) - res(k - count) <= 0
                        count = count + 1;
                    else
                        check = 0;
                    end
                    if count >= 20
                        NotDone = 0;
                        last_valid = k;
                        check = 0;
                    end
                end
            end
            k = k -1;
        end
        res(last_valid : j) = NaN;
    elseif (valid_vals(j) == 0) && (valid_vals(j+1) == 1)
        NotDone = 1;
        k = j;
        last_valid = 0;
        while NotDone && k < length(sig)
            if res(k) - res(k+1) >= 0
                count = 0;
                check = 1;
                while check
                    if k + count + 1 > length(res)
                        last_valid = length(res);
                        check = 0;
                        NotDone = 0;
                    elseif res(k + count) - res(k + count + 1) >= 0
                        count = count + 1;
                    else
                        check = 0;
                    end
                    if count >= 20
                        NotDone = 0;
                        last_valid = k;
                        check = 0;
                    end
                end
            end
            k = k + 1;
        end
        res(j : last_valid) = NaN;
    end    
end

% Combining Consecutive NaN segments

res(~valid_vals) = NaN;
valid_vals = (res < upper);
res(~valid_vals) = NaN;
valid_vals = isnan(res);
k = 1;
while k < length(valid_vals)
    if valid_vals(k) == 1 && valid_vals(k+1) == 0
        j = k+1;
        while valid_vals(j) == 0 && j < length(valid_vals)
            j = j + 1;
        end
        if j- (k+1) <= fs*15
            res((k+1):(j-1)) = NaN;
        end
        k = j-1;
    end
    k = k + 1;
end

