module phase_err_path # (
   parameter INPUT_WIDTH_1 = 40,        
   parameter INPUT_WIDTH_2 = 43,     
   
   parameter OUT_WIDTH = 11
) ( 

  input logic i_clk,
  input logic i_rst_n,
  input logic i_iir_en,
  input logic signed [INPUT_WIDTH_1-1:0] i_phase_err,
  output logic signed [OUT_WIDTH-1:0] o_err
);


logic signed [INPUT_WIDTH_2-1:0] o_phase_err_iir1;
logic signed [INPUT_WIDTH_2+6-1:0] o_phase_err_iir2;
logic signed [INPUT_WIDTH_2+7-1:0] o_err_full;          // (21)
logic signed [INPUT_WIDTH_2+7-1:0] o_phase_err_iir1_ext;

//---------------------- Instantiate DUT---------------------------//
IIR_1 #(
    .INPUT_WIDTH(INPUT_WIDTH_1)
) IIR_1 (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_iir_en(i_iir_en),
    .i_iir(i_phase_err),
    .o_iir(o_phase_err_iir1)
);

IIR_2 #(
    .INPUT_WIDTH(INPUT_WIDTH_2)
) IIR_2 (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_iir_en(i_iir_en),
    .i_iir(o_phase_err_iir1),
    .o_iir(o_phase_err_iir2)
);

assign o_phase_err_iir1_ext = signed'({o_phase_err_iir1[INPUT_WIDTH_2-1], o_phase_err_iir1, 6'd0});

assign o_err_full = o_phase_err_iir1_ext - signed'({o_phase_err_iir2[INPUT_WIDTH_2+6-1], o_phase_err_iir2});

assign o_err = o_err_full[25:15];

endmodule
