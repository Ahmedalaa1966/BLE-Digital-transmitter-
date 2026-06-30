function y = modified_MASH(Xin_int, M, mismatch_enable , bitrotaotr_enable)

    persistent S1 S2 S3
    persistent Cin1 Cin2 Cin3
    persistent C2_1 C3_1 C3_2
    persistent delta_f1 delta_f2 delta_f3

    
    if isempty(S1)
        S1 = 0; S2 = 0; S3 = 0;
        Cin1 = 0; Cin2 = 0; Cin3 = 0;
        C2_1 = 0;
        C3_1 = 0; C3_2 = 0;


        if mismatch_enable
            delta_f1 = 0.9;
            delta_f2 = 1.0;
            delta_f3 = 1.1;
        else
            delta_f1 = 1;
            delta_f2 = 1;
            delta_f3 = 1;
        end
    end

    % -------- Stage 1
    tmp1 = S1 + Xin_int + Cin1;
    C1   = floor(tmp1 / M);
    S1   = mod(tmp1, M);
    Cin1 = C1;

    % -------- Stage 2
    tmp2 = S2 + S1 + Cin2;
    C2   = floor(tmp2 / M);
    S2   = mod(tmp2, M);
    Cin2 = C2;

    % -------- Stage 3
    tmp3 = S3 + S2 + Cin3;
    C3   = floor(tmp3 / M);
    S3   = mod(tmp3, M);
    Cin3 = C3;


    % -------- Bit rotator enable
    if bitrotaotr_enable==1
        rot_en = LFSR() ;
    else 
        rot_en = 0 ;
    end

    if rot_en == 1
        tmp = delta_f1;
        delta_f1 = delta_f2;
        delta_f2 = delta_f3;
        delta_f3 = tmp;
    end

    % -------- Output
    y = delta_f1 * C1 ...
      + delta_f2 * (C2 - C2_1) ...
      + delta_f3 * (C3 - 2*C3_1 + C3_2);


    % -------- Update delays
    C2_1 = C2;
    C3_2 = C3_1;
    C3_1 = C3;

end


