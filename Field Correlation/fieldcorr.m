function[corrmap, pmap, isSig] = fieldcorr(ts, field, p, MC, noiseType)
%% Determines the correlation coefficients of a time series with a field, 
% and performs a Monte Carlo significance test on the correlation.
% 
% [corrmap, pmap , isSig] = fieldcorr( ts, field, p, MC, noiseType)
%
% ----- Inputs -----
% 
% ts: a time series. This is a single vector.
%
% field: A field. The time series at individual points in the field should
%   have the same length as ts. Field may be n-dimensional. In all cases,
%   each set of observations is stored along one column.
%
% p: The desired confidence level. (e.g. p = 0.05 corresponds to the 95%
% confidence level
%
% noisetype: The type of noise in the Monte Carlo time series.
%    'white': White Gaussian noise
%    'red': Red lag-1 autocorrelated noise with added Gaussian white noise
%
% MC: The Monte Carlo number
%
% ----- Outputs -----
%
% corrmap: An array displaying the correlation coefficients at each point
% on the field.
%
% pmap: Displays the p value of the correlation coefficient for each point
% on the field.
%
% ----- Additional Reading -----
%
% Livezney and Chen (1983)
%
% -----
% Jonathan King, 2017

% Perform some initial error checking, get the number of dimensions.
[sField] = setup(ts, field);


%% Perform the actual correlation

% Reshape the field to a 2D matrix and the time series to a column vector
field = reshape(field, sField(1), prod(sField(2:end)) );
if isrow(ts)
    ts = ts';
end

% Perform the correlation
[corrmap, pmap] = corr(ts, field);

% Reshape the correlation map to the shape of the original field
corrmap = reshape( corrmap, [1 sField(2:end)] );

% (Before reshaping the pmap, perform a significance test...

%% Perform significance tests

% P values of NaN are not actual tests, just missing data. Thus, remove
% them from statistical considerations.
ptests = pmap(~isnan(pmap));

% Now reshape the pmap
pmap = reshape( pmap, [1 sField(2:end)]);

% Check that the finite number of tests do not cause the true significance
% of the tests to fall below the desired significance level.
nTests = size(ptests, 2);
nPass = sum( ptests<=p );

isSig = finiteTestsAreSig( nTests, nPass, p);

if ~isSig
    % If the tests are not significant, stop
    return;
      
else
    % The number of passed tests is greater than the number expected to
    % occur randomly.
    
    % However, reduced degrees of freedom (from spatial correlation) could
    % raise the number expected to occur randomly. Test this possibility
    % with a Monte Carlo simulation.
    
    % Begin by creating a set of random time series.
    randTS = buildRandomTS(ts, MC, noiseType);
        
    % Scale to the standard deviation of the time series
    randTS = randTS * std(ts);

    % Get the correlation of each time series with the data from each point
    % in the field
    [~, mcPvals] = corr(randTS, field);
    
    % Get the number of points that pass the significance test for each
    % time series across the field.
    mcPass = nansum( mcPvals < p, 2);

    % Sort the number of passed tests
    mcPass = sort( mcPass);
    
    % Get the index of minimum of the p largest number of passed tests
    sigDex = ceil(p*MC);
    mcNPass = mcPass(sigDex);
    
    % Compare this number of passed tests to the number passed by the time
    % series.
    if nPass < mcNPass
        % The number of passed tests does not exceed the number from the
        % Monte Carlo simulations (to account for spatial relationship)
        isSig = false;
    else
        isSig = true;
    end
    
end

end


% ----- Helper Functions -----
function[sField] = setup(ts, field)

% Ensure ts and field have the correct dimensions
if ~isvector(ts)
    error('ts must be a vector');
end

dField = ndims(field);
if dField == 1
    error('field cannot be a scalar');
end

% Ensure that ts and field have the same lengths
lTS = numel(ts);
sField = size(field);

if lTS ~= sField
    error('ts and field must have the number of observations per point');
end

end
    
function[randTS] = buildRandomTS(ts, MC, noise)
% Build a set of random time series with the appropriate noise type.

% Get the length of the time series
lts = length(ts);
    
switch noise
    
    case 'white'
        randTS = randn( lts, MC );
        
    case 'red'
        % Preallocate
        randTS = NaN( lts, MC);
        
        % Get the lag-1 autocorrelation
        ar1 = corr( ts(1:end-1), ts(2:end));
        
        % Initialize the first row
        randTS(1,:) = randn(1,MC);
        
        % Calculate autocorrelation through matrix. Add random noise
        for k = 1:lts-1
            randTS(k+1,:) = (ar1 * randTS(k,:)) + randn(1,MC);
        end
        
        % Standardize so later scaling is correct
        randTS = zscore(randTS);
        
    otherwise
        error('Unrecognized noise type');
end

end



