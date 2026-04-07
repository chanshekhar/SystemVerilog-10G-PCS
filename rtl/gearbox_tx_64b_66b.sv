module gearbox_tx_64b_66b (
    input wire        clk,
    input wire        reset,
    input wire        valid,
    input wire [63:0] data_in,
    output wire [65:0] data_out,
    output reg         data_out_valid
);

    parameter WIDTH = 2;
    parameter DEPTH = 128; 
    parameter COUNT = 33;

    reg [65:0] data_reg;
    reg        valid_reg;
    reg        valid_reg2;
    reg [5:0]  counter;
    
    // Mask and Data now stored as registers to 'retain' values
    reg [COUNT -1:0] mask_shifted; 
    reg [65:0] data_rotated;

    // --- NEW REGISTRATION REGISTERS ---
    reg [COUNT-1:0][1:0] data_array_reg;
    reg [COUNT-1:0]      wr_en_reg;

    // The 'Base' values for the rotation
    localparam [32:0] INITIAL_MASK = 33'h0_FFFFFFFF; 

    wire [COUNT -1:0][1:0]  data_array ;
    wire [COUNT -1 :0]      fifo_empty;
    wire                    read_all;
    wire [COUNT - 1:0]      wr_en;
    wire [COUNT -1:0][1:0]  fifo_dout_packed;

    // 1. Pipeline and Valid Logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data_reg  <= 66'd0;
            valid_reg <= 1'b0;
            valid_reg2 <= 1'b0;
        end else begin
            data_reg  <= {2'b00, data_in}; 
            valid_reg <= valid;            
            valid_reg2 <= valid_reg;            
        end
    end

    // 2. Counter Logic (Only increments when valid_reg is high)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 6'd0;
        end else if (valid_reg) begin
            if (counter == 6'd32) counter <= 6'd0;
            else counter <= counter + 1'b1;
        end
    end

    // 3. Conditional Circular Shift (Rotation)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mask_shifted <= INITIAL_MASK;
            data_rotated <= 66'd0;
        end else if (valid_reg) begin
            mask_shifted <= (INITIAL_MASK >> counter) | (INITIAL_MASK << (33 - counter));
            data_rotated <= (data_reg >> (counter * 2)) | (data_reg << (66 - (counter * 2)));
        end
    end

    // 4. Parallel Mapping to FIFOs
    genvar k;
    generate
        for (k = 0; k < COUNT; k = k + 1) begin : input_mapping
            assign data_array[k] = data_rotated[(k*2) +: 2];
            assign wr_en[k]      = valid_reg2 ? mask_shifted[k] : 0;
        end
    endgenerate

    // --- NEW: Registration Stage for FIFO inputs ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data_array_reg <= '0;
            wr_en_reg      <= '0;
        end else begin
            data_array_reg <= data_array;
            wr_en_reg      <= wr_en;
        end
    end

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
                .din(data_array_reg[i]), // Using registered data
                .wr_en(wr_en_reg[i]),    // Using registered wr_en
                .rd_en(read_all),
                .empty(fifo_empty[i]),
                .dout(fifo_dout_packed[i])
            );
        end
    endgenerate

    always @(posedge clk or posedge reset) begin
        if (reset)
            data_out_valid <= 1'b0;
        else
            data_out_valid <= read_all;
    end

endmodule