module gaussian_filter_block #(
    parameter int SPAN        = 4,
    parameter int SPS         = 16,
    parameter int L           = SPAN*SPS,
    parameter int HALF_TAPS   = L/2,
    parameter int TAP_W       = 16,
    parameter int ADDR_W      = 5,
    parameter int FRAC_W      = 15,
    parameter int ACC_W       = TAP_W + $clog2(HALF_TAPS) + 1,
    parameter int OUT_W       = 16
)(
    input  logic                     i_div16_clk,
    input  logic                     i_ref_clk,
    input  logic                     i_rst_n,
    input  logic                     i_rst_tap_n,
    input  logic                     i_gaussian_en,

    input  logic signed [1:0]        i_bit_upsample,
    input  logic                     i_bit_upsample_valid,

    input  logic signed [TAP_W-1:0]  i_tap_value,
    input  logic        [ADDR_W-1:0] i_tap_address,
    input  logic                     i_tap_we,
    output logic signed [TAP_W-1:0]  o_tap_read_value,

    output logic signed [OUT_W-1:0]  o_gaussian_filter,
    output logic                     o_gaussian_filter_valid
);

    logic signed [TAP_W-1:0] tap_mem [0:HALF_TAPS-1];
    logic signed [1:0]       delay_line [0:L-1];

    assign o_tap_read_value = tap_mem[i_tap_address];

    logic signed [ACC_W-1:0] acc_next;
    logic signed [ACC_W-1:0] acc_rounded;
    logic signed [OUT_W-1:0] acc_resized;

    always_comb begin : fir_accum
        acc_next = '0;

        for (int k = 0; k < HALF_TAPS; k++) begin
            logic signed [1:0] left_sample;
            logic signed [1:0] right_sample;
            logic signed [2:0] s_pair;
            logic signed [ACC_W-1:0] tap_ext;

            tap_ext = {{(ACC_W-TAP_W){tap_mem[k][TAP_W-1]}}, tap_mem[k]};

            if (k == 0)
                left_sample = i_bit_upsample;
            else
                left_sample = delay_line[k-1];

            if ((L-1-k) == 0)
                right_sample = i_bit_upsample;
            else
                right_sample = delay_line[L-1-k-1];

            s_pair = left_sample + right_sample;

            case (s_pair)
                 3'sd2: acc_next = acc_next + (tap_ext <<< 1);
                 3'sd1: acc_next = acc_next + tap_ext;
                 3'sd0: acc_next = acc_next;
                -3'sd1: acc_next = acc_next - tap_ext;
                -3'sd2: acc_next = acc_next - (tap_ext <<< 1);
                default: acc_next = acc_next;
            endcase
        end
    end

    always_comb begin : resize_sat
        acc_rounded = acc_next;

        if (acc_rounded > $signed({1'b0, {(OUT_W-1){1'b1}}})) begin
            acc_resized = {1'b0, {(OUT_W-1){1'b1}}};
        end
        else if (acc_rounded < $signed({1'b1, {(OUT_W-1){1'b0}}})) begin
            acc_resized = {1'b1, {(OUT_W-1){1'b0}}};
        end
        else begin
            acc_resized = acc_rounded[OUT_W-1:0];
        end
    end

always_ff @(posedge i_ref_clk) begin : tap_logic
        if (!i_rst_tap_n) begin
            for (int n = 0; n < HALF_TAPS; n++) begin
                tap_mem[n] <= '0;
            end
        end
        else if (i_tap_we) begin
                tap_mem[i_tap_address] <= i_tap_value;
        end 
end

    always_ff @(posedge i_div16_clk or negedge i_rst_n) begin : seq_logic
        if (!i_rst_n) begin
            o_gaussian_filter       <= '0;
            o_gaussian_filter_valid <= 1'b0;
            for (int m = 0; m < L; m++) begin
                delay_line[m] <= '0;
            end
        end
        else if (i_gaussian_en) begin
            if(i_bit_upsample_valid) begin
                delay_line[0] <= i_bit_upsample;
                for (int p = 1; p < L; p++) begin
                    delay_line[p] <= delay_line[p-1];
                end
                o_gaussian_filter       <= acc_resized;
                o_gaussian_filter_valid <= 1'b1;
            end
            else begin
               o_gaussian_filter_valid <= 1'b1;
            end
        end
    end

endmodule