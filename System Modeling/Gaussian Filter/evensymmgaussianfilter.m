%% BLE Gaussian FIR – EVEN-Length Symmetric, Multiplier-Free (Sample-Based)
% Type-II linear-phase FIR (no center tap)
% Uses half-sample-shifted Gaussian coefficients (64 taps for span=4, sps=16)
% RTL-style: shift register + symmetric pre-add + sign/shift logic
% Verified against MATLAB reference filter(h_even,1,x)

clear; clc; close all;

%% ------------------------
% Parameters
%% ------------------------
BT   = 0.5;
span = 4;         % symbols
sps  = 16;        % samples per symbol

L = span * sps;  % EVEN length = 64 taps
Ts_sym = 1/sps;  % sample period in symbol-time units

fprintf("Using EVEN-length FIR: L = %d taps (Type II)\n", L);
fprintf("Group delay = %.1f samples (%.3f symbols)\n", ...
        (L-1)/2, ((L-1)/2)/sps);

%% ------------------------
% Generate EVEN-length Gaussian coefficients (half-sample centered)
%% ------------------------

% Time support: [-span/2, +span/2] in symbol units
t0 = span / 2;

% Half-sample shifted grid (symmetry center between samples)
t = (-t0 + Ts_sym/2) : Ts_sym : (t0 - Ts_sym/2);
assert(length(t) == L, "Time grid mismatch");

% Gaussian sigma (symbol-time units)
sigma = sqrt(log(2)) / (2*pi*BT);

% Continuous Gaussian
g = exp(-(t.^2) / (2*sigma^2));

% Normalize for unity DC gain
h = g(:);
h = h / sum(h);

% Symmetry check
assert(max(abs(h - flipud(h))) < 1e-12, "Coefficients not symmetric");

%% ------------------------
% Generate NRZ input (sample-based)
%% ------------------------
numSymbols = 20;
bits = randi([0 1], numSymbols, 1);
nrz  = 2*bits - 1;        % {0,1} → {-1,+1}
x    = repelem(nrz, sps);

%% ------------------------
% Delay line
%% ------------------------
delayLine = zeros(L,1);

%% ------------------------
% Output buffer
%% ------------------------
y = zeros(length(x),1);

pairs = L / 2;   % 32 symmetric pairs for L=64

%% ------------------------
% Multiplier-Free EVEN-Length Symmetric FIR
%% ------------------------
% x[n] ∈ {-1,+1}
% s = x1 + x2 ∈ {-2,0,+2}
% h[k] * s = {+2h[k], 0, -2h[k]}
%
% No center tap in EVEN-length case

for n = 1:length(x)

    % Shift register (1 sample per clock)
    delayLine = [x(n); delayLine(1:end-1)];

    acc = 0;

    % Symmetric tap processing
    for k = 1:pairs
        s = delayLine(k) + delayLine(L-k+1);  % ∈ {-2,0,+2}

        if s == 2
            acc = acc + 2*h(k);
        elseif s == -2
            acc = acc - 2*h(k);
        end
        % s == 0 → no contribution
    end

    y(n) = acc;
end

%% ------------------------
% Reference FIR for verification
%% ------------------------
y_ref = filter(h, 1, x);

%% ------------------------
% Error check
%% ------------------------
max_err = max(abs(y - y_ref));
fprintf("Max absolute error vs reference = %.3e\n", max_err);

%% ------------------------
% Plot comparison
%% ------------------------
figure;
plot(y_ref, 'k', 'LineWidth', 1.5); hold on;
plot(y, 'r--', 'LineWidth', 1.2);
grid on;
title('Even-Length Gaussian FIR: RTL-Style vs MATLAB filter()');
xlabel('Sample Index');
ylabel('Amplitude');
legend('Reference FIR', 'Symmetric Multiplier-Free Model');

%% ------------------------
% Zoomed view (timing behavior)
%% ------------------------
figure;
idx = 1:min(400, length(x));
plot(idx, y_ref(idx), 'k', 'LineWidth', 1.5); hold on;
plot(idx, y(idx), 'r--', 'LineWidth', 1.2);
grid on;
title('Zoomed View – Note Half-Sample Timing Behavior (Type II FIR)');
xlabel('Sample Index');
ylabel('Amplitude');
legend('Reference FIR', 'Symmetric Multiplier-Free Model');
