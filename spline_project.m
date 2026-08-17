clear; close all; clc;
%% Fix random seed so we get the same QAM data every run
rng(0);
%% QAM signals parameters
L=5;                                   %sample factor
BW          = 20e6;                    % Target occupied bandwidth (Hz)
alpha       = 0.15;                    % RRC roll-off
num_symbols = 4000;                    % Number of QAM symbols
fs          = 60e6;                    % 60MSa/s -IQ signals SampleRate
fs1         = fs*L;                    % 300 MSa/s -IQ signals SampleRate
SymbolRate  = BW / (1 + alpha);        % ≈17.39 Msym/s
OS = 3;                                % oversampling factor for 60Mhz signal
OS1 = OS*L;                            % oversampling factor for 300Mhz signal
%% Generate QAM-64 signals with 60MSa/s & 300MSa/s (floating point) & normlize..
[iq60, fs] = QAMsignalGenerator(fs,num_symbols,OS,alpha);
[iq300,fs1] =QAMsignalGenerator(fs1,num_symbols,OS1,alpha);

iq60= iq60/(2*rms(iq60));
iq300= iq300/(2*rms(iq300));            % refrence signal
ND = length(iq60);
NU=L*(ND-1)+1;
 
save_plots(iq60, fs, '60Msps Signal');
plotIQfft(iq60,  fs, '60Msps Signal- FFT', 50);
save_plots(iq300, fs1, '300Msps Refrence Signal');
plotIQfft(iq300,  fs1, '300Msps Refrence Signal-FFT', 150);


%% Spline interpolation on 60Msa/s I/Q signals  (floating point) + Filtering
t_D  = (0:ND-1)/fs;                   %time points of original samples 
t_U = ((0:NU-1)/fs1);                 %time points of interpolated sampels 
I_in = real(iq60);
Q_in = imag(iq60);

% Matlab built in spline interpolation function
I_spline =interp1(t_D, I_in, t_U, 'spline');
Q_spline =interp1(t_D, Q_in, t_U, 'spline');
iq60_spline = I_spline + 1j*Q_spline ;
%iq60_spline_filt = LPF_fir1(BW,fs1, iq60_spline);            %Filter the signal using FIR1 LPF
save_plots(iq60_spline, fs1, '300Msps Spline', 'before filtering');
plotIQfft(iq60_spline,  fs1, 'FFT 60→300 spline', 150);

%floating point minAJ2 spline interpolation 
iq60_splinefloat =  interp_minAJ2(iq60,L);
%iq60_splinefloat_filt =LPF_fir1(BW,fs1, iq60_splinefloat);    %Filter the signal using FIR1 LPF 

% Save and plot results before and after filtering
save_plots(iq60_splinefloat, fs1, '300Msps Spline float', 'before filtering');
plotIQfft(iq60_splinefloat,  fs1, 'FFT 60→300 spline float before filtering', 150);

%% shift the dealyed signal 
[cc,lags] = xcorr(iq300, iq60_splinefloat);
[~,idxMax] = max(abs(cc));
bestLag = lags(idxMax);   

if bestLag > 0
    % float is EARLIER (advanced) relative to original
    d = bestLag;
   orig_al = iq300(1+d:end);                 % drop first d from original
   float_al  = iq60_splinefloat(1:end-d); % drop last d from float
elseif bestLag < 0
   d = -bestLag;
  orig_al = iq300(1:end-d);
   float_al = iq60_splinefloat(1+d:end);
else
    orig_al = iq300;
    float_al  = iq60_splinefloat;
end

fprintf('bestlag = %.2f\n ',bestLag );
%% compare Floating vs Original in time domain
figure;

% --- Real Part (Left Column) ---
subplot(2,2,1);
plot(real(orig_al(1:6000))); hold on;
plot(real(float_al(1:6000)));
legend('original','float');
grid on;
title('Real Part: Floating vs Reference');

% --- Imaginary Part (Right Column) ---
subplot(2,2,2);
plot(imag(orig_al(1:6000))); hold on;
plot(imag(float_al(1:6000)));
legend('reference','float');
grid on;
title('Imag Part: Floating vs Reference');

% --- Real Difference (Left Column) ---
subplot(2,2,3);
plot(real(orig_al(1:6000) - float_al(1:6000)));
grid on;
title('Difference (Real Part)');

% --- Imag Difference (Right Column) ---
subplot(2,2,4);
plot(imag(orig_al(1:6000) - float_al(1:6000)));
grid on;
title('Difference (Imag Part)');
sgtitle('Floating vs Reference Time-Domain Comparison');% Main Figure Title

%% fixed point parameters
%estimated noise floor
N  = length(iq60_spline);
X  = fftshift(fft(iq60_spline)/N);                                   %to get symmetric IQ signal, centered around 0 Hz
f  = linspace(-fs1/2, fs1/2, N);
magdB = 20*log10(abs(X)/max(abs(X)) + eps);

% take only frequencies outside the useful band (e.g. |f| > 15 MHz)
idx = abs(f) > BW/2 + 5e6;   % little guard band

noise_floor_dB = mean(magdB(idx));
fprintf('Estimated noise floor ≈ %.2f dB\n', noise_floor_dB);
max_val = max(abs(iq60_spline));
IL = ceil(log2(max_val));
fprintf('max val = %.4f, so integer length = %.4f\n',max_val, IL);
fl= 12 ;                                                                 % fraction length
wl = 16 ;                                                              % word length = 1(sign bit) + 3(integer bit) + fraction length

%% Spline Interpolation on 60Msa/s I/Q signals (Fixed point)
iq60_splineFixed =  minAJ2_fixed(iq60(1:2400), L,wl, fl);

%plot and compare to original signal

save_plots(double(iq60_splineFixed) , fs1, '300Msps spline fixed', 'before filtering');
plotIQfft(double(iq60_splineFixed), fs1, 'IQfft 60→300 spline fixed before filtering', 150);

%% compare refrence vs fixed signals in time domain
figure;
% --- Real Part (Left Column) ---
subplot(2,2,1);
plot(real(iq300(1:6000))); hold on;
plot(real(iq60_splineFixed(1:6000)));
legend('reference','fixed');
grid on;
title('Real Part: Reference vs Fixed');

% --- Imaginary Part (Right Column) ---
subplot(2,2,2);
plot(imag(iq300(1:6000))); hold on;
plot(imag(iq60_splineFixed(1:6000)));
legend('reference','fixed');
grid on;
title('Imag Part: Reference vs Fixed');


% --- Real Difference (Left Column) ---
subplot(2,2,3);
plot(real(iq300(1:6000) - iq60_splineFixed(1:6000)));
grid on;
title('Difference (Real Part)');

% --- Imag Difference (Right Column) ---
subplot(2,2,4);
plot(imag(iq300(1:6000) - iq60_splineFixed(1:6000)));
grid on;
title('Difference (Imag Part)');

sgtitle('Reference vs Fixed version Time-Domain Comparison');% Main Title


%% Calculating RMSE 

% Calculating RMSE (floating point)
orig_al  = orig_al(:);
float_al = float_al(:);
% (floating point)                                                                    
len1= min(length(float_al),length(orig_al));
rmse_float = sqrt(mean(abs(orig_al(1:len1)- float_al(1:len1)).^2));
rmse_dB = 20*log10(rmse_float);
fprintf('floating point signal length  = %.6f,refrence signal length   %.2f \n', length(float_al), length(orig_al));
fprintf('For floating point, we got RMSE (linear) = %.6f,  RMSE (dB) = %.2f dB\n', rmse_float, rmse_dB);

% Calculating RMSE (fixed point)

iq300 = iq300(:);
iq60_SplineFixed    =iq60_splineFixed(:);
len2 = min(length(iq300), length(iq60_SplineFixed));
rmse_fixed = sqrt(mean(abs( double(iq300(1:len2) -iq60_SplineFixed(1:len2))).^2));
rmse_fixed_dB = 20*log10(rmse_fixed);
fprintf('For fixed point, we got RMSE (linear) = %.6f,  RMSE (dB) = %.2f dB\n', rmse_fixed, rmse_fixed_dB);

fprintf('\n===============================================================\n');
fprintf('                    RMSE REPORT-Before Filtering            \n');
fprintf('===============================================================\n');
fprintf(' RMSE-Flaoting Point :RMSE_linear = %.6f, RMSE_dB= %.2f dB\n',rmse_float, rmse_dB);
fprintf(' RMSE-Fixed Point :RMSE_linear = %.6f, RMSE_dB= %.2f dB\n', rmse_fixed, rmse_fixed_dB);
fprintf('===============================================================\n');


%% Local functions definition
%======================================
%QAM-64 signal genaerator function
function [iqdata,fs] = QAMsignalGenerator(fs,num_symbols,OS,alpha)
[iqdata, ~, ~, ~, ~] = iqmod( ...
    'sampleRate', fs, 'numSymbols', num_symbols, ...
    'data', 'Random', 'modType', 'QAM64', 'oversampling', OS, ...
    'shift', 0, 'invert', 0, ...
    'filterType', 'Root Raised Cosine', 'filterNsym', 80, ...
    'filterBeta', alpha, 'carrierOffset', 0, 'magnitude', 0, ...
    'quadErr', 0, 'iqskew', 0, 'gainImbalance', 0, 'XYgainImbalance', 0, ...
    'correction', 0, 'snlCorrection', 0, 'phasenoise', 0, ...
    'function', 'download');
end

%---------------------------

% LPF_fir1 filter 
function iq_filtered = LPF_fir1(BW, Fs, iq)

fc   = 0.85 * BW;          % recommended cutoff
Wn   = fc / (Fs/2);

Nfir = 256;
b    = fir1(Nfir, Wn, 'low', hamming(Nfir+1));

iq_filtered = filter(b, 1, iq);

fprintf('Cutoff = %.2f MHz | DC gain = %.6f\n', fc/1e6, sum(b));
end

%--------------------------
% fixed manual LPF
function b = designLPF_manual(BW,alpha, Fs, Nfir)
%DESIGNLPF_MANUAL  Low-pass FIR design without fir1.
%   b = designLPF_manual(BW, Fs, Nfir)
%
%   BW   - occupied bandwidth (Hz), e.g. 20e6
%   Fs   - sampling rate (Hz), e.g. 300e6
%   Nfir - filter order (e.g. 256)

    fc = (BW/2)*(1+alpha);           % cutoff (Hz)
    fc_norm =  fc / (Fs/2);        % normalized to Fs (0..0.5)

    n = 0:Nfir;
    m = n - Nfir/2;

    hideal = 2*fc_norm * sinc(2*fc_norm * m);
    w      = hamming(Nfir+1).';       % Hamming window
    b      = hideal .* w;             % windowed-sinc

    b      = b / sum(b);              % DC gain = 1
end

function y_fx = LPF_manual_fixed(BW,alpha, Fs, x, wl, fl, Nfir)

    % --------- 1) design double-precision coefficients ----------
    b_d = designLPF_manual(BW,alpha, Fs, Nfir);   % from function above

    % --------- 2) define fixed-point type & fimath ----------
    T = numerictype(1, wl, fl);
    F = fimath('RoundingMethod','Nearest', ...
               'OverflowAction','Saturate', ...
               'ProductMode','SpecifyPrecision', ...
               'ProductWordLength', wl, ...
               'ProductFractionLength', fl, ...
               'SumMode','SpecifyPrecision', ...
               'SumWordLength', wl, ...
               'SumFractionLength', fl);

    % quantize coefficients and input
    b_fx = fi(b_d, T, F);
    x_fx = fi(x, T, F); 
   % --------- 3) manual FIR convolution (no filter()) ----------
    y_fx = fi(zeros(size(x_fx)), T, F);   % pre-allocate
     L  = length(x_fx);
    M  = length(b_fx);

    for n = 1:L
        acc = fi(0, T, F);                % accumulator
        for k = 1:M
            idx = n - k + 1;
            if idx >= 1
                acc = acc + b_fx(k) * x_fx(idx);
            end
        end
        y_fx(n) = acc;
    end
fprintf('DC gain of LPF_fixed = %.4f in linear, %.4f\n in dB\n', sum(b_fx), 20*log10(double(sum(b_fx)))); % to check if the gain of the filter = 1.
end

function plotIQfft(iq, fs, title_str, freq_limit)
    if nargin < 4
        freq_limit = fs/(2e6);   % show full Nyquist range if not given
    end
    N  = length(iq);
    X = fftshift(fft(iq)/N);     % normalize by N
    f = linspace(-fs/2, fs/2, N);% frequency axis (Hz)
    magdB = 20*log10(abs(X)/max(abs(X)) + eps); % avoid log(0)
    figure;
    plot(f/1e6, magdB, 'LineWidth', 1);
    xlim([-freq_limit freq_limit]);
    ylim([-140 5]);
    grid on;
    xlabel('Frequency (MHz)');
    ylabel('Magnitude (dB)');
    title(title_str);
end


function [EVM_linear, EVM_dB] = calc_evm(ref, test)
    ref  = ref(:);
    test = test(:);   
    N = min(length(ref), length(test)); % Align lengths
    ref  = ref(1:N);
    test = test(1:N);

  
    err = test - ref;  % Error vector

    % EVM computations
    EVM_linear = sqrt(sum(abs(err).^2) / sum(abs(ref).^2));
    EVM_dB     = 20 * log10(EVM_linear);


end
%---------------------------
% plotting & saving 
function save_plots(iqdata, fs, filename, stage)
    % Optional argument: if 'stage' is not provided, set it to empty
    if nargin < 4 || isempty(stage)
        stage = '';  % no text if not provided
    end

    t = (0:length(iqdata)-1)/fs * 1e6; % time in µs

    % --- Time-domain plot ---
    fig1 = figure('Visible','off');
    plot(t, real(iqdata)); hold on;
    plot(t, imag(iqdata));
    xlabel('Time (µs)');
    ylabel('Amplitude');
    legend('I','Q');
    % add stage only if it's not empty
    if isempty(stage)
        title([filename 'Time-Domain-f = ' num2str(fs/1e6) ' MSa/s']);
    else
        title([ filename '(' stage ') — Time Domain']);
    end
    grid on;
    fname_time = ['QAM64_' filename '_' stage '_TimeDomain.fig'];
    fname_time = strrep(fname_time, ' ', '_');
    savefig(fig1, fname_time);
    close(fig1);

    % --- Spectrum plot ---
    fig2 = figure('Visible','off');
    pspectrum(iqdata, fs);
    if isempty(stage)
        title([ filename 'Spectrum — f = ' num2str(fs/1e6) ' MSa/s']);
    else
        title([ filename '(' stage ') — Spectrum']);
    end
    fname_spec = ['QAM64_' filename '_' stage '_Spectrum.fig'];
    fname_spec = strrep(fname_spec, ' ', '_');
    savefig(fig2, fname_spec);
    close(fig2);

    % --- Automatically open both saved figures ---
    openfig(fname_time, 'new', 'visible');
    openfig(fname_spec, 'new', 'visible');
end
%plotIQfft  Plot normalized FFT magnitude (in dB) of an IQ signal.

