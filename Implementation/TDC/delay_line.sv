`timescale 1ps/1ps
module delay_line #(
		parameter int  TAP_COUNT,     // Number of taps
		parameter time T_RES = 10ps
	)(
		input  logic i_signal,
		input  logic enable,
		output logic [0: TAP_COUNT-1] q_delay_line
	);
	
	assign q_delay_line[0] = (enable) ? i_signal:1'b0;
	genvar i;
	generate
		for( i = 1;i<TAP_COUNT;i++) begin : delay_stages
			assign #(T_RES) q_delay_line[i] = q_delay_line[i-1];
		end
	endgenerate 
endmodule