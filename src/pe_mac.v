//=============================================================================
// pe_mac.v - Single Processing Element (MAC) for 3x3 convolution
//--------------------------------------------------------------------------
// Function: one signed multiply + accumulate unit.
//   product = ifm_data * wgt_data   (combinational, inferred DSP48E1)
//   acc     = acc + product         (sequential, 32-bit)
// The accumulator is cleared once per output pixel (acc_clr) and is
// enabled cycle-by-cycle (acc_en) for the 9 MAC iterations.
//--------------------------------------------------------------------------
// Fixed-point: input/weight are int16 (Q8.7); accumulator is int32.
// Bias, arithmetic right-shift and saturation are handled in the top level.
//--------------------------------------------------------------------------
// Design rules (per AGENTS.md):
//   - Pure Verilog-2001, no SystemVerilog.
//   - Sequential logic uses non-blocking assignment (<=).
//   - All registers have explicit reset (active-low rst_n).
//   - Single clock domain; no clock frequency assumption in RTL.
//=============================================================================

module pe_mac #(
    parameter DATA_W = 16,  // input / weight width (signed)
    parameter ACC_W  = 32   // accumulator width
)(
    input  wire                     clk,     // clock
    input  wire                     rst_n,   // active-low reset
    input  wire signed [DATA_W-1:0] ifm_data, // feature pixel (Q8.7)
    input  wire signed [DATA_W-1:0] wgt_data, // weight (Q8.7)
    input  wire                     acc_clr, // clear accumulator (start of pixel)
    input  wire                     acc_en,  // enable accumulate (one MAC per cycle)
    output reg  signed [ACC_W-1:0]  acc_out  // 32-bit accumulation result
);

    //---------------------------------------------------------------------
    // Combinational multiply (inferred DSP48E1 by the synthesis tool).
    //---------------------------------------------------------------------
    wire signed [DATA_W+DATA_W-1:0] product;
    assign product = ifm_data * wgt_data;

    //---------------------------------------------------------------------
    // Sequential accumulator.
    // Priority: reset > acc_clr > acc_en > hold.
    // acc_clr loads the first product (instead of clearing to 0) so that
    // tap 0 is accumulated directly; taps 1..8 then add via acc_en.
    // This keeps the 9 MAC iterations in a clean 9-cycle loop.
    //---------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out <= {ACC_W{1'b0}};
        end else if (acc_clr) begin
            acc_out <= {{(ACC_W-DATA_W-DATA_W){product[DATA_W+DATA_W-1]}}, product};
        end else if (acc_en) begin
            acc_out <= acc_out + product;
        end
        // else: hold current value
    end

endmodule
