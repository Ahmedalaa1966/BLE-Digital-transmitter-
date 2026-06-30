clc;clear;close all;
%% define parameters
PVT =1;
PVT_c0 =1;
lms_enabled = false;  
L =1e-9;
F_ref = 32e6;
%% reset DCO
[cap_state_m1,cap_state_m2,cap_state_m3,cap_state_m4,C_o,f] = DCO_reset(L,PVT,PVT_c0);
d_C =  cap_on(cap_state_m1,cap_state_m2,cap_state_m3,cap_state_m4,PVT,PVT_c0);
fDCO=@(d_C)1/(2*pi*((C_o + d_C)*L).^0.5);
C_t = C_o + d_C;
cap_state_m1_new = cap_state_m1;
cap_state_m2_new = cap_state_m2;
cap_state_m3_new = cap_state_m3;
cap_state_m4_new = cap_state_m4;

%% start modulation on 
% input signal defination

N_sym = 20   ;                   % no of symbols .
OSR   = 32   ;                   % oversampling ratio
Tsym = 1e-6  ;                   % symbol time 1 mico second
dt = 1/F_ref ;                   % Fref is the frequency of the crystal
Nb  = 8      ;
M   = 2^Nb   ;
s   = 13     ;

t = [0:dt:(N_sym*Tsym)-dt] ;                % time vector 
N = length(t);                              % number of iterations of the for loop
alt_signal = (-1).^(0:N_sym-1);             % alternative signal used to estimate Gain before send data
mod_signal = repelem(alt_signal, OSR);      % oversample

% define DCO mode.
d_C1 =  cap_on(cap_state_m1,cap_state_m2,cap_state_m3,cap_state_m4,PVT,PVT_c0);
F_locked = fDCO(d_C1);
F_dco = zeros(size(t));
F_dco(1) = F_locked; % measure instantenous F_dco
mode = 3;
% set DCO gain 
KDCO = 25e3;
G_prev = zeros(size(t));
G_prev(1) =F_ref/KDCO;

% calculate real gain
d_C1 =  cap_on(cap_state_m1,cap_state_m2,cap_state_m3-10,cap_state_m4,PVT,PVT_c0);
d_C2 =  cap_on(cap_state_m1,cap_state_m2,cap_state_m3+10,cap_state_m4,PVT,PVT_c0);
f1 = fDCO(d_C1);
f2 = fDCO(d_C2);
KDCO_real = (f1-f2)/20;
G_real =F_ref / KDCO_real;
FCW = F_locked/F_ref;

FCW_prev = FCW; 
phi_err = zeros(size(t));
phi = zeros(size(t));
phi_i= zeros(size(t));
F_target = zeros(size(t));
F_target(1) = F_locked;
mu = 0.5;
if(lms_enabled)
lms_str = sprintf('with LMS(step =%0.3f)',mu); 
lms_state = "LMS Active";
else
lms_str ='without LMS';
lms_state = "LMS Disabled"; 
end
fprintf("%s\n",lms_state);
fprintf("start modulation:\n");
frac_NTW =zeros(1,N-1);
alpha  = 2^-8;
beta = 2^-12;
I = 0;
OTW = 0;
reset = 0 ;
%% 
for i = 1 : N-1
    signal = mod_signal(i);
    FCW_prev = FCW; 
    [F_target(i+1), mod_fsk, mod_prev] = FSK(F_locked,signal);
    FCW = (F_target(i+1)-F_locked) / F_ref ;                                            % FCW_data + FCW;
    

    % word of FSk enter first to DCO while FCW is word of next step.
    NTW_two_point = (-FCW + OTW)*G_prev(i);
    NTW_mat(i+1) = floor(NTW_two_point);
    frac_NTW(i) = NTW_two_point -  NTW_mat(i+1);
    [cap_state_m1_new ,cap_state_m2_new, cap_state_m3_new,cap_state_m4_new] = DCO_interface_logic(cap_state_m1,...
    cap_state_m2,cap_state_m3,cap_state_m4,NTW_mat(i+1),mode)  ;
        Xin_int = frac_NTW(i) * M                 ; 
        for k = 1 : s-1 
            reset = (k==1) ;
            Yout_modified_dither(k) = Modified_dither(Xin_int,M,0,0,reset )                                         ;
            C =  cap_on(cap_state_m1_new,cap_state_m2_new,cap_state_m3_new,(Yout_modified_dither(k)+4),PVT,PVT_c0)  ;
            F_dco_SD(k) =fDCO(C)                                                                                    ;
    end
    F_dco(i+1) =mean(F_dco_SD);
    

    [phi(i+1),phi_i(i+1),phi_err(i+1)]= ideal_PD(F_target(i+1),F_ref,F_dco(i+1),phi_i(i), phi(i));
    [OTW , I] = DLF_function(phi_err(i+1), alpha, beta , I);
    

    if(lms_enabled)
        [G]= LMS(G_prev(i),phi_err(i+1) - phi_err(i),mu,mod_fsk,mod_prev) ;          %signed LMS               
        G_prev(i+1) = G;
    else 
        G_prev(i+1) = G_real ;
        
    end
end

%% PSD 
Fs = 1e6;

x = F_dco - mean(F_dco);   % remove DC

figure('Name', 'Power spectral denity of the output frequecy vector ')
[PSD_Fdco, f] = pwelch(x, [], [], [], Fs);

f_norm = f / Fs;
plot(f_norm, 10*log10(PSD_Fdco), 'LineWidth', 1.5);
grid on;
xlabel('Normalized Frequency (f/F_s)');
ylabel('PSD (Hz^2/Hz)');
title('DCO Frequency PSD');
xlim([0 0.5]);


%% phase Noise
Fs = 1e6;
x1 = F_dco - mean(F_dco);
[PSD_F, f] = pwelch(x1, [], [], [], Fs);
PSD_phi = PSD_F ./ (2*pi*f).^2;
PSD_phi(1) = 0;   % avoid divide-by-zero at DC
figure('Name','Phase Noise of DCO','NumberTitle','off')
semilogx(f, 10*log10(PSD_phi), 'LineWidth', 1.5);
grid on;
xlabel('Frequency Offset (Hz)');
ylabel('Phase Noise (dBc/Hz)');
title('Estimated DCO Phase Noise');
xlim([1 Fs/2]);



%% ADPLL FSK Frequency Deviation
figure('Name', 'ADPLL FSK Frequency Deviation');
plot(t*1e6, F_dco - F_locked, ...
     'LineWidth', 2, 'DisplayName', 'DCO modulation'); 
hold on;
plot(t*1e6, F_target - F_locked, ...
     'LineWidth', 2, 'DisplayName', 'Ideal modulation');

xlabel('Time (\mus)', 'FontSize', 14);
ylabel('Deviation (Hz)', 'FontSize', 14);
title(sprintf('ADPLL FSK Modulation (PVT change %.0f %s %s)', ...
      (PVT-1)*100,'%', lms_str), ...
      'FontSize', 16, 'FontWeight', 'bold');
legend('Location', 'southeast', 'FontSize', 12);
grid on;
ylim([-300e3 300e3]);
xlim([0 t(end)*1e6]);
set(gca, 'FontSize', 12, 'LineWidth', 1.2);
hold off;

%% ADPLL Phase Error
figure('Name', 'ADPLL Phase Error');
plot(t*1e6, phi_err, 'LineWidth', 2);
xlabel('Time (\mus)', 'FontSize', 14);
ylabel('Phase Error', 'FontSize', 14);
title(sprintf('Phase Error During Modulation %s', lms_str), ...
      'FontSize', 16, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 12, 'LineWidth', 1.2);

%% Frequency Error
figure('Name', 'Frequency Error');
plot(t*1e6, F_dco - F_target, 'LineWidth', 2);
xlabel('Time (\mus)', 'FontSize', 14);
ylabel('F (Hz)', 'FontSize', 14);
title('Difference Between Ideal and DCO Modulation', ...
      'FontSize', 16, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 12, 'LineWidth', 1.2);

%% LMS DCO Gain Calibration
lms_initial_err = (G_real - G_prev(1))/G_real;
figure('Name', 'LMS DCO Gain Calibration');
plot(t/Tsym, (G_prev - G_real)./G_real, 'LineWidth', 2);
xlabel('Symbol Index', 'FontSize', 14);
ylabel('Gain Error (M)', 'FontSize', 14);
title(sprintf('Sign-Sign LMS Gain Convergence (\\mu=%0.4f, initial error = %0.3f%s)', ...
      mu, lms_initial_err*100, '%'), ...
      'FontSize', 16, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 12, 'LineWidth', 1.2);

%% Code Word
figure('Name', 'Code Word');
plot(t*1e6, NTW_mat, 'LineWidth', 2);
xlabel('Time (\mus)', 'FontSize', 14);
ylabel('Normalized Tuning Word (NTW)', 'FontSize', 14);
title('Two-Point Modulation Code Word', ...
      'FontSize', 16, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 12, 'LineWidth', 1.2);

%% Prints
fprintf("real gain of DCO %0.1f\n", G_real);
lms_err = (G_real - G_prev(end))/G_real;
fprintf("estimated gain of DCO = %0.1f %s\n", G_prev(end), lms_str);
fprintf("LMS gain error = %0.2f%s\n", lms_err*100, '%%');



%%=============================== functions ================================


% cap_on function calculated the value of variable capcitance  
function C =  cap_on(cap_state_m1,cap_state_m2,cap_state_m3,cap_state_m4,PVT,PVT_c0)
% capacitor bank of first mode:
incr_cap_m1 =7.2e-15.*PVT_c0;
cap_bank_m1 =incr_cap_m1.*ones(1,256);
% capacitor bank of second mode
incr_cap_m2 = 1.8e-15.*PVT;
cap_bank_m2 =incr_cap_m2.*ones(1,256);
% capacitor bank of third mode : integer part ;
incr_cap_m3 = 90.16e-18.*PVT;
cap_bank_m3 =incr_cap_m3.*ones(1,128);
cap_bank_m4 =incr_cap_m3.*ones(1,8);

C = sum(cap_bank_m1(1:cap_state_m1))+ ...
    sum(cap_bank_m2(1:cap_state_m2))+...
    sum(cap_bank_m3(1:cap_state_m3))+...
    sum(cap_bank_m4(1:cap_state_m4));
end


function [cap_state_m1,cap_state_m2,cap_state_m3,cap_state_m4,C_o,fmid] = DCO_reset(L,PVT,PVT_c0)
% define cap state idealy at PVT 1 all cap should be on and frequency will
% be around 2.44GHz
cap_state_m1 = 128;
cap_state_m2 = 128;
cap_state_m3 = 64;
cap_state_m4 = 4;
f_mid = 2.44e9;
d_C =  cap_on(cap_state_m1,cap_state_m2,cap_state_m3,cap_state_m4,1,1);
C_o = ((2*pi*f_mid)^2 *L)^-1 - d_C; % typical value shouldn't depends on PVT
C_o = C_o.*PVT_c0;% the value depend on PVT
d_C =  cap_on(cap_state_m1,cap_state_m2,cap_state_m3,cap_state_m4,PVT,PVT_c0);

fDCO=@(d_C)1/(2*pi*((C_o + d_C)*L).^0.5);
fmid=fDCO(d_C);
end

% ideal phase detector :
function [phi ,phi_i,phi_err]= ideal_PD(F_target,F_ref,F,phi_i_prev, phi_prev)
phi = F/F_ref + phi_prev;
phi_i =F_target/F_ref + phi_i_prev;  %ideal phae
phi_err = phi - phi_i;
end

% normalizer Block:
function NTW = normalizer(phi_err,F_ref , mode)
KDCO(1) = 2e6;
KDCO(2) =0.5e6;
KDCO(3)=25e3; 
if mode > 4
    error('normalizer:InvalidMode', 'Mode must be 1, 2,3,or 4 . Got: %d', mode);
elseif mode < 1
    warning('normalizer:InvalidMode', 'Mode should be 1-4. Using mode=%d', mode);
end
NTW = phi_err * F_ref / KDCO(mode);  % Fixed: removed (i+1) indexing
end

% DCO interface 
function [cap_state_m1 ,cap_state_m2, cap_state_m3,cap_state_m4] = DCO_interface_logic(cap_state_m1_prev,...
 cap_state_m2_prev,cap_state_m3_prev,cap_state_m4_prev,NTW,mode)
 cap_state_m1 =cap_state_m1_prev;
 cap_state_m2 =cap_state_m2_prev;
 cap_state_m3 =cap_state_m3_prev;
 cap_state_m4=cap_state_m4_prev;
if(mode == 1)
 cap_state_m1 = cap_state_m1_prev + floor(NTW);
 cap_state_m1 = min(256,max(cap_state_m1,1));
 elseif(mode==2)
 cap_state_m2 = cap_state_m2_prev + floor(NTW);
 cap_state_m2 = min(256,max(cap_state_m2,1));
 elseif(mode==3)
 cap_state_m3 = cap_state_m3_prev + floor(NTW);
 cap_state_m3 = min(128,max(cap_state_m3,1));  
 elseif(mode==4)
 cap_state_m4 = cap_state_m4_prev + floor(NTW);
 cap_state_m4 = min(8,max(cap_state_m4,1));  
 end
end


%  FSK 
function [F_target,modfsk, mod_prev] = FSK(F_locked,signal)

if(signal == 1)
F_target =F_locked  + 250e3;
modfsk = 1;
mod_prev = 0;
else
F_target = F_locked + -250e3;
modfsk = -1;
mod_prev = 0;
end
end

%% LMS function
function  [G]= LMS(G_prev,phase_er,mu,mod,mod_perv) %signed LMS               
    G = G_prev - mu*sign(mod - mod_perv)*sign(phase_er);    
end



% sigma delta 
function y = Modified_dither(Xin_int, M, mismatch_enable, bitrotator_enable, reset)

    % ===============================
    % Persistent states
    % ===============================
    persistent S1 S2 S3
    persistent C1_d C1_2d
    persistent C2_1 C2_2
    persistent C3_1 C3_2
    persistent delta_f1 delta_f2 delta_f3

    % -------------------------------
    % Reset / initialization
    % -------------------------------
    if isempty(S1) || reset
        S1    = 0;
        S2    = 0; 
        S3    = 0;
        C1_d  = 0;
        C1_2d = 0;
        C2_1  = 0;
        C2_2  = 0;
        C3_1  = 0;
        C3_2  = 0;

        if mismatch_enable
            delta_f1 = 0.9;
            delta_f2 = 1.0;
            delta_f3 = 1.1;
        else
            delta_f1 = 1.0;
            delta_f2 = 1.0;
            delta_f3 = 1.0;
        end
    end

    % ===============================
    % Dither
    % ===============================
    d = LFSR();

    % ===============================
    % Stage 1
    % ===============================
    SUM1 = S1 + Xin_int      ;
    SUM2 = S2 + S1 + d       ;
    SUM3 = S3 + S2 + C1_d   ;
    S1   = mod(SUM1, M)      ;
    S2   = mod(SUM2, M)      ;
    S3   = mod(SUM3, M)      ;
    C1   = floor(SUM1 / M)   ;
    C2   = floor(SUM2 / M)   ;
    C3   = floor(SUM3 / M)   ;

   
    % ===============================
    % DEM bit rotation
    % ===============================
    if bitrotator_enable && LFSR()
        tmp = delta_f1;
        delta_f1 = delta_f2;
        delta_f2 = delta_f3;
        delta_f3 = tmp;
    end

    % ===============================
    % Noise cancellation
    % ===============================
    y =  C1_2d ...
      +  (C2_2 - C2_1) ...
      +  (C3 - 2*C3_1 + C3_2);

    % ===============================
    % Update delays
    % ===============================
    
    % C2 delay chain (RAW C2 only)
    C2_2 = C2_1;
    C2_1 = C2;

    % C3 delay chain
    C3_2 = C3_1;
    C3_1 = C3;

    % C1 delay
    C1_d = C1;
    C1_2d = C1_d ;
end




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

function [OTW , I] = DLF_function(phase_error, alpha, beta , I)
    % ADPLL PI Loop Filter
    % phase_error : input phase error vector
    % alpha       : proportional gain
    % beta        : integral gain
    % OTW         : output DCO tuning word

    I = I + beta * phase_error;        % integrator
    OTW = alpha * phase_error + I;  % PI output
end
