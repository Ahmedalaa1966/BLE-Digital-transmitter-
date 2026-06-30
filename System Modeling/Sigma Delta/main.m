
clc;
clear;
close all;
clear Modified_dither;
clear LFSR;

%% Parameters
N               = 15;        % SD iterations (inner loop)
L               = 20;         % length of input vector (outer loop)
SD_in_vec       = [0.3 0.5 0.325 0.415 0.21 0.39 0.57 0.45 0.285 0.256 0.64 0.128 0.365 0.482 0.297 0.553 0.412 0.338 0.601 0.274 ];   % example vector input (size = L)
generate_input_file(SD_in_vec, 'input_binary.txt', 0, 10, 10);
Nb              = 10;
M               = 2^Nb;

sign            = 0;
bit_width       = 10;
fractional_bits = 0;

%% Pre-allocate
Yout_all = zeros(L, N);

%% 🔥 TWO LOOPS

for k = 1:L   % ===== Loop over input vector =====

    % Convert each input to fixed-point
    Xin     = fi(SD_in_vec(k), 0, 8, 8);
    Xin_int = fi(Xin*1024, sign, bit_width, fractional_bits);

    
    % Reset SD ONLY once per new input
    reset = 1;

    for n = 1:N   % ===== Sigma-Delta loop =====

        Yout_all(k, n) = Modified_dither(Xin_int, M, 0, 0, reset);

        % After first iteration, disable reset
        reset = 0;

    end

end


%% Results
disp("Output matrix:");
disp(Yout_all);

%% =========================
% 🔥 Correct average (NO scaling)
%% =========================
avg_out = mean(Yout_all,2);

%% =========================
% 🔥 Compare with input
%% =========================
disp("Original Input vs SD Average:");

result_table = table( ...
    SD_in_vec.', ...
    avg_out, ...
    (SD_in_vec.' - avg_out), ...
    'VariableNames', {'Input', 'Avg_SD_Output', 'Error'} ...
);

disp(result_table);

%% Save output
writematrix(Yout_all, 'Modeling_output.txt', 'Delimiter', 'tab');
%% Modified Dither 
function y = Modified_dither(Xin_int, M, mismatch_enable, bitrotator_enable, reset)
    % ===============================
    % Persistent states
    % ===============================
    persistent S1 S2 S3
    persistent C1_d C1_2d
    persistent C2_1 C2_2
    persistent C3_1 C3_2
    persistent delta_f1 delta_f2 delta_f3
    persistent sum_stage1_d
    persistent sum_stage1 

    % -------------------------------
    % Reset / initialization
    % -------------------------------
    if isempty(S1) || reset
        % Main accumulators as fixed-point (same type as Xin_int)
        S1 = fi(0, Xin_int.Signed, Xin_int.WordLength,Xin_int.FractionLength );
        S2 = fi(0, Xin_int.Signed, Xin_int.WordLength, Xin_int.FractionLength);
        S3 = fi(0, Xin_int.Signed, Xin_int.WordLength, Xin_int.FractionLength);
        
        % Carry-out chains as 1-bit integers
        C1_d = 0; C1_2d = 0;
        C2_1 = 0; C2_2 = 0;
        C3_1 = 0; C3_2 = 0;
        sum_stage1_d = fi(0, 1, 2, 0);
        sum_stage1  = fi (0,1,2,0) ;
        % Delta factors
        if mismatch_enable
            delta_f1 = fi(0.9, 1, 16, 14);
            delta_f2 = fi(1.0, 1, 16, 14);
            delta_f3 = fi(1.1, 1, 16, 14);
        else
            delta_f1 = fi(1.0, 1, 16, 14);
            delta_f2 = fi(1.0, 1, 16, 14);
            delta_f3 = fi(1.0, 1, 16, 14);
        end
    end

    % ===============================
    % Dither
    % ===============================
    d = LFSR(reset) ;
    M_fi = fi(M, Xin_int.Signed, Xin_int.WordLength, 0);  % same type for mod/floor

    SUM1 = S1 + Xin_int;
    SUM2 = S2 + S1 + d;
    C1 = floor(double(SUM1) / double(M_fi)) ;
    SUM3 = S3 + S2 ;


    % Carry-outs as 1-bit integers
    C1 = floor(double(SUM1) / double(M_fi)) ;
    C2 = floor(double(SUM2) / double(M_fi)) ;
    C3 = floor(double(SUM3) / double(M_fi)) ;

    % Update accumulators with mod (works between fi objects)
    S1 = mod(SUM1, M_fi+1);
    S2 = mod(SUM2, M_fi+1);
    S3 = mod(SUM3, M_fi+1);
     fprintf("M_fi = %d\n", M_fi);

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
    % Noise cancellation network
    % ===============================
    sum_stage1 = C2_1 + C3 - C3_1;                   
    y          = C1_2d + sum_stage1 - sum_stage1_d ;  

    % ===============================
    % Update delays
    % ===============================
    C1_2d = C1_d; C1_d = C1;
    C2_2 = C2_1; C2_1 = C2;
    C3_2 = C3_1; C3_1 = C3;
    sum_stage1_d = sum_stage1 ;
    fprintf("d = %d\n", d);
    fprintf("C1 = %d, C2 = %d, C3 = %d\n", C1, C2, C3);
    fprintf("S1 = %.10f, S2 = %.10f, S3 = %.10f\n", double(S1), double(S2), double(S3));
    fprintf("sum_stage1 = %d\n", sum_stage1);

    
end


function generate_input_file(SD_in_vec, filename, sign, word_length, fraction_length)

    L = length(SD_in_vec);

    fid = fopen(filename, 'w');

    for k = 1:L
        
        % Convert like your SD flow
        Xin     = fi(SD_in_vec(k), 0, 8, 8);
        Xin_int = fi(Xin * 2^fraction_length, sign, word_length, 0);
        
        % Write binary
        fprintf(fid, '%s\n', Xin_int.bin);
        
    end

    fclose(fid);

    fprintf("Input file '%s' generated successfully.\n", filename);

end