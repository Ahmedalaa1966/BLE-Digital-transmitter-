module LFSR (
    input  wire clk,
    input  wire rst_n,
    output wire o_lfsr
);

    // 19-bit register
    reg [18:0] reg_lfsr;


    wire feedback;

    assign feedback = reg_lfsr[18] ^ reg_lfsr[4]  ;   


    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
            reg_lfsr <= 19'b1001011010110010001;
        else
            reg_lfsr <= {feedback, reg_lfsr[18:1]};
    end

    assign o_lfsr = reg_lfsr[0];

endmodule