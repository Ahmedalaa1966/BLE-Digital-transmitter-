clear; clc; close all;

%% ============================================================
% MATLAB checker for Gaussian filter RTL (NO TAIL FLUSH)
%
% This checker is valid for BOTH of these SystemVerilog testbenches:
%
% 1) Old no-ready TB:
%    - tb_ble_tx_chain_no_flush.sv
%    - sends one bit every SPS clocks manually
%
% 2) Better ready-based TB:
%    - tb_ble_tx_chain_no_flush_ready.sv
%    - waits for NRZ_ready_o from the upsample block
%
% IMPORTANT:
% Numerically, both TBs should produce the SAME Gaussian filter output.
% The difference is only the handshake / flow-control style.
%
% This checker assumes:
%   - no tail flush
%   - Gaussian output file contains signed Q1.15 integer samples
%   - output file name:
%         gaussian_output_samples_no_flush.txt
%
% Chain being checked:
%   bits -> NRZ (0->-1, 1->+1) -> upsample x16 -> Gaussian FIR
%
% Since there is NO tail flush, the expected output length is:
%   NUM_BITS * SPS
%% ============================================================

%% ------------------------------------------------------------
% Parameters (must match RTL)
%% ------------------------------------------------------------
BT      = 0.5;
span    = 4;
sps     = 16;

L       = span*sps;         % 64 taps
HALF    = L/2;              % 32 half taps
TAP_W   = 16;               % Q1.15 taps
FRAC_W  = 15;
OUT_W   = 16;               % Q1.15 output
ACC_W   = TAP_W + ceil(log2(HALF)) + 1; %#ok<NASGU>

%% ------------------------------------------------------------
% Packet bits (must match TB exactly)
%% ------------------------------------------------------------
bits_str = '10110010101100101101';
bits = bits_str - '0';
bits = bits(:);

%% ------------------------------------------------------------
% NRZ mapping: 0 -> -1, 1 -> +1
%% ------------------------------------------------------------
nrz = 2*bits - 1;

%% ------------------------------------------------------------
% Upsampling
%
% This matches both:
%   - the old TB that manually spaces bits by SPS clocks
%   - the ready-based TB where the upsampler controls acceptance
%
% In both cases, the effective signal entering the Gaussian filter is:
%   each NRZ symbol repeated SPS times
%% ------------------------------------------------------------
x = repelem(nrz, sps);

fprintf("Input samples = %d\n", length(x));

%% ------------------------------------------------------------
% Build Gaussian taps
%% ------------------------------------------------------------
Ts_sym = 1/sps;
t0 = span/2;
t  = (-t0 + Ts_sym/2) : Ts_sym : (t0 - Ts_sym/2);
t  = t(:);

sigma = sqrt(log(2)) / (2*pi*BT);
h = exp(-(t.^2)/(2*sigma^2));
h = h / sum(h);

assert(length(h) == L, 'Unexpected tap length');
assert(max(abs(h - flipud(h))) < 1e-12, 'Gaussian taps are not symmetric');

%% ------------------------------------------------------------
% Quantize taps to Q1.15 exactly like RTL storage
%% ------------------------------------------------------------
scale = 2^FRAC_W;

h_q = round(h * scale);

% Saturate to signed int16
h_q(h_q >  32767) =  32767;
h_q(h_q < -32768) = -32768;

% Store only half taps like RTL
h_half_q = h_q(1:HALF);

%% ------------------------------------------------------------
% Bit-accurate RTL-style Gaussian filter model (NO FLUSH)
%
% This models the current gaussian_filter_block RTL:
%   - half-tap storage
%   - symmetric pair accumulation
%   - signed integer accumulation in Q1.15 domain
%   - saturation to signed 16-bit output
%
% Since there is NO tail flush, we process only the upsampled packet samples.
%% ------------------------------------------------------------
delay_line = zeros(L,1);              % stores {-1,0,+1}
y_model_int = zeros(length(x),1);     % signed Q1.15 integer output

for n = 1:length(x)

    % shift register update (same behavior as RTL valid path)
    delay_line = [x(n); delay_line(1:end-1)];

    % wide accumulator
    acc = int64(0);

    for k = 1:HALF
        s_pair = delay_line(k) + delay_line(L-k+1);   % {-2,-1,0,1,2}
        tap    = int64(h_half_q(k));                  % stored Q1.15 integer

        switch s_pair
            case 2
                acc = acc + bitshift(tap, 1);   % +2*h
            case 1
                acc = acc + tap;                % +1*h
            case 0
                % no contribution
            case -1
                acc = acc - tap;                % -1*h
            case -2
                acc = acc - bitshift(tap, 1);   % -2*h
            otherwise
                error('Unexpected s_pair value');
        end
    end

    % Saturate to signed 16-bit Q1.15 exactly like RTL
    if acc > 32767
        y_model_int(n) = 32767;
    elseif acc < -32768
        y_model_int(n) = -32768;
    else
        y_model_int(n) = double(acc);
    end
end

fprintf("MATLAB model output samples = %d\n", length(y_model_int));

%% ------------------------------------------------------------
% Read RTL output file
%
% This file can be produced by:
%   - tb_ble_tx_chain_no_flush.sv
%   - tb_ble_tx_chain_no_flush_ready.sv
%
% as long as the file name remains:
%   gaussian_output_samples_no_flush.txt
%% ------------------------------------------------------------
rtl_file = "gaussian_output_samples_no_flush.txt";
if ~isfile(rtl_file)
    error("RTL output file not found. Run simulation first.");
end

y_rtl = readmatrix(rtl_file);
y_rtl = y_rtl(:);

fprintf("RTL output samples = %d\n", length(y_rtl));

%% ------------------------------------------------------------
% Align lengths
%% ------------------------------------------------------------
min_len = min(length(y_model_int), length(y_rtl));

y_model_int = y_model_int(1:min_len);
y_rtl       = y_rtl(1:min_len);

%% ------------------------------------------------------------
% Error analysis
%% ------------------------------------------------------------
err = y_rtl - y_model_int;

max_abs_err = max(abs(err));
rmse = sqrt(mean(double(err).^2));

fprintf("\n========================================\n");
fprintf("Gaussian Filter RTL vs MATLAB Q1.15 Check\n");
fprintf("========================================\n");
fprintf("Samples compared = %d\n", min_len);
fprintf("Max abs error    = %d LSB\n", max_abs_err);
fprintf("RMSE             = %.4f LSB\n", rmse);

%% ------------------------------------------------------------
% Plot outputs
%% ------------------------------------------------------------
figure('Name','RTL vs MATLAB Q1.15 saturated output');
plot(y_model_int, 'k', 'LineWidth', 1.5); hold on;
plot(y_rtl, 'r--', 'LineWidth', 1.2);
grid on;
xlabel('Sample index');
ylabel('Amplitude (signed integer, Q1.15)');
title('Gaussian Filter Output: MATLAB vs RTL (No Flush)');
legend('MATLAB bit-accurate model','RTL output');

%% ------------------------------------------------------------
% Plot error
%% ------------------------------------------------------------
figure('Name','Error');
plot(err, 'LineWidth', 1.2);
grid on;
xlabel('Sample index');
ylabel('RTL - MATLAB (LSB)');
title(sprintf('Error (Max abs = %d LSB)', max_abs_err));

%% ------------------------------------------------------------
% Pass/Fail
%% ------------------------------------------------------------
tol_lsb = 0;   % bit-for-bit target

if max_abs_err <= tol_lsb
    fprintf("\nPASS: RTL matches MATLAB bit-for-bit.\n");
else
    fprintf("\nFAIL: RTL does not match MATLAB bit-for-bit.\n");
end