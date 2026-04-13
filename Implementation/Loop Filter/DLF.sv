module DLF 
#( parameter PHASE_ERR_WIDTH = 40,
   parameter OTW_WIDTH = 23,
   parameter ACCUMULATOR_WIDTH = 64
 )    

 (
   input logic i_ckr_clk,
   input logic i_rst_n,
   input logic signed [PHASE_ERR_WIDTH-1:0] i_phase_err,      //TDC phase error 

   //Inputs from Control Unit
   input logic i_dlf_en,
   input logic i_gear_shift_en,
   //Proportional and integral gains from ccontrol unit for reconfigurability
   input logic [3:0] i_alpha_shift,   //proportional gain = 2^-alpha_shift_i
   input logic [3:0] i_beta_shift,    // integral gain = 2^-beta_shift_i

   output logic signed [OTW_WIDTH-1:0] o_otw        // DCO tuning word  

 );
//------------------------------LOCAL PARAMETERS-----------------------------------//
   
   // Intgrator saturation limits capped at OTW range
   localparam signed [ACCUMULATOR_WIDTH-1:0] MAX_I = {1'b0, {(ACCUMULATOR_WIDTH-1){1'b1}}};
   localparam signed [ACCUMULATOR_WIDTH-1:0] MIN_I = {1'b1, {(ACCUMULATOR_WIDTH-1){1'b0}}};
  
//------------------------------Internal signals---------------------------------//
  
   logic signed [ACCUMULATOR_WIDTH-1 : 0] integrator;    
   logic signed [ACCUMULATOR_WIDTH-1 : 0] I_next;
   logic signed [ACCUMULATOR_WIDTH-1 : 0] I_sat;
   logic signed [ACCUMULATOR_WIDTH-1 : 0] I;
   logic gear_shift_done;

   logic signed [ACCUMULATOR_WIDTH-1 : 0] prop_path;             // accumulator width to be able to be added to I_sat
   logic signed [ACCUMULATOR_WIDTH-1 : 0] phase_err_extended;    // phase error with accumulator width to match prop path
   logic signed [ACCUMULATOR_WIDTH-1:0]   otw_full;              // OTW with accumulator width


//-----------------------------INITIALIZALIZATIONS-------------------------------------//
    //sign-extion phase error to accumulator width keeping sign bit 
   assign phase_err_extended = {{(ACCUMULATOR_WIDTH-PHASE_ERR_WIDTH){i_phase_err[PHASE_ERR_WIDTH-1]}}, i_phase_err};
    // proportional and integral paths
   assign prop_path = phase_err_extended >>> i_alpha_shift;
   assign I_next    = integrator + (phase_err_extended >>>i_beta_shift);
    //Full width otw (64)
   assign otw_full = prop_path + I_sat;


//----------------Gear shift pulse detection----------------//
always_ff @(posedge i_ckr_clk or negedge i_rst_n) begin
  if (!i_rst_n)
    gear_shift_done <= 1'b0;
  else if (i_gear_shift_en && i_dlf_en)
    gear_shift_done <= 1'b1;
  else if(!i_dlf_en)
    gear_shift_done <=0;
end

//-------------------- Integrator mux--------------------//
always_comb begin
 
 if (i_gear_shift_en) begin   
     // Gear shift: pre-load sign extended(64) old otw(23) - new prop path 
    I = {{(ACCUMULATOR_WIDTH-OTW_WIDTH){o_otw[OTW_WIDTH-1]}}, o_otw} - prop_path;                       
  end
  else if ((!i_gear_shift_en && gear_shift_done)) begin
    //Normal operation
    I = I_next;  
  end
  else begin
    I = 0;               // Pre gear-shift: (Accumulator is off Type-I DLF)
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


//------------------------------------ Sequential update---------------------------------//
    always_ff @(posedge i_ckr_clk or negedge i_rst_n ) begin  
     if(!i_rst_n) begin 
      integrator   <= 0 ; 
      o_otw        <= 0;
     end
     else if(i_dlf_en) begin

        integrator   <= I_sat;
        o_otw       <= otw_full[OTW_WIDTH-1:0];

     end
    end

endmodule

