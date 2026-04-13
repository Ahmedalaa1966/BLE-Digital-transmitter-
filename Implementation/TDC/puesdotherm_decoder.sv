module puesdotherm_decoder #(parameter int     TAP_COUNT,
							 parameter int OUT_BIT_WIDTH)
	(
		input  logic [0:TAP_COUNT - 1]              q,
		output logic                       rise_found, 
		output logic                       fall_found,
		output logic [OUT_BIT_WIDTH - 1:0]   tdc_rise, 		
		output logic [OUT_BIT_WIDTH - 1:0]   tdc_fall 	
	);
	
	logic [0:TAP_COUNT - 2] q_rise;  
	logic [0:TAP_COUNT - 2] q_fall;
	assign q_rise = (q[0:TAP_COUNT-2])&(~q[1:TAP_COUNT-1]);
	assign q_fall = (~q[0:TAP_COUNT-2])&(q[1:TAP_COUNT-1]);
	
	always_comb begin
		rise_found     = 0;
		tdc_rise       = 0;
		fall_found     = 0;
		tdc_fall       = 0;
		
		for(int i = (TAP_COUNT - 2); i>= 1;i--) begin
			if (q_rise[i]) begin
				rise_found = 1;
				tdc_rise = i;
			end
			
			if (q_fall[i]) begin
				fall_found = 1;
				tdc_fall = i;
			end
		end
	end
endmodule 