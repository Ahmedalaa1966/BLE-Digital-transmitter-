module tdc_block #(
	parameter int FRACTIONAL_BIT_WIDTH,
	parameter int INTEGER_BIT_WIDTH,
	parameter int TAP_COUNT,
	parameter int T_RES,
	parameter int ROM_DIVIDENT_SIZE,
	parameter int ROM_DIVISOR_SIZE
	
)(
	input  logic i_rst_n,
	input  logic i_dco_clk,
	input  logic i_ref_clk,
	input  logic i_ckr2_clk_sync,                                             // retimed delayed ref clock after 2 stage synchronizer
	input  logic i_ckr_clk_sync_c,                                            // retimed ref clock after 3 stage synchronizer 
	input  logic i_ckr2_clk_sync_c,                                           // retimed delayed ref clock after 3 stage synchronizer 
	input  logic i_ckv_delay_line_en,
	output logic o_valid,                                                     // indicates output variable phase is valid
	output logic [FRACTIONAL_BIT_WIDTH + INTEGER_BIT_WIDTH - 1:0] o_var_phase //output variable phase
	
);

	////////         CONTROL SIGNALS               ///// 
	logic accumulator_en;    		// enable for accumulators
	logic skip;                     // determine if cycle is potentially skipped due to FREF edge being close to CKV edge
	logic ckr_xor_ckr2;
	
	
	////////         OUTPUT SIGNALS               /////
	logic [FRACTIONAL_BIT_WIDTH - 1:0] 	tdc_frac_out_comp;  // 2's complement fractional part of variable phase
	logic [FRACTIONAL_BIT_WIDTH - 1:0] 	tdc_frac_out;       // fractional part of variable phase
	logic [FRACTIONAL_BIT_WIDTH - 1:0] 	tdc_frac_o;         // fractional part of variable phase
	logic [INTEGER_BIT_WIDTH - 1:0]    	tdc_int_out;        // ceiled integer part of variable phase


	//////// 		INTERNAL SIGNALS                ////
	logic [INTEGER_BIT_WIDTH - 1:0]     dco_cycles_count;         // number of dco cycles
	logic                              	r_dec;                    // subtract 1 from integer part of variable phase to account for cycle skipping       
	logic [0: TAP_COUNT-1]             	ckv_delay_line_word;      // digital word of the dco clock delay line
	logic [0: TAP_COUNT-1]              q_delay_line_sync;        // digital word captured by reference clock
	
	
	////////   ACCOUNTING FOR RANDOM PHASE START    /////
	logic                               r_dec_0;          // r_dec value of the first REF rising edge
	logic [FRACTIONAL_BIT_WIDTH - 1:0]  frac_out_init;    // initial fractional part captured 
	
	
	////////         DELAY LINE              /////
	delay_line #(
		.TAP_COUNT(TAP_COUNT),     
		.T_RES(T_RES)
	) ckv_delay_line(
		.i_signal(i_dco_clk),
		.enable(i_ckv_delay_line_en),
		.q_delay_line(ckv_delay_line_word)
	);
	
	///// capture puesdo-theromometer code from delay line  ////
	always_ff @(posedge i_ref_clk or negedge i_rst_n) begin
		if(!i_rst_n) begin
			q_delay_line_sync <= 0;
		end
		else begin
			q_delay_line_sync <= ckv_delay_line_word;
		end
	end
	
	///// puesdo theromometer code edge detector + divider  ////
	tdc_core#(.TAP_COUNT(TAP_COUNT),
			  .ROM_DIVIDENT_SIZE(ROM_DIVIDENT_SIZE),
			  .FRACTIONAL_BIT_WIDTH(FRACTIONAL_BIT_WIDTH),
			  .ROM_DIVISOR_SIZE(ROM_DIVISOR_SIZE)
	) tdc_core_u(
			  .i_clk(i_ckr2_clk_sync),
			  .i_rst_n(i_rst_n),
			  .i_q(q_delay_line_sync),
			  .o_skip(skip),
			  .o_tdc_frac(tdc_frac_out),
			  .o_tdc_frac_comp(tdc_frac_out_comp)
	);
	
	/// update reference counter and capture variable phase
	always_comb begin
		if(skip || ckr_xor_ckr2) begin
			r_dec = 1;
		end 
		else begin
			r_dec = 0;
		end
	end
	
	always_ff @(posedge i_ckr2_clk_sync_c or negedge i_rst_n) begin
		if(!i_rst_n) begin
			tdc_int_out    <= 0;
			accumulator_en <= 0;
			r_dec_0        <= 0;
			frac_out_init  <= 0;
			o_valid        <= 0;
			tdc_frac_o     <= 0;
			o_var_phase        <= 0;
		end
		else begin
			if(accumulator_en) begin
				o_var_phase   = (dco_cycles_count<<FRACTIONAL_BIT_WIDTH) + ((r_dec_0 - r_dec)<<FRACTIONAL_BIT_WIDTH);
				o_var_phase   = o_var_phase - tdc_frac_out_comp + frac_out_init;
				tdc_int_out  <= o_var_phase[FRACTIONAL_BIT_WIDTH + INTEGER_BIT_WIDTH - 1: FRACTIONAL_BIT_WIDTH];
				tdc_frac_o   <= o_var_phase[FRACTIONAL_BIT_WIDTH - 1: 0];
				o_valid      <= 1;
			end
			else begin
				o_valid       <= 0;
				tdc_int_out   <= 0;
				frac_out_init <= tdc_frac_out_comp;
				tdc_frac_o    <= 0;
				r_dec_0       <= r_dec;
				o_var_phase   <= 0;
			end
			accumulator_en <= 1;
			
		end      
    end
	
	/// integer number of dco cycles 
	always_ff @(negedge i_dco_clk or negedge i_rst_n) begin
		if(!i_rst_n) begin
			dco_cycles_count <= 0;
		end
		else if(accumulator_en) begin
			dco_cycles_count <= dco_cycles_count + 1;
		end
	end
	
	/// XOR CKR and CKR2
	always_ff @(negedge i_dco_clk or negedge i_rst_n) begin
		if(!i_rst_n) begin
			ckr_xor_ckr2 <= 0;
		end
		else begin
			ckr_xor_ckr2 <= i_ckr_clk_sync_c ^ i_ckr2_clk_sync_c;
		end
	end

endmodule