`timescale 1ns/1ps

module gearbox_64b_66b_tb;

    // Clock and Reset
    reg clk;
    reg reset;
    reg valid;
    reg [63:0] data_in;
    wire [65:0] data_out;

    // Instantiate the Gearbox
    gearbox_64b_66b dut (
        .clk(clk),
        .reset(reset),
        .valid(valid),
        .data_in(data_in),
        .data_out(data_out)
    );

    // Clock Generation
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz

    // --- LINEAR TEST CASES ---
    initial begin
        // Initialize
        reset = 1;
        valid = 0;
        data_in = 0;
        #20 reset = 0;

        // TEST 1: Continuous Stream (Verify TC_01)
        $display("Starting TC_01: Continuous Stream...");
        repeat (66) begin
            @(posedge clk);
            valid = 1;
            data_in = $urandom_64();
        end
        valid = 0;
        #100;

        // TEST 2: Gapped Valid (Verify TC_02)
        $display("Starting TC_02: Gapped Valid...");
        repeat (20) begin
            @(posedge clk);
            valid = $urandom % 2; // Randomly toggle valid
            data_in = 64'hAAAA_BBBB_CCCC_DDDD;
        end
        valid = 0;
        
        $display("Regression Completed.");
        $finish;
    end

    // SIMPLE SCOREBOARD: Monitor the output
    always @(posedge clk) begin
        if (dut.read_all) begin
            $display("TIME: %0t | DATA_OUT: %h | STATUS: VALID OUTPUT READY", $time, data_out);
        end
    end

endmodule
