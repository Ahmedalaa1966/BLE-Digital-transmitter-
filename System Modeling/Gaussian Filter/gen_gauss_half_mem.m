clear; clc;

%% Parameters
BT   = 0.5;
span = 4;
sps  = 16;

L = span*sps;         % 64
pairs = L/2;          % 32

%% Build Gaussian coefficients (half-sample centered)
Ts_sym = 1/sps;
t0 = span/2;
t  = (-t0 + Ts_sym/2) : Ts_sym : (t0 - Ts_sym/2);
t  = t(:);

sigma = sqrt(log(2)) / (2*pi*BT);
h = exp(-(t.^2)/(2*sigma^2));
h = h / sum(h);

% Symmetry check
assert(max(abs(h - flipud(h))) < 1e-12, 'Gaussian coefficients are not symmetric.');

%% Keep only half
h_half = h(1:pairs);

%% Quantize to signed 16-bit fixed-point
% Recommended: Q1.15
scale = 2^15;
h_q = round(h_half * scale);

% Saturate to int16 range just in case
h_q(h_q >  32767) =  32767;
h_q(h_q < -32768) = -32768;

%% Write hex file for $readmemh
fname = 'gauss_half.mem';
fid = fopen(fname, 'w');
if fid == -1
    error('Could not open file %s for writing.', fname);
end

for k = 1:length(h_q)
    % Convert signed int16 to raw 16-bit hex
    val_u16 = typecast(int16(h_q(k)), 'uint16');
    fprintf(fid, '%04X\n', val_u16);
end

fclose(fid);

fprintf('Wrote %d half-taps to %s\n', length(h_q), fname);

%% Optional display
disp('First 10 quantized half-taps (decimal):');
disp(h_q(1:min(10,end)));

disp('First 10 quantized half-taps (hex):');
for k = 1:min(10,length(h_q))
    val_u16 = typecast(int16(h_q(k)), 'uint16');
    fprintf('%04X\n', val_u16);
end