module LMS_inputs (

  input logic i_clk,
  input logic i_rst_n,
  input logic i_iir_en,
  input logic signed [39:0] i_phase_err,
  input logic signed [5:0] i_mod_data,
  output logic signed [10:0] o_err,
  output logic signed [5:0] o_data
);



//---------------------- Instantiate DUT---------------------------//
phase_err_path  phase_err_path (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_iir_en(i_iir_en),
    .i_phase_err(i_phase_err),
    .o_err(o_err)
);

Mod_path  Mod_path (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_iir_en(i_iir_en),
    .i_mod_data(i_mod_data),
    .o_data(o_data)
);



endmodule