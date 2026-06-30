clc;
clear;
close all;

%% ===============================
%  Parameters
% ===============================
N   = 10000;
Xin = sqrt(2)/10;

Nb  = 9;
M   = 2^Nb;
Xin_int = Xin * M;

%% ===============================
%  State initialization
% ===============================
S1 = 0; S2 = 0; S3 = 0;

C1 = zeros(1,N);
C2 = zeros(1,N);
C3 = zeros(1,N);
Yout = zeros(1,N);

%% ===============================
%  Sample-by-sample simulation
% ===============================
for n = 1:N

    % ===== LSB DITHER (±1 LSB) =====
    dither = 2*(rand > 0.5) - 1;   % +1 or -1

    % -------- Stage 1 --------
    tmp1 = S1+ Xin_int + dither;
    C1(n) = floor(tmp1 / M);
    S1 = mod(tmp1, M);

    % -------- Stage 2 --------
    tmp2 = S2 + S1  ;
    C2(n) = floor(tmp2 / M);
    S2 = mod(tmp2, M);

    % -------- Stage 3 --------
    tmp3 = S3 + S2 ;
    C3(n) = floor(tmp3 / M);
    S3 = mod(tmp3, M);

    % -------- Noise cancellation --------
    if n == 1
        Yout(n) = C1(n) + C2(n) + C3(n);
    elseif n == 2
        Yout(n) = C1(n) ...
                + (C2(n) - C2(n-1)) ...
                + (C3(n) - 2*C3(n-1));
    else
        Yout(n) = C1(n) ...
                + (C2(n) - C2(n-1)) ...
                + (C3(n) - 2*C3(n-1) + C3(n-2));
    end
end

%% ===============================
%  Results
% ===============================
fprintf('Average of Yout = %.6f\n', mean(Yout));

%% ===============================
%  PSD
% ===============================
figure;
[PSD, f] = pwelch(Yout - mean(Yout), [], [], [], 1);
plot(f, 10*log10(PSD), 'LineWidth', 1.5);
grid on;
xlabel('Normalized Frequency');
ylabel('PSD (dB)');
title('9-bit MASH 1-1-1 with ±1 LSB Dither');
xlim([0 0.5]);
