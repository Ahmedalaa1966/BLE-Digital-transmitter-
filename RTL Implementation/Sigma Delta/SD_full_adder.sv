module SD_full_adder #(
    parameter ACCUMULATOR_WIDTH = 10                    
)(
    input   logic  [ACCUMULATOR_WIDTH-1:0] in_1     ,
    input   logic  [ACCUMULATOR_WIDTH-1:0] in_2     ,
    output  logic  [ACCUMULATOR_WIDTH-1:0] out      ,
    input   logic                         c_in     ,
    input   logic                         rst_n    ,
    output  logic                         c_out    

    );
    assign {c_out, out} = (rst_n == 0) ? {1'b0, 11'b0} : (in_1 + in_2 + c_in);

    
  
endmodule