import dco_package::*; 

module dco_interface(
    input  logic              i_clk_ckr,    // Clock domain: CKR
    input  logic              i_rst_n,      // Asynchronous active-low reset
    input  logic signed [7:0] i_otw,        // Signed Oscillator Tuning Word from Loop Filter & gain_normalization
    input  logic              i_dco_int_en, // dco interface enable 
    input  dco_mode_t         i_mode,       // Current FSM state (PVT/ACQ/TRACK)
    output logic        [7:0] o_otw_p,      // Unsigned Output to PVT Bank
    output logic        [7:0] o_otw_acq,    // Unsigned Output to Acquisition Bank
    output logic        [5:0] o_otw_track   // Unsigned Output to Tracking Bank
);

// DCO interface description:
// DCO has different capacitor banks for coarse, fine frequency control.
// Selected i_mode takes output from loop filter while others keep their old state.

    logic signed [7:0] tune_next_p , tune_prev_p;
    logic signed [7:0] tune_next_acq , tune_prev_acq;
    logic signed [5:0] tune_next_track,tune_prev_track;

// flip MSB for sign to unsign conversion

    assign o_otw_p =tune_next_p; 
    assign o_otw_acq = tune_next_acq;
    assign o_otw_track = tune_next_track;

    always_ff @( posedge i_clk_ckr , negedge i_rst_n ) begin : blockName
        if(!i_rst_n) begin
        tune_next_p     <= 8'h80; // Reset to mid-scale (unsigned 128)
        tune_next_acq   <= 8'h80;
        tune_next_track <= 6'h20; 
        end
        else if(i_dco_int_en)  begin
        tune_next_p <=tune_prev_p;
        tune_next_acq <= tune_prev_acq;
        tune_next_track <= tune_prev_track ; 
        end
    end
    always_comb begin
        tune_prev_p     = tune_next_p;
        tune_prev_acq   = tune_next_acq;
        tune_prev_track = tune_next_track;
        case (i_mode)
            PVT_MODE  : tune_prev_p = {~i_otw[7],i_otw[6:0]}; 
            ACQ_MODE   : tune_prev_acq = {~i_otw[7],i_otw[6:0]}; 
            TRACK_MODE : begin
            if ((i_otw[7] == i_otw[6]) && (i_otw[6] == i_otw[5])) begin
                tune_prev_track =  {~i_otw[5],i_otw[4:0]};
            end 
            else if (i_otw[7] == 1'b0) begin
                tune_prev_track = 6'd63;    
            end 
            else begin
                tune_prev_track = 0;   
            end
            end
        endcase 
    end
    
endmodule 