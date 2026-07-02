module Mod_path # (
   parameter INPUT_WIDTH_1 = 6,        
   parameter INPUT_WIDTH_2 = 9,        
   //     final = 9+6 = 15 
   parameter OUT_WIDTH = 6            
) ( 

  input logic i_clk,
  input logic i_rst_n,
  input logic i_iir_en,
  input logic signed [INPUT_WIDTH_1-1:0] i_mod_data,
  output logic signed [OUT_WIDTH-1:0] o_data
);


logic signed [INPUT_WIDTH_2-1:0] o_mod_data_iir1;
logic signed [INPUT_WIDTH_2+6-1:0] o_mod_data_iir2;
logic signed [INPUT_WIDTH_2+7-1:0] o_data_full;         
logic signed [INPUT_WIDTH_2+7-1:0] o_mod_data_iir1_ext;

//---------------------- Instantiate DUT---------------------------//
IIR_1 #(
    .INPUT_WIDTH(INPUT_WIDTH_1)
) IIR_1 (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_iir_en(i_iir_en),
    .i_iir(i_mod_data),
    .o_iir(o_mod_data_iir1)
);

IIR_2 #(
    .INPUT_WIDTH(INPUT_WIDTH_2)
) IIR_2 (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_iir_en(i_iir_en),
    .i_iir(o_mod_data_iir1),
    .o_iir(o_mod_data_iir2)
);


assign o_mod_data_iir1_ext = signed'({o_mod_data_iir1[INPUT_WIDTH_2-1], o_mod_data_iir1 , 6'd0});

assign o_data_full = o_mod_data_iir1_ext - signed'({o_mod_data_iir2[INPUT_WIDTH_2+6-1], o_mod_data_iir2});

assign o_data = o_data_full[13:8];      

endmodule
