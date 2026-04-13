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
	
	////////         CONTROL SIGNALS               ///// 
	logic ref_delay_line_en = 1'b1; //delay line enable of fref 
	logic ckv_delay_line_en = 1'b1;
	
	////////         OUTPUT SIGNALS               /////
	logic [INTEGER_BIT_WIDTH - 1:0]    					   tdc_int_out;        // ceiled integer part of variable phase
	logic [FRACTIONAL_BIT_WIDTH - 1:0]                     tdc_frac_out;       // ceiled integer part of variable phase
	logic [FRACTIONAL_BIT_WIDTH + INTEGER_BIT_WIDTH - 1:0] tdc_out;            // ceiled integer part of variable phase
	logic                                                  o_valid;            // indiciate output phase value is valid
	
	////////        INTERNAL SIGNALS               /////
	logic [0: FREF_DELAY-1]  ref_delay_line_word;      // digital word of the delay line
	
	////////         CLOCK SYNCHRONIZER            /////
	data_sync #(
				.NUM_STAGES(NUM_STAGES), 
				.BUS_WIDTH(1)
				) ckr_sync(
				.i_clk(dco_clk), 
				.i_rst_n(1'b1),
				.i_unsync_bus(ref_clk), 
				.o_sync_bus(ckr_clk_sync)
				);
				
	data_sync #(
				.NUM_STAGES(NUM_STAGES), 
				.BUS_WIDTH(1)
				) ckr2_sync(
				.i_clk(dco_clk), 
				.i_rst_n(1'b1),
				.i_unsync_bus(ref_delayed_clk), 
				.o_sync_bus(ckr2_clk_sync)
				);
				
	data_sync #(
				.NUM_STAGES(NUM_STAGES+1), 
				.BUS_WIDTH(1)
				) ckr_sync_c(
				.i_clk(dco_clk), 
				.i_rst_n(1'b1),
				.i_unsync_bus(ref_clk), 
				.o_sync_bus(ckr_clk_sync_c)
				);
				
	data_sync #(
				.NUM_STAGES(NUM_STAGES+1), 
				.BUS_WIDTH(1)
				) ckr2_sync_c(
				.i_clk(dco_clk), 
				.i_rst_n(1'b1),
				.i_unsync_bus(ref_delayed_clk), 
				.o_sync_bus(ckr2_clk_sync_c)
				);
				
	
	
	assign tdc_int_out  = tdc_out[INTEGER_BIT_WIDTH + FRACTIONAL_BIT_WIDTH - 1: FRACTIONAL_BIT_WIDTH];
	assign tdc_frac_out = tdc_out[FRACTIONAL_BIT_WIDTH - 1: 0];
	
	
	////////         CLOCK GENERATION              /////
	 
	always begin //dco clk generation
		#(T_DCO/2) dco_clk = ~dco_clk;
	end
	
	always begin //ref clk generation
		#(T_REF/2) ref_clk = ~ref_clk;
	end
	
	always_ff @(posedge dco_clk) begin //retimed CKR clk generation 
		ckr_clk <= ref_clk;
	end
	
	always_ff @(posedge dco_clk ) begin //retimed delayed CKR2 clk generation 
		ckr_delayed_clk <= ref_delayed_clk;
	end
	
	////////         REF CLOCK DELAY              /////
	
	delay_line #(
		.TAP_COUNT(FREF_DELAY),     
		.T_RES(T_RES)
	) ref_clk_delay_line(
		.i_signal(ref_clk),
		.enable(ref_delay_line_en),
		.q_delay_line(ref_delay_line_word)
	);
	assign ref_delayed_clk = ref_delay_line_word[FREF_DELAY - 1];
	
	////////        TDC BLOCK INSTANIATION             /////
	tdc_block #(
				.FRACTIONAL_BIT_WIDTH(FRACTIONAL_BIT_WIDTH),
				.INTEGER_BIT_WIDTH(INTEGER_BIT_WIDTH),
				.TAP_COUNT(TAP_COUNT),
				.T_RES(T_RES),
				.ROM_DIVIDENT_SIZE(ROM_DIVIDENT_SIZE),
				.ROM_DIVISOR_SIZE(ROM_DIVISOR_SIZE)
	
			)tdc_block_u(
				.i_rst_n(rst_n),
				.i_dco_clk(dco_clk),
				.i_ref_clk(ref_clk),
				.i_ckr2_clk_sync(ckr2_clk_sync),                                             
				.i_ckr_clk_sync_c(ckr_clk_sync_c),                                            
				.i_ckr2_clk_sync_c(ckr2_clk_sync_c),                                           
				.i_ckv_delay_line_en(ckv_delay_line_en),
				.o_valid(o_valid),                                                     
				.o_var_phase(tdc_out) 
			);
	
	
	
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