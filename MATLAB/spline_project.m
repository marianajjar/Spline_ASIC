clear; close all; clc;

%% Fix random seed so we get the same QAM data every run
rng(0);

%% QAM signals parameters
L = 2;                                  % Interpolation factor
BW          = 20e6;                     % Target occupied bandwidth (Hz)
alpha       = 0.15;                     % RRC roll-off
num_symbols = 4000;                     % Number of QAM symbols
fs          = 60e6;                     % Input sample rate: 60 MSa/s
fs1         = fs*L;                     % Output sample rate
SymbolRate  = BW / (1 + alpha);         % ≈17.39 Msym/s
OS          = 3;                        % Oversampling factor at 60 MSa/s
OS1         = OS*L;                     % Oversampling factor at output rate


%% Generate QAM-64 signals
[iq60, fs]   = QAMsignalGenerator(fs, num_symbols, OS, alpha);
[iq300, fs1] = QAMsignalGenerator(fs1, num_symbols, OS1, alpha);

% Normalize signals
iq60  = iq60/(2*rms(iq60));
iq300 = iq300/(2*rms(iq300));           % Reference signal

ND = length(iq60);
NU = L*(ND-1)+1;

save_plots(iq60, fs, '60Msps Signal');
plotIQfft(iq60, fs, '60Msps Signal - FFT', 50);

save_plots(iq300, fs1, 'Reference Signal');
plotIQfft(iq300, fs1, ...
    sprintf('Reference Signal - FFT (L = %d)', L), ...
    fs1/(2e6));


%% MATLAB built-in spline interpolation

t_D = (0:ND-1)/fs;                      % Original sample locations
t_U = (0:NU-1)/fs1;                     % Interpolated sample locations

I_in = real(iq60);
Q_in = imag(iq60);

I_spline = interp1(t_D, I_in, t_U, 'spline');
Q_spline = interp1(t_D, Q_in, t_U, 'spline');

iq60_spline = I_spline + 1j*Q_spline;

save_plots(iq60_spline, fs1, ...
    'MATLAB Spline', 'before filtering');

plotIQfft(iq60_spline, fs1, ...
    sprintf('MATLAB Spline Spectrum (L = %d)', L), ...
    fs1/(2e6));


%% Floating-point MINAJ2 interpolation

iq60_splinefloat = interp_minAJ2(iq60, L);

save_plots(iq60_splinefloat, fs1, ...
    'MINAJ2 Floating Point', 'before filtering');

plotIQfft(iq60_splinefloat, fs1, ...
    sprintf('Floating-Point MINAJ2 Spectrum (L = %d)', L), ...
    fs1/(2e6));


%% Align floating-point MINAJ2 signal with reference

[cc, lags] = xcorr(iq300, iq60_splinefloat);

[~, idxMax] = max(abs(cc));
bestLag = lags(idxMax);

if bestLag > 0

    % Floating-point signal is earlier than reference
    d = bestLag;

    orig_al  = iq300(1+d:end);
    float_al = iq60_splinefloat(1:end-d);

elseif bestLag < 0

    d = -bestLag;

    orig_al  = iq300(1:end-d);
    float_al = iq60_splinefloat(1+d:end);

else

    orig_al  = iq300;
    float_al = iq60_splinefloat;

end

fprintf('Best lag = %d samples\n', bestLag);


%% Compare Floating-Point MINAJ2 vs Reference
% Plot first 3000 samples, including startup transient

nPlot = min(3000, min(length(orig_al), length(float_al)));
n = 0:nPlot-1;

figure('Position',[100 100 1100 700]);

tiledlayout(2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');


% -------------------------------------------------------------
% I Component
% -------------------------------------------------------------
nexttile;

plot(n, real(orig_al(1:nPlot)), ...
    'LineWidth',1.4);

hold on;

plot(n, real(float_al(1:nPlot)), ...
    '--', ...
    'LineWidth',1.4);

grid on;

xlabel('Sample Index');
ylabel('Amplitude');

title('I Component');

legend('Reference','Floating-Point', ...
    'Location','best');

xlim([0 nPlot-1]);


% -------------------------------------------------------------
% Q Component
% -------------------------------------------------------------
nexttile;

plot(n, imag(orig_al(1:nPlot)), ...
    'LineWidth',1.4);

hold on;

plot(n, imag(float_al(1:nPlot)), ...
    '--', ...
    'LineWidth',1.4);

grid on;

xlabel('Sample Index');
ylabel('Amplitude');

title('Q Component');

legend('Reference','Floating-Point', ...
    'Location','best');

xlim([0 nPlot-1]);


% -------------------------------------------------------------
% I Error
% -------------------------------------------------------------
nexttile;

plot(n, ...
    real(orig_al(1:nPlot) - float_al(1:nPlot)), ...
    'LineWidth',1.3);

grid on;

xlabel('Sample Index');
ylabel('Error');

title('I-Component Error');

xlim([0 nPlot-1]);


% -------------------------------------------------------------
% Q Error
% -------------------------------------------------------------
nexttile;

plot(n, ...
    imag(orig_al(1:nPlot) - float_al(1:nPlot)), ...
    'LineWidth',1.3);

grid on;

xlabel('Sample Index');
ylabel('Error');

title('Q-Component Error');

xlim([0 nPlot-1]);


sgtitle(sprintf( ...
    'Floating-Point MINAJ2 vs. Reference Signal (L = %d)', L), ...
    'FontWeight','bold');


set(findall(gcf,'Type','axes'), ...
    'FontSize',11, ...
    'LineWidth',1);

% Optional:
exportgraphics(gcf, ...
    sprintf('Floating_vs_Reference_L%d.png',L), ...
   'Resolution',300);


%% Fixed-point parameters

% Estimated noise floor
N = length(iq60_spline);

X = fftshift(fft(iq60_spline)/N);

f = linspace(-fs1/2, fs1/2, N);

magdB = 20*log10( ...
    abs(X)/max(abs(X)) + eps);


% Frequencies outside useful signal band
idx = abs(f) > BW/2 + 5e6;

noise_floor_dB = mean(magdB(idx));

fprintf('Estimated noise floor = %.2f dB\n', ...
    noise_floor_dB);


max_val = max(abs(iq60_spline));

IL = ceil(log2(max_val));

fprintf( ...
    'Maximum value = %.4f, integer length = %.4f\n', ...
    max_val, IL);


fl = 12;                                % Fraction length
wl = 16;                                % Word length


%% Fixed-point MINAJ2 interpolation

iq60_splineFixed = ...
    minAJ2_fixed(iq60(1:2400), L, wl, fl);


save_plots( ...
    double(iq60_splineFixed), ...
    fs1, ...
    'MINAJ2 Fixed Point', ...
    'before filtering');


plotIQfft( ...
    double(iq60_splineFixed), ...
    fs1, ...
    sprintf('Fixed-Point MINAJ2 Spectrum (L = %d)', L), ...
    fs1/(2e6));


%% Compare Fixed-Point MINAJ2 vs Reference
% Plot first 1500 samples, including startup transient

fixed_sig = double(iq60_splineFixed);

nPlot = min(3000, ...
    min(length(iq300), length(fixed_sig)));

n = 0:nPlot-1;


figure('Position',[100 100 1100 700]);

tiledlayout(2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');


% -------------------------------------------------------------
% I Component
% -------------------------------------------------------------
nexttile;

plot(n, real(iq300(1:nPlot)), ...
    'LineWidth',1.4);

hold on;

plot(n, real(fixed_sig(1:nPlot)), ...
    '--', ...
    'LineWidth',1.4);

grid on;

xlabel('Sample Index');
ylabel('Amplitude');

title('I Component');

legend('Reference','Fixed-Point', ...
    'Location','best');

xlim([0 nPlot-1]);


% -------------------------------------------------------------
% Q Component
% -------------------------------------------------------------
nexttile;

plot(n, imag(iq300(1:nPlot)), ...
    'LineWidth',1.4);

hold on;

plot(n, imag(fixed_sig(1:nPlot)), ...
    '--', ...
    'LineWidth',1.4);

grid on;

xlabel('Sample Index');
ylabel('Amplitude');

title('Q Component');

legend('Reference','Fixed-Point', ...
    'Location','best');

xlim([0 nPlot-1]);


% -------------------------------------------------------------
% I Error
% -------------------------------------------------------------
nexttile;

plot(n, real(iq300(1:nPlot) - fixed_sig(1:nPlot)), 'LineWidth',1.3);

grid on;

xlabel('Sample Index');
ylabel('Error');

title('I-Component Error');

xlim([0 nPlot-1]);


% -------------------------------------------------------------
% Q Error
% -------------------------------------------------------------
nexttile;

plot(n, ...
    imag(iq300(1:nPlot) - fixed_sig(1:nPlot)), ...
    'LineWidth',1.3);

grid on;

xlabel('Sample Index');
ylabel('Error');

title('Q-Component Error');

xlim([0 nPlot-1]);


sgtitle(sprintf( ...
    'Fixed-Point MINAJ2 vs. Reference Signal (L = %d)', L), ...
    'FontWeight','bold');


set(findall(gcf,'Type','axes'), ...
    'FontSize',11, ...
    'LineWidth',1);


exportgraphics(gcf,sprintf('Fixed_vs_Reference_L%d.png',L),'Resolution',300);


%% Calculate RMSE
% Exclude first 500 samples because of startup transient

transientSamples = 500;


% =============================================================
% Floating-Point RMSE
% =============================================================

orig_al  = orig_al(:);
float_al = float_al(:);

len1 = min(length(float_al),length(orig_al));


if len1 <= transientSamples

    error( ...
        'Not enough samples to remove the first %d transient samples.', ...
        transientSamples);

end


% Remove transient samples only for RMSE calculation
orig_rmse = ...
    orig_al(transientSamples+1 : len1);

float_rmse = ...
    float_al(transientSamples+1 : len1);


rmse_float = sqrt( ...
    mean(abs(orig_rmse - float_rmse).^2));


rmse_dB = ...
    20*log10(rmse_float);


fprintf( ...
    'Floating-point signal length = %d, reference signal length = %d\n', ...
    length(float_al), ...
    length(orig_al));


fprintf( ...
    ['Floating-point RMSE after removing first %d samples: ' ...
     'RMSE = %.6f, RMSE = %.2f dB\n'], ...
    transientSamples, ...
    rmse_float, ...
    rmse_dB);


% =============================================================
% Fixed-Point RMSE
% =============================================================

iq300 = iq300(:);

iq60_SplineFixed = ...
    double(iq60_splineFixed(:));


len2 = min( ...
    length(iq300), ...
    length(iq60_SplineFixed));


if len2 <= transientSamples

    error( ...
        'Not enough samples to remove the first %d transient samples.', ...
        transientSamples);

end


% Remove transient samples only for RMSE calculation
ref_fixed_rmse =  iq300(transientSamples+1 : len2);

test_fixed_rmse = iq60_SplineFixed(transientSamples+1 : len2);


rmse_fixed = sqrt(mean(abs(ref_fixed_rmse - test_fixed_rmse).^2));


rmse_fixed_dB =  20*log10(rmse_fixed);


fprintf( ...
    ['Fixed-point RMSE after removing first %d samples: ' ...
     'RMSE = %.6f, RMSE = %.2f dB\n'], ...
    transientSamples, ...
    rmse_fixed, ...
    rmse_fixed_dB);


%% RMSE summary

fprintf('\n');
fprintf('===============================================================\n');
fprintf('                 RMSE REPORT - Before Filtering\n');
fprintf('                      L = %d\n', L);
fprintf('             First %d transient samples excluded\n', ...
    transientSamples);
fprintf('===============================================================\n');

fprintf( ' Floating-Point : RMSE_linear = %.6f, RMSE_dB = %.2f dB\n', ...
    rmse_float, ...
    rmse_dB);

fprintf(  ' Fixed-Point    : RMSE_linear = %.6f, RMSE_dB = %.2f dB\n', ...
    rmse_fixed, ...
    rmse_fixed_dB);

fprintf('===============================================================\n');



%% Local Functions
% =============================================================


%% QAM-64 signal generator

function [iqdata,fs] = ...
    QAMsignalGenerator(fs,num_symbols,OS,alpha)

[iqdata, ~, ~, ~, ~] = iqmod( ...
    'sampleRate', fs, ...
    'numSymbols', num_symbols, ...
    'data', 'Random', ...
    'modType', 'QAM64', ...
    'oversampling', OS, ...
    'shift', 0, ...
    'invert', 0, ...
    'filterType', 'Root Raised Cosine', ...
    'filterNsym', 80, ...
    'filterBeta', alpha, ...
    'carrierOffset', 0, ...
    'magnitude', 0, ...
    'quadErr', 0, ...
    'iqskew', 0, ...
    'gainImbalance', 0, ...
    'XYgainImbalance', 0, ...
    'correction', 0, ...
    'snlCorrection', 0, ...
    'phasenoise', 0, ...
    'function', 'download');

end


%% FIR1 low-pass filter

function iq_filtered = ...
    LPF_fir1(BW, Fs, iq)

fc = 0.85 * BW;

Wn = fc/(Fs/2);

Nfir = 256;

b = fir1( Nfir, Wn, 'low',hamming(Nfir+1));

iq_filtered = filter(b,1,iq);
fprintf( ...
    'Cutoff = %.2f MHz | DC gain = %.6f\n', ...
    fc/1e6, ...
    sum(b));

end


%% Manual FIR coefficient design

function b = designLPF_manual(BW,alpha,Fs,Nfir)

fc = (BW/2)*(1+alpha);

fc_norm = fc/(Fs/2);

n = 0:Nfir;

m = n-Nfir/2;

hideal = 2*fc_norm*sinc(2*fc_norm*m);
w =  hamming(Nfir+1).';

b =  hideal.*w;

% Normalize DC gain
b =  b/sum(b);

end


%% Manual fixed-point FIR

function y_fx = ...
    LPF_manual_fixed( ...
    BW,alpha,Fs,x,wl,fl,Nfir)

% Design floating-point coefficients
b_d = ...
    designLPF_manual(BW,alpha,Fs,Nfir);


% Fixed-point type
T = numerictype(1,wl,fl);

F = fimath( ...
    'RoundingMethod','Nearest', ...
    'OverflowAction','Saturate', ...
    'ProductMode','SpecifyPrecision', ...
    'ProductWordLength',wl, ...
    'ProductFractionLength',fl, ...
    'SumMode','SpecifyPrecision', ...
    'SumWordLength',wl, ...
    'SumFractionLength',fl);


% Quantize input and coefficients
b_fx = fi(b_d,T,F);

x_fx = fi(x,T,F);


% FIR convolution
y_fx = ...
    fi(zeros(size(x_fx)),T,F);

Lsig = length(x_fx);

M = length(b_fx);


for n = 1:Lsig

    acc = fi(0,T,F);

    for k = 1:M

        idx = n-k+1;

        if idx >= 1

            acc = ...
                acc + b_fx(k)*x_fx(idx);

        end

    end

    y_fx(n) = acc;

end


fprintf( ...
    'DC gain of LPF_fixed = %.4f linear, %.4f dB\n', ...
    double(sum(b_fx)), ...
    20*log10(double(sum(b_fx))));

end


%% Plot normalized IQ FFT

function plotIQfft( ...
    iq,fs,title_str,freq_limit)

if nargin < 4

    freq_limit = ...
        fs/(2e6);

end


N = length(iq);

X = fftshift(fft(iq)/N);

f = linspace(-fs/2,fs/2,N);

magdB =20*log10(abs(X)/max(abs(X)) + eps);


figure;

plot( f/1e6,magdB,'LineWidth',1.2);

xlim([-freq_limit freq_limit]);

ylim([-140 5]);

grid on;

xlabel('Frequency (MHz)');
ylabel('Normalized Magnitude (dB)');

title(title_str);

set(gca,'FontSize',11,'LineWidth',1);

end


%% EVM calculation

function [EVM_linear,EVM_dB] =calc_evm(ref,test)

ref  = ref(:);
test = test(:);

N = min( length(ref),length(test));

ref  = ref(1:N);
test = test(1:N);

err = test-ref;


EVM_linear = sqrt(  sum(abs(err).^2) / sum(abs(ref).^2));


EVM_dB = 20*log10(EVM_linear);

end


%% Plot and save time-domain and spectrum figures

function save_plots( iqdata,fs,filename,stage)

if nargin < 4 || isempty(stage)

    stage = '';

end


t = (0:length(iqdata)-1)/fs * 1e6;


% =============================================================
% Time-domain figure
% =============================================================

fig1 = figure('Visible','off');

plot(  t, real(iqdata), 'LineWidth',1.1);

hold on;

plot(  t,  imag(iqdata), 'LineWidth',1.1);

xlabel('Time (\mus)');
ylabel('Amplitude');

legend('I','Q');

grid on;


if isempty(stage)
    title( ...
        [filename ...
         ' - Time Domain, f_s = ' ...
         num2str(fs/1e6) ...
         ' MSa/s']);

else

    title( ...
        [filename ...
         ' (' ...
         stage ...
         ') - Time Domain']);

end


fname_time = ...
    ['QAM64_' ...
     filename ...
     '_' ...
     stage ...
     '_TimeDomain.fig'];

fname_time = ...
    strrep(fname_time,' ','_');

savefig(fig1,fname_time);

close(fig1);


% =============================================================
% Spectrum figure
% =============================================================

fig2 = figure('Visible','off');

pspectrum(iqdata,fs);


if isempty(stage)

    title( ...
        [filename ...
         ' Spectrum - f_s = ' ...
         num2str(fs/1e6) ...
         ' MSa/s']);

else

    title( ...
        [filename ...
         ' (' ...
         stage ...
         ') - Spectrum']);

end


fname_spec = ...
    ['QAM64_' ...
     filename ...
     '_' ...
     stage ...
     '_Spectrum.fig'];

fname_spec =strrep(fname_spec,' ','_');

savefig(fig2,fname_spec);

close(fig2);


% Open saved figures
openfig( fname_time, 'new', 'visible');

openfig( fname_spec,'new','visible');

end

