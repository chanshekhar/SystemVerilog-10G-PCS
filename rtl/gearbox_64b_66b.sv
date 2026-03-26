module gearbox (
    input wire        clk,
    input wire        reset,
    input wire        valid,
    input wire [63:0] data_in,
    output wire [65:0] data_out
);

    parameter WIDTH = 2;
    parameter DEPTH = 128; 
    parameter COUNT = 33;

    reg [65:0] data_reg;
    reg        valid_reg;
    reg [5:0]  counter;
    
    // Mask and Data now stored as registers to 'retain' values
    reg [32:0] mask_shifted; 
    reg [65:0] data_rotated;

    // The 'Base' values for the rotation
    localparam [32:0] INITIAL_MASK = 33'h0_7FFFFFFF; 

    wire [1:0]  data_array [0:32];
    wire [32:0] fifo_empty;
    wire        read_all;
    wire [32:0][1:0] fifo_dout_packed;

    // 1. Pipeline and Valid Logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data_reg  <= 66'd0;
            valid_reg <= 1'b0;
        end else begin
            data_reg  <= {2'b00, data_in}; 
            valid_reg <= valid;            
        end
    end

    // 2. Counter Logic (Only increments when valid_reg is high)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 6'd0;
        end else if (valid_reg) begin
            if (counter >= 6'd32) counter <= 6'd0;
            else counter <= counter + 1'b1;
        end
    end

    // 3. Conditional Circular Shift (Rotation)
    // These registers only update their "Shifted View" when valid_reg is high
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mask_shifted <= INITIAL_MASK;
            data_rotated <= 66'd0;
        end else if (valid_reg) begin
            // MASK: Rotate right by 'counter'
            mask_shifted <= (INITIAL_MASK >> counter) | (INITIAL_MASK << (33 - counter));
            
            // DATA: Rotate right by 'counter * 2'
            data_rotated <= (data_reg >> (counter * 2)) | (data_reg << (66 - (counter * 2)));
        end
        // If valid_reg is low, mask_shifted and data_rotated retain their previous values
    end

    // 4. Parallel Mapping to FIFOs
    genvar k;
    generate
        for (k = 0; k < COUNT; k = k + 1) begin : input_mapping
            assign data_array[k] = data_rotated[(k*2) +: 2];
        end
    endgenerate

    // 5. Read Logic & Output
    assign read_all = ~(|fifo_empty);
    assign data_out = fifo_dout_packed;

    // 6. FIFO Instances
    genvar i;
    generate
        for (i = 0; i < COUNT; i = i + 1) begin : fifo_gen
            c_fifo #(
                .WIDTH(WIDTH),
                .DEPTH(DEPTH)
            ) c_fifo_inst (
                .clk(clk),
                .rst(reset),
                .din(data_array[i]),
                .wr_en(mask_shifted[i] & valid_reg), // Double protection with valid_reg
                .rd_en(read_all),
                .empty(fifo_empty[i]),
                .dout(fifo_dout_packed[i])
            );
        end
    endgenerate

endmodule
