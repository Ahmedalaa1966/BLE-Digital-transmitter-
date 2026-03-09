clc;
clear;
close all;
%%
% Parameters
N   = 10000;
Xin = 0.5;

Nb  = 10;
M   = 2^Nb;
Xin_int = Xin * M;
reset = 0 ;

Yout                 = zeros(1, N) ;
Yout_dithered        = zeros(1, N) ;
Yout_modified        = zeros(1, N) ;
Yout_normal_dither   = zeros(1, N) ;
Yout_modified_dither = zeros(1,N)  ;

% Run persistent MASH
for n = 1:N
    Yout(n)                 = MASH111(Xin_int, M,0,0)          ;
    Yout_dithered(n)        = MASH_dithered(Xin_int,M,0,0)   ;
    Yout_modified(n)        = modified_MASH(Xin_int,M,0,0)   ;
    Yout_normal_dither(n)   = normal_dither(Xin_int,M,0,0)   ;
    Yout_modified_dither(n) = Modified_dither(Xin_int,M,0,0,0) ;
end

% Average of the outputs 
fprintf ("Input                       = %.6f\n" , Xin )
fprintf ("Average of Modified Mash    = %.6f\n", mean(Yout_modified+3));
fprintf ("Average of XOR based dither = %.6f\n", mean(Yout_dithered));
fprintf ("Average of normal dither    = %.6f\n", mean(Yout_normal_dither));
fprintf ("Average of original MASH    = %.6f\n", mean(Yout));
fprintf ("Average of Modified dither  = %.6f\n", mean(Yout_modified_dither));


% PSD (Normalized Frequency)

Fs = 400e6;   % Sampling frequency (Hz)

figure(1);
% 1) No Dither
subplot(5,1,1)
[PSD1, f] = pwelch(Yout - mean(Yout), [], [], [], Fs);
f_norm = f / Fs;
plot(f_norm, 10*log10(PSD1), 'LineWidth', 1.5);
grid on;
xlabel('Normalized Frequency (f/F_s)');
ylabel('PSD (dB/Hz)');
title('MASH 1-1-1 with no Dither');
xlim([0 0.5]);


% 2) Modified Dither
subplot(5,1,2)
[PSD2, f] = pwelch(Yout_dithered - mean(Yout_dithered), [], [], [], Fs);
f_norm = f / Fs;
plot(f_norm, 10*log10(PSD2), 'LineWidth', 1.5);
grid on;
xlabel('Normalized Frequency (f/F_s)');
ylabel('PSD (dB/Hz)');
title('MASH 1-1-1 (XOR Dither)');
xlim([0 0.5]);


% 3) Modified MASH
subplot(5,1,3)
[PSD3, f] = pwelch(Yout_modified - mean(Yout_modified), [], [], [], Fs);
f_norm = f / Fs;
plot(f_norm, 10*log10(PSD3), 'LineWidth', 1.5);
grid on;
xlabel('Normalized Frequency (f/F_s)');
ylabel('PSD (dB/Hz)');
title('Modified Mash (HK Mash)');
xlim([0 0.5]);



% 4) Normal dithering
subplot(5,1,4)
[PSD3, f] = pwelch(Yout_normal_dither - mean(Yout_normal_dither), [], [], [], Fs);
f_norm = f / Fs;
plot(f_norm, 10*log10(PSD3), 'LineWidth', 1.5);
grid on;
xlabel('Normalized Frequency (f/F_s)');
ylabel('PSD (dB/Hz)');
title('Normal Dither');
xlim([0 0.5]);


% 5) Modified Dither 
subplot(5,1,5)
[PSD3, f] = pwelch(Yout_modified_dither - mean(Yout_modified_dither), [], [], [], Fs);
f_norm = f / Fs;
plot(f_norm, 10*log10(PSD3), 'LineWidth', 1.5);
grid on;
xlabel('Normalized Frequency (f/F_s)');
ylabel('PSD (dB/Hz)');
title('Modified Dither');
xlim([0 0.5]);

