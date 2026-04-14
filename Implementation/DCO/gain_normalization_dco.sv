import dco_package::*; 

module gain_normalization_dco #(parameter int DATA_WIDTH =23)  (
input logic       signed  [DATA_WIDTH-1:0]         i_norm,    // input from loop filter
input dco_mode_t                                   i_mode,    // mode < PVT_MODE , ACQ_MODE , TRACK_MODE >
output logic signed [7:0]            o_otw_int,   // 8-bit Integer to DCO Interface "absolute frequency tuning word"
output logic        [7:0]            o_otw_frac   // 8-bit Fraction to Sigma-Delta  "absolute frequency tuning word"
    );
    // normalizer : phase error is normalized to reference clock
    // gain_normalization_dco opposite operation to generate absolute OTW (oscillator control word)
    // shift_value by how much we will multipler is input taken from control unit depends on mode
    // in case of PVT mode then we multiply by 32MHz/2MHz =16 shift left by 4
    // in case of  acquistion  32MHz/0.5MHz = 64 -> shift left by 16
    // in case of tracking 32MHz/25KHz = 1280 = (2^10 + 2^8)
    // max integer is +- 8 would be in PVT calibration
  logic      signed  [(DATA_WIDTH+10):0]     o_otw_dco ;  // absolute frequency tuning word goes to dco interface after determine fixed point
    always_comb begin
            case (i_mode)
                PVT_MODE: o_otw_dco = i_norm <<< 4;
                ACQ_MODE: o_otw_dco = i_norm <<< 6;
                TRACK_MODE:begin
                 o_otw_dco = (i_norm <<< 10) + (i_norm <<< 8);
                 end
                default:  o_otw_dco = 0;
            endcase
    end   
   assign o_otw_int  = o_otw_dco[26:19];
   assign o_otw_frac = (i_mode == TRACK_MODE) ? o_otw_dco[18:11] : 8'b0;
endmodule
