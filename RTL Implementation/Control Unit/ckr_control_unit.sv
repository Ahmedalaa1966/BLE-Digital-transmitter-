import dco_package::*;

module ckr_control_unit (
    input  logic      clk,           
    input  logic      rst_n,         
    input  dco_mode_t next_state,
    
    output dco_mode_t mode_adpll_del ,
    output logic      pd_rst_del     ,
    output logic      gear_shifting  ,
    output logic      lf_coeff_sel  

);
    dco_mode_t target_state, mode_adpll;
    logic  pd_rst; 
    logic pd_idle, pd_idle_reg;
    logic gear_shifting_reg; 
    logic gear_sh_state_reg;
    logic      gear_sh_state;
    assign lf_coeff_sel = gear_sh_state_reg;
    always_comb begin 
        case (target_state)
            FREEZE_MODE: pd_idle = pd_idle_reg;
            ACQ_MODE   : pd_idle = 1;
            TRACK_MODE : pd_idle = 1;
            PVT_MODE   : pd_idle = 1;
            default:     pd_idle = 1;
        endcase
    end
    always_comb begin 
        case (target_state)
            FREEZE_MODE: gear_sh_state = gear_shifting_reg;
            ACQ_MODE   : gear_sh_state = 0;
            TRACK_MODE : gear_sh_state = 1;
            default:     gear_sh_state = 0;
            PVT_MODE   : gear_sh_state = 0;
        endcase
    end
   always_ff @(posedge clk or negedge rst_n) begin
           if (!rst_n) begin
                gear_sh_state_reg   <= 0;
        end 
        else begin
                gear_sh_state_reg  <= gear_sh_state;
        end
   end
    // 1-cycle delay to align all outputs to DLF and DCO
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_adpll_del <= FREEZE_MODE;
            pd_rst_del     <= 1'b0;
            pd_idle_reg    <= 1'b0;
            gear_shifting  <= 1'b0;
        end 
        else begin
            mode_adpll_del <= mode_adpll;
            pd_rst_del     <= pd_rst & pd_idle;
            pd_idle_reg    <= pd_idle;
            gear_shifting  <= gear_shifting_reg; // perfectly aligned with mode_adpll_del
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_adpll        <= FREEZE_MODE;
            pd_rst            <= 1'b0;
            target_state      <= FREEZE_MODE;
            gear_shifting_reg <= 1'b0;
        end 
        else begin
            gear_shifting_reg <= 1'b0;
            pd_rst            <= 1'b1;
            
            // If we are currently in FREEZE_MODE as a transition state to TRACK_MODE
            if (mode_adpll == FREEZE_MODE && target_state == TRACK_MODE) begin
                mode_adpll        <= TRACK_MODE;
                gear_shifting_reg <= 1'b1; // Trigger gear shift exactly when mode becomes TRACK
            end
            // Detect request to change state
            else if (target_state != next_state && next_state != FREEZE_MODE) begin                
                if (target_state == ACQ_MODE && next_state == TRACK_MODE) begin
                    // Intentional 1-cycle FREEZE_MODE to prevent 3000KHz shoot!
                    mode_adpll   <= FREEZE_MODE; 
                    target_state <= next_state; // target is now TRACK_MODE
                    pd_rst       <= 1'b0;
                end
                else begin
                    target_state <= next_state;
                    mode_adpll   <= next_state; 
                    pd_rst       <= 1'b0;
                end              
            end 
            else begin
                mode_adpll   <= next_state;        
                target_state <= next_state;
            end
        end
    end
endmodule
