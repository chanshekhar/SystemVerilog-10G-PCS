module scrambler (
    input  logic [63:0] data_in,        // 64-bit input data
    input  logic        data_valid_in,  // Input data validity
    input  logic        clk,
    input  logic        rst_n,          // Global Hardware Reset
    output logic [63:0] data_out,       // 64-bit scrambled output data
    output logic        data_valid_out  // Output data validity
);

    // -------------------------------------------------------------------------
    // Signal Declarations
    // -------------------------------------------------------------------------
    logic [63:0] lfsr;
    
    // Pipeline Stages
    logic [63:0] data_in_reg, data_in_reg_v2;
    logic        data_valid_reg, data_valid_reg_v2;

    // Output Registers
    logic [63:0] data_out_reg;
    logic        data_valid_out_reg; 

    // Combinational result of the scrambling polynomial
    logic [63:0] scrambled_data;

    // -------------------------------------------------------------------------
    // Output Assignments
    // -------------------------------------------------------------------------
    assign data_out       = data_out_reg;
    assign data_valid_out = data_valid_out_reg;

    // -------------------------------------------------------------------------
    // Sequential Logic (Pipeline & LFSR Update)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr               <= 64'hFFFF_FFFF_FFFF_FFFF;
            data_in_reg        <= 64'h0;
            data_valid_reg     <= 1'b0;
            data_in_reg_v2     <= 64'h0;
            data_valid_reg_v2  <= 1'b0;
            data_valid_out_reg <= 1'b0;
            data_out_reg       <= 64'h0;
        end else begin
            // Stage 1: Initial Capture
            data_valid_reg <= data_valid_in;
            if (data_valid_in) begin
                data_in_reg <= data_in;
            end

            // Stage 2: Second flip-flop stage (Calculation source)
            data_valid_reg_v2 <= data_valid_reg;
            if (data_valid_reg) begin
                data_in_reg_v2 <= data_in_reg;
            end

            // Stage 3: Output Valid Alignment
            data_valid_out_reg <= data_valid_reg_v2;

            // LFSR & Output Update
            // Loading directly with combinational 'scrambled_data' 
            // ensures the next word sees the updated state immediately.
            if (data_valid_reg_v2) begin
                lfsr         <= scrambled_data;
                data_out_reg <= scrambled_data;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Scrambling Logic: 10GBASE-R G(x) = 1 + x^39 + x^58
    // -------------------------------------------------------------------------
    // Logic is split into 3 regions to handle parallel feedback correctly:
    // Region 1 (0-38):  Uses 2 bits of history from previous word (LFSR).
    // Region 2 (39-57): Uses 1 bit from current word, 1 from history.
    // Region 3 (58-63): Uses 2 bits from the current word.
    // -------------------------------------------------------------------------
    always_comb begin
        for (int i = 0; i < 64; i = i + 1) begin
            if (i < 39) begin
                // Taps: 58 bits back (i+6) and 39 bits back (i+25) in LFSR
                scrambled_data[i] = data_in_reg_v2[i] ^ lfsr[i + 6] ^ lfsr[i + 25];
            end 
            else if (i < 58) begin
                // Taps: 58 bits back (i+6) in LFSR and 39 bits back in current word
                scrambled_data[i] = data_in_reg_v2[i] ^ scrambled_data[i - 39] ^ lfsr[i + 6];
            end 
            else begin
                // Both taps are within the current scrambled word
                scrambled_data[i] = data_in_reg_v2[i] ^ scrambled_data[i - 39] ^ scrambled_data[i - 58];
            end
        end
    end

endmodule
