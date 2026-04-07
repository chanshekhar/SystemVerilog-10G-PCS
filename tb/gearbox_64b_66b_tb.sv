`timescale 1ns/1ps

module gearbox_64b_66b_tb;

    // Clock and Reset
    reg clk;
    reg reset;
    reg valid;
    reg [63:0] data_in;
    
    // TX Output Wires
    wire [65:0] data_out;
    wire data_out_valid;

    // RX Output Wires
    wire [63:0] rx_data_out;
    wire rx_data_out_valid;

    // Reference Queues
    bit [1:0] tx_ref_queue[$];   // For TX 66-bit reconstruction
    bit [63:0] rx_ref_queue[$];  // For RX 64-bit comparison
    
    bit [65:0] expected_tx_data;
    bit [63:0] expected_rx_data;
    
    int pass_count = 0;
    int fail_count = 0;
    int rx_pass_count = 0;
    int rx_fail_count = 0;

    // 1. Instantiate the Gearbox TX
    gearbox_tx_64b_66b dut_tx (
        .clk(clk),
        .reset(reset),
        .valid(valid),
        .data_in(data_in),
        .data_out(data_out),
        .data_out_valid(data_out_valid)
    );

    // 2. Instantiate the Gearbox RX 
    gearbox_rx_66b_64b dut_rx (
        .clk(clk),
        .reset(reset),
        .valid(data_out_valid),
        .data_in(data_out),
        .data_out(rx_data_out),
        .data_out_valid(rx_data_out_valid)
    );

    // Clock Generation
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz

    // --- DRIVER & MONITOR LOGIC ---
    
    // 1. Capture driven data into Reference Queues
    always @(posedge clk) begin
        if (valid && !reset) begin
            // Store 2-bit chunks for TX scoreboard
            for (int i = 0; i < 32; i++) begin
                tx_ref_queue.push_back(data_in[i*2 +: 2]);
            end
            // Store full 64-bit word for RX scoreboard
            rx_ref_queue.push_back(data_in);
        end
    end

    // 2. Scoreboard TX: (Monitoring 66-bit intermediate output)
    always @(posedge clk) begin
        if (data_out_valid) begin
            if (tx_ref_queue.size() >= 33) begin
                for (int i = 0; i < 33; i++) begin
                    expected_tx_data[i*2 +: 2] = tx_ref_queue.pop_front();
                end

                if (data_out === expected_tx_data) begin
                    $display("[PASS] TX-STAGE | TIME: %0t | Expected: %h | Actual: %h", $time, expected_tx_data, data_out);
                    pass_count++;
                end else begin
                    $display("[FAIL] TX-STAGE | TIME: %0t | Expected: %h | Actual: %h", $time, expected_tx_data, data_out);
                    fail_count++;
                end
            end
        end
    end

    // 3. Scoreboard RX: (Comparing RX 64-bit output with original input)
    always @(posedge clk) begin
        if (rx_data_out_valid) begin
            if (rx_ref_queue.size() > 0) begin
                expected_rx_data = rx_ref_queue.pop_front();

                if (rx_data_out === expected_rx_data) begin
                    $display("[PASS] RX-STAGE | TIME: %0t | Expected: %h | Actual: %h", $time, expected_rx_data, rx_data_out);
                    rx_pass_count++;
                end else begin
                    $display("[FAIL] RX-STAGE | TIME: %0t | Expected: %h | Actual: %h", $time, expected_rx_data, rx_data_out);
                    rx_fail_count++;
                end
            end else begin
                $display("[ERROR] RX-STAGE | TIME: %0t | RX valid but rx_ref_queue is empty!", $time);
                rx_fail_count++;
            end
        end
    end

    // --- TEST CASES ---
    initial begin
        reset = 1;
        valid = 0;
        data_in = 0;
        #25 reset = 0;

        $display("Starting TC_01: End-to-End Loopback Test...");
        repeat (100) begin
            @(negedge clk);
            valid = 1;
            data_in = {$urandom(), $urandom()};
        end
        
        @(negedge clk);
        valid = 0;
        #1000; // Delay to allow entire pipeline to drain

        $display("---------------------------------------");
        $display("TX Regression Results: PASSED: %0d, FAILED: %0d", pass_count, fail_count);
        $display("RX Regression Results: PASSED: %0d, FAILED: %0d", rx_pass_count, rx_fail_count);
        $display("---------------------------------------");
        
        if (fail_count == 0 && rx_fail_count == 0 && rx_pass_count > 0) 
            $display("RESULT: ALL TEST CASES PASSED");
        else 
            $display("RESULT: REGRESSION FAILED");
            
        $finish;
    end

endmodule