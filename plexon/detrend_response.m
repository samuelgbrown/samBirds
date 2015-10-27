function [ detrended trend maxendtime ] = detrend_response(response, d, data, detrend);

persistent last_detrend;
if isempty(detrend)
    if isfield(data, 'detrend')
        detrend = data.detrend;
    else
        detrend = last_detrend;
    end
end
if isempty(response)
    response = d.response;
end

if data.version >= 18 ...
        & isfield(data, 'detrend') ...
        & isequal(detrend, data.detrend) ...
        & isfield(d, 'response_detrended') ...
        & all(size(response) == size(d.response))
    disp('detrend_response: Using cached detrend with the same parameters.');
    detrended = d.response_detrended;
    trend = d.response_trend;
    maxendtime = data.tdt.detrend_maxendtime;
    return;
end

%disp(sprintf('DETRENDING %d pulses per channel, %d channels...', ...
%    size(response,1), size(d.response,3)));

if isempty(response)
    % Use a processed version (e.g. mean) if provided; otherwise revert to detrending individuals
    response = d.response;
end

[nstims nsamples nchannels] = size(d.response);

s = size(response);
[nstims_m b c] = size(response);

if length(s) == 2
    response = reshape(response, 1, b, c);
    %response = reshape(response, [nsamples nchannels]); % must already be mean(response, 1)
end

% Try:
% Fourier, 8 terms
% Polynomial, degree 8
% Smoothing spline with specify 0.9999999999? Hmmm...

times = d.times_aligned;

minstarttime = 0.001 + times(d.stim_active_indices(end));
maxendtime = -0.0005 + 1/data.repetition_Hz;
maxendtime = min(maxendtime, d.times_aligned(nsamples));

roi(1) = max(detrend.range(1), minstarttime);
roi(2) = min(detrend.range(2), maxendtime);
disp(sprintf('detrend_response using range [%g %g] ms', roi(1)*1000, roi(2)*1000));

roii = find(d.times_aligned >= roi(1) & d.times_aligned < roi(2));
roitimes = d.times_aligned(roii);


len = length(d.times_aligned);
lenfit = length(roitimes);

% FITOPTIONS doesn't work in a parfor!?
%opts = fitoptions(fittype, 'Normalize', 'on');

trend = zeros(nstims_m, nsamples, nchannels);
detrended = zeros(nstims_m, nsamples, nchannels);

parfor stim = 1:nstims_m
    for channel = 1:nchannels
        f = fit(roitimes', reshape(response(stim, roii, channel), [length(roii) 1]), ...
            detrend.model, 'Normalize', 'on');
        trend(stim, :, channel) = f(d.times_aligned);
        detrended(stim, :, channel) = squeeze(response(stim, :, channel)) - trend(stim, :, channel);
        %detrendotron{channel} = f;
    end
end

last_detrend = detrend;