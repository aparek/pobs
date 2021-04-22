function clippedY = detectClipping(y)
% function clippedY = detectClipping(y)
%
% This function will detect clipping in the input signal y
%
% Brute force code using histogram - TBA: Sophisticated approaches
% 
%

y = y(:);

[cnt, edges, bin] = histcounts(y);

pctClipped = (cnt(1) + cnt(end))./sum(cnt);

clippedY = y;
clippedY(clippedY > edges(end-1) & clippedY < edges(end)) = NaN;
clippedY(clippedY < edges(2) & clippedY > edges(1)) = NaN;

