`timescale 1ps/1ps
module tdc_env();
	////////          PARAMETERS         /////
	localparam time T_REF                = 31250ps;
	localparam time T_DCO                = 400ps;
	localparam time T_RES                = 10ps;    // propagation delay of buffers in tapped delay line
	localparam int  TAP_COUNT            = 62;      // number of taps in the delay line
	localparam int  FREF_DELAY           = 4;       // number of buffer delays 
	localparam int  FRACTIONAL_BIT_WIDTH = 16;
	localparam int  INTEGER_BIT_WIDTH    = 24;
	localparam int  ROM_DIVIDENT_SIZE    = 64;      // number of dividents in divider rom
	localparam int  ROM_DIVISOR_SIZE     = 64;      // number of divisors in divider rom
	localparam int  N                    = 20;      // number of reference cycles the simulation will run for
	
	localparam int  NUM_STAGES           = 2;       // number of stages in reference clock synchronizer 
	
	////////          RESET              /////
	logic rst_n;
	
	////////          CLOCKS              /////
	logic ref_clk           = 1; //FREF
	logic dco_clk           = 1; //CKV
	logic ckr_clk;
	logic ckr_delayed_clk;
	logic ref_delayed_clk;
	
	logic ckr_clk_sync;
	logic ckr2_clk_sync;
	
	logic ckr_clk_sync_c; 
	logic ckr2_clk_sync_c;
	
	////////         CLOCK SYNCHRONIZER            /////
	data_sync #(
				.NUM_STAGES(NUM_STAGES), 
				.BUS_WIDTH(1)
				) ckr_sync(
				.clk(dco_clk), 
				.rst_n(1'b1),
				.unsync_bus(ref_clk), 
				.sync_bus(ckr_clk_sync)
				);
				
	data_sync #(
				.NUM_STAGES(NUM_STAGES), 
				.BUS_WIDTH(1)
				) ckr2_sync(
				.clk(dco_clk), 
				.rst_n(1'b1),
				.unsync_bus(ref_delayed_clk), 
				.sync_bus(ckr2_clk_sync)
				);
				
	data_sync #(
				.NUM_STAGES(NUM_STAGES+1), 
				.BUS_WIDTH(1)
				) ckr_sync_c(
				.clk(dco_clk), 
				.rst_n(1'b1),
				.unsync_bus(ref_clk), 
				.sync_bus(ckr_clk_sync_c)
				);
				
	data_sync #(
				.NUM_STAGES(NUM_STAGES+1), 
				.BUS_WIDTH(1)
				) ckr2_sync_c(
				.clk(dco_clk), 
				.rst_n(1'b1),
				.unsync_bus(ref_delayed_clk), 
				.sync_bus(ckr2_clk_sync_c)
				);
				
	logic count_en;  //enable dco running counters
	
	data_sync #(
				.NUM_STAGES(NUM_STAGES), 
				.BUS_WIDTH(1)
				) count_en_sync(
				.clk(dco_clk), 
				.rst_n(rst_n),
				.unsync_bus(1'b1), 
				.sync_bus(count_en)
				);
				
	////////         CONTROL SIGNALS               ///// 
	logic accumulator_en    = 0;    // enable for accumulators
	logic skip;                     // determine if cycle is potentially skipped due to FREF edge being close to CKV edge
	logic ckr_xor_ckr2;
	logic ref_delay_line_en = 1'b1; //delay line enable of fref 
	logic ckv_delay_line_en = 1'b1;
	
	////////         OUTPUT SIGNALS               /////
	logic [FRACTIONAL_BIT_WIDTH - 1:0] 		 			   tdc_frac_out_comp;  // 2's complement fractional part of variable phase
	logic [FRACTIONAL_BIT_WIDTH - 1:0] 					   tdc_frac_out;       // fractional part of variable phase
	logic [FRACTIONAL_BIT_WIDTH - 1:0] 					   tdc_frac_o;         // fractional part of variable phase
	logic [INTEGER_BIT_WIDTH - 1:0]    					   tdc_int_out;        // ceiled integer part of variable phase
	logic [FRACTIONAL_BIT_WIDTH + INTEGER_BIT_WIDTH - 1:0] tdc_out;            // ceiled integer part of variable phase
	logic                                                  o_valid;            // indiciate output phase value is valid

	//////// 		INTERNAL SIGNALS                ////
	logic [INTEGER_BIT_WIDTH - 1:0]    		dco_cycles_count;         // number of dco cycles
	logic                              		r_dec;                    // subtract 1 from integer part of variable phase to account for cycle skipping       
	logic [0: TAP_COUNT-1]             		ckv_delay_line_word;      // digital word of the dco clock delay line
	logic [0: TAP_COUNT-1]             		q_delay_line_sync;        // digital word captured by reference clock
	logic [0: FREF_DELAY-1]            		ref_delay_line_word;      // digital word of the delay line
	
	logic                              		rise_found;               // indiciate if rising edge is found within the delay line
	logic                              		fall_found;          	  // indiciate if falling edge is found within the delay line
	logic [$clog2(ROM_DIVIDENT_SIZE):0] 	tdc_rise;                 // index of first rising edge in the delay line
	logic [$clog2(ROM_DIVIDENT_SIZE):0] 	tdc_fall;			      // index of first falling edge in the delay line
	
	logic [$clog2(ROM_DIVIDENT_SIZE):0] 	t_ckv_calc;			      // calculated dco clock period interms of tap delays
	logic [$clog2(ROM_DIVIDENT_SIZE):0] 	t_ckv_half_period;        // calculated dco clock half period interms of tap delays	
	
	logic  [FRACTIONAL_BIT_WIDTH - 1:0]     o_frac_output;            //output of divider
	
	////////   ACCOUNTING FOR RANDOM PHASE START    /////
	logic                              count_start;      //start dco clock counter
	logic                              r_dec_0;          // r_dec value of the first REF rising edge
	logic [FRACTIONAL_BIT_WIDTH - 1:0] frac_out_init;    // initial fractional part captured 
	
	
	////////         CLOCK GENERATION              /////
	 
	always begin //dco clk generation
		#(T_DCO/2) dco_clk = ~dco_clk;
	end
	
	always begin //ref clk generation
		#(T_REF/2) ref_clk = ~ref_clk;
	end
	
	always_ff @(posedge dco_clk or negedge rst_n) begin //retimed CKR clk generation 
		if(!rst_n) begin
			ckr_clk <= 0;
		end 
		else begin
			ckr_clk <= ref_clk;
		end
	end
	
	always_ff @(posedge dco_clk or negedge rst_n) begin //retimed delayed CKR2 clk generation 
		if(!rst_n) begin
			ckr_delayed_clk <= 0;
		end
		else begin
			ckr_delayed_clk <= ref_delayed_clk;
		end
	end
	
	////////         DELAY LINE              /////
	delay_line #(
		.TAP_COUNT(TAP_COUNT),     
		.T_RES(T_RES)
	) ckv_delay_line(
		.i_signal(dco_clk),
		.enable(ckv_delay_line_en),
		.q_delay_line(ckv_delay_line_word)
	);
	
	delay_line #(
		.TAP_COUNT(FREF_DELAY),     
		.T_RES(T_RES)
	) ref_clk_delay_line(
		.i_signal(ref_clk),
		.enable(ref_delay_line_en),
		.q_delay_line(ref_delay_line_word)
	);
	assign ref_delayed_clk = ref_delay_line_word[FREF_DELAY - 1];
	
	///// capture puesdo-theromometer code from delay line  ////
	always_ff @(posedge ref_clk or negedge rst_n) begin
		if(!rst_n) begin
			q_delay_line_sync <= 0;
		end
		else begin
			q_delay_line_sync <= ckv_delay_line_word;
		end
	end
	
	///// puesdo theromometer code edge detector + divider  ////
	puesdotherm_decoder #(.TAP_COUNT(TAP_COUNT),
						  .OUT_BIT_WIDTH($clog2(ROM_DIVIDENT_SIZE) + 1))
	puedotherm_decoder_u (
		.q(q_delay_line_sync),
		.rise_found(rise_found), 
		.fall_found(fall_found),
		.tdc_rise(tdc_rise), 		
		.tdc_fall(tdc_fall) 	
	);
	
	divider_rom#(
		.OUTPUT_BIT_WIDTH(FRACTIONAL_BIT_WIDTH),
		.ROM_DIVIDENT_SIZE(ROM_DIVIDENT_SIZE),
		.ROM_DIVISOR_SIZE(ROM_DIVISOR_SIZE)
	) divider_u(	
		.clk(ckr2_clk_sync),
		.rst_n(rst_n),
		.i_dividend(tdc_rise), 
		.i_divisor(t_ckv_calc),
		.o_frac_output(o_frac_output)
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
				tdc_frac_out      = (1<<FRACTIONAL_BIT_WIDTH) - 1;
				tdc_frac_out_comp = 0;
			end
			else begin
				tdc_frac_out = o_frac_output;
				tdc_frac_out_comp = ~o_frac_output + 1;
			end
			
			if (({1'b0, tdc_rise} + 2) >= t_ckv_calc) begin
				skip = 1;
			end else begin
				skip = 0;
			end
			
		end else begin
			t_ckv_calc = 0;
			tdc_frac_out = 0;
			tdc_frac_out_comp = 0;
			skip = 0;
		end 
	end
	
	/// update reference counter and capture variable phase
	always_comb begin
		if(skip || ckr_xor_ckr2) begin
			r_dec = 1;
		end 
		else begin
			r_dec = 0;
		end
	end
	
	always_ff @(posedge ckr2_clk_sync_c or negedge rst_n) begin
		if(!rst_n) begin
			tdc_int_out    <= 0;
			accumulator_en <= 0;
			r_dec_0        <= 0;
			frac_out_init  <= 0;
			o_valid        <= 0;
			tdc_frac_o     <= 0;
			tdc_out        <= 0;
		end
		else begin
			if(accumulator_en) begin
				tdc_out       = (dco_cycles_count<<FRACTIONAL_BIT_WIDTH) + ((r_dec_0 - r_dec)<<FRACTIONAL_BIT_WIDTH);
				tdc_out       = tdc_out - tdc_frac_out_comp + frac_out_init;
				tdc_int_out  <= tdc_out[FRACTIONAL_BIT_WIDTH + INTEGER_BIT_WIDTH - 1: FRACTIONAL_BIT_WIDTH];
				tdc_frac_o   <= tdc_out[FRACTIONAL_BIT_WIDTH - 1: 0];
				o_valid      <= 1;
			end
			else begin
				o_valid       <= 0;
				tdc_int_out   <= 0;
				frac_out_init <= tdc_frac_out_comp;
				tdc_frac_o    <= 0;
				r_dec_0       <= r_dec;
				tdc_out       <= 0;
			end
			accumulator_en <= 1;
			
		end      
    end
	
	/// integer number of dco cycles 
	always_ff @(negedge dco_clk or negedge rst_n) begin
		if(!rst_n) begin
			dco_cycles_count <= 0;
		end
		else if(accumulator_en) begin
			dco_cycles_count <= dco_cycles_count + 1;
		end
	end
	
	/// XOR CKR and CKR2
	always_ff @(negedge dco_clk or negedge rst_n) begin
		if(!rst_n) begin
			ckr_xor_ckr2 <= 0;
		end
		else begin
			ckr_xor_ckr2 <= ckr_clk_sync_c ^ ckr2_clk_sync_c;
		end
	end
	
	/// simuluation 
	initial begin
		$dumpfile("tdc_waveforms.vcd");
		$dumpvars(0, tdc_env);
		rst_n = 1'b0;
		repeat(10) @(negedge dco_clk);
		
		rst_n = 1;
		
		#(N*T_REF);
		
		$finish;	
	end
endmodule