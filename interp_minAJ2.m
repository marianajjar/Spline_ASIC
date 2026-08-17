function y_up = interp_minAJ2(x, L)
% MinAJ2 cubic Hermite interpolation
% x : input samples (real or complex)
% L : upsampling factor
x = x(:);
N = length(x);
Nout = (N-1)*L + 1;

y_up   = zeros(Nout,1);
outIdx = 1;

% ------------------------------------
% Hermite basis
% ------------------------------------
u  = (0:L-1).' / L;
u2 = u .* u;
u3 = u2 .* u;

H00 =  2*u3 - 3*u2 + 1;
H01 = -2*u3 + 3*u2;
H10 =  u3 - 2*u2 + u;
H11 =  u3 - u2;

% ------------------------------------
% Startup slopes
% ------------------------------------
s0 = x(2) - x(1);           % slope at x(1)
s1 = 0.5*(x(3) - x(1));     % slope at x(2)

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
        s_curr = (-11*x(i-1) - 4*s_prev + 8*x(i) + 3*x(i+1)) / 10;
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
end