function [T xx] = f2( A1,A2, varargin)
% Computes that spatial statistics of input signals A1 and A2.  The
% functions appropriately normalizes the statistics.  This function is
% optimized using fast Fourier transforms to expedite the computation of
% the convolution.
%
% Nonperiodic and periodic refer the the boundary conditions under which
% the material information was generated.  Experimental information will
% always have nonperiodic boundary conditions while some simulations with
% have periodic boundary conditions.  As a result, this function defaults
% to computing nonperiodic statistcs.
%
% This function can also compute statistics for partial datasets that are
% sampled on an evenly spaced pixel/voxel grid.  If some information is
% known and some is not, then one can compute the spatial statistics using
% this function.  A tutorial will be made available later.
%
% [T, xx] = f2( DATA1 ) computes the nonperiodic autocorrelation of DATA1.
% T is an array of the spatial statistics corresponding to the cell arrray
% of vector lengths in xx.
%
% [T, xx] = f2( DATA1, DATA2 )  computes the nonperiodic crosscorrelation
% of DATA1 and DATA2 where they are the head and tail of the vector, respectively.
%
% [T, xx] = f2( DATA1, DATA2, 'ARG1', val1, ..,.., 'ARGN', valN ) computes
% the crosscorrelation of DATA1 and DATA2 with a set of optional parameters
% listed below.
%
% [T, xx] = f2( DATA1, [], 'ARG1', val1, ..,.., 'ARGN', valN ) computes the
% autocorrelation of DATA1 with optional parameters
%
% Parameters ARGUMENTS
% --------------------
% ARG - class - default - description
% -----------------------------------
% 'normalize' - logical - true - Spatial statistics require computing the
%   convolutions in the numerator and denominator separately.  The numerator
%   is the number of times the statistics criteria is satisfied while the
%    denominator is the number events that were sampled.  If
%    f2( DATA1, [], 'normalize',false ) is executed then only the top
%   numerator is returned.  It is really just the convolution of DATA1.
%
% 'display' - logical - true - When display is true, a plot will appear
%    after each function call of the spatial statistics.
%
% 'cutoff' - double - Cutoff is the maximum vector size to be returned in
%   the statistics.  f2( DATA1, [], 'cutoff', 10 ) will return spatial
%   statistics for vectors whose elements are less than or equal to 10;
%
% 'periodic' - [1xd] logical - If the model information was generated by
%   simulation then it may have periodic boundary conditions.
%   f2( DATA1, [], 'periodic', true ) forces all boundaries to be periodic
%   f2( DATA1, [], 'periodic', [ true true false] ) places the condition
%   that the information is periodic in dimensions 1 and 2 and nonperiodic
%   in the last.  Conditions like this are useful for interfatial
%   simulation information.
%
% 'Mask1' - [N1xN2xN3] double - Sometimes the data returned is not complete,
%   datapoints may be unpopulated. [N1xN2xN3] is the size of the input information.
%   f2( DATA1, [], 'Mask1', M )  computes are spatial statistics for
%   populated datapoints and normalizes the function appropriately.  M is
%   a logical array that describes whether a value is populated<true> or
%   not populated<false> for the first dataset, the one at the tail of the vector .
%
% 'Mask2' - [N1xN2xN3] double -
%   f2( DATA1, [], 'Mask2', M )  computes are spatial statistics for
%   populated datapoints and normalizes the function appropriately.  M is
%   a logical array that describes whether a value is populated<true> or
%   not populated<false> for the second dataset, the one at the head of the vector .
%
% 'Mask' - [N1xN2xN3] logical -populates Mask1 and Mask2 with the same
% mask.

%% Initialize Critical Data Elements
param = setparam(varargin, size(A1));

%%
% Decide whether the correlation is an auto or cross correlation

if exist('A2','var') && numel(A2) > 0
    if all(size(A1) == size(A2))
        if any(A1(:)~=A2(:)) param.auto = false; end
    else error('The size of the input signals are not the same.'); end
end

%% Compute numerator

if param.auto  % Autocorrelation
    if numel( param.Mask1 ) == 0
        T = convolve( param.periodic, A1 );
    else   % Partial
        T = convolve( param.periodic, param.Mask1.*A1 );
    end
else   % Crosscorrelation
    if numel( param.Mask1 ) == 0
        T = convolve( param.periodic, A1, A2 );
    else  % Partial
        T = convolve( param.periodic, param.Mask1.*A1, param.Mask2.*A2 );
    end
end


%% Compute denominator
if param.normalize
    if numel(param.Mask1)  == 0  % Complete
        if all(param.periodic)  % All Periodic
            T = T./ numel( A1 );
        else  % Partial and Nonperiodic
            % compute it directly, for the meantime use the convolution
            T(:) = T./ convolve( param.periodic, ones(size(A1)));
        end
    else  % Partial
        if param.auto  % Auto
            T(:) = T./ convolve( param.periodic, param.Mask1 );
        else   % Cross
            T(:) = T./ convolve( param.periodic, param.Mask1, param.Mask2 );
        end
    end
end

%% T vector sizes
for ii = 1 : ndims(T)
    uu = 1 : floor(size(T,ii)./2);
    
    if mod( size(T,ii), 2) == 0
        xx.values{ii} = [uu-1,fliplr(uu)*-1];
    else
        xx.values{ii} = [ 0 , uu, fliplr( uu ) * -1 ];
    end
    
    incut{ii} = abs(xx.values{ii}) > param.cutoff(ii);
end

%% Truncate Statistics
T(incut{1},:,:) = [];
if ndims(T) >= 2
    T(:,incut{2},:) = [];
end
if ndims(T) >= 3
    T(:,:,incut{3}) = [];
end
xx.values = arrayfun( @(x)xx.values{x}(~incut{x}),1:ndims(T),'UniformOutput',false);

%% Display the statistics
if param.display
    % When the statistics are visualized, the outputs are
    % forced to be real, this result should be removed
    pcolor(fftshift(xx.values{2}),fftshift(xx.values{1}),fftshift(real(T))); colorbar; shading flat
end


end


%%
function param = setparam( inptvar,sz )
% Set parameters for the code

param = struct('normalize',true, ...
    'display',true,...
    'cutoff', sz./2,...
    'auto',true,...
    'periodic',false*ones(1,numel(sz)),...
    'Mask1',[],...
    'Mask2',[] );


fldnm = fieldnames( param );

if numel(inptvar) > 0
    for ii = [1 : (numel(inptvar)./2)]*2-1
        if ismember( inptvar{ii}, fldnm );
            % update parameters
            param = setfield( param, inptvar{ii}, inptvar{ii+1});
        elseif strcmp( inptvar{ii}, 'Mask' );
            [ param.Mask1 param.Mask2 ] = deal( inptvar{ii+1} );
        else % error message for bad input parameters
            disp(sprintf('f2 accepts the following options:'));
            for jj = 1 : numel( fldnm )
                disp(sprintf(':: %s - type ::  %s', fldnm{jj}, class(getfield(param, fldnm{jj}))));
            end
            disp(sprintf(':: %s - type ::  %s', 'Mask', class(getfield(param, 'Mask1'))));
            error( sprintf('%s is not a valid parameter.', inptvar{ii}));
        end
    end
    
    n = {size( getfield( param, 'Mask1' )) ;  size( getfield( param, 'Mask2' ))};
    if ~( all(n{1}==0) & all(n{2}==0)) && (numel( n{1})~=numel(n{2}) || ~all( n{1}==n{2}))
        disp('test')
        if numel( getfield( param, 'Mask1') ) == 0 param.Mask1 = ones( size(getfield( param, 'Mask2')));
        elseif numel( getfield( param, 'Mask2') ) == 0 param.Mask2 = ones( size(getfield( param, 'Mask1')));
        else error( 'The size of Mask1 and Mask2 are not the same.'); end
        
    end
end
param.Mask1 = cast( param.Mask1, 'double' );
param.Mask2 = cast( param.Mask2, 'double' );

if numel( param.cutoff ) == 1 param.cutoff = param.cutoff * ones(1, numel( sz )); end
id = find(isinf(param.cutoff)); if numel(id) > 0 param.cutoff(id) = sz(id)./2; end
end