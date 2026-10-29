//=============================================================================
// addr_gen_slide.v - Sliding-window address generator for 3x3 conv
//--------------------------------------------------------------------------
// Walks over all output pixels (row-major) and, for each pixel, over the 9
// taps of the 3x3 kernel. For every tap it computes the IFM read address
// and flags whether the tap falls outside the valid input (zero padding).
//
// Coordinate model (padding=1):
//   output pixel (row, col)  ->  window covers IFM( row-1+r , col-1+c )
//   r,c in {0,1,2} (tap_r, tap_c). Out-of-range source -> pad (data=0).
//
// All counters are independent (no division / modulo), keeping LUT usage low:
//   tap_r (0..2), tap_c (0..2), row (0..IMG_H-1), col (0..IMG_W-1)
//
// Design rules (per AGENTS.md): pure Verilog-2001; non-blocking sequential;
// explicit active-low reset; single clock domain; no frequency assumption.
//=============================================================================

module addr_gen_slide #(
    parameter IMG_H  = 16,   // output feature map height
    parameter IMG_W  = 16,   // output feature map width
    parameter K_SIZE = 3,    // kernel size
    parameter PAD    = 1     // zero padding on each side
)(
    input  wire        clk,       // clock
    input  wire        rst_n,     // active-low reset
    input  wire        en,        // advance one tap per cycle
    input  wire        clr,       // reset counters to pixel(0,0), tap(0,0)
    output wire [7:0]  ifm_addr,  // IFM BRAM read address
    output wire        pad_valid, // 1 = tap is padding, data must be 0
    output wire [3:0]  wgt_idx,   // weight index 0..8 (== tap linear index)
    output reg         pix_done,  // pulse when last tap of last pixel done
    output wire [7:0]  pix_cnt    // current output pixel index (row-major)
);

    //-------------------------------------------------------------------------
    // Local width parameters.
    //-------------------------------------------------------------------------
    localparam IDX_W = $clog2(IMG_W);   // 4 bits for 16
    localparam TAP_W = $clog2(K_SIZE);  // 2 bits for 3

    //-------------------------------------------------------------------------
    // Counters: tap position and output pixel position.
    //-------------------------------------------------------------------------
    reg [TAP_W-1:0] tap_r;   // 0..K_SIZE-1
    reg [TAP_W-1:0] tap_c;   // 0..K_SIZE-1
    reg [IDX_W-1:0] row;     // 0..IMG_H-1
    reg [IDX_W-1:0] col;     // 0..IMG_W-1

    //-------------------------------------------------------------------------
    // Source pixel coordinate with padding offset (signed, +1 stage).
    //-------------------------------------------------------------------------
    wire signed [IDX_W:0] src_r = $signed({1'b0,row}) - $signed(PAD) + $signed({1'b0,tap_r});
    wire signed [IDX_W:0] src_c = $signed({1'b0,col}) - $signed(PAD) + $signed({1'b0,tap_c});

    // Valid range check (PAD == K_SIZE/2 for this design).
    wire src_r_ok = (src_r >= 0) && (src_r < IMG_H);
    wire src_c_ok = (src_c >= 0) && (src_c < IMG_W);

    //-------------------------------------------------------------------------
    // IFM address (row-major). Only meaningful when !pad_valid.
    //-------------------------------------------------------------------------
    wire [IDX_W-1:0] ifm_r = src_r[IDX_W-1:0];
    wire [IDX_W-1:0] ifm_c = src_c[IDX_W-1:0];
    assign ifm_addr = (src_r_ok && src_c_ok)
                    ? (ifm_r * IMG_W + ifm_c)
                    : {IDX_W{1'b0}};

    assign pad_valid = !(src_r_ok && src_c_ok);

    // Weight index == linear tap index = tap_r*K_SIZE + tap_c.
    assign wgt_idx = tap_r * K_SIZE + tap_c;

    //-------------------------------------------------------------------------
    // Output pixel index (row-major).
    //-------------------------------------------------------------------------
    assign pix_cnt = row * IMG_W + col;

    //-------------------------------------------------------------------------
    // Counter advance. en clocks one tap; on tap wrap, advance col/row.
    //-------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tap_r    <= {TAP_W{1'b0}};
            tap_c    <= {TAP_W{1'b0}};
            row      <= {IDX_W{1'b0}};
            col      <= {IDX_W{1'b0}};
            pix_done <= 1'b0;
        end else if (clr) begin
            tap_r    <= {TAP_W{1'b0}};
            tap_c    <= {TAP_W{1'b0}};
            row      <= {IDX_W{1'b0}};
            col      <= {IDX_W{1'b0}};
            pix_done <= 1'b0;
        end else if (en) begin
            if (tap_c == K_SIZE-1) begin
                tap_c <= {TAP_W{1'b0}};
                if (tap_r == K_SIZE-1) begin
                    tap_r <= {TAP_W{1'b0}};
                    // advance to next output pixel
                    if (col == IMG_W-1) begin
                        col <= {IDX_W{1'b0}};
                        if (row == IMG_H-1) begin
                            row      <= {IDX_W{1'b0}};
                            pix_done <= 1'b1;    // last pixel finished
                        end else begin
                            row      <= row + 1'b1;
                            pix_done <= 1'b0;
                        end
                    end else begin
                        col      <= col + 1'b1;
                        pix_done <= 1'b0;
                    end
                end else begin
                    tap_r    <= tap_r + 1'b1;
                    pix_done <= 1'b0;
                end
            end else begin
                tap_c    <= tap_c + 1'b1;
                pix_done <= 1'b0;
            end
        end
    end

endmodule
