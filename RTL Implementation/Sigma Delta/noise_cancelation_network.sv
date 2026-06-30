module noise_cancelation_network #(
    parameter SD_OUTPUT_WIDTH = 3                    
) (

    input  logic               clk   ,   // clock for the sigma delta
    input  logic               rst_n ,   // asynchronus reset
    input  logic               c1    ,   // from first accumulator
    input  logic               c2    ,   // from second accumulator
    input  logic               c3    ,   // from third accumulator
    output logic signed  [2:0] out       // 3-bit output of the sigma delta
    
);

    // Delayed carries registers
    logic c1_d1, c1_d2;
    logic c2_d1;
    logic c3_d1;

    // Intermediate sums
    logic signed [2:0] sum_stage1 , sum_stage1_d ;

    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c1_d1        <= 1'b0 ;
            c1_d2        <= 1'b0 ;
            c2_d1        <= 1'b0 ;
            c3_d1        <= 1'b0 ;
            sum_stage1_d <= 3'b0 ;
        end
        else begin
            c1_d1 <= c1                   ;
            c1_d2 <= c1_d1                ;      // 
            c2_d1 <= c2                   ;      // one delay
            c3_d1 <= c3                   ;      // one delay
            sum_stage1_d <= sum_stage1    ;      // sum stage 1  
        end
    end

    // C2 + C3
    assign sum_stage1 = c2_d1 + c3 - c3_d1;

    // (C2+C3) + delayed C1
    assign out = sum_stage1 + c1_d2 - sum_stage1_d;


endmodule