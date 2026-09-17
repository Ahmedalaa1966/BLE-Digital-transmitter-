module ble_tx_chain_two_paths_top #(
    parameter int SPAN         = 4,
    parameter int SPS          = 16,
    parameter int L            = SPAN*SPS,
    parameter int HALF_TAPS    = L/2,

    parameter int TAP_W        = 16,
    parameter int GAUSS_W      = 16,
    parameter int TAP_ADDR_W   = $clog2(HALF_TAPS),

    parameter int FIFO_ADDR_W  = 2,

    parameter int LMS_W        = 11,
    parameter int LMS_EXT_W    = LMS_W + 1,
    parameter int PROD_W       = GAUSS_W + LMS_EXT_W,
    parameter int DCO_W        = 14,

    parameter int ALIGN_STAGES = 2
    )(
    // ============================================================
    // Clocks and reset
    // ============================================================
    input  logic                         i_div16_clk,
    input  logic                         i_tdc_clk,
    input  logic                         i_rst_n,
    input  logic                         i_rst_tap_n,
    input  logic                         i_ref_clk,
    input  logic                         i_fifo_rst_n,

    // ============================================================
    // Enables
    // ============================================================
    input  logic                         i_nrz_en,
    input  logic                         i_upsample_en,
    input  logic                         i_gaussian_en,
    input  logic                         i_path1_en,
    input  logic                         i_path2_en,
    input  logic                         i_hold_sample,



    // ============================================================
    // Input to first block: NRZ
    // ============================================================
    input  logic                         i_phy_bit,
    input  logic                         i_bit_valid,
    output logic                         o_bit_ready,

    // ============================================================
    // Gaussian coefficient loading interface
    // Can come from TB, CU, register file, ROM, etc.
    // ============================================================
    input  logic signed [TAP_W-1:0]      i_tap_value,
    input  logic        [TAP_ADDR_W-1:0] i_tap_address,
    input  logic                         i_tap_we,
    output logic signed [TAP_W-1:0]      o_tap_read_value,

    // ============================================================
    // LMS value for modulation path 1
    // ============================================================
    input  logic        [LMS_W-1:0]      i_lms,

    // ============================================================
    // Optional monitor outputs
    // ============================================================

    // ============================================================
    // Final outputs
    // ============================================================
    output logic signed [DCO_W-1:0]      o_dco_data,

    output logic signed [GAUSS_W-1:0]    o_tdc_data
    );

      // Internal wires


      // ============================================================
    // Internal wires: NRZ to upsampler
    // ============================================================

    logic signed [1:0]  nrz_data;
    logic              nrz_valid;
    logic              nrz_ready;

    // ============================================================
    
      logic signed [GAUSS_W-1:0]    o_gaussian_filter;
      logic                         o_gaussian_filter_valid;
      logic                         o_fifo_full;
      logic                         o_fifo_empty;
      logic signed [GAUSS_W-1:0]    o_fifo_rd_data;
      logic                         o_fifo_rd_valid;
      logic                         o_dco_valid;
      logic                         o_tdc_valid;

    // Internal wires: upsampler to Gaussian filter
    // ============================================================

    logic signed [1:0] bit_upsample;
    logic              bit_upsample_valid;

    // ============================================================
    // Internal FIFO control
    // ============================================================

    logic fifo_wr_en;
    logic fifo_rd_en;

    assign fifo_wr_en = o_gaussian_filter_valid && !o_fifo_full;
    assign fifo_rd_en = !o_fifo_empty;

    // ============================================================
    // NRZ block
    // ============================================================

    nrz_block_ready u_nrz (
        .i_div16_clk (i_div16_clk),
        .i_rst_n     (i_rst_n),
        .i_nrz_en    (i_nrz_en),

        .i_phy_bit   (i_phy_bit),
        .i_bit_valid (i_bit_valid),
        .o_bit_ready (o_bit_ready),

        .i_nrz_ready (nrz_ready),
        .o_nrz       (nrz_data),
        .o_nrz_valid (nrz_valid)
    );

      // Internal wires


      // ============================================================
    // Upsampler block
    // ============================================================

    upsample_block_ready #(
        .SPS(SPS)
    ) u_upsample (
        .i_div16_clk          (i_div16_clk),
        .i_rst_n              (i_rst_n),
        .i_upsample_en        (i_upsample_en),
        .i_hold_sample        (i_hold_sample),  
        .i_nrz                (nrz_data),
        .i_nrz_valid          (nrz_valid),
        .o_nrz_ready          (nrz_ready),

        .o_bit_upsample       (bit_upsample),
        .o_bit_upsample_valid (bit_upsample_valid)
    );

      // Internal wires


      // ============================================================
    // Gaussian filter block
    // ============================================================

    gaussian_filter_block #(
        .SPAN      (SPAN),
        .SPS       (SPS),
        .L         (L),
        .HALF_TAPS (HALF_TAPS),
        .TAP_W     (TAP_W),
        .ADDR_W    (TAP_ADDR_W),
        .OUT_W     (GAUSS_W)
    ) u_gaussian (
        .i_div16_clk             (i_div16_clk),
        .i_ref_clk               (i_ref_clk),
        .i_rst_n                 (i_rst_n),
        .i_rst_tap_n             (i_rst_tap_n),
        .i_gaussian_en           (i_gaussian_en),

        .i_bit_upsample          (bit_upsample),
        .i_bit_upsample_valid    (bit_upsample_valid),

        .i_tap_value             (i_tap_value),
        .i_tap_address           (i_tap_address),
        .i_tap_we                (i_tap_we),
        .o_tap_read_value        (o_tap_read_value),

        .o_gaussian_filter       (o_gaussian_filter),
        .o_gaussian_filter_valid (o_gaussian_filter_valid)
    );

      // Internal wires


      // ============================================================
    // Async FIFO
    //
    // Write side: div16 clock domain
    // Read side : tdc clock domain
    //
    // This FIFO outputs each Gaussian sample twice.
    // ============================================================
logic rst_ckr_0, rst_ckr_sync;
always_ff @(posedge i_tdc_clk or negedge i_fifo_rst_n) begin
    if (!i_fifo_rst_n) begin
        rst_ckr_0 <= 1'b0;
        rst_ckr_sync <= 1'b0;
    end else begin
        rst_ckr_0 <= 1'b1;           // Flop 1 D-pin is tied high
        rst_ckr_sync <= rst_ckr_0;  // Flop 2 catches Flop 1
    end
end
//    async_fifo_gray_read_twice #(
//         .DATA_W (GAUSS_W),
//         .ADDR_W (FIFO_ADDR_W)
//     ) u_fifo (
//         .i_wr_clk    (i_div16_clk),
//         .i_wr_rst_n  (i_fifo_rst_n),
//         .i_wr_en     (fifo_wr_en),
//         .i_wr_data   (o_gaussian_filter),
//         .o_full      (o_fifo_full),

//         .i_rd_clk    (i_tdc_clk),
//         .i_rd_rst_n  (rst_ckr_sync),
//         .i_rd_en     (fifo_rd_en),
//         .o_rd_data   (o_fifo_rd_data),
//         .o_empty     (o_fifo_empty),
//         .o_rd_valid  (o_fifo_rd_valid)
//     );

//       // Internal wires


      // ============================================================
    // Modulation path 1: LMS Booth multiplier
    // ============================================================

    modulation_path1_lms_booth #(
        .SAMPLE_W (GAUSS_W),
        .LMS_W    (LMS_W),
        .PROD_W   (PROD_W),
        .OUT_W    (DCO_W)
    ) u_path1 (
        .i_tdc_clk     (i_tdc_clk),
        .i_rst_n       (rst_ckr_sync),
        .i_path1_en    (i_path1_en),

        .i_fifo_sample (o_gaussian_filter),
        .i_fifo_valid  (1'b1),

        .i_lms         (i_lms),

        .o_dco_data    (o_dco_data),
        .o_dco_valid   (o_dco_valid)
    );

      // Internal wires
      // ============================================================
    // Modulation path 2: TDC alignment path
    // ============================================================

    modulation_path2_tdc_align #(
        .DATA_W       (GAUSS_W),
        .ALIGN_STAGES (ALIGN_STAGES)
    ) u_path2 (
        .i_tdc_clk     (i_tdc_clk),
        .i_rst_n       (rst_ckr_sync),
        .i_path2_en    (i_path2_en),

        .i_fifo_sample (o_gaussian_filter),
        .i_fifo_valid  (1'b1),

        .o_tdc_data    (o_tdc_data),
        .o_tdc_valid   (o_tdc_valid)
    );

endmodule