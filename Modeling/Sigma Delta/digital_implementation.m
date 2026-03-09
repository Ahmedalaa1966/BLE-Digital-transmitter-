clc; clear; close all;

% Parameters
N   = 13;        % number of samples (use large N for PSD)
Xin = sqrt(2);
Nb  = 9;
M   = 2^Nb;

Xin_int = Xin * M;

% Storage for 7 digital outputs
dTF = zeros(N,7);

% Run digital MASH
for n = 1:N
    [ ...
        dTF(n,1), ...
        dTF(n,2), ...
        dTF(n,3), ...
        dTF(n,4), ...
        dTF(n,5), ...
        dTF(n,6), ...
        dTF(n,7)  ...
    ] = digital_implementation1(Xin_int, M, 0);
end

    Kv = 20e3;    % 20 kHz gain per varactor
    
    % DCO frequency deviation
    f_var = Kv * sum(dTF,2);
    Fc = 2.4e9;
    f_out = Fc + f_var;

    Fs = 500e6;   % sampling frequency
    
    figure;
    fprintf("mean = %d", mean(f_var) )
    [PSD, f] = pwelch(f_var - mean(f_var), [], [], [], Fs);
    
    plot(f/Fs, 10*log10(PSD), 'LineWidth', 1.5);
    grid on;
    xlabel('Normalized Frequency (f/F_s)');
    ylabel('PSD (dB/Hz)');
    title('PSD – Digital MASH with 7-Element Varactor Array');
    xlim([0 0.5]);



function [dTF1,dTF2,dTF3,dTF4,dTF5,dTF6,dTF7] = digital_implementation1(Xin_int, M, reset)

    % ===============================
    % Persistent states
    % ===============================
    persistent S1 S2 S3
    persistent S1_d S2_d
    persistent C1_1 C1_2 C1_3
    persistent C2_1 C2_2 C2_3
    persistent C3_1 C3_2 C3_3

    % -------------------------------
    % Reset
    % -------------------------------
    if isempty(S1) || reset
        S1 = 0; S2 = 0; S3 = 0;
        S1_d = 0; S2_d = 0;

        C1_1 = 0; C1_2 = 0; C1_3 = 0;
        C2_1 = 0; C2_2 = 0; C2_3 = 0;
        C3_1 = 0; C3_2 = 0; C3_3 = 0;
    end

    % ===============================
    % Dither (1-bit)
    % ===============================
    d = LFSR();   % must return 0 or 1

    % ===============================
    % Stage 1
    % ===============================
    tmp1 = S1 + Xin_int;
    C1   = floor(tmp1 / M);
    S1_n = mod(tmp1, M);

    % ===============================
    % Stage 2 (sum feedforward + dither)
    % ===============================
    tmp2 = S2 + S1_d ;
    C2   = floor(tmp2 / M);
    S2_n = mod(tmp2, M);

    % ===============================
    % Stage 3 (sum feedforward)
    % ===============================
    tmp3 = S3 + S2_d;
    C3   = floor(tmp3 / M);
    S3_n = mod(tmp3, M);

    % ===============================
    % Carry delay updates
    % ===============================
    C1_3 = C1_2;   C1_2 = C1_1;   C1_1 = C
    1;
    C2_3 = C2_2;   C2_2 = C2_1;   C2_1 = C2;
    C3_3 = C3_2;   C3_2 = C3_1;   C3_1 = C3;

    % ===============================
    % Outputs
    % ===============================
    dTF1 = C1_3;

    dTF2 = C2_2;
    dTF3 = 1 - C2_3;   % inverter bubble

    dTF4 = C3_1;
    dTF5 = 1 - C3_2;   % inverter bubble
    dTF6 = 1 - C3_2;   % same node, fanned out
    dTF7 = C3_3;

    % ===============================
    % Update sums
    % ===============================
    S1_d = S1;
    S2_d = S2;

    S1 = S1_n;
    S2 = S2_n;
    S3 = S3_n;
end

% =================== LFSR ====================
function d = LFSR()
    persistent reg


    % Initialization (reset behavior)
    if isempty(reg)
        % Non-zero 19-bit seed
        reg = [1 0 0 1 0 1 1 0 1 0 1 1 0 0 1 0 0 0 1];
    end

    

    % Feedback taps (x^19 + x^5 + 1)


    
    feedback = xor(reg(19), reg(5));

    % ===============================
    % Shift register
    % ===============================
    reg = [feedback reg(1:end-1)];

    % ===============================
    % Output bit
    % ===============================
    d = reg(end);   % 1-bit output (0 or 1)
end

