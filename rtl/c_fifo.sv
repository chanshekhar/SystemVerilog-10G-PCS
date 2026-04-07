// Save this as c_fifo.v or include it in your project
module c_fifo #(
    parameter WIDTH = 2,
    parameter DEPTH = 128
)(
    input  wire             clk,
    input  wire             rst,
    input  wire [WIDTH-1:0] din,
    input  wire             wr_en,
    input  wire             rd_en,
    output wire [WIDTH-1:0] dout,
    output wire             empty,
    output wire             full
);

   xpm_fifo_sync #(
      .CASCADE_HEIGHT(0),        
      .DOUT_RESET_VALUE("0"),    
      .ECC_MODE("no_ecc"),       
      .FIFO_MEMORY_TYPE("auto"), // Can be "auto", "block", or "distributed"
      .FIFO_READ_LATENCY(1),     // 1 for standard, 0 for FWFT
      .FIFO_WRITE_DEPTH(DEPTH),   
      .READ_DATA_WIDTH(WIDTH),      
      .READ_MODE("std"),         // Standard read mode
      .USE_ADV_FEATURES("0000"), // Disable flags we aren't using
      .WRITE_DATA_WIDTH(WIDTH),     
      .WR_DATA_COUNT_WIDTH(8)    
   ) xpm_fifo_sync_inst (
      .din(din),
      .wr_en(wr_en),
      .rd_en(rd_en),
      .dout(dout),
      .empty(empty),
      .full(full),
      .rst(rst),
      .wr_clk(clk),
      .injectdbiterr(1'b0),
      .injectsbiterr(1'b0),
      .sleep(1'b0)
   );

endmodule
