clear;close all;clc;

Ls = 2:5;

fs_in = 60e6;
num_symbols = 4000;
OS60 = 3;
alpha = 0.15;

NTAPS = 10;
F_PASS = 14e6;
F_STOP = 44e6;
W_PASS = 10000;
W_STOP = 200;

WL = 16;
FL = 12;

OUT_DIR = getDocumentsOutputFolder();

VSA_PREFIR_MAT_DIR = fullfile(OUT_DIR, 'vsa_prefir_mat');
VSA_PREFIR_TXT_DIR = fullfile(OUT_DIR, 'vsa_prefir_txt');
VSA_FINAL_MAT_DIR  = fullfile(OUT_DIR, 'vsa_final_mat');
VSA_FINAL_TXT_DIR  = fullfile(OUT_DIR, 'vsa_final_txt');

makeDir(VSA_PREFIR_MAT_DIR);
makeDir(VSA_PREFIR_TXT_DIR);
makeDir(VSA_FINAL_MAT_DIR);
makeDir(VSA_FINAL_TXT_DIR);

allCoeffTables = cell(numel(Ls), 1);

for iL = 1:numel(Ls)

    L = Ls(iL);
    fs_out = L * fs_in;

    fprintf('\n========================================\n');
    fprintf('L = %d | Fs_out = %.0f MHz\n', L, fs_out/1e6);
    fprintf('========================================\n');

    rng(1000 + L);

    [iq60, ~] = QAMsignalGenerator( ...
        fs_in, num_symbols, OS60, alpha);

    iq60 = iq60 / (2 * rms(iq60));

    Nin = min(5000, length(iq60));

    iq_spline = minAJ2_fixed( ...
        iq60(1:Nin), L, WL, FL);

    prefir_vsa = complex( ...
        double(real(iq_spline(:))), ...
        double(imag(iq_spline(:))));

    saveVsaMat( ...
        fullfile(VSA_PREFIR_MAT_DIR, sprintf('L%d_prefir_signal.mat', L)), ...
        prefir_vsa, ...
        fs_out);

    saveIQTxt( ...
        fullfile(VSA_PREFIR_TXT_DIR, sprintf('L%d_prefir_signal.txt', L)), ...
        prefir_vsa);

    [iq_filtered, coeffTable] = applyFIRFilterFixedIQ_pm( ...
        iq_spline, ...
        fs_out, ...
        F_PASS, ...
        F_STOP, ...
        W_PASS, ...
        W_STOP, ...
        NTAPS, ...
        WL, ...
        FL);

    coeffTable.L = repmat(L, height(coeffTable), 1);
    coeffTable = movevars(coeffTable, 'L', 'Before', 'Tap');
    allCoeffTables{iL} = coeffTable;

    fprintf('\nCoefficients for L = %d:\n', L);
    disp(coeffTable);

    final_vsa = complex( ...
        double(real(iq_filtered(:))), ...
        double(imag(iq_filtered(:))));

    saveVsaMat( ...
        fullfile(VSA_FINAL_MAT_DIR, sprintf('L%d_final_signal.mat', L)), ...
        final_vsa, ...
        fs_out);

    saveIQTxt( ...
        fullfile(VSA_FINAL_TXT_DIR, sprintf('L%d_final_signal.txt', L)), ...
        final_vsa);

end

coeffAll = vertcat(allCoeffTables{:});
coeffCsv = fullfile(OUT_DIR, 'firpm_coefficients_all_L.csv');
writetable(coeffAll, coeffCsv);

fprintf('\nFinished.\n');
fprintf('Results folder: %s\n', OUT_DIR);
fprintf('Coefficient table: %s\n', coeffCsv);


function [y_filt, coeffTable] = applyFIRFilterFixedIQ_pm( ...
    x, fs, f_pass, f_stop, w_pass, w_stop, Ntaps, WL, FL)

nyq = fs / 2;

Fm = [0 f_pass f_stop nyq] / nyq;

h_float = firpm( ...
    Ntaps - 1, ...
    Fm, ...
    [1 1 0 0], ...
    [w_pass w_stop]);

h_float = h_float(:);

coeff_int = int_sat( ...
    round(h_float * 2^FL), ...
    WL);

h_q12 = double(coeff_int) / 2^FL;

SumWL = WL + ceil(log2(Ntaps));

F = fimath( ...
    'ProductMode', 'SpecifyPrecision', ...
    'ProductWordLength', WL + 2, ...
    'ProductFractionLength', FL, ...
    'SumMode', 'SpecifyPrecision', ...
    'SumWordLength', SumWL, ...
    'SumFractionLength', FL, ...
    'OverflowAction', 'Saturate', ...
    'RoundingMethod', 'Nearest');

b_fi = fi( ...
    h_q12, ...
    1, ...
    WL, ...
    FL, ...
    'fimath', F);

tap = (0:Ntaps-1).';

coeff_hex = cellstr( ...
    dec2hex( ...
        mod(double(coeff_int), 2^WL), ...
        4));

coeffTable = table( ...
    tap, ...
    h_float, ...
    double(b_fi), ...
    double(coeff_int), ...
    coeff_hex, ...
    'VariableNames', ...
    {'Tap','FloatCoeff','Q12Coeff','IntValue','Hex'});

xR = fi(real(x), 1, WL, FL, 'fimath', F);
xI = fi(imag(x), 1, WL, FL, 'fimath', F);

Lx = length(xR);
M = length(b_fi);

zr = fi(zeros(M,1), 1, WL, FL, 'fimath', F);
zq = fi(zeros(M,1), 1, WL, FL, 'fimath', F);

yR = fi(zeros(Lx,1), 1, WL, FL, 'fimath', F);
yQ = fi(zeros(Lx,1), 1, WL, FL, 'fimath', F);

for n = 1:Lx
    zr = [xR(n); zr(1:end-1)];
    zq = [xI(n); zq(1:end-1)];

    yR(n) = dot(b_fi, zr);
    yQ(n) = dot(b_fi, zq);
end

y_filt = yR + 1j*yQ;

end


function saveVsaMat(fileName, y, fs)

Y = double(y(:));
XDelta = 1 / fs;
InputZoom = 1;
XStart = 0;

save(fileName, 'Y', 'XDelta', 'InputZoom', 'XStart');

end


function saveIQTxt(fileName, y)

y = double(y(:));

fid = fopen(fileName, 'w');

if fid < 0
    error('Cannot open %s for writing.', fileName);
end

cleanupObj = onCleanup(@() fclose(fid)); 

fprintf(fid, '%.15g %.15g\n', [real(y).'; imag(y).']);

end


function q = int_sat(x, WL)

q = max( ...
    min(round(x(:)), 2^(WL-1)-1), ...
    -2^(WL-1));

end


function [iqdata, fs] = QAMsignalGenerator(fs, num_symbols, OS, alpha)

[iqdata,~,~,~,~] = iqmod( ...
    'sampleRate', fs, ...
    'numSymbols', num_symbols, ...
    'data', 'Random', ...
    'modType', 'QAM64', ...
    'oversampling', OS, ...
    'filterType', 'Root Raised Cosine', ...
    'filterNsym', 80, ...
    'filterBeta', alpha);

end


function makeDir(pathName)

if ~exist(pathName, 'dir')
    mkdir(pathName);
end

end


function OUT_DIR = getDocumentsOutputFolder()

if ispc

    oneDrive = getenv('OneDrive');

    if ~isempty(oneDrive) && isfolder(fullfile(oneDrive, 'Documents'))
        documentsPath = fullfile(oneDrive, 'Documents');
    else
        documentsPath = fullfile(getenv('USERPROFILE'), 'Documents');
    end

else

    documentsPath = fullfile(getenv('HOME'), 'Documents');

end

OUT_DIR = fullfile(documentsPath, 'firpm_all_modes_results');
makeDir(OUT_DIR);

end
