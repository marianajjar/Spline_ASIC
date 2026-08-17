% RUN_ALL_MODES
% Big tapeout regression + VSA MAT export.
%
% Run from tapeout_verif/sim:
%   addpath('../golden')
%   run_all_modes
%
% First run:
%   creates seg*.txt, manifest.txt, regression_golden.mat, and golden/input VSA files.
%
% Then run simulator:
%   ./run_vcs.sh    or    ./run_sim.sh
%
% Second MATLAB run:
%   compares seg*.txt.out and saves RTL VSA MAT files.

clear; clc;

WL = 16;
FL = 12;
fs_in = 60e6;
FIR_ROUND = 0;

% Bigger QAM signal for VSA/EVM.
% 4000 symbols at 3 samples/symbol gives enough data for EVM.
QAM_SYMBOLS = 4000;
QAM_SPS     = 3;
QAM_ALPHA   = 0.15;

% Corner tests do not need as many samples for EVM.
NSAMP_CORNER = 1024;

Ls = [2 3 4 5];

pairs = [];
for a = Ls
    for b = Ls
        if a ~= b
            pairs(end+1,:) = [a b]; %#ok<AGROW>
        end
    end
end

make_vsa_dirs();

manifest = {};
golden = struct();
seg_id = 0;
seed0 = 7000;

fprintf('\n============================================================\n');
fprintf('Generating big regression + VSA files\n');
fprintf('QAM normal segments: %d symbols, %d samples/symbol\n', QAM_SYMBOLS, QAM_SPS);
fprintf('============================================================\n');

% ============================================================
% 1) Transition regression segments, long QAM for VSA/EVM
% ============================================================
for p = 1:size(pairs,1)
    for L = pairs(p,:)
        seg_id = seg_id + 1;
        name = sprintf('seg%02d_L%d.txt', seg_id, L);

        [I,Q,co,input_cx] = make_segment(L, 'qam', QAM_SYMBOLS, QAM_SPS, ...
                                         QAM_ALPHA, NSAMP_CORNER, WL, FL, fs_in, seed0+seg_id);

        gen_tb_input(L, co, I, Q, name);

        [dI,dQ,uI,uQ] = spline_golden_rtl(I, Q, L, co, FIR_ROUND);

        fs_out = L * fs_in;
        key = matlab.lang.makeValidName(name);
        golden.(key) = struct('I',dI,'Q',dQ,'uI',uI,'uQ',uQ,'L',L,'fs_out',fs_out);

        manifest{end+1} = name; %#ok<SAGROW>

        save_segment_vsa(name, input_cx, fs_in, uI, uQ, dI, dQ, fs_out, FL);
    end
end

% ============================================================
% 2) Corner cases
% ============================================================
corners = {
    'zero',      2
    'dc',        4
    'impulse',   5
    'fullscale', 3
    'fullscale', 2
    'maxsat',    4
};

for c = 1:size(corners,1)
    kind = corners{c,1};
    L = corners{c,2};

    seg_id = seg_id + 1;
    name = sprintf('seg%02d_%s_L%d.txt', seg_id, kind, L);

    [I,Q,co,input_cx] = make_segment(L, kind, QAM_SYMBOLS, QAM_SPS, ...
                                     QAM_ALPHA, NSAMP_CORNER, WL, FL, fs_in, seed0+seg_id);

    gen_tb_input(L, co, I, Q, name);

    [dI,dQ,uI,uQ] = spline_golden_rtl(I, Q, L, co, FIR_ROUND);

    fs_out = L * fs_in;
    key = matlab.lang.makeValidName(name);
    golden.(key) = struct('I',dI,'Q',dQ,'uI',uI,'uQ',uQ,'L',L,'fs_out',fs_out);

    manifest{end+1} = name; %#ok<SAGROW>

    save_segment_vsa(name, input_cx, fs_in, uI, uQ, dI, dQ, fs_out, FL);
end

% ============================================================
% 3) Write manifest and golden database
% ============================================================
fid = fopen('manifest.txt','w');
for k = 1:numel(manifest)
    fprintf(fid, '%s\n', manifest{k});
end
fclose(fid);

save('regression_golden.mat', 'manifest', 'golden', 'WL', 'FL', ...
     'FIR_ROUND', 'QAM_SYMBOLS', 'QAM_SPS', 'QAM_ALPHA', 'NSAMP_CORNER');

fprintf('\nGenerated %d segments.\n', numel(manifest));
fprintf('manifest.txt written.\n');
fprintf('Golden/Input VSA MAT files saved under: vsa/\n');
fprintf('\nNow run simulator, then run this MATLAB script again to compare and save RTL VSA.\n\n');

% ============================================================
% 4) If RTL outputs exist, compare and save RTL VSA MAT files
% ============================================================
npass = 0;
nfail = 0;

for k = 1:numel(manifest)
    name = manifest{k};
    of = [name '.out'];

    if isfile(of)
        key = matlab.lang.makeValidName(name);
        g = golden.(key);

        fprintf('%-32s : ', name);
        [ok, offset, ~] = compare_rtl_golden(of, g.I, g.Q);

        [rtlI_all, rtlQ_all] = read_hex_pairs_local(of);
        rtl_raw = complex(double(rtlI_all), double(rtlQ_all)) / 2^FL;
        saveVsaMat(fullfile('vsa','rtl_raw', [strip_txt(name) '_rtl_raw.mat']), ...
                   rtl_raw, g.fs_out);

        Ng = numel(g.I);
        rtlI = rtlI_all(offset+1 : offset+Ng);
        rtlQ = rtlQ_all(offset+1 : offset+Ng);
        rtl_aligned = complex(double(rtlI), double(rtlQ)) / 2^FL;

        saveVsaMat(fullfile('vsa','rtl_dac_aligned', [strip_txt(name) '_rtl_dac_aligned.mat']), ...
                   rtl_aligned, g.fs_out);

        if ok
            npass = npass + 1;
        else
            nfail = nfail + 1;
        end
    end
end

if (npass + nfail) > 0
    fprintf('\n==== REGRESSION: %d passed, %d failed ====\n', npass, nfail);
    fprintf('RTL VSA MAT files saved under:\n');
    fprintf('  vsa/rtl_raw/\n');
    fprintf('  vsa/rtl_dac_aligned/\n');
end

% ============================================================
% Local functions
% ============================================================
function [I,Q,co,input_cx] = make_segment(L, kind, qam_symbols, qam_sps, qam_alpha, ...
                                          n_corner, WL, FL, fs_in, seed)
    is15 = (L == 3 || L == 5);

    if strcmp(kind, 'maxsat')
        co = repmat(int_sat(2^(WL-1)-1, WL), 10, 1);
    else
        co = make_coeffs(L, fs_in, WL, FL);
    end

    switch kind
        case 'qam'
            iq = makeQAM(fs_in, qam_sps, qam_alpha, qam_symbols, seed);
            iq = iq(:);
            iq = iq / (2 * sqrt(mean(abs(iq).^2)));

            I = int_sat(round(real(iq) * 2^FL), WL);
            Q = int_sat(round(imag(iq) * 2^FL), WL);

        case 'zero'
            I = zeros(n_corner,1);
            Q = zeros(n_corner,1);

        case 'dc'
            if is15
                I = 4000 * ones(n_corner,1);
                Q = 4000 * ones(n_corner,1);
            else
                I = 8000 * ones(n_corner,1);
                Q = 8000 * ones(n_corner,1);
            end

        case 'impulse'
            I = zeros(n_corner,1);
            Q = zeros(n_corner,1);
            I(4) = 20000;
            Q(4) = 20000;

        case 'fullscale'
            I = repmat([2^(WL-1)-1; -2^(WL-1)], ceil(n_corner/2), 1);
            Q = repmat([-2^(WL-1); 2^(WL-1)-1], ceil(n_corner/2), 1);
            I = I(1:n_corner);
            Q = Q(1:n_corner);

        case 'maxsat'
            I = repmat([2^(WL-1)-1; 2^(WL-1)-1; -2^(WL-1); -2^(WL-1)], ...
                       ceil(n_corner/4), 1);
            Q = repmat([2^(WL-1)-1; -2^(WL-1); 2^(WL-1)-1; -2^(WL-1)], ...
                       ceil(n_corner/4), 1);
            I = I(1:n_corner);
            Q = Q(1:n_corner);

        otherwise
            error('unknown segment kind: %s', kind);
    end

    if is15
        I = signext15(I);
        Q = signext15(Q);
    else
        I = int_sat(I, WL);
        Q = int_sat(Q, WL);
    end

    input_cx = complex(double(I), double(Q)) / 2^FL;
end

function coeffs_int = make_coeffs(L, fs_in, WL, FL)
    fs_out = L * fs_in;
    Fm = [0, 14e6, 44e6, fs_out/2] / (fs_out/2);
    hm = firpm(10-1, Fm, [1 1 0 0], [10000, 200]);
    coeffs_int = int_sat(round(hm(:) * 2^FL), WL);
end

function q = int_sat(x, WL)
    q = max(min(round(x(:)), 2^(WL-1)-1), -2^(WL-1));
end

function y = signext15(x)
    u = mod(round(x(:)), 32768);
    y = u - 32768 * (u >= 16384);
end

function save_segment_vsa(name, input_cx, fs_in, uI, uQ, dI, dQ, fs_out, FL)
    base = strip_txt(name);

    golden_prefir = complex(double(uI), double(uQ)) / 2^FL;
    golden_dac    = complex(double(dI), double(dQ)) / 2^FL;

    saveVsaMat(fullfile('vsa','input', [base '_input.mat']), ...
               input_cx, fs_in);

    saveVsaMat(fullfile('vsa','golden_prefir', [base '_golden_prefir.mat']), ...
               golden_prefir, fs_out);

    saveVsaMat(fullfile('vsa','golden_dac', [base '_golden_dac.mat']), ...
               golden_dac, fs_out);
end

function saveVsaMat(fileName, y, fs)
    Y = double(y(:));
    XDelta = 1/fs;
    InputZoom = 1;
    XStart = 0;
    save(fileName, 'Y', 'XDelta', 'InputZoom', 'XStart');
end

function make_vsa_dirs()
    dirs = {
        fullfile('vsa','input')
        fullfile('vsa','golden_prefir')
        fullfile('vsa','golden_dac')
        fullfile('vsa','rtl_raw')
        fullfile('vsa','rtl_dac_aligned')
    };

    for k = 1:numel(dirs)
        if ~exist(dirs{k}, 'dir')
            mkdir(dirs{k});
        end
    end
end

function base = strip_txt(name)
    [~, base, ~] = fileparts(name);
end

function [I, Q] = read_hex_pairs_local(fname)
    fid = fopen(fname, 'r');
    if fid < 0
        error('cannot open %s', fname);
    end

    I = [];
    Q = [];

    while true
        ln = fgetl(fid);
        if ~ischar(ln)
            break;
        end

        ln = strtrim(ln);
        if isempty(ln)
            continue;
        end

        t = sscanf(ln, '%x %x');
        if numel(t) == 2
            I(end+1,1) = s16(t(1)); %#ok<AGROW>
            Q(end+1,1) = s16(t(2)); %#ok<AGROW>
        end
    end

    fclose(fid);
end

function v = s16(u)
    u = mod(u, 65536);
    v = u - 65536 * (u >= 32768);
end
