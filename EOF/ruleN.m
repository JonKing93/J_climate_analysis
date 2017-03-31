function[nSig, randEigSort, normEigvals, thresh, trueConf, iterTrueConf, iterConfEigs] = ...
    ruleN(Data, matrix, eigVals, MC, noiseType, pval, varargin)
%% Runs a Rule N significance test on a data matrix and its eigenvalues.
%
% [nSig, randEigSort, normEigvals, thresh, trueConf, iterTruePval, iterConfEigs] = ...
%    ruleN(Data, matrix, eigVals, MC, noiseType, pval)
% Runs a Rule N significance test on a dataset and saves Monte Carlo
% convergence data.
%
% [nSig, randEigSort, normEigvals, thresh, trueConf] = ...
%    ruleN(..., 'noConvergeTest')
% 
%
%
% ----- Inputs -----
%
% Data: A 2D data matrix. Each column corresponds to a series of
%   observations.
%
% matrix: The desired analysis matrix.
%       'cov': Covariance matrix -- Minimizes variance along EOFs
%       'corr': Correlation matrix -- Minimizes relative variance along
%               EOFs. Often useful for data series with significantly
%               different magnitudes.
%       'none': Perform svd directly on data matrix. (This analysis will 
%               detrend but not zscore the data)
%
% eigVals: The eigenvalues of the analysis matrix of Data
%
% MC: The number of Monte Carlo iterations to perform
%
% noiseType: 
%   'white':    white noise
%   'red':      lag-1 autocorrelated red noise with Gaussian white noise.
%
% pval: The significance level desired for the test to pass. Must be on the
%       interval (0 1).
%
%            
% ----- Outputs -----
%
% lastSigNum: The number of eigenvalues that pass rule N
%
% randEigSort: The matrix of random, normalized, sorted eigenvalues
%
% normEigvals: The normalized data eigenvalues
% 
% thresh: The integer threshold that eigenvalues were required to pass
%
% realConf: The true confidence interval of this threshold
% 


[ar1, normEigvals] = setup(Data, eigVals, noiseType, pval, MC);

% Get the data size
[m, n] = size(Data);

% Preallocate
randEigvals = NaN(MC,n);
testConverge = true; %%%%%%%%AHHHHHHHHHHHHHHH FIX THIS!!!!!!!!!!!!!!!!!!
if testConverge
    iterConfEigs = NaN(MC, n);
    iterTrueConf = NaN(MC, 1);
else
    iterConfEigs = [];
    iterTrueConf = [];
end

% Run Rule N...
for k = 1:MC
    k
    
    % Create a random matrix
    g = buildMatrix(noiseType,m,n,ar1);
    
    % Scale to the standard deviation of the original matrix
    g = g * sqrt( diag( var( Data)));
    
    % Run an EOF analysis on the random matrix
    [randEig, ~] = simpleEOF(g, covcorr, varargin{:});
    
    % Normalize the eigenvalues
    randEig = randEig ./ sum(randEig);
    
    % Store the random eigenvalues
    randEigvals(k,:) = randEig;
    
    % If testing Monte Carlo convergence...
    if testConverge
        % Sort the current set of random eigenvalues
        randEigvals = sort(randEigvals);
        
        % Calculate the current confidence level threshold
        thresh = ceil(k * pval);
        iterTrueConf(k) = thresh / k;
        
        % Get the set of values on the confidence interval
        iterConfEigs(k,:) = randEigvals(thresh,:);
    end
    
end

% Sort the eigenvalues
randEigSort = sort(randEigvals);

% Calculate the confidence level threshold
thresh = ceil( MC * pval);
trueConf = thresh / MC;

% Find the significant values
for k = 1:n
    if normEigvals(k) <= randEigSort(thresh, k)
        nSig = k-1;
        break;
    end
end

end

%%%%% Helper Functions %%%%%
function[g] = buildMatrix(noiseType, m, n, ar1)
%% Builds the matrix g as appropriate for red or white noise
switch noiseType
    
    % Random matrix for white noise
    case 'white'
        % Create a random matrix
        g = randn(m,n);
    
    % Add lag-1 autocorrelation for red noise
    case 'red'
        % Preallocate 
        g = NaN(m,n);
        
        % Create random first row
        g(1,:) = randn(1,n);
        
        % Calculate autocorrelation through matrix. Add random noise
        for j = 1:m-1
            g(j+1,:) = (ar1' .* g(j,:)) + randn(1,n);
        end
        
        % Standardize so later scaling is correct
        g = zscore(g);   
end
end

function[ar1, normEigvals] = setup(Data, eigVals, noiseType, confidence, MC)

% Ensure Data is 2D
if ~ismatrix(Data)
    error('RuleN is for 2D Data matrices');
end

% Get noise type
if ~( strcmp(noiseType,'red') || strcmp(noiseType, 'white') )
    error('Unrecognized noise type');
end

% Precalculate ar1 if required
if strcmp(noiseType, 'red')
    r = corr( Data(1:end-1,:), Data(2:end,:) );
    ar1 = diag(r);
else
    ar1 = NaN;
end    

% Normalize Eigenvalues
normEigvals = eigVals ./ sum(eigVals);

% Ensure confidence interval is on (0 1)
if confidence <=0 || confidence >=1
    error('confidence must be on the interval (0,1)');
end

% Ensure the Monte Carlo number is positive
if MC < 1
    error('The Monte Carlo number must be a positive integer');
end


end
    