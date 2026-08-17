function [dacI, dacQ, uI, uQ] = spline_golden_rtl(I_int, Q_int, L, coeffs_int, fir_round)
% SPLINE_GOLDEN_RTL  Bit-exact integer model of the spline interpolator RTL.
%
% Outputs are signed Q3.12 integer codes, not floating-point values.

    if nargin < 5
        fir_round = 0;
    end

    I_int = double(I_int(:));
    Q_int = double(Q_int(:));
    coeffs_int = double(coeffs_int(:));

    uI = minaj2_stream(I_int, L);
    uQ = minaj2_stream(Q_int, L);

    dacI = fir_stream(uI, coeffs_int, 12, fir_round);
    dacQ = fir_stream(uQ, coeffs_int, 12, fir_round);
end

% =====================================================================
% MinAJ2 interpolation, streamed like RTL
% =====================================================================
function u = minaj2_stream(s, L)
    N = numel(s);
    U = u_table(L);

    u = zeros(N*L, 1);
    oi = 1;

    m_p = 0;
    w0 = 0;
    w1 = 0;
    w2 = 0;

    for i = 1:N
        w2 = w1;
        w1 = w0;
        w0 = s(i);

        x_prev = w2;
        x_c    = w1;
        x_n    = w0;

        [y, m_new] = minaj2_segment(x_prev, x_c, x_n, m_p, L, U);

        u(oi:oi+L-1) = y;
        oi = oi + L;

        m_p = m_new;
    end
end

function [y, m_new] = minaj2_segment(x_prev, x_c, x_n, m_p, L, U)
    % ---- slope update ----
    Sum      = 8*x_c + 3*x_n - 11*x_prev - 4*m_p;
    mult_res = Sum * 1638;
    raw_m    = sra(mult_res + 8192, 14);
    m_new    = sat16(raw_m);

    % ---- RTL c0..c3 are signed [17:0] ----
    delta = x_c - x_prev;

    c0 = wrapN(x_prev, 18);
    c1 = wrapN(m_p, 18);
    c2 = wrapN(3*delta - 2*m_p - m_new, 18);
    c3 = wrapN(m_p + m_new - 2*delta, 18);

    % ---- outputs ----
    y = zeros(L, 1);
    y(1) = wrap16(x_prev);

    for j = 2:L
        y(j) = eval_poly(c0, c1, c2, c3, U(j-1));
    end
end

function r = eval_poly(c0, c1, c2, c3, U)
    t1 = sra(c3 * U + 16384, 15);
    t1 = t1 + c2;

    t2 = sra(t1 * U + 16384, 15);
    t2 = t2 + c1;

    t3 = sra(t2 * U + 16384, 15);
    t3 = t3 + c0;

    r = wrap16(t3);
end

% =====================================================================
% 10-tap FIR
% =====================================================================
function y = fir_stream(u, coeffs, FL, do_round)
    N = numel(u);
    NT = numel(coeffs);

    if do_round
        RND = 2^(FL-1);
    else
        RND = 0;
    end

    y = zeros(N, 1);
    dl = zeros(NT, 1);

    for n = 1:N
        dl = [u(n); dl(1:NT-1)];

        acc = sum(dl .* coeffs);

        y(n) = sat16(sra(acc + RND, FL));
    end
end

% =====================================================================
% Q1.15 interpolation constants from RTL
% =====================================================================
function U = u_table(L)
    switch L
        case 2
            U = 16384;
        case 3
            U = [10923; 21845];
        case 4
            U = [8192; 16384; 24576];
        case 5
            U = [6554; 13107; 19661; 26214];
        otherwise
            error('L must be 2,3,4,5');
    end
end

% =====================================================================
% Integer helpers
% =====================================================================
function r = sra(v, n)
    r = floor(v ./ (2.^n));
end

function r = wrap16(v)
    r = mod(v + 32768, 65536) - 32768;
end

function r = wrapN(v, n)
    r = mod(v + 2^(n-1), 2^n) - 2^(n-1);
end

function r = sat16(v)
    r = max(min(v, 32767), -32768);
end
