module IIR_1 # (
   parameter INPUT_WIDTH = 11,          // 1 int , 10 frac
   parameter ALPHA_IIR = 3,
   parameter INT_WIDTH = INPUT_WIDTH + 12 // performing internal calculations with 12 extra fractional bits
) 
(
   input logic i_clk,
   input logic i_rst_n,
   input logic i_iir_en,
   input logic signed [INPUT_WIDTH-1:0] i_iir,

   output logic signed [INPUT_WIDTH+3-1:0] o_iir        

);

//------------------------------Internal signals---------------------------------//
   logic signed [INT_WIDTH-1:0] i_iir_ext;
   logic signed [INT_WIDTH-1:0] prop_path;
   logic signed [INT_WIDTH-1:0] feedback_path;
   logic signed [INT_WIDTH-1:0] previous_o_iir_ext;
   logic signed [INT_WIDTH-1:0] iir_next;

//-------------------------------Combinational updates---------------------------//

//--------Proportional path----------// 
   assign i_iir_ext = signed'({i_iir , 12'd0}) ;       // 1 int , 13 (10+3) frac  

   assign prop_path = signed'( i_iir_ext >>> ALPHA_IIR );      
   // prop_path     =    INPUT_WIDTH+3 (14)

//--------feedback path------------//
   assign feedback_path = previous_o_iir_ext - ( previous_o_iir_ext >>> ALPHA_IIR );


   assign iir_next = feedback_path + prop_path;

   assign o_iir = iir_next[INT_WIDTH-1:9];
//------------------------------------ Sequential update---------------------------------//

    always_ff @(posedge i_clk or negedge i_rst_n ) begin  
     
     if(!i_rst_n) begin 
   
    previous_o_iir_ext <= 0;
       end
     else if(i_iir_en) begin
   
      previous_o_iir_ext <= iir_next; 
       end
    end

endmodule
