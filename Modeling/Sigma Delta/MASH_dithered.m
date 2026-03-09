function y = MASH_dithered(Xin_int, M, mismatch_enable, bitrotaotr_enable)
% MASH 1-1-1 with:
% - Carry feedforward: C1 -> stage 3
% - XOR-based dither in stage 2
% - Optional 10% frequency-step mismatch
% - Optional Shift bit rotator enabled by LFSR


    % ===============================
    % Persistent states
    % ===============================
    persistent S1 S2 S3
    persistent C2_1 C3_1 C3_2
    persistent delta_f1 delta_f2 delta_f3   % rotated frequency steps

    % -------------------------------
    % Reset / initialization
    % -------------------------------
    if isempty(S1)
        S1 = 0; S2 = 0; S3 = 0;
        C2_1 = 0;
        C3_1 = 0; C3_2 = 0;

        % Initialize frequency steps
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


    % LFSR dither (1-bit)
    d = LFSR();

    
    % -------- Stage 1 --------
    tmp1 = S1 + Xin_int;
    C1  = floor(tmp1 / M);
    S1  = mod(tmp1, M);

    % -------- Stage 2 --------
    % XOR dither: LFSR ⊕ delayed C3
    d_xor = xor(d, C3_1); 
    
    tmp2 = S2 + S1 + d_xor;
    C2  = floor(tmp2 / M);
    S2  = mod(tmp2, M);


    % -------- Stage 3 --------
    % Feedforward carry: + C1
    tmp3 = S3 + S2 + C1;
    C3  = floor(tmp3 / M);
    S3  = mod(tmp3, M);

    % Bit rotator enable (from LFSR)
    if bitrotaotr_enable
        rot_en = LFSR() ;
    else 
        rot_en = 0 ;
    end

    if rot_en == 1
        temp      = delta_f1;
        delta_f1  = delta_f2;
        delta_f2  = delta_f3;
        delta_f3  = temp;
    end
    % if rot_en == 0 → hold mapping

    % Noise cancellation (MASH 1-1-1)
    % with mismatch + DEM
    y = delta_f1 * C1 ...
      + delta_f2 * (C2 - C2_1) ...
      + delta_f3 * (C3 - 2*C3_1 + C3_2);


    % Update delay registers
    C2_1 = C2;
    C3_2 = C3_1;
    C3_1 = C3;


end

