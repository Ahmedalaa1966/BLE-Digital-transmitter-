import CU_states::*;
import dco_package::*;

module control_unit_fsm #(parameter ch_fraction = 16) (
    // system signal
    input  logic i_clk,
    input  logic i_rst_n_cu,

    // link layer flag
    input  logic i_ll_tx_start                            ,      // flag form the link layer to start transmitter   
    input  logic i_ll_modulation_start                    ,      // flag from the link layer to start the modulation
    input  logic i_ll_hopping                             ,      // flag to indicate hopping
 

    // tmu flags
    input  logic i_connection_end                         ,      // flag from the link layer to indicate the connection end              
    input  logic i_done_flag                              ,      // flag form the tmu unit 
    input  logic i_pvt_required                           ,      // flag from the tmu to indicate the 

    // non return to zero block 
    input logic  i_bit_ready                              ,      // output bit ready is the output of the NRZ block and input to the control unit and when this signal is high the control unit send the input bit valid which makes the non return to zero receive signal 
//    input logic  i_sending_bits                           ,  

    // Outputs
    //  output to tmu 
    output logic o_bg_tmu_count_en                        ,      // enable for background counter that calc sleep mode duration                
    output logic o_tmu_en                                 ,      // enable for counter that account latency in system and mode transition
    output cu_state_t o_cu_state                          ,

    //  output to adpll_fsm
    output logic [1:0] o_mode                             ,
    output logic  o_adpll_en                              ,
         //  output to GMSK
    output logic o_upsample_en                            , 
    output logic o_nrz_en                                 ,
    output logic o_gaussian_en                            ,      
    output logic o_input_bit_valid                        ,      

    // output to LMS
    output logic o_lms_enable                             ,     
    output logic o_lms_reset                              ,  

    // path enables 
    output logic o_path1_en                               ,
    output logic o_path2_en                               , 
    output logic o_rst_n_tmu                              ,
    output logic o_rst_sd_n                               ,
    output logic o_sd_en                                  ,
    output logic o_ckr_rst_n
);

    cu_state_t cs, ns;     
    logic rst_n_tmu_reg , rst_n_tmu;
    logic tmu_en_reg;
    logic ckr_rst_reg;
    // Matches MATLAB's 'tmu_wake_en' persistent variable:
    // - Clears whenever NOT in SLEEP (so it starts fresh each sleep entry)
    // - Latches to 1 when i_ll_modulation_start fires DURING SLEEP
    logic sleep_wakeup_latch;

    assign o_cu_state = cs;
    // STATE REGISTER
    always_ff @(posedge i_clk or negedge i_rst_n_cu) begin
        if (!i_rst_n_cu) begin
            cs <= IDLE;
        end
        else begin
            cs <= ns;
        end    
    end
    always_ff @(posedge i_clk or negedge i_rst_n_cu) begin
        if (!i_rst_n_cu) begin
           tmu_en_reg <= 0;
        end
        else begin
           tmu_en_reg <= o_tmu_en;
        end    
    end

    // sleep_wakeup_latch: cleared every cycle we are NOT in SLEEP
    //                     latches high when wake-up arrives IN SLEEP
    always_ff @(posedge i_clk or negedge i_rst_n_cu) begin
        if (!i_rst_n_cu) begin
            sleep_wakeup_latch <= 1'b0;
        end else begin
            if (cs == SLEEP) begin
                if (i_ll_modulation_start)
                    sleep_wakeup_latch <= 1'b1;  // latch wake-up
                // else: hold existing value (stays 0 until wake-up comes)
            end else begin
                sleep_wakeup_latch <= 1'b0;  // clear on any non-SLEEP state
            end
        end
    end

// we should reset ckr unit to avoid overflow of phase error as sleep mode make takes seconds in BLE 
    always_ff @(posedge i_clk or negedge i_rst_n_cu) begin
        if (!i_rst_n_cu) begin
            ckr_rst_reg <= 1'b0;
        end else begin
            case (cs)
                IDLE: begin
                    ckr_rst_reg <= 1'b0;
                end
                SLEEP: begin
                    if (i_ll_modulation_start || sleep_wakeup_latch) begin
                        ckr_rst_reg <= 1'b1;
                    end else begin
                        ckr_rst_reg <= 1'b0;
                    end
                end
                default: begin
                    ckr_rst_reg <= 1'b1;
                end
            endcase
        end
    end
    assign o_ckr_rst_n = ckr_rst_reg;
   
    // NEXT STATE LOGIC
    always_comb begin
        ns = cs;
        case (cs)

            IDLE: begin
                if (i_ll_tx_start)
                    ns = PVT_CAL;
                else 
                    ns = IDLE ;
            end

            PVT_CAL: begin
                if (i_done_flag )
                    ns = ACQUISITION;
                else 
                    ns = PVT_CAL ;
            end

            ACQUISITION: begin
                if (i_done_flag )
                    ns = TRACKING ;
                else 
                    ns = ACQUISITION ;
            end

            TRACKING: begin 
                    if (i_done_flag )
                        ns = TRAINING;
                    else 
                        ns = TRACKING ;    
            end

            TRAINING: begin
                if (i_done_flag )
                    ns = MODULATION;
                else    
                    ns = TRAINING ;
            end

            MODULATION: begin
                if (i_done_flag) begin
                    ns = SLEEP;
                end
                else if (i_connection_end) begin
                    ns = IDLE;
                end
            end

            SLEEP: begin
                if (i_ll_hopping || (i_pvt_required && i_ll_modulation_start)) begin
                   ns   = PVT_CAL ;
                end
                else if(i_done_flag)
                    ns = MODULATION ;
                else if (i_connection_end)
                    ns = IDLE ;
                else    
                    ns = SLEEP ;
            end

            default: ns = IDLE ;

        endcase
    end




    // output logic FSM
    always_comb begin
        // Default values
        o_adpll_en              = 1;
        o_gaussian_en           = 0;
        o_upsample_en           = 0;
        o_input_bit_valid       = 0;
        o_path1_en              = 0;
        o_path2_en              = 0;
        o_lms_enable            = 0;
        o_lms_reset             = i_rst_n_cu;
        o_mode                  = FREEZE_MODE;
        o_nrz_en                = 0;
        o_tmu_en                = 1;
        o_bg_tmu_count_en       = 1;
        o_rst_sd_n              = 0;
        o_sd_en                 = 0;
        o_rst_n_tmu             = 1;   // Default: TMU running in all active states
        rst_n_tmu               = 1;   // Local default (used only in SLEEP)
        case (cs)

            IDLE: begin
                o_adpll_en         = 0;
                o_tmu_en           = 0;
                o_bg_tmu_count_en  = 0;
                o_rst_n_tmu        = 0;   // TMU reset in IDLE
             end

            PVT_CAL: begin
                o_mode      = PVT_MODE;
            end

            ACQUISITION: begin
                o_mode      = ACQ_MODE;
            end

            TRACKING: begin
                o_mode    = TRACK_MODE;
            end

            TRAINING: begin      
                o_sd_en                  = 1;
                o_rst_sd_n               = 1;
                o_lms_enable             = 1;                  
                o_lms_reset              = 1;                  
                o_upsample_en            = 1;                   
                o_mode                   = TRACK_MODE;
                o_nrz_en                 = 1;                    
                o_input_bit_valid        = i_bit_ready;
                o_path1_en               = 1;
                o_path2_en               = 1;
                o_gaussian_en            = 1;


            end

            MODULATION: begin
                o_sd_en                  = 1;
                o_rst_sd_n               = 1;

                o_lms_reset              = 1;
                o_gaussian_en            = 1;
                o_nrz_en                 = 1;
                o_upsample_en            = 1;
                o_nrz_en                 = 1;
                o_mode                   = TRACK_MODE;
                o_path1_en              = 1;
                o_path2_en              = 1;
                o_input_bit_valid        = i_bit_ready;
                // if(i_sending_bits)
                    o_input_bit_valid        = i_bit_ready;
                // else 
                //     o_input_bit_valid        = 'b0;
            end

            SLEEP: begin
                o_mode             = FREEZE_MODE;
                o_tmu_en           = 0;
                o_bg_tmu_count_en  = 1;
                if (i_ll_modulation_start || sleep_wakeup_latch) begin
                    rst_n_tmu   = 1;
                    o_rst_n_tmu = 1;
                    o_tmu_en    = 1;
                end else begin
                    rst_n_tmu   = 0;
                    o_rst_n_tmu = 0;
                end
            end

        endcase
    end

endmodule