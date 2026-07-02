module DLF                                  
#( parameter PHASE_INT_BITS  = 24,
   parameter PHASE_FRAC_BITS = 16,
   parameter OTW_INT_BITS    = 4,
   parameter OTW_FRAC_BITS   = 19,
   parameter ACC_FRAC_BITS   = 31      //MAX  SHIFT Value of beta = 15 (4 bit reg)     
 )    
 (
   input logic i_ckr_clk,
   input logic i_rst_n,
   input logic signed [PHASE_INT_BITS+PHASE_FRAC_BITS-1:0] i_phase_err,      //TDC phase error 

   //Inputs from Control Unit
   input logic i_dlf_en,
   input logic i_gear_shift_en,

   //Proportional and integral gains from ccontrol unit for reconfigurability
   input logic [3:0] i_alpha_shift,   //proportional gain = 2^-alpha_shift_i
   input logic [3:0] i_beta_shift,    // integral gain = 2^-beta_shift_i

   output logic signed [OTW_INT_BITS+OTW_FRAC_BITS-1:0] o_otw        // DCO tuning word  

 );
//------------------------------LOCAL PARAMETERS-----------------------------------//
   localparam PHASE_ERR_WIDTH = PHASE_INT_BITS + PHASE_FRAC_BITS;
   localparam OTW_WIDTH = OTW_INT_BITS + OTW_FRAC_BITS;
   localparam ACCUMULATOR_WIDTH = PHASE_INT_BITS + ACC_FRAC_BITS;
   localparam PAD_WIDTH = ACC_FRAC_BITS - PHASE_FRAC_BITS;     // 31 - 16 = 15 

    // Signals saturation limits
   localparam signed [ACCUMULATOR_WIDTH-1:0] MAX_I = {1'b0, {(ACCUMULATOR_WIDTH-1){1'b1}}};
   localparam signed [ACCUMULATOR_WIDTH-1:0] MIN_I = {1'b1, {(ACCUMULATOR_WIDTH-1){1'b0}}};
   localparam signed [OTW_WIDTH-1:0] OTW_MAX = {1'b0, {(OTW_WIDTH-1){1'b1}}};  //  7.9999...
   localparam signed [OTW_WIDTH-1:0] OTW_MIN = {1'b1, {(OTW_WIDTH-1){1'b0}}};  // -8

  
//------------------------------Internal signals---------------------------------//
  
   logic signed [ACCUMULATOR_WIDTH-1 : 0] integrator;    
   logic signed [ACCUMULATOR_WIDTH-1 : 0] I_next;
   logic signed [ACCUMULATOR_WIDTH-1 : 0] I_sat;
   logic signed [ACCUMULATOR_WIDTH-1 : 0] I;
   logic gear_shift_done;

   logic signed [ACCUMULATOR_WIDTH-1 : 0] prop_path;  // accumulator width to be able to be added to I_sat
   logic signed [ACCUMULATOR_WIDTH-1:0] otw_full;     // OTW with accumulator width
   logic signed [ACCUMULATOR_WIDTH-1:0] phase_ext;    
   logic signed [PHASE_ERR_WIDTH-1:0] sampled_ph_err;    
   logic signed [PHASE_ERR_WIDTH-1:0] Adj_ph_err;    

   logic signed [OTW_WIDTH-1:0] otw_sat;
   logic signed [OTW_WIDTH-1:0] otw_trunc;
   
//-----------------------------Initializations-------------------------------------//
   assign Adj_ph_err = i_phase_err - sampled_ph_err;

   assign phase_ext = {Adj_ph_err, {PAD_WIDTH{1'b0}}};         //Extend phase error with max possible shift value

   assign prop_path  = phase_ext >>> i_alpha_shift;  

   assign I_next    = integrator +  (phase_ext >>> i_beta_shift);   
   
   assign otw_full = prop_path + I_sat;
   //truncate otw to check saturation
   assign otw_trunc = signed'({otw_full[ACCUMULATOR_WIDTH-1],                                         // Sign bit 
                                otw_full[ACC_FRAC_BITS + OTW_INT_BITS - 2 : ACC_FRAC_BITS],           // OTW integer bits -1 (sign)
                                  otw_full[ACC_FRAC_BITS-1 : ACC_FRAC_BITS-OTW_FRAC_BITS]});          // OTW Fractional bits


//----------------------OTW saturation logic-----------------//

always_comb begin
  if (otw_trunc > OTW_MAX)
    otw_sat = OTW_MAX;
  else if (otw_trunc < OTW_MIN)
    otw_sat = OTW_MIN;
    else
    otw_sat = signed'({otw_full[ACCUMULATOR_WIDTH-1],                                           // Sign bit 
                                otw_full[ACC_FRAC_BITS + OTW_INT_BITS - 2 : ACC_FRAC_BITS],    // OTW integer bits -1 (sign)
                                  otw_full[ACC_FRAC_BITS-1 : ACC_FRAC_BITS-OTW_FRAC_BITS]});   // OTW Fractional bits
end
   
//-------------------Gear shift pulse detection--------------//

always_ff @(posedge i_ckr_clk or negedge i_rst_n) begin
  if (!i_rst_n)
    gear_shift_done <= 1'b0;
  else if (i_gear_shift_en && i_dlf_en)
    gear_shift_done <= 1'b1;
  else if(!i_dlf_en)
    gear_shift_done <=0;
end

//---------------------- Integrator mux----------------------//

always_comb begin
 
 if (i_gear_shift_en && !gear_shift_done) begin    
    I = 0;                 
  end
  else if ((!i_gear_shift_en && gear_shift_done)) begin
    //Normal operation
    I = I_next;  
  end
  else begin
    I =  0;               // Pre gear-shift: (Accumulator is off Type-I DLF)
  end
end

//---------------Integrator saturation logic--------------//
always_comb begin
  if (I > MAX_I)
    I_sat = MAX_I;
  else if (I < MIN_I)
    I_sat = MIN_I;
  else
    I_sat = I;
end

//-----------------------Sequential update-------------------//

    always_ff @(posedge i_ckr_clk or negedge i_rst_n ) begin  
     if(!i_rst_n) begin 
      integrator   <= 0 ; 
      o_otw        <= 0;
     sampled_ph_err <=0; 
     end
     else if(i_dlf_en) begin      // Infered clock gating at synthesis (turn off clock if enable =0)

      integrator   <= I_sat ;
      o_otw        <= otw_sat ;
      if (i_gear_shift_en && !gear_shift_done) 
      sampled_ph_err <= i_phase_err;
    
     end
    end



endmodule
