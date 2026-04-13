module puesdotherm_decoder #(
		parameter int     TAP_COUNT,
		parameter int OUT_BIT_WIDTH
	)
	(
		input  logic [0:TAP_COUNT - 1]                i_q,
		output logic                         o_rise_found, 
		output logic                         o_fall_found,
		output logic [OUT_BIT_WIDTH - 1:0]     o_tdc_rise, 		
		output logic [OUT_BIT_WIDTH - 1:0]     o_tdc_fall 	
	);
	
	logic [0:TAP_COUNT - 2] q_rise;  
	logic [0:TAP_COUNT - 2] q_fall;
	assign q_rise = (i_q[0:TAP_COUNT-2])&(~i_q[1:TAP_COUNT-1]);
	assign q_fall = (~i_q[0:TAP_COUNT-2])&(i_q[1:TAP_COUNT-1]);
	
	always_comb begin
		o_rise_found     = 0;
		o_tdc_rise       = 0;
		o_fall_found     = 0;
		o_tdc_fall       = 0;
		
		for(int i = (TAP_COUNT - 2); i>= 1;i--) begin
			if (q_rise[i]) begin
				o_rise_found = 1;
				o_tdc_rise = i;
			end
			
			if (q_fall[i]) begin
				o_fall_found = 1;
				o_tdc_fall = i;
			end
		end
	end
endmodule 