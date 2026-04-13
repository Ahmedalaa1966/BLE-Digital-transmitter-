module tdc_core#(
	parameter int TAP_COUNT,
	parameter int ROM_DIVIDENT_SIZE,
	parameter int FRACTIONAL_BIT_WIDTH,
	parameter int ROM_DIVISOR_SIZE
)(
	input  logic                              i_clk,
	input  logic                              i_rst_n,
	input  logic [0: TAP_COUNT-1]             i_q,
	output logic                              o_skip,
	output logic [FRACTIONAL_BIT_WIDTH - 1:0] o_tdc_frac,
	output logic [FRACTIONAL_BIT_WIDTH - 1:0] o_tdc_frac_comp
	
);

	logic                              		rise_found;               // indiciate if rising edge is found within the delay line
	logic                              		fall_found;          	  // indiciate if falling edge is found within the delay line
	logic [$clog2(ROM_DIVIDENT_SIZE):0] 	tdc_rise;                 // index of first rising edge in the delay line
	logic [$clog2(ROM_DIVIDENT_SIZE):0] 	tdc_fall;			      // index of first falling edge in the delay line
	logic [$clog2(ROM_DIVIDENT_SIZE):0] 	t_ckv_calc;			      // calculated dco clock period interms of tap delays
	logic  [FRACTIONAL_BIT_WIDTH - 1:0]     o_frac;                   //output of divider
	
	puesdotherm_decoder #(.TAP_COUNT(TAP_COUNT),
						  .OUT_BIT_WIDTH($clog2(ROM_DIVIDENT_SIZE) + 1))
	puedotherm_decoder_u (
		.i_q(i_q),
		.o_rise_found(rise_found), 
		.o_fall_found(fall_found),
		.o_tdc_rise(tdc_rise), 		
		.o_tdc_fall(tdc_fall) 	
	);
	
	divider_rom#(
		.OUTPUT_BIT_WIDTH(FRACTIONAL_BIT_WIDTH),
		.ROM_DIVIDENT_SIZE(ROM_DIVIDENT_SIZE),
		.ROM_DIVISOR_SIZE(ROM_DIVISOR_SIZE)
	) divider_u(	
		.i_clk(i_clk),
		.i_rst_n(i_rst_n),
		.i_dividend(tdc_rise), 
		.i_divisor(t_ckv_calc),
		.o_frac(o_frac)
	);
	
	always_comb begin
		if (rise_found && fall_found) begin
			if(tdc_rise >= tdc_fall) begin
				t_ckv_calc = (tdc_rise - tdc_fall)<<1;
			end
			else begin
				t_ckv_calc = (tdc_fall - tdc_rise)<<1;
			end

			if(tdc_rise >= t_ckv_calc) begin
				o_tdc_frac      = (1<<FRACTIONAL_BIT_WIDTH) - 1;
				o_tdc_frac_comp = 0;
			end
			else begin
				o_tdc_frac = o_frac;
				o_tdc_frac_comp = ~o_frac + 1;
			end
			
			if (({1'b0, tdc_rise} + 2) >= t_ckv_calc) begin
				o_skip = 1;
			end else begin
				o_skip = 0;
			end
			
		end else begin
			t_ckv_calc        = 0;
			o_tdc_frac        = 0;
			o_tdc_frac_comp   = 0;
			o_skip            = 0;
		end 
	end
endmodule