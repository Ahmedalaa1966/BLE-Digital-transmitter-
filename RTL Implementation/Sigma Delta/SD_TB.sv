`timescale 1ns/1ps

module SD_top_tb;

    parameter FRACTIONAL_WIDTH  = 9;
    parameter SD_OUTPUT_WIDTH   = 3;
    parameter ACCUMULATOR_WIDTH = 10;
    parameter N = 15; // SD iterations per input

    // Testbench signals
    logic [ACCUMULATOR_WIDTH-1:0]      i_sd;
    logic                              clk;
    logic                              rst_n;
    logic signed [SD_OUTPUT_WIDTH-1:0] o_sd;
    logic                              i_sd_en;

    // Storage for output samples
    logic signed [SD_OUTPUT_WIDTH-1:0] sd_samples [0:9999];

    integer sample_index;
    integer file, infile;
    integer j;

    // Input storage
    logic [ACCUMULATOR_WIDTH-1:0] input_mem [0:999];
    integer num_inputs;

    // DUT
    SD_top #(
        .FRACTIONAL_WIDTH(FRACTIONAL_WIDTH),
        .SD_OUTPUT_WIDTH(SD_OUTPUT_WIDTH),
        .ACCUMULATOR_WIDTH(ACCUMULATOR_WIDTH)
    ) DUT (
        .i_sd(i_sd),
        .clk(clk),
        .rst_n(rst_n),
        .o_sd(o_sd),
        .i_sd_en(i_sd_en)
    );

    // Clock (400 MHz)
    initial clk = 0;
    always #1.25 clk = ~clk;

    // Stimulus
initial begin

    sample_index = 0;
    i_sd    = 0;
    rst_n   = 1;
    i_sd_en = 0;


    file = $fopen("Implementation_output.txt","w");

    // Read input file
    infile = $fopen("input_binary.txt","r");
    num_inputs = 0;

    while (!$feof(infile)) begin
        $fscanf(infile, "%b\n", input_mem[num_inputs]);
        num_inputs = num_inputs + 1;
    end

    $fclose(infile);


    // MAIN LOOP
    for (int k = 0; k < num_inputs; k++) begin

        i_sd = input_mem[k];

        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        i_sd_en = 1;

        for (int n = 0; n < N; n++) begin
            @(posedge clk);
        end

    end

    i_sd_en = 0;


    $fclose(file);

    $display("Simulation finished. Data written to sd_output.txt");
    $stop;
end
     always @(posedge clk) begin
            // When reset happens → start new line
            if (!rst_n) begin
                $fwrite(file, "\n");
            end
            // Write samples
            if (i_sd_en && rst_n) begin
                $fwrite(file, "%0d ", o_sd);
            end
        end

    // Capture output
    always @(posedge clk) begin
        if (i_sd_en && rst_n) begin
            sd_samples[sample_index] = o_sd;
            sample_index = sample_index + 1;
        end
    end

endmodule