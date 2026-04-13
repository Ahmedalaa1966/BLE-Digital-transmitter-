module divider_rom#(
		parameter int OUTPUT_BIT_WIDTH,
		parameter int ROM_DIVIDENT_SIZE,
		parameter int ROM_DIVISOR_SIZE
	)(	
		input  logic 								     i_clk,
		input  logic                                     i_rst_n,
		input  logic  [$clog2(ROM_DIVIDENT_SIZE) - 1:0]  i_dividend, 
		input  logic  [$clog2(ROM_DIVISOR_SIZE) - 1:0]   i_divisor,
		output logic  [OUTPUT_BIT_WIDTH - 1:0]       	 o_frac //Q0.OUTPUT_BIT_WIDTH 
	);
	
	logic [OUTPUT_BIT_WIDTH - 1:0] rom_memory [0:ROM_DIVIDENT_SIZE - 1][0:ROM_DIVISOR_SIZE - 1];

    initial begin
        $readmemh("frac_div_lut.mem", rom_memory);
    end
	
	always_ff @(posedge i_clk or negedge i_rst_n) begin
		if(!i_rst_n) begin
			o_frac <= 0;
		end
		else begin
			o_frac <= rom_memory[i_dividend][i_divisor];
		end
	end
endmodule