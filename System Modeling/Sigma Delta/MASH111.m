function y = MASH111(Xin_int, M, mismatch_enable,reset)
% Persistent-based MASH 1-1-1 (NO dither)
% Optional 10% frequency-step mismatch at output
%
% mismatch_enable = 0 → ideal matched case
% mismatch_enable = 1 → 10% mismatch enabled


    % ===============================
    % Persistent states
    % ===============================
    persistent S1 S2 S3
    persistent C2_1 C3_1 C3_2


    % -------------------------------
    % Reset / initialization
    % -------------------------------
    if isempty(S1) || reset
        S1 = 0; S2 = 0; S3 = 0;
        C2_1 = 0;
        C3_1 = 0; C3_2 = 0;
    end

    % ===============================
    % -------- Stage 1 --------
    % ===============================
    tmp1 = S1 + Xin_int;
    C1  = floor(tmp1 / M);
    S1  = mod(tmp1, M);

    % ===============================
    % -------- Stage 2 --------
    % ===============================
    tmp2 = S2 + S1;
    C2  = floor(tmp2 / M);
    S2  = mod(tmp2, M);

    % ===============================
    % -------- Stage 3 --------
    % ===============================
    tmp3 = S3 + S2;
    C3  = floor(tmp3 / M);
    S3  = mod(tmp3, M);

    % ===============================
    % Frequency-step mismatch selection
    % ===============================
    if mismatch_enable
        delta_f1 = 0.9;   % -10%
        delta_f2 = 1.0;   % nominal
        delta_f3 = 1.1;   % +10%
    else
        delta_f1 = 1.0;
        delta_f2 = 1.0;
        delta_f3 = 1.0;
    end


    
    % ===============================
    % Noise cancellation (MASH 1-1-1)
    % with optional mismatch
    % ===============================
    y = delta_f1 * C1 ...
      + delta_f2 * (C2 - C2_1) ...
      + delta_f3 * (C3 - 2*C3_1 + C3_2);

    % ===============================
    % Update delay registers
    % ===============================
    C2_1 = C2;
    C3_2 = C3_1;
    C3_1 = C3;

    
end

