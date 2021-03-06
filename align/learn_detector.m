clear;

rng('shuffle');

% What is the value of a non-hit on the training data?  0 or -1 would be
% good choices... should make no difference at all--this is for debugging.
global Y_NEGATIVE;
Y_NEGATIVE = 0;

if 1
        BIRD='lny64';
        load('~/Desktop/lny64/roboaggregate.mat');
        MIC_DATA = audio.data;
        agg_audio.fs = audio.fs;
        times_of_interest = [0.15 0.315 0.402]
elseif 0
        BIRD='lg373rblk';
        load('/Users/Shared/lg373rblk/test/lg373_MANUALCLUST/mat/roboaggregate/roboaggregate.mat');
        MIC_DATA = audio.data;
        agg_audio.fs = audio.fs;
        times_of_interest = [0.115 0.2 0.325];
elseif 0
        BIRD='lw8rhp';
        load('/Users/bwpearre/Desktop/Will/test_MANUALCLUST/mat/roboaggregate/roboaggregate.mat');
        MIC_DATA = audio.data;
        agg_audio.fs = audio.fs;
elseif 0
        BIRD='lw27ry';
        load('~/r/data/lw27ry_extracted_data');
        agg_audio.data = agg_audio.data(1:24000,:);
        clear agg_data;
        MIC_DATA = agg_audio.data;
end

%%% Code snippet to create songs for audio device input
%some_songs = reshape(MIC_DATA(:, 1:50), [], 1);
%
%audiowrite('birdsongs.ogg', ...
%        some_songs / max([max(max(some_songs)) abs(min(min(some_songs)))]), ...
%        44100);

[nsamples_per_song, nmatchingsongs] = size(MIC_DATA);

%% Downsample the data
samplerate = 20000;
if agg_audio.fs ~= samplerate
        disp(sprintf('Resampling data from %g Hz to %g Hz...', agg_audio.fs, samplerate));
        [a b] = rat(samplerate/agg_audio.fs);

        MIC_DATA = double(MIC_DATA);
        MIC_DATA = resample(MIC_DATA, a, b);
end
%MIC_DATA = MIC_DATA(1:raw_time_ds:end,:);
MIC_DATA = MIC_DATA / max(max(max(MIC_DATA)), -min(min(MIC_DATA)));

clear agg_audio.data;
clear agg_data;

[nsamples_per_song, nmatchingsongs] = size(MIC_DATA);

NTRAIN = 1000;

disp(sprintf('Found %d songs.  Using %d.', nmatchingsongs, min(nmatchingsongs, NTRAIN)));

%% Add some non-matching sound fragments and songs and such from another
%% bird... try around 10% of the training corpus?
NONSINGING_FRACTION = 2;
nonmatchingbird = 'lblk121rr';
if strcmp(BIRD, nonmatchingbird)
        fprintf('ERROR: using the same bird--%s--for training and for nonmatching data!\n', BIRD);
        a(0);
end
nonmatchingloc = '/Volumes/disk2/winData';
l = dir(sprintf('%s/%s', nonmatchingloc, nonmatchingbird));
nonmatchingsongs = zeros(round(size(MIC_DATA) .* [1 NONSINGING_FRACTION]));
need_n_songs = size(nonmatchingsongs, 2);

fprintf('Borrowing some non-matching songs from ''%s/%s''...\n', nonmatchingloc, nonmatchingbird);

% incorporate nonmatching data
done = false;
nnewsongs = 0;
for i = 1:length(l)
        if ~strncmp(l(i).name(end:-1:1), 'vaw.', 4)
                continue;
        end
        %fprintf('reading ''%s''\n', l(i).name);
        [foo, nonmatchingfs] = audioread(sprintf('%s/%s/%s', nonmatchingloc, nonmatchingbird, l(i).name));

        % downsample
        nonmatching_resample = round([samplerate nonmatchingfs]);
        foo = resample(foo, round(samplerate), round(nonmatchingfs));
        % normalise
        foo = foo / max(max(foo), -min(foo));

        % append to the extant audio
        songs_available = floor(length(foo) / nsamples_per_song);
        foo = reshape(foo(1:(songs_available*nsamples_per_song)), nsamples_per_song, songs_available);
        
        take_n_songs = min(need_n_songs, songs_available);
        
        nonmatchingsongs(:, nnewsongs+1:min(size(nonmatchingsongs, 2), nnewsongs+songs_available)) = foo(:, 1:take_n_songs);
        nnewsongs = nnewsongs + songs_available;
        need_n_songs = need_n_songs - take_n_songs;
        if need_n_songs <= 0
                break;
        end
end

MIC_DATA = single([MIC_DATA nonmatchingsongs]);

nsongs = size(MIC_DATA, 2);

disp('Bandpass-filtering the data...');
[B A] = butter(4, [0.03 0.9]);
MIC_DATA = filter(B, A, MIC_DATA);


% Compute the spectrogram using original parameters (probably far from
% optimal but I have not played with them).  Compute one to get size, then
% preallocate memory and compute the rest in parallel.

% SPECGRAM(A,NFFT=512,Fs=[],WINDOW=[],NOVERLAP=500)
%speck = specgram(MIC_DATA(:,1), 512, [], [], 500) + eps;
FFT_SIZE = 256;
FFT_TIME_SHIFT = 0.002;                        % seconds
NOVERLAP = FFT_SIZE - (floor(samplerate * FFT_TIME_SHIFT));
fprintf('FFT time shift = %g s\n', FFT_TIME_SHIFT);

window = hamming(FFT_SIZE);

[speck freqs times] = spectrogram(MIC_DATA(:,1), window, NOVERLAP, [], samplerate);
[nfreqs, ntimes] = size(speck);
speck = speck + eps;

% This _should_ be the same as FFT_TIME_SHIFT, but let's use this because
% round-off error is a possibility.  This is actually seconds/timestep.
timestep = (times(end)-times(1))/(length(times)-1);


%% Define training set
% Hold some data out for final testing.
ntrainsongs = min(floor(nsongs*8/10), NTRAIN) * (1 + NONSINGING_FRACTION);
ntestsongs = nsongs - ntrainsongs;
% On each run of this program, change the presentation order of the
% data, so we get (a) a different subset of the data than last time for
% training vs. final testing and (b) different training data presentation
% order.
randomsongs = randperm(nsongs);


spectrograms = zeros([nsongs nfreqs ntimes]);
spectrograms(1, :, :) = speck;
disp('Computing spectrograms...');
parfor i = 2:nsongs
        spectrograms(i, :, :) = spectrogram(MIC_DATA(:,i), window, NOVERLAP, [], samplerate) + eps;
end

spectrograms = single(spectrograms);


% Create a pretty graphic for display (which happens later)
spectrograms = abs(spectrograms);
spectrogram_avg_img = squeeze(log(sum(spectrograms(1:nmatchingsongs,:,:))));

%% Draw the pretty full-res spectrogram and the targets
figure(4);
subplot(2,1,1);
imagesc([times(1) times(end)]*1000, [freqs(1) freqs(end)]/1000, spectrogram_avg_img);
axis xy;
xlabel('Time (ms)');
ylabel('Frequency (kHz)');

% Construct "ds" (downsampled) dataset.  This is heavily downsampled to save on computational
% resources.  This would better be done by modifying the spectrogram's
% parameters above (which would only reduce the number of frequency bins,
% not the number of timesteps), but this will do for now.

% Number of samples: (nsongs*(ntimes-time_window))
% Size of each sample: (ntimes-time_window)*length(freq_range)



%% Cut out a region of the spectrum (in space and time) to save on compute
%% time:
freq_range = [1000 8000]; % TUNE
time_window = 0.03; % TUNE
%%%%%%%%%%%%


freq_range_ds = find(freqs >= freq_range(1) & freqs <= freq_range(2));
disp(sprintf('Using frequencies in [ %g %g ] Hz: %d frequency samples.', ...
        freq_range(1), freq_range(2), length(freq_range_ds)));
time_window_steps = double(floor(time_window / timestep));
disp(sprintf('Time window is %g ms, %d samples.', time_window*1000, time_window_steps));

% How big will the neural network's input layer be?
layer0sz = length(freq_range_ds) * time_window_steps;

% The training input set X is made by taking all possible time
% windows.  How many are there?  The training output set Y will be made by
% setting all time windows but the desired one to 0.
nwindows_per_song = ntimes - time_window_steps + 1;


if 0
        randomsongs = 1:nsongs;
        fprintf('\n    NOT PERMUTING TRAINING SONGS\n\n');
end

disp(sprintf('%d training songs.  %d remain for test.', ntrainsongs, ntestsongs));
trainsongs = randomsongs(1:ntrainsongs);
testsongs = randomsongs(ntrainsongs+1:end);

if 0
        disp('Looking for promising syllables...');
        tstep_of_interest = suggest_moments_of_interest(5, ...
                spectrogram_avg_img, ...
                time_window_steps, ...
                timestep, ...
                layer0sz, ...
                nwindows_per_song, ...
                ntimes, ...
                freq_range_ds);
        times_of_interest = tstep_of_interest * timestep
elseif exist('times_of_interest', 'var') % TUNE
    tstep_of_interest = round(times_of_interest / timestep);
else
    disp('You must define a timestep in which you are interested');
end


if any(times_of_interest < time_window)
        error('learn_detector:invalid_time', ...
                'All times_of_interest [ %s] must be >= time_window (%g)', ...
                sprintf('%g ', times_of_interest), time_window);
end


ntsteps_of_interest = length(tstep_of_interest);

%% For each timestep of interest, get the offset of this song from the most typical one.
disp('Computing target jitter compensation...');

% We'll look for this long around the timestep, to compute the canonical
% song
time_buffer = 0.04;
tstep_buffer = round(time_buffer / timestep);

% For alignment: which is the most stereotypical song at each target?
for i = 1:ntsteps_of_interest
        range = tstep_of_interest(i)-tstep_buffer:tstep_of_interest(i)+tstep_buffer;
        range = range(find(range>0&range<=ntimes));
        foo = reshape(spectrograms(1:nmatchingsongs, :, range), nmatchingsongs, []) * reshape(mean(spectrograms(:, :, range), 1), 1, [])';
        [val canonical_songs(i)] = max(foo);
        [target_offsets(i,:) sample_offsets(i,:)] = get_target_offsets_jeff(MIC_DATA(:, 1:nmatchingsongs), tstep_of_interest(i), samplerate, timestep, canonical_songs(i));
end

%hist(target_offsets', 40);

%% Draw the pretty full-res spectrogram and the targets
figure(4);
subplot(ntsteps_of_interest+1,1,1);
specfig = imagesc([times(1) times(end)]*1000, [freqs(1) freqs(end)]/1000, spectrogram_avg_img);
axis xy;
xlabel('Time (ms)');
ylabel('Frequency (kHz)');
% Draw the syllables of interest:
line(repmat(times_of_interest, 2, 1)*1000, repmat([freqs(1) freqs(end)]/1000, ntsteps_of_interest, 1)', 'Color', [1 0 0]);

for i = 1:ntsteps_of_interest
    windowrect = rectangle('Position', [(times_of_interest(i) - time_window)*1000 ...
        freq_range(1)/1000 ...
        time_window(1)*1000 ...
        (freq_range(2)-freq_range(1))/1000], ...
        'EdgeColor', [1 0 0]);
end
drawnow;



%% Create the training set
disp(sprintf('Creating training set from %d songs...', ntrainsongs));
% This loop also shuffles the songs according to randomsongs, so we can use
% contiguous blocks for training / testing

% The following uses nsongs rather than ntrainsongs: build the complete dataset for the neural
% network to make testing easier.  However, only ntrainsongs will be given to train()

training_set_MB = 8 * nsongs * nwindows_per_song * layer0sz / (2^20);

disp(sprintf('   ...(Allocating %g MB for training set X.)', training_set_MB));
nnsetX = zeros(layer0sz, nsongs * nwindows_per_song);
nnsetY = Y_NEGATIVE * ones(ntsteps_of_interest, nsongs * nwindows_per_song);

%% OPTIONAL: MANUAL PER-SYLLABLE TUNING!

% Some syllables are really hard to pinpoint to within the frame rate, so
% the network has to try to learn "image A is a hit, and this thing that
% looks identical to image A is not a hit".  For each sample of interest,
% define a "shotgun function" that spreads the "acceptable" timesteps in
% the training set a little.  This could be generalised for multiple
% syllables, but right now they all share one sigma.

% This only indirectly affects final timing precision, since thresholds are
% optimally tuned based on the window defined in MATCH_PLUSMINUS.
shotgun_max_sec = 0.02;
shotgun_sigma = 0.003; % TUNE
shotgun = normpdf(0:timestep:shotgun_max_sec, 0, shotgun_sigma);
shotgun = shotgun / max(shotgun);
shotgun = shotgun(find(shotgun>0.1));
shothalf = length(shotgun);
if shothalf
        shotgun = [ shotgun(end:-1:2) shotgun ]
end

% Populate the training data.  Infinite RAM makes this so much easier!
for song = 1:nsongs
    
    for tstep = time_window_steps : ntimes
        
        nnsetX(:, (song-1)*nwindows_per_song + tstep - time_window_steps + 1) ...
            = reshape(spectrograms(randomsongs(song), ...
            freq_range_ds, ...
            tstep - time_window_steps + 1  :  tstep), ...
            [], 1);
        
        % Fill in the positive hits, if appropriate...
        if randomsongs(song) > nmatchingsongs
            % If the index is from the non-song region of the corpus, do not mark a hit.  This
            % cannot simply be moved to the outer loop because we still need to put it in nnsetX.
            continue;
        end
        for interesting = 1:ntsteps_of_interest
            if tstep == tstep_of_interest(interesting)
                nnsetY(interesting, (song-1)*nwindows_per_song + tstep + target_offsets(interesting, randomsongs(song)) - time_window_steps - shothalf + 2 : ...
                    (song-1)*nwindows_per_song + tstep + target_offsets(interesting, randomsongs(song)) - time_window_steps + shothalf) = shotgun;
            end
        end
    end
end

disp('Converting neural net data to singles...');
nnsetX = single(nnsetX);
nnsetY = single(nnsetY);

%% Shape only?  Let's try normalising the training inputs:
nnsetX = normc(nnsetX);

%yy=reshape(nnsetY, nwindows_per_song, nsongs);
%imagesc(yy');

% original order: spectrograms, spectrograms_ds, song_montage
%   indices into original order: trainsongs, testsongs
% shuffled: nnsetX, nnsetY, testout
%   indices into shuffled arrays: nnset_train, nnset_test

% These are contiguous blocks, since the spectrograms have already been
% shuffled.
nnset_train = 1:(ntrainsongs * nwindows_per_song);
nnset_test = ntrainsongs * nwindows_per_song + 1 : size(nnsetX, 2);

% Create the network.  The parameter is the number of units in each hidden
% layer.  [8] means one hidden layer with 8 units.  [] means a simple
% perceptron.



net = feedforwardnet(ceil([1.3*ntsteps_of_interest]+1)); % TUNE
%net = feedforwardnet([ntsteps_of_interest]);
%net = feedforwardnet([]);

%net.trainParam.goal=1e-3;

%net.trainFcn = 'trainbfg';

fprintf('Training network with %s...\n', net.trainFcn);

% Once the validation set performance stops improving, it doesn't seem to
% get better, so keep this small.
net.trainParam.max_fail = 2;
if training_set_MB < 10000 & false
        parallelise_training = 'yes'; % Actually slows down training??
        disp('   ...parallelising...');
else
        parallelise_training = 'no';
end
tic
%net = train(net, nnsetX(:, nnset_train), nnsetY(:, nnset_train), {}, {}, 0.1 + nnsetY(:, nnset_train));
[net, train_record] = train(net, nnsetX(:, nnset_train), nnsetY(:, nnset_train), 'UseParallel', parallelise_training);
% Oh yeah, the line above was the hard part.
disp(sprintf('   ...training took %g minutes.', toc/60));
% Test on all the data:

%% Why not test just on the non-training data?  Compute them all, and then only count ntestsongs for statistics (later)
testout = sim(net, nnsetX);
testout = reshape(testout, ntsteps_of_interest, nwindows_per_song, nsongs);

disp('Creating spectral power image...');

% Create an image on which to superimpose the results...
power_img = squeeze((sum(spectrograms, 2)));
power_img(find(isinf(power_img))) = 0;
power_img = power_img(randomsongs,:);
power_img = repmat(power_img / max(max(power_img)), [1 1 3]);

disp('Computing optimal output thresholds...');

% How many seconds on either side of the tstep_of_interest is an acceptable match?
MATCH_PLUSMINUS = 0.02;
% Cost of false positives is relative to that of false negatives.
FALSE_POSITIVE_COST = 0.01 % TUNE

% Which songs should have hits?  The first nmatchingsongs, but permuted to the same order as the
% training/test sets, as given by randomsongs.
songs_with_hits = [ones(1, nmatchingsongs) zeros(1, nsongs - nmatchingsongs)]';
songs_with_hits = songs_with_hits(randomsongs);

% Search for the optimal trigger thresholds using just the training set
trigger_thresholds = optimise_network_output_unit_trigger_thresholds(...
    testout(:,:,1:ntrainsongs), ...
    nwindows_per_song, ...
    FALSE_POSITIVE_COST, ...
    times_of_interest, ...
    tstep_of_interest, ...
    MATCH_PLUSMINUS, ...
    timestep, ...
    time_window_steps, ...
    songs_with_hits(1:ntrainsongs));

% Now that we've computed the thresholds using just the training set, print the confusion matrices
% using just the holdout test set.
show_confusion(...
    testout(:,:,ntrainsongs+1:end), ...
    nwindows_per_song, ...
    FALSE_POSITIVE_COST, ...
    times_of_interest, ...
    tstep_of_interest, ...
    MATCH_PLUSMINUS, ...
    timestep, ...
    time_window_steps, ...
    songs_with_hits(ntrainsongs+1:end), ...
    trigger_thresholds);



SHOW_THRESHOLDS = true;
SHOW_ONLY_TRUE_HITS = true;
SORT_BY_ALIGNMENT = true;
% For each timestep of interest, draw that output unit's response to all
% timesteps for all songs:

specdims = get(get(specfig, 'Parent'), 'Position');
for i = 1:ntsteps_of_interest
    figure(4);
    subplot(ntsteps_of_interest+1,1,i+1);
    foo = reshape(testout(i,:,:), [], nsongs);
    barrr = zeros(time_window_steps-1, nsongs);
    
    if SHOW_THRESHOLDS
        % "img" is a tricolour image
        img = power_img * 0.8;
        fooo = trigger(foo', trigger_thresholds(i), 0.1, timestep);
        fooo = [barrr' fooo];
        [val pos] = max(fooo,[],2);
        
        img(1:ntrainsongs, :, 1) = img(1:ntrainsongs, :, 1) - fooo(1:ntrainsongs,:);
        img(1:ntrainsongs, :, 2) = img(1:ntrainsongs, :, 2) + fooo(1:ntrainsongs,:);
        img(1:ntrainsongs, :, 3) = img(1:ntrainsongs, :, 3) + fooo(1:ntrainsongs,:);
        img(ntrainsongs+1:end, :, 1) = img(ntrainsongs+1:end, :, 1) + fooo(ntrainsongs+1:end,:);
        img(ntrainsongs+1:end, :, 2) = img(ntrainsongs+1:end, :, 2) - fooo(ntrainsongs+1:end,:);
        img(ntrainsongs+1:end, :, 3) = img(ntrainsongs+1:end, :, 3) - fooo(ntrainsongs+1:end,:);
        
        img(1:ntrainsongs, 1:time_window_steps, 3) = 1;
        img(1:ntrainsongs, 1:time_window_steps, 2) = 1;
        img(1:ntrainsongs, 1:time_window_steps, 1) = 0;
        img(ntrainsongs+1:end, 1:time_window_steps, 2) = 0;
        img(ntrainsongs+1:end, 1:time_window_steps, 1) = 1;
        img(ntrainsongs+1:end, 1:time_window_steps, 3) = 0;

        if SHOW_ONLY_TRUE_HITS
            img = img(find(songs_with_hits), :, :);
            pos = pos(find(songs_with_hits));
        end
        
        if SORT_BY_ALIGNMENT
            %[~, new_world_order] = sort(target_offsets);
            [~, new_world_order] = sort(pos);
            img = img(new_world_order,:,:);
        end
        
        if SHOW_ONLY_TRUE_HITS
            imh = image([times(1) times(end)]*1000, [1 sum(songs_with_hits)], img);
        else
            imh = image([times(1) times(end)]*1000, [1 nsongs], img);
        end
    else
        barrr(:, 1:ntrainsongs) = max(max(foo))/2;
        barrr(:, ntrainsongs+1:end) = 3*max(max(foo))/4;
        foo = [barrr' foo'];
        imagesc([times(1) times(end)]*1000, [1 nsongs], foo);
    end
    xlabel('Time (ms)');
    ylabel('Song');
    if ~SORT_BY_ALIGNMENT
        text(time_window/2*1000, ntrainsongs/2, 'train', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
        text(time_window/2*1000, ntrainsongs+ntestsongs/2, 'test', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
    end
end

% Draw the hidden units' weights.  Let the user make these square or not
% because lazy...
if net.numLayers > 1
        figure(5);
        for i = 1:size(net.IW{1}, 1)
                subplot(size(net.IW{1}, 1), 1, i)
                imagesc([-time_window_steps:0]*FFT_TIME_SHIFT*1000, linspace(freq_range(1), freq_range(2), length(freq_range_ds))/1000, ...
                        reshape(net.IW{1}(i,:), length(freq_range_ds), time_window_steps));
                axis xy;
                ylabel('frequency');

                if i == 1
                        title('Hidden layers');
                end
                if i == size(net.IW{1}, 1)
                        xlabel('time (ms)');
                end
                %imagesc(reshape(net.IW{1}(i,:), time_window_steps, length(freq_range_ds)));
        end
end
drawnow;

%% Save input file for the LabView detector
% Extract data from net structure, because LabView is too fucking stupid to
% permit the . operator.  Or I am.
layer0 = net.IW{1};
layer1 = net.LW{2,1};
bias0 = net.b{1};
bias1 = net.b{2};
mmminoffset = net.inputs{1}.processSettings{1}.xoffset;
mmmingain = net.inputs{1}.processSettings{1}.gain;
mmmoutoffset = net.outputs{2}.processSettings{1}.xoffset;
mmmoutgain = net.outputs{2}.processSettings{1}.gain;
filename = sprintf('detector_%s%s_%dHz_%dhid_%dtrain.mat', ...
        BIRD, sprintf('_%g', times_of_interest), floor(1/FFT_TIME_SHIFT), net.layers{1}.dimensions, NTRAIN);
fprintf('Saving as ''%s''...\n', filename);
save(filename, ...
        'net', 'train_record', 'layer0', 'layer1', 'bias0', 'bias1', ...
        'samplerate', 'FFT_SIZE', 'FFT_TIME_SHIFT', 'freq_range_ds', ...
        'time_window_steps', 'trigger_thresholds', ...
        'mmminoffset', 'mmmingain', 'mmmoutoffset', 'mmmoutgain', 'shotgun_sigma', ...
        'NTRAIN');
%% Save sample data: audio on channel0, canonical hits for first syllable on channel1
% Re-permute with a new random order
newrand = randperm(nsongs);
orig_songs_with_hits =  [ones(1, nmatchingsongs) zeros(1, nsongs - nmatchingsongs)]';
new_songs_with_hits = orig_songs_with_hits(newrand);
songs = reshape(MIC_DATA(:, newrand), [], 1);
songs_scale = max([max(songs) -min(songs)]);
songs = songs / songs_scale;
hits = zeros(size(MIC_DATA));
samples_of_interest = round(times_of_interest * samplerate);
for i = 1:nsongs
        if new_songs_with_hits(i)
                % The baseline signal is recorded only for the first sample
                % of interest:
                hits(samples_of_interest(1) + sample_offsets(1, newrand(i)), i) = 1;
        end
end
hits = reshape(hits, [], 1);
songs = [songs hits];
audiowrite(sprintf('songs_%s%ss_%d%%.wav', BIRD, sprintf('_%g', times_of_interest), round(100/(1+NONSINGING_FRACTION))), songs, round(samplerate));
