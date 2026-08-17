
function y_up = minAJ2_fixed(x, L, wl, fl)
% MinAJ2 cubic Hermite interpolation
% x : input samples (real or complex)
% L : upsampling factor


 % Final output type 
    T_sig = numerictype(1, wl, fl);
    F_sig = fimath('RoundingMethod','Nearest', ...
                   'OverflowAction','Saturate', ...
                   'ProductMode','SpecifyPrecision', ...
                   'ProductWordLength', wl, ...
                   'ProductFractionLength', fl, ...
                   'SumMode','SpecifyPrecision', ...
                   'SumWordLength', wl, ...
                   'SumFractionLength', fl);

    wlA = wl + 3;
    flA = fl +2;
T = numerictype(1, wlA, flA);
F= fimath( ...
    'RoundingMethod','Nearest', ...
    'OverflowAction','Saturate', ...
    'ProductMode','SpecifyPrecision', ...
    'ProductWordLength', wlA+flA, ...
    'ProductFractionLength', flA+flA, ...
    'SumMode','SpecifyPrecision', ...
    'SumWordLength', wlA, ...
    'SumFractionLength', flA);
     %constant coefficients
    one   = fi( 1,   T, F); 
    two   = fi( 2,   T, F);
    m2  = fi(-2,   T, F);
    three  = fi( 3,   T, F);
    m3  = fi(-3,   T, F);
    m4 = fi(-0.4, T, F);
    eight=fi(0.8, T, F);
    m11=fi(-1.1, T, F);
    c3 =fi(0.3, T, F);
     half = fi(0.5, T, F);

    % Hermite basis in fixed point
    u  = fi((0:L-1)./L, T, F);
    % Hermite basis
            H00 = one + (two.*u +m3) .* u .* u;
            H10 = u .* ( one + u .* ( m2 + u ));
            H01 = u .* ( u .* ( three+m2 .* u ));
            H11 = u .* ( u .* ( u - one ) );

x = fi(x(:), T, F);
N = length(x);
Nout = (N-1)*L + 1;

y_up   = fi(zeros(Nout,1),T,F);
outIdx = 1;

% Startup slopes
% ------------------------------------
s0 = x(2) - x(1);            % slope at x(1)
s1 = half*(x(3) - x(1));     % slope at x(2)

% ------------------------------------
% Interpolate first segment [0,1] 
% ------------------------------------
x0 = x(1);
x1 = x(2);
m0 = s0;
m1 = s1;

for k = 1:L
    y_up(outIdx) = H00(k)*x0 + H01(k)*x1 + H10(k)*m0 + H11(k)*m1;
    outIdx = outIdx + 1;
end

% ------------------------------------
% Buffered steady-state
% ------------------------------------
s_prev = s1;   % this is s_{i-1}

for i = 3:N
    % compute slope s_i (with lookahead)
    if i < N
        s_curr = (m11*x(i-1) +m4*s_prev + eight*x(i) + c3*x(i+1)) ;
    else
        % terminal slope
        s_curr = x(i) - x(i-1);
    end

    % interpolate segment [i-2, i-1]
    x0 = x(i-1);
    x1 = x(i);
    m0 = s_prev;
    m1 = s_curr;

    for k = 1:L
        y_up(outIdx) = H00(k)*x0 + H01(k)*x1 + H10(k)*m0 + H11(k)*m1;
        outIdx = outIdx + 1;
    end

    s_prev = s_curr;
end

% final knot
y_up(end) = x(end);
% Cast back to final (wl, fl)
    y_up = fi(y_up, T_sig, F_sig);
end