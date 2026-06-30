function d = LFSR(reset)
    persistent reg

    % Initialization (same as Verilog reset)
    if isempty(reg) || reset 
        % index 1 = MSB (bit 18), index 19 = LSB (bit 0)
        reg = [1 0 0 1 0 1 1 0 1 0 1 1 0 0 1 0 0 0 1];
    end


    d = reg(19);   % LSB
    feedback = xor(reg(1), reg(15));  % bit18 ^ bit4
    reg = [feedback reg(1:end-1)];

end