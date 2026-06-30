import CU_states::*;
import dco_package::*;
import ble_tx_params_pkg::*;

module outside_adpll_top #(

    parameter int          FIFO_ADDR_W  = 2,

    parameter int          LMS_W        = 11,
    parameter int          LMS_EXT_W    = LMS_W + 1,
    parameter int          PROD_W       = GAUSS_W + LMS_EXT_W,
    parameter int          DCO_W        = 14,

    parameter int          ALIGN_STAGES = 2
) (
    // =========================================================================
    // Clocks & reset
    // =========================================================================
    input  logic                          i_ref_clk,            // crystal clock
    input  logic                          i_tdc_clk,            //ckr clock
    input  logic                          i_rst_n_cu,           //  global reset

    // =========================================================================
    // Link-layer → Control-unit interface
    // =========================================================================
    input  logic                          i_ll_tx_start,        // Start transmitter
    input  logic                          i_ll_modulation_start,// Start modulation
    input  logic                          i_ll_hopping,         // Channel-hop indicator
    input  logic                          i_ll_mod_end,         // Modulation end
    input  logic                          i_ll_conn_end,        // Connection end

    // =========================================================================
    // Control-unit → external (ADPLL / RF / upper layers)
    // =========================================================================
    output logic                          o_phy_ready,          // PHY ready to link layer
    output logic                          o_pvt_required,       // PVT calibration request
    output logic                          o_rf_flag,            // RF enable flag
    output logic [1:0]                    o_mode,               // ADPLL mode select              // Training-sequence enable (→ TMU/MUX)

    // =========================================================================
    // LMS control (driven to external LMS update block)
    // =========================================================================
    output logic                          o_lms_enable,
    output logic                          o_lms_reset,
    // sd signal
    output logic                          o_sd_en,
    output logic                          o_rst_sd_n,
    output logic                          o_rst_tap_n,
    // =========================================================================
    // Gaussian filter reset (driven to TX chain externally if needed)
    // Note: exposed here so ADPLL FSM or a reset-sync block can assert it
    //       independently from i_rst_n.
    // =========================================================================

    // =========================================================================
    // TX-chain data input
    // =========================================================================
    input  logic                          i_phy_bit,                                // Raw PHY bit from link layer 

    // =========================================================================
    // Gaussian coefficient ROM/register interface
    // =========================================================================
    input  logic signed [TAP_W-1:0]       i_tap_value,
    input  logic        [TAP_ADDR_W-1:0]  i_tap_address,
    input  logic                          i_tap_we,

    // =========================================================================
    // LMS modulation gain input
    // =========================================================================
    input  logic        [LMS_W-1:0]       i_lms,

    // =========================================================================
    // TX-chain monitor outputs (optional; tie-off if not needed)
    // =========================================================================

    // =========================================================================
    // Final modulation outputs
    // =========================================================================
    output logic signed [DCO_W-1:0]       o_dco_data,          

    output logic signed [GAUSS_W-1:0]     o_tdc_data, 
    output logic                          o_adpll_en,
    output logic                          o_ckr_rst_n
);

    // =========================================================================
    // Internal wires – control_unit → ble_tx_chain_two_paths_top
    // =========================================================================
    logic                   w_nrz_en;
    logic                   w_upsample_en;
    logic                   w_gaussian_en;
    logic                   w_path1_en;
    logic                   w_path2_en;
    logic                   w_input_bit_valid;
    logic                   o_tr_en;

    // =========================================================================
    // Internal wires – ble_tx_chain_two_paths_top → control_unit
    // =========================================================================
    logic                   w_bit_ready  ;
    logic                   w_gmsk_rst_n ;
    logic                   w_fifo_rst_n ;
    logic                   w_rst_tap_n  ;
    logic                   w_hold_sample;
    assign o_rst_tap_n = w_rst_tap_n;

    // =========================================================================
    // Instance 1 : control_unit
    // =========================================================================
    control_unit #(
        .ch_fraction (ch_fraction)
    ) u_control_unit (
        // ── System ────────────────────────────────────────────────────────────
        .i_clk                  (i_ref_clk),
        .i_rst_n_cu                (i_rst_n_cu),

        // ── Link-layer inputs ─────────────────────────────────────────────────
        .i_ll_tx_start          (i_ll_tx_start),
        .i_ll_modulation_start  (i_ll_modulation_start),
        .i_ll_hopping           (i_ll_hopping),
        .i_ll_mod_end           (i_ll_mod_end),
        .i_ll_conn_end          (i_ll_conn_end),
        .i_sending_bits          (1'b1) ,

        // ── Feedback from TX chain ────────────────────────────────────────────
        .i_bit_ready            (w_bit_ready),

        // ── External outputs ──────────────────────────────────────────────────
        .o_phy_ready            (o_phy_ready),
        .o_pvt_required         (o_pvt_required),
        .o_rf_flag              (o_rf_flag),
        .o_mode                 (o_mode),
        .o_tr_en                (o_tr_en),
        .o_adpll_en             (o_adpll_en),

        // ── LMS control (top-level ports) ─────────────────────────────────────
        .o_lms_enable           (o_lms_enable),
        .o_lms_reset            (o_lms_reset),

        // ── Enables → TX chain (internal) ─────────────────────────────────────
        .o_nrz_en               (w_nrz_en),
        .o_upsample_en          (w_upsample_en),
        .o_gaussian_en          (w_gaussian_en),
        .o_path1_en             (w_path1_en),
        .o_path2_en             (w_path2_en),
        .o_input_bit_valid      (w_input_bit_valid) ,
        .o_sd_en                (o_sd_en),
        .o_rst_sd_n             (o_rst_sd_n),
        .o_gmsk_rst_n           (w_gmsk_rst_n),
        .o_rst_tap_n            (w_rst_tap_n),
        .o_hold_sample          (w_hold_sample),
        .o_fifo_rst_n           (w_fifo_rst_n),
        .o_ckr_rst_n            (o_ckr_rst_n)
    );

    // =========================================================================
    // Clock Divider (32 MHz -> 16 MHz)
    // =========================================================================
    logic w_clk_16mhz;

    clk_divider #(
        .DIV_FACTOR(2)
    ) u_clk_div (
        .i_clk    (i_ref_clk),
        .i_rst_n  (i_rst_n_cu),
        .o_clk_div(w_clk_16mhz)
    );

    // =========================================================================
    // Instance 1.5 : Training Sequence Generator & Multiplexer
    // =========================================================================
    logic w_training_bit;
    logic w_muxed_phy_bit;
    logic w_bit_ready_d;

    always_ff @(posedge w_clk_16mhz or negedge i_rst_n_cu) begin
        if (!i_rst_n_cu) begin
            w_bit_ready_d <= 1'b0;
        end else begin
            w_bit_ready_d <= w_bit_ready;
        end
    end

    logic w_bit_ready_pe;
    assign w_bit_ready_pe = w_bit_ready && (~w_bit_ready_d);

    training_seq_generation u_training_seq (
        .i_clk    (w_clk_16mhz),
        .i_rst_n  (i_rst_n_cu),
        .i_en     (w_input_bit_valid && w_bit_ready_pe && o_tr_en),
        .o_seq_bit(w_training_bit)
    );

    assign w_muxed_phy_bit = o_tr_en ? w_training_bit : i_phy_bit;

    // =========================================================================
    // Instance 2 : ble_tx_chain_two_paths_top
    // =========================================================================
    ble_tx_chain_two_paths_top #(
        .SPAN         (SPAN),
        .SPS          (SPS),
        .L            (L),
        .HALF_TAPS    (HALF_TAPS),
        .TAP_W        (TAP_W),
        .GAUSS_W      (GAUSS_W),
        .TAP_ADDR_W   (TAP_ADDR_W),
        .FIFO_ADDR_W  (FIFO_ADDR_W),
        .LMS_W        (LMS_W),
        .LMS_EXT_W    (LMS_EXT_W),
        .PROD_W       (PROD_W),
        .DCO_W        (DCO_W),
        .ALIGN_STAGES (ALIGN_STAGES)
    ) u_ble_tx_chain (
        // ── Clocks & reset ─────────────────────────────────────────────────────
        .i_div16_clk            (w_clk_16mhz),
        .i_tdc_clk              (i_tdc_clk),
        .i_rst_n                (w_gmsk_rst_n),

        // ── Enables (from control_unit) ───────────────────────────────────────
        .i_nrz_en               (w_nrz_en),
        .i_upsample_en          (w_upsample_en),
        .i_gaussian_en          (w_gaussian_en),
        .i_path1_en             (w_path1_en),
        .i_path2_en             (w_path2_en),
        .i_ref_clk              (i_ref_clk),
        .i_rst_tap_n            (w_rst_tap_n),
        .i_fifo_rst_n           (w_fifo_rst_n),
        .i_hold_sample        (w_hold_sample),  

        // ── Data input ────────────────────────────────────────────────────────
        .i_phy_bit              (w_muxed_phy_bit),
        .i_bit_valid            (w_gmsk_rst_n),   // tied to 1 as requested
        .o_bit_ready            (w_bit_ready),         // fed back to CU

        // ── Coefficient interface ─────────────────────────────────────────────
        .i_tap_value            (i_tap_value),
        .i_tap_address          (i_tap_address),
        .i_tap_we               (i_tap_we),

        // ── LMS gain ──────────────────────────────────────────────────────────
        .i_lms                  (i_lms),

        // ── Monitor outputs ───────────────────────────────────────────────────

        // ── Final outputs ─────────────────────────────────────────────────────
        .o_dco_data             (o_dco_data),
        .o_tdc_data             (o_tdc_data)
    );



endmodule