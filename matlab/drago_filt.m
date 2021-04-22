function [f, x, cost] = drago_filt(y, lam1, lam2, Nit)
%
% [f, x, cost] = drago_filt(y, lam1, lam2, Nit)
% Smoothing filter for Data with RAndom Gaps and Outliers (DRAGO)
%
% INPUT
%   y - noisy data (use NaN for missing values)
%   lam1, lam2 - regularization parameters
%   Nit - number of iterations
%
% OUTPUT
%   f - smooth signal
%   x - outliers (spike noise)
%   cost - cost function history

% Ivan Selesnick,  NYU-Tandon, 2015

y = y(:);               % Convert to column vector
cost = zeros(1, Nit);   % Cost function history
N = length(y);

% Define matrix D (second-order derivative matrix)
% D is defined as a sparse matrix so that Matlab
% subsequently uses a fast banded system solver.

e = ones(N, 1);
D = spdiags([e -2*e e], 0:2, N-2, N);
DTD = D'*D;

k = isfinite(y);	% k : logical vector, indices of known values
S = speye(N);
S(~k, :) = [];		% S : sampling matrix

Sy = y(k);
x = randn(size(Sy));             % Initialization
for i = 1:Nit
    r = lam1 ./ (abs(x) + lam1);
    A = sparse(1:N, 1:N, S'*r);       % sparse matrix
    f = (A + lam2*DTD) \ (S'*( r .* Sy ));
    x = (Sy - f(k)) .* abs(x) ./ (abs(x) + lam1);
    cost(i) = 0.5 * sum( ( Sy - f(k) - x).^2 ) ...
        + lam1 * sum(abs(x)) + 0.5 * lam2 * sum((D*f).^2);
end
x = S'*x;