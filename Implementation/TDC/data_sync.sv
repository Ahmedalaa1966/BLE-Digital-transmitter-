module data_sync #(
	parameter int NUM_STAGES, //number of stages used in the synchroniser
	parameter int BUS_WIDTH // number of bits in bus
)(
	input logic clk, //destination domain clock signal 
	input logic rst_n, //destination domain asynchronous active low reset
	input logic [BUS_WIDTH - 1:0] unsync_bus, //unsynchronised bus
	
	output logic [BUS_WIDTH - 1:0] sync_bus //synchronised bus
);

	//synchronise data
	logic [BUS_WIDTH - 1:0] data_sync [0 : NUM_STAGES - 1];

	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			for(int i = 0;i<NUM_STAGES;i=i+1) begin
				data_sync[i] <= 0;
			end
		end
		else begin
			data_sync[0] <= unsync_bus;
			for(int i = 1;i<NUM_STAGES;i=i+1) begin
				data_sync[i] <= data_sync[i-1];
			end
		end
	end
	assign sync_bus = data_sync[NUM_STAGES - 1];

endmodule