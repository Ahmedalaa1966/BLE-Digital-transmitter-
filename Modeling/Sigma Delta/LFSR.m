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

