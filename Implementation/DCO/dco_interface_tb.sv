`timescale 1ns / 1ps
import dco_package::*; 
module dco_interface_tb();

    // DCO interface signals
    logic              i_clk_ckr;   // Clock domain: CKR
    logic              i_rst_n;     // Asynchronous active-low reset
    logic signed [7:0] i_otw;    // Signed Oscillator Tuning Word from gain_normalization
    dco_mode_t         i_mode;     // Current FSM state (PVT/ACQ/TRACK)
    logic              i_dco_int_en; 
    logic        [7:0] o_otw_p;     // Unsigned Output to PVT Bank
    logic        [7:0] o_otw_acq;   // Unsigned Output to Acquisition Bank
    logic        [5:0] o_otw_track;  // Unsigned Output to Tracking Bank
    // gain_normalization_dco signals 
    parameter DATA_WIDTH = 23;
    logic signed [DATA_WIDTH-1:0] i_norm;
    logic [7:0] frac_sd;
    // Verification Signals
    logic [7:0] otw_p_exp;
    logic [7:0] otw_acq_exp;
    logic [5:0] otw_track_exp;
    // input file 
    int file_h, status;
    int error_count = 0;
    string path = "H:/BLE graduation project/Simulation and modeling/TDC_DCO - Copy/dco_interface_vectors.txt";
    // output file 
    int out_file_h; 
    string out_path = "H:/BLE graduation project/Simulation and modeling/TDC_DCO - Copy/dco_interface_rtl_vs_matlab.txt";
   
    // Clock generation (32 MHz)
    localparam real HALF_PERIOD = 15.625;
    initial begin
    i_clk_ckr = 0;
        forever #(HALF_PERIOD) i_clk_ckr = ~i_clk_ckr;
    end

    // Instantiate DUT with new port names



        gain_normalization_dco #(
                .DATA_WIDTH(DATA_WIDTH)
            ) dut (
                .i_norm(i_norm),
                .i_mode(i_mode), 
                .o_otw_int(i_otw),
                .o_otw_frac(frac_sd)
            );
        dco_interface dut2(
                .i_clk_ckr(i_clk_ckr),   
                .i_rst_n(i_rst_n),
                .i_dco_int_en(i_dco_int_en),     
                .i_otw(i_otw),   
                .i_mode(i_mode),     
                .o_otw_p(o_otw_p),  
                .o_otw_acq(o_otw_acq),   
                .o_otw_track(o_otw_track)  
            );

    initial begin
        i_rst_n = 0; 
        i_mode = PVT_MODE;      
        #(HALF_PERIOD * 4); 
        i_rst_n = 1;
        i_dco_int_en = 1; 
        file_h = $fopen(path, "r");
        if (!file_h) $fatal("Error: Could not open lms_test_vectors.txt");
        out_file_h = $fopen(out_path, "w");
        if (!out_file_h) $fatal("Could not create output file!");
            while (!$feof(file_h)) begin
            @(posedge i_clk_ckr); 
            #2;
            $fdisplay(out_file_h, "%d %d %d %d %d %d",otw_p_exp,o_otw_p,otw_acq_exp,o_otw_acq,otw_track_exp,o_otw_track);
            #2;
            if (otw_p_exp !== o_otw_p) begin
                $display("Mismatch! PVT:  | RTL: %d | Expected: %d", 
                         o_otw_p, otw_p_exp);
                         error_count = error_count + 1;
            end
            if (otw_acq_exp !== o_otw_acq) begin
                $display("Mismatch! acq:  | RTL: %d | Expected: %d"
                         ,o_otw_acq, otw_acq_exp);
                         error_count = error_count + 1;
            end
            if (otw_track_exp !== o_otw_track) begin
                $display("Mismatch! track:  | RTL: %d | Expected: %d", 
                          o_otw_track, otw_track_exp);
                         error_count = error_count + 1;
            end
                @(negedge i_clk_ckr); 
                status = $fscanf(file_h, "%d %d %d %d %d\n", 
                                 i_norm, i_mode, otw_p_exp, otw_acq_exp, otw_track_exp);

        end

        $display("Simulation COMPLETE: %0d errors found.", error_count);
        $fclose(file_h);
        $fclose(out_file_h);
        $stop;
    end
   
endmodule