module upsample_block_ready #(
    parameter int SPS = 16
)(
    input  logic              i_div16_clk,
    input  logic              i_rst_n,
    input  logic              i_upsample_en,
    input  logic              i_hold_sample, // added to support pipeline flushing

    input  logic signed [1:0] i_nrz,
    input  logic              i_nrz_valid,
    output logic              o_nrz_ready,

    output logic signed [1:0] o_bit_upsample,
    output logic              o_bit_upsample_valid
);

    logic signed [1:0] hold_sample;
    logic [$clog2(SPS):0] repeat_cnt;
    logic                  repeating;

    always_ff @(posedge i_div16_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            hold_sample          <= 2'sd0;
            repeat_cnt           <= '0;
            repeating            <= 1'b0;
            o_bit_upsample       <= 2'sd0;
            o_bit_upsample_valid <= 1'b0;
        end
        else if (!i_upsample_en) begin
            hold_sample          <= 2'sd0;
            repeat_cnt           <= '0;
            repeating            <= 1'b0;
            o_bit_upsample       <= 2'sd0;
            o_bit_upsample_valid <= 1'b0;
        end
        else begin
            if (i_nrz_valid && (~repeating)) begin
                if (!i_hold_sample) begin
                    hold_sample          <= i_nrz;
                    o_bit_upsample       <= i_nrz;
                end else begin
                    // If i_hold_sample is active, hold the previous sample to flush GMSK
                    o_bit_upsample       <= hold_sample;
                end
                o_bit_upsample_valid <= 1'b1;

                if (SPS > 1) begin
                    repeat_cnt <= SPS-1;
                    repeating  <= 1'b1;
                end
                else begin
                    repeat_cnt <= '0;
                    repeating  <= 1'b0;
                end
            end
            else if (repeating) begin
                o_bit_upsample       <= hold_sample;
                o_bit_upsample_valid <= 1'b1;

                if (repeat_cnt == 1) begin
                    repeat_cnt <= '0;
                    repeating  <= 1'b0;
                end
                else begin
                    repeat_cnt <= repeat_cnt - 1'b1;
                    repeating  <= 1'b1;
                end
            end
            else begin
                o_bit_upsample       <= 2'sd0;
                o_bit_upsample_valid <= 1'b0;
            end
        end
    end

    assign o_nrz_ready = i_upsample_en && ((~repeating) || (repeat_cnt == 1));

endmodule