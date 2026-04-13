module data_sync #(
	parameter int NUM_STAGES, //number of stages used in the synchroniser
	parameter int BUS_WIDTH   // number of bits in bus
)(
	input  logic                   i_clk,        // destination domain clock signal 
	input  logic                   i_rst_n,      // destination domain asynchronous active low reset
	input  logic [BUS_WIDTH - 1:0] i_unsync_bus, // unsynchronised bus
	output logic [BUS_WIDTH - 1:0] o_sync_bus    //synchronised bus
);

	//synchronise data
	logic [BUS_WIDTH - 1:0] data_sync [0 : NUM_STAGES - 1];

	always_ff @(posedge i_clk or negedge i_rst_n) begin
		if(!i_rst_n) begin
			for(int i = 0;i<NUM_STAGES;i=i+1) begin
				data_sync[i] <= 0;
			end
		end
		else begin
			data_sync[0] <= i_unsync_bus;
			for(int i = 1;i<NUM_STAGES;i=i+1) begin
				data_sync[i] <= data_sync[i-1];
			end
		end
	end
	assign o_sync_bus = data_sync[NUM_STAGES - 1];

endmodule