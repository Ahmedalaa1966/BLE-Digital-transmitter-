module DLF_tb;

//------------------------Parameters -------------------------//
   localparam  PHASE_INT_BITS  = 24;
   localparam  PHASE_FRAC_BITS = 16;
   localparam  OTW_INT_BITS    = 4;
   localparam  OTW_FRAC_BITS   = 19;
   localparam  ACC_FRAC_BITS   = 31;       // Configured according to the value of shift needed (31 for max value 16 + 15)
   localparam PHASE_ERR_WIDTH = PHASE_INT_BITS + PHASE_FRAC_BITS;
   localparam OTW_WIDTH = OTW_INT_BITS + OTW_FRAC_BITS;
   localparam real HALF_PERIOD = 15.625;

logic clk;
logic rst_n;
logic signed [PHASE_ERR_WIDTH-1:0] phase_err;

logic dlf_en;
logic gear_shift_en;

logic [3:0] alpha_shift;
logic [3:0] beta_shift;

logic signed [OTW_WIDTH-1:0] otw_golden;
logic signed [OTW_WIDTH-1:0] otw;

/*-------------- for integrator check-------------------/
logic signed [ACCUMULATOR_WIDTH-1 : 0] integrator;
logic signed [ACCUMULATOR_WIDTH-1 : 0] golden_integrator;
*/

//------------------------Clock generation---------------------------//
initial clk = 0;
    always #(HALF_PERIOD) clk = ~clk;


//---------------------- Instantiate DUT---------------------------//
DLF #(
    .ACC_FRAC_BITS(ACC_FRAC_BITS)
) DUT (
    .i_ckr_clk(clk),
    .i_rst_n(rst_n),
    .i_phase_err(phase_err),
    .i_dlf_en(dlf_en),
    .i_gear_shift_en(gear_shift_en),
    .i_alpha_shift(alpha_shift),
    .i_beta_shift(beta_shift),
    .o_otw(otw)
);


//----------------------------File handles---------------------------//

integer fid_err, fid_otw, fid_I, fid_gs , fid_alpha , fid_beta , fid_Integrator , fid_k_final;
integer i =0 , N;   //N: no of cycles
integer status=0;
logic signed [63:0] temp; 
integer I_pass_count =0, I_fail_count=0;
integer otw_pass_count =0, otw_fail_count=0;

//output file
integer fid_otw_out;

//---------------------------MAIN TEST-------------------------------//

initial begin

//---------------------------Apply stimulus-------------------------//
// Open all files
       
        fid_err = $fopen("phase_err_sv.txt",      "r");
        fid_otw = $fopen("otw_sv.txt",            "r");
        fid_Integrator = $fopen("I_sv.txt", "r");
     //   fid_I   = $fopen("I_sv.txt",              "r");
        fid_gs  = $fopen("Gear_shift_en_sv.txt",  "r");
        fid_alpha  = $fopen("Alpha_sv.txt",  "r");
        fid_beta  = $fopen("Beta_sv.txt",  "r");
        fid_otw_out = $fopen("otw_rtl_out.txt", "w");
        fid_k_final = $fopen("k_final.txt", "r");
        
        // Check all files opened successfully
        if (fid_err == 0) $fatal("Cannot open phase_err_sv.txt");
        if (fid_otw == 0) $fatal("Cannot open otw_sv.txt");
      //  if (fid_I   == 0) $fatal("Cannot open I_sv.txt");
        if (fid_gs  == 0) $fatal("Cannot open Gear_shift_en_sv.txt");
        if (fid_alpha  == 0) $fatal("Cannot open Alpha_sv.txt");
        if (fid_beta  == 0) $fatal("Cannot open Beta_sv.txt");
        if (fid_otw_out == 0) $fatal("Cannot create otw_rtl_out.txt");
        if (fid_Integrator  == 0) $fatal("Cannot open I_sv.txt");
        if (fid_k_final  == 0) $fatal("Cannot open k_final.txt");
        
        $display("All files opened successfully");


        $fscanf(fid_k_final, "%d", N);
 // Reset sequence
       
        rst_n = 0;
        //Initializations
        gear_shift_en = 0;
        alpha_shift   = 3; 
        beta_shift    = 0; 
        phase_err     = 0;
        dlf_en        = 1;
        
        repeat(5) 
        @(posedge clk);
        
        rst_n = 1;
       
     
//Read and drive inputs
      


        for (i = 0; i < N; i++) begin

            // Read one value from each file
            status = $fscanf(fid_err, "%d\n", temp);
            phase_err = temp; 

            status = $fscanf(fid_gs,  "%d\n", temp);
            gear_shift_en = temp; 

            status = $fscanf(fid_alpha,  "%d\n", temp);            
            alpha_shift = temp ; 

            status = $fscanf(fid_beta,  "%d\n", temp);
            beta_shift = temp;

            status = $fscanf(fid_otw, "%d\n", temp);
            otw_golden = temp;

          //  status = $fscanf(fid_Integrator, "%d\n", temp);
          //  golden_integrator = temp; 

            @(posedge clk);
            #1; 

            //Check 
            $fdisplay(fid_otw_out, "%0d", $signed(otw));   //  dump RTL output

            check_otw(otw, otw_golden, i);
          //  check_integrator(integrator , golden_integrator , i);
end

//Close files

        $fclose(fid_err);
        $fclose(fid_otw);
        $fclose(fid_I);
        $fclose(fid_gs);
        $fclose(fid_alpha);
        $fclose(fid_beta);
       // $fclose(fid_Integrator);
        $fclose(fid_otw_out);
        $fclose(fid_k_final);
        print_report();

 $stop;   

end

//--------------------------Helper Tasks-------------------------//
    
    //---------Checker_task----------//
    task check_otw;
        input signed [OTW_WIDTH-1:0] dut_otw;
        input signed [OTW_WIDTH-1:0] otw_golden;
        input integer                cycle;

        if (dut_otw === otw_golden) begin
            otw_pass_count++;
        end else begin
            otw_fail_count++;
            $display("OTW MISMATCH @ sample %0d | golden=%0d | dut=%0d",
                      cycle,
                      otw_golden,
                      dut_otw);
        end
    endtask
    
    //---------Checker_task----------//

    task check_integrator;
        input signed [OTW_WIDTH-1:0] integrator;
        input signed [OTW_WIDTH-1:0] golden_integrator;
        input integer                cycle;

        if (integrator === golden_integrator) begin
            I_pass_count++;
        end else begin
            I_fail_count++;
            $display("INTEGRATOR MISMATCH @ sample %0d | golden=%0d | dut=%0d",
                      cycle,
                      golden_integrator,
                      integrator);
        end
    endtask

    //---------Final_Printing_task----------//
    task print_report;
        $display("=====================================");
        $display("  VERIFICATION REPORT");
        $display("=====================================");
        $display("  Total samples : %0d", N);
        $display("  PASSED_OTW          : %0d", otw_pass_count);
        $display("  FAILED_OTW          : %0d", otw_fail_count);
      //  $display("  PASSED_I          : %0d", I_pass_count);
      //  $display("  FAILED_I          : %0d", I_fail_count);
        
        if (otw_fail_count == 0)
            $display("  RESULT : *** ALL PASS DLF OUT***");
        else
            $display("  RESULT : *** FAILED ***");
        $display("=====================================");
    endtask

endmodule
