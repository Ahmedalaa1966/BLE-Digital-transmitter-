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
        sum_stage1_d = 0 ;

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
    C1   = floor(SUM1 / M)   ;
    SUM3 = S3 + S2           ;
    S1   = mod(SUM1, M)      ;
    S2   = mod(SUM2, M)      ;
    S3   = mod(SUM3, M)      ;
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
    % y =  C1_2d ...
    %   +  (C2_2 - C2_1) ...
    %   +  (C3 - 2*C3_1 + C3_2);

    sum_stage1 = C2_1 + C3 - C3_1 ;
    y = C1_2d + sum_stage1 - sum_stage1_d ; 

    % ===============================
    % Update delays
    % ===============================
    % C1 delay chain
    C1_2d = C1_d;
    C1_d  = C1;

    % C2 delay chain
    C2_2 = C2_1;
    C2_1 = C2;

    % C3 delay chain
    C3_2 = C3_1;
    C3_1 = C3;
    sum_stage1_d = sum_stage1 ;
end
