module SD_top #(
    parameter int FRACTIONAL_WIDTH  = 9  ,                             // Number of fractional bits
    parameter int ACCUMULATOR_WIDTH = 10 ,                             // bit width of the accumulator
    parameter int SD_OUTPUT_WIDTH   = 3                                // Number of intger bits 
) (
    
    input  logic  [ACCUMULATOR_WIDTH-1:0]      i_sd     ,             // input to the sigma delta  ( 9 bit 1 for sign and 8 fractional bits )
    input  logic                               clk      ,             // clk for all the sigma delta usually 400-500 Mhz
    input  logic                               rst_n    ,             // Asynchronous reset
    input  logic                               i_sd_en  ,             // Enable signal for the sigma delta               
    output logic signed [SD_OUTPUT_WIDTH-1:0]  o_sd                   // output of the sigma delta ( 3 bits one for sign and two intger bits )

    );


    // initernal registers declaration
    logic [ACCUMULATOR_WIDTH-1:0] s_out1 , s_out1_d ;                 // sum out and the delayed sum out for the first accumulator (11 bits one for sign and 10 intger bits )
    logic [ACCUMULATOR_WIDTH-1:0] s_out2 , s_out2_d ;                 // sum out and the delayed sum out for the second accumulator (11 bits one for sign and 10 intger bits )
    logic [ACCUMULATOR_WIDTH-1:0] s_out3 , s_out3_d ;                 // sum out and the delayed sum out for the third accumulator (11 bits one for sign and 10 intger bits )
    logic                         lfsr_out          ;                 // output of the LFSR
    logic                         cout_1            ;                 // carry out of the first accumulator 
    logic                         cout_2            ;                 // carry out of the second accumulator 
    logic                         cout_3            ;                 // carry out of the third  accumulator 
    logic                         rst_en            ;

    assign rst_en = !rst_n || !i_sd_en ;

    // =============== LFSR instantiation ====================
    LFSR LFSR_ins (
                        .clk   (clk)      ,
                        .rst_n (rst_n)    ,
                        .o_lfsr(lfsr_out)   
    ) ;

    // =============== First accumulator ======================
    SD_full_adder #(
    .ACCUMULATOR_WIDTH (ACCUMULATOR_WIDTH)
    )     acc_1        ( 
                        .in_1  (i_sd)      , 
                        .in_2  (s_out1_d)  ,
                        .c_in  (1'b0)      ,
                        .c_out (cout_1)    ,
                        .rst_n (!rst_en )     ,
                        .out   (s_out1)      
    ); 
    SD_dff         DFF_1 ( 
                        .clk   (clk)       ,
                        .rst_n (rst_n)     ,
                        .d     (s_out1)    ,
                        .q     (s_out1_d)      
    );


    // =============== Second accumulator ======================
    SD_full_adder  #(
    .ACCUMULATOR_WIDTH (ACCUMULATOR_WIDTH)
    )      acc_2       ( 
                        .in_1  (s_out1_d)  , 
                        .in_2  (s_out2_d)  ,
                        .c_in  (lfsr_out)  ,
                        .c_out (cout_2)    ,
                        .rst_n (!rst_en)     ,
                        .out   (s_out2)      
    );  
    SD_dff         DFF_2 ( 
                        .clk   (clk)       ,
                        .rst_n (rst_n)     ,
                        .d     (s_out2)    ,
                        .q     (s_out2_d)      
    );


    // =============== Third accumulator ======================
    SD_full_adder  #(
    .ACCUMULATOR_WIDTH (ACCUMULATOR_WIDTH)
    )       acc_3     ( 
                        .in_1 (s_out2_d)   , 
                        .in_2 (s_out3_d)   ,
                        .c_in (1'b0)     ,
                        .c_out(cout_3)     ,
                        .rst_n(!rst_en)      ,
                        .out  (s_out3)      
    );  
    SD_dff         DFF_3 ( 
                        .clk  (clk)       ,
                        .rst_n(rst_n)     ,
                        .d    (s_out3)    ,
                        .q    (s_out3_d)      
    );

    // =============== Noise cancelation network ======================
    noise_cancelation_network   #(
    .SD_OUTPUT_WIDTH (SD_OUTPUT_WIDTH)
    )           n1    ( 
                        .clk (clk)        ,
                        .rst_n(rst_n)     ,
                        .c1  (cout_1)     ,
                        .c2  (cout_2)     ,
                        .c3  (cout_3)     ,
                        .out (o_sd) 
    );


endmodule