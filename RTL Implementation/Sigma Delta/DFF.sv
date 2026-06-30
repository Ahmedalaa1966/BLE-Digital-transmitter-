module SD_dff #(
    parameter int ACCUMULATOR_WIDTH = 10                            // Number of fractional bits
) (
    input  logic                           clk   ,
    input  logic                           rst_n ,                 // Active low reset
    input  logic [ACCUMULATOR_WIDTH-1:0]   d     ,                 // Data input
    output logic [ACCUMULATOR_WIDTH-1:0]   q                       // Data output
);

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            q <= 11'b0 ;
        end
        else begin
            q <= d ;
        end
    end


endmodule