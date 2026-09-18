module nrz_block_ready (
    input  logic              i_div16_clk,
    input  logic              i_rst_n,
    input  logic              i_nrz_en,

    input  logic              i_phy_bit,
    input  logic              i_bit_valid,
    output logic              o_bit_ready,

    input  logic              i_nrz_ready,
    output logic signed [1:0] o_nrz,
    output logic              o_nrz_valid
);

    logic signed [1:0] nrz_data_r;
    logic              nrz_valid_r;

    always_ff @(posedge i_div16_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            nrz_data_r  <= 2'sd0;
            nrz_valid_r <= 1'b0;
        end
        else if (!i_nrz_en) begin
            nrz_data_r  <= 2'sd0;
            nrz_valid_r <= 1'b0;
        end
        else begin
            if (i_bit_valid && o_bit_ready) begin
                nrz_data_r  <= i_phy_bit ? 2'sd1 : -2'sd1;
                nrz_valid_r <= 1'b1;
            end
            else if (nrz_valid_r && i_nrz_ready) begin
                nrz_valid_r <= 1'b0;
            end
        end
    end

    assign o_bit_ready = i_nrz_en && ((~nrz_valid_r) || i_nrz_ready);

    assign o_nrz       = nrz_data_r;
    assign o_nrz_valid = i_nrz_en && nrz_valid_r;

endmodule