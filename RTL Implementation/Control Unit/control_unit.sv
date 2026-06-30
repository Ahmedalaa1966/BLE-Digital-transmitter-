import CU_states::*;
import dco_package::*;

module control_unit #(
    parameter ch_fraction = 16
) (
// system signal
    input  logic i_clk,
    input  logic i_rst_n_cu,
    
    // link layer flag
    input  logic i_ll_tx_start                  ,  // flag form the link layer to start transmitter   
    input  logic i_ll_modulation_start          ,  // flag from ----
    input  logic i_ll_hopping                   ,  // flag to indicate hopping

    input  logic i_ll_mod_end                   ,  // Connection end trigger
    input  logic i_ll_conn_end                  ,
    input  logic i_bit_ready                    ,
    input  logic i_sending_bits                 ,

    // Outputs
    output logic o_phy_ready                    ,   // link layer flag
    output logic o_pvt_required                 ,
    output logic o_rf_flag                      ,   // Rf enable flag
    output logic o_adpll_en                       ,
    //  output to adpll_fsm
    output logic [1:0] o_mode                   ,

    //  output to GMSK
    output logic o_tr_en                        ,  //select between training sequence and link layer data enable
    output logic o_gaussian_en                  ,
    output logic o_upsample_en                  ,
    output logic o_nrz_en                       ,
    output logic o_input_bit_valid              ,

    // output to LMS
    output logic o_lms_enable                   ,
    output logic o_lms_reset                    ,

    // path enables 
    output logic o_path1_en                     ,
    output logic o_path2_en                     ,                   
    output logic o_rst_sd_n                     ,
    output logic o_sd_en                        ,
    output logic o_gmsk_rst_n                   ,
    output logic o_rst_tap_n                    ,
    output logic o_hold_sample                  ,
    output logic o_fifo_rst_n                   ,
    output logic o_ckr_rst_n

);

logic      connection_end  ;
logic      done_flag       ;
logic      pvt_required    ;
logic      bg_tmu_count_en ;
logic      tmu_en          ;
cu_state_t cu_state        ;
logic      w_rst_n_tmu     ;


assign o_pvt_required = pvt_required;

control_unit_fsm #(.ch_fraction(ch_fraction)) cu_u (

    // system signal
    .i_clk                 (i_clk),
    .i_rst_n_cu            (i_rst_n_cu),
    .i_ll_tx_start         (i_ll_tx_start)                   ,      // flag form the link layer to start transmitter   
    .i_ll_modulation_start (i_ll_modulation_start)           ,      // flag from ----
    .i_ll_hopping          (i_ll_hopping)                    ,      // flag to indicate hopping

    .i_connection_end      (connection_end)                  ,      // flag from the link layer to indicate the connection end              
    .i_done_flag           (done_flag)                       ,      // flag form the tmu unit 
    .i_pvt_required        (pvt_required)                    ,      // flag from the tmu to indicate the  
    .i_bit_ready           (i_bit_ready)                     ,      // input from the nrz block 

    // Outputs 
    .o_bg_tmu_count_en     (bg_tmu_count_en)                 ,      // enable for background counter that calc sleep mode duration                
    .o_tmu_en              (tmu_en)                          ,      // enable for counter that account latency in system and mode transition
    .o_cu_state            (cu_state)                        ,
    .o_adpll_en            (o_adpll_en)                        , 
    .o_mode                (o_mode)                          ,
    .o_gaussian_en         (o_gaussian_en)                   , 
    .o_nrz_en              (o_nrz_en)                        ,
    .o_upsample_en         (o_upsample_en)                   ,
    .o_input_bit_valid     (o_input_bit_valid)               ,
    .o_lms_enable          (o_lms_enable)                    ,
    .o_lms_reset           (o_lms_reset)                     ,
    .o_path1_en            (o_path1_en)                      ,
    .o_path2_en            (o_path2_en)                      ,
    .o_sd_en               (o_sd_en)                           ,
    .o_rst_sd_n            (o_rst_sd_n)                        ,
    .o_rst_n_tmu           (w_rst_n_tmu)                       ,
    .o_ckr_rst_n           (o_ckr_rst_n)

    );

    tmu tmu_u1 (
    .i_clk                 (i_clk)                          ,    // 32MHz Clock
    .i_rst_n_tmu           (w_rst_n_tmu)                    ,    // Active low reset
    .i_cu_state            (cu_state)                       ,    // Current state from cu
    .i_bg_tmu_count_en     (bg_tmu_count_en)                ,    // enable for background counter that calc sleep mode duration                
    .i_tmu_en              (tmu_en)                         ,    // enable for counter that account latency in system and mode transition
    .i_ll_mod_end          (i_ll_mod_end)                   ,    // Connection end trigger
    .i_ll_conn_end         (i_ll_conn_end)                  ,
    .o_done_flag           (done_flag)                      ,    // Trigger for CU state transition
    .o_pvt_required        (pvt_required)                   , 
    .o_conn_end            (connection_end)                 ,
    .o_tr_en               (o_tr_en)                        ,    // training sequence enable 
    .o_rf_flag             (o_rf_flag)                      ,    // rf flag  on when link layer modulated data reach to interface between phy and rf  
    .o_phy_ready           (o_phy_ready)                     ,    // PHY status signal
    .o_rst_tap_n           (o_rst_tap_n)                    ,
    .o_gmsk_rst_n          (o_gmsk_rst_n)                   ,
    .o_fifo_rst_n          (o_fifo_rst_n)                   ,
    .o_hold_sample         (o_hold_sample)
    );

endmodule