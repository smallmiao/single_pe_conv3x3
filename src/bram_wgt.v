//=============================================================================
// bram_wgt.v - Weight (WGT) BRAM, synchronous read
//--------------------------------------------------------------------------
// Stores the 3x3 kernel weights plus one bias: 10 x 16-bit (Q8.7 signed).
// Index 0..8  = kernel weights (wgt_idx from addr_gen)
// Index 9     = bias
// Simple dual-port style:
//   Port A : write from PS (weight/feature load)
//   Port B : read  by the convolution pipeline
// Synchronous read (1-cycle latency).
//
// Design rules (per AGENTS.md): pure Verilog-2001; non-blocking sequential;
// single clock domain.
//=============================================================================

module bram_wgt #(
    parameter DATA_W = 16,       // data width
    parameter ADDR_W = 4,        // 10 entries -> 4 bits
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
