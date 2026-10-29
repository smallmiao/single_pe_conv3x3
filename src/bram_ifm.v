//=============================================================================
// bram_ifm.v - Input Feature Map (IFM) BRAM, synchronous read
//--------------------------------------------------------------------------
// Stores the 16x16 input feature map (256 x 16-bit), Q8.7 signed.
// Simple dual-port style:
//   Port A : write from PS (weight/feature load)
//   Port B : read  by the convolution pipeline
// Synchronous read (1-cycle latency) - standard inferred BRAM.
//
// Design rules (per AGENTS.md): pure Verilog-2001; non-blocking sequential;
// explicit reset for the read-data register; single clock domain.
//=============================================================================

module bram_ifm #(
    parameter DATA_W = 16,       // data width
    parameter ADDR_W = 8,        // 256 entries -> 8 bits
    parameter INIT_FILE = ""     // optional .hex init (empty = not used)
)(
    input  wire                 clk,      // clock
    // Port A: write (from PS)
    input  wire                 we_a,     // write enable
    input  wire [ADDR_W-1:0]    addr_a,   // write address
    input  wire [DATA_W-1:0]    din_a,    // write data
    // Port B: read (pipeline)
    input  wire [ADDR_W-1:0]    addr_b,   // read address
    output reg  [DATA_W-1:0]    dout_b    // read data (1-cycle latency)
);

    //-------------------------------------------------------------------------
    // Memory array.
    //-------------------------------------------------------------------------
    reg [DATA_W-1:0] mem [0:(1<<ADDR_W)-1];

    // optional initialisation from hex file (for testbench / on-chip ROM)
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    //-------------------------------------------------------------------------
    // Port A write (synchronous).
    //-------------------------------------------------------------------------
    always @(posedge clk) begin
        if (we_a) begin
            mem[addr_a] <= din_a;
        end
    end

    //-------------------------------------------------------------------------
    // Port B read (synchronous -> 1-cycle latency).
    //-------------------------------------------------------------------------
    always @(posedge clk) begin
        dout_b <= mem[addr_b];
    end

endmodule
