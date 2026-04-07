module gearbox_rx_66b_64b (
    input wire        clk,
    input wire        reset,
    input wire        valid,
    input wire [65:0] data_in,
    output wire [63:0] data_out,
    output reg        data_out_valid
);

    // Parameters
    parameter WIDTH = 2;
    parameter DEPTH = 128; 
    parameter COUNT = 33;

    // Internal Registers
    reg [65:0] data_reg;
    reg        valid_reg;
    reg [5:0]  rx_counter; 
    reg [65:0] mask_shifted;
    reg [63:0] data_rotated;
    reg        any_read_d1;

    // Initial Mask: 64 LSBs are 1, 2 MSBs are 0
    localparam [65:0] INITIAL_MASK = 66'h0_FFFF_FFFF_FFFF_FFFF;

    // 1. Input Registration Stage
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data_reg  <= 66'd0;
            valid_reg <= 1'b0;
        end else begin
            data_reg  <= data_in;
            valid_reg <= valid;
        end
    end

    // Internal wires for FIFO connections
    wire [COUNT-1:0][1:0] data_array;      
    wire [COUNT-1:0]      wr_en;           
    wire [COUNT-1:0]      read_all;        
    wire [COUNT-1:0]      fifo_empty;      
    wire [COUNT-1:0][1:0] fifo_dout_packed;

    // 2. Data Slicing Logic (66-bit to 33 x 2-bit)
    genvar k;
    generate
        for (k = 0; k < COUNT; k = k + 1) begin : bit_slicing
            assign data_array[k] = data_reg[(k*2) +: 2];
            assign wr_en[k]      = valid_reg; 
        end
    endgenerate

    // 3. Read Control Logic
    // Drives rd_en of FIFOs using the mask only when all FIFOs have data
    assign read_all = (~(|fifo_empty)) ? mask_shifted : {COUNT{1'b0}};

    // 4. Counter Logic
    // Increments on successful read, resets at 32
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_counter <= 6'd0;
        end else if (~(|fifo_empty)) begin
            if (rx_counter >= 6'd32) 
                rx_counter <= 6'd0;
            else 
                rx_counter <= rx_counter + 1'b1;
        end
    end

    // 5. RX Circular Shift & Output Logic
    // Mask: Right Rotate | Data: Left Rotate
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mask_shifted   <= INITIAL_MASK;
            data_rotated   <= 64'd0;
            any_read_d1    <= 1'b0;
            data_out_valid <= 1'b0;
        end else begin
            // Pipeline valid signal to align with FIFO + Shift latency
            any_read_d1    <= ~(|fifo_empty);
            data_out_valid <= any_read_d1;

            if (~(|fifo_empty)) begin
                // MASK: Right Circular Shift by rx_counter
                mask_shifted <= (INITIAL_MASK >> rx_counter) | 
                                (INITIAL_MASK << (66 - rx_counter));
                
                // DATA: Left Circular Shift by (rx_counter * 2) and extract 64-bit payload
                data_rotated <= ((fifo_dout_packed << (rx_counter * 2)) | 
                                 (fifo_dout_packed >> (66 - (rx_counter * 2))));
            end
        end
    end

    // 6. FIFO Instance Array
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
                .wr_en(wr_en[i]),
                .rd_en(read_all[i]), 
                .empty(fifo_empty[i]),
                .dout(fifo_dout_packed[i])
            );
        end
    endgenerate

    // Final Output Assignment
    assign data_out = data_rotated[63:0]; 

endmodule