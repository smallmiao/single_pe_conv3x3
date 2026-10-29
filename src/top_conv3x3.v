//=============================================================================
// top_conv3x3.v - Top level: single-PE 3x3 convolution accelerator
//--------------------------------------------------------------------------
// Data path:  IFM_BRAM --addr--> PE(MAC) --acc--> [bias+shift+saturate]
//             WGT_BRAM --addr-->                --> OFM_BRAM
// Control:    conv_ctrl_fsm schedules addr_gen + PE + write-back.
//
// Fixed-point: ifm/weight/bias are int16 (Q8.7); accumulator int32.
// Result = saturate( (acc + bias) >>> SHIFT_BITS )  -> int16 (Q8.7)
//
// PS interaction (simple, non-AXI for this stage):
//   - load IFM / WGT via ifm_we/ifm_addr/ifm_din and wgt_we/wgt_addr/wgt_din
//   - assert start to begin; poll busy/done
//   - read OFM via ofm_rd_addr/ofm_rd_data
//
// ALIGNMENT MODEL (BRAM synchronous read, 1-cycle latency):
//   cycle N   : FSM asserts addr_en; addr_gen drives address + tap + pad.
//   cycle N+1 : BRAM returns data (ifm_data, wgt_data). At the same edge the
//               top level registers: data_vld (=addr_en), tap_d1 (=win_idx),
//               ifm_aligned (=ifm_data), wgt_aligned (=wgt_data),
//               pad_d1 (=pad_valid). All are aligned on cycle N+1.
//   cycle N+1 edge: PE samples product using the aligned ifm/wgt and the
//               combinational acc_clr/acc_en (based on tap_d1). No skew.
//   For tap_d1==8 the accumulator holds the full pixel sum; ofm_wr_en is
//   registered (asserts cycle N+2), writing the settled result to OFM.
//   The OFM write address is sampled on the address cycle (addr_en) so it
//   targets the correct pixel P (not P+1).
//
// Design rules (per AGENTS.md): pure Verilog-2001; non-blocking sequential;
// explicit active-low reset; single clock domain; no frequency assumption.
//=============================================================================

module top_conv3x3 #(
    parameter DATA_W    = 16,   // ifm/weight/output width
    parameter ACC_W     = 32,   // accumulator width
    parameter SHIFT_BITS= 4,    // arithmetic right-shift for scaling
    parameter IMG_H     = 16,   // output height
    parameter IMG_W     = 16,   // output width
    parameter K_SIZE    = 3,
    parameter PAD       = 1,
    parameter TAPS      = K_SIZE * K_SIZE,  // 9
    parameter N_PIX     = IMG_H * IMG_W,    // 256
    parameter IFM_INIT  = "",   // optional init file for ifm (tb)
    parameter WGT_INIT  = ""    // optional init file for wgt (tb)
)(
    input  wire                 clk,
    input  wire                 rst_n,

    // ---- control ----
    input  wire                 start,
    output wire                 busy,
    output wire                 done,

    // ---- IFM load (PS) ----
    input  wire                 ifm_we,
    input  wire [7:0]           ifm_wr_addr,
    input  wire signed [DATA_W-1:0] ifm_din,

    // ---- WGT load (PS) ----
    input  wire                 wgt_we,
    input  wire [3:0]           wgt_wr_addr,
    input  wire signed [DATA_W-1:0] wgt_din,

    // ---- OFM read (PS) ----
    input  wire [7:0]           ofm_rd_addr,
    output wire signed [DATA_W-1:0] ofm_rd_data
);

    //-------------------------------------------------------------------------
    // Internal nets.
    //-------------------------------------------------------------------------
    wire        a_en;        // addr_en from FSM
    wire [7:0]  ifm_addr;    // IFM read address (addr_gen)
    wire        pad_valid;   // 1 = padding tap (data must be 0)
    wire [3:0]  wgt_idx;     // weight index 0..8
    wire [7:0]  pix_cnt;     // addr_gen: current pixel index
    wire        pix_done;    // addr_gen: last tap done

    wire        acc_clr;     // PE control from FSM (combinational)
    wire        acc_en;
    wire        ofm_wr_en;

    wire signed [DATA_W-1:0] ifm_data;   // IFM BRAM read data
    wire signed [DATA_W-1:0] wgt_data;   // WGT BRAM read data (weight)

    // alignment registers (driven below; declared before use)
    reg         data_vld;      // = addr_en delayed 1 cycle (data stable)
    reg [3:0]   tap_d1;        // = wgt_idx delayed 1 cycle (matches data)
    reg         pad_d1;        // = pad_valid delayed 1 cycle (matches data)
    reg done_r;              // done pulse (driven below)

    //-------------------------------------------------------------------------
    // Sub-instantiations.
    //-------------------------------------------------------------------------
    conv_ctrl_fsm #(
        .IMG_H (IMG_H),
        .IMG_W (IMG_W),
        .K_SIZE(K_SIZE),
        .TAPS  (TAPS)
    ) u_fsm (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .busy      (busy),
        .addr_en   (a_en),
        .data_vld  (data_vld),
        .finish    (done_r),      // top-level done pulse -> back to IDLE
        .acc_clr   (acc_clr),
        .acc_en    (acc_en),
        .ofm_wr_en (ofm_wr_en),
        .tap_d1    (tap_d1)
    );

    addr_gen_slide #(
        .IMG_H (IMG_H),
        .IMG_W (IMG_W),
        .K_SIZE(K_SIZE),
        .PAD   (PAD)
    ) u_addr (
        .clk      (clk),
        .rst_n    (rst_n),
        .en       (a_en),
        .clr      (1'b0),       // reset only via rst_n
        .ifm_addr (ifm_addr),
        .pad_valid(pad_valid),
        .wgt_idx  (wgt_idx),
        .pix_done (pix_done),
        .pix_cnt  (pix_cnt)
    );

    bram_ifm #(
        .DATA_W   (DATA_W),
        .ADDR_W   (8),
        .INIT_FILE(IFM_INIT)
    ) u_ifm (
        .clk    (clk),
        .we_a   (ifm_we),
        .addr_a (ifm_wr_addr),
        .din_a  (ifm_din),
        .addr_b (ifm_addr),
        .dout_b (ifm_data)
    );

    bram_wgt #(
        .DATA_W   (DATA_W),
        .ADDR_W   (4),
        .INIT_FILE(WGT_INIT)
    ) u_wgt (
        .clk    (clk),
        .we_a   (wgt_we),
        .addr_a (wgt_wr_addr),
        .din_a  (wgt_din),
        .addr_b (wgt_idx),
        .dout_b (wgt_data)
    );

    //-------------------------------------------------------------------------
    // Bias handling: preloaded by PS into a dedicated register (index 9).
    //-------------------------------------------------------------------------
    localparam BIAS_ADDR = 9;
    reg signed [DATA_W-1:0] bias_hold;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bias_hold <= {DATA_W{1'b0}};
        end else if (wgt_we && (wgt_wr_addr == BIAS_ADDR)) begin
            bias_hold <= wgt_din;
        end
    end

    //-------------------------------------------------------------------------
    // ALIGNMENT (single-stage pipeline, relative to a_en / addr_gen output).
    //
    // addr_gen advances the tap on each a_en edge. On that same edge the BRAM
    // latches the *previous* tap's address, so its data becomes stable one
    // cycle later. Delaying a_en, wgt_idx and pad_valid by exactly one cycle
    // aligns data_vld / tap_d1 / pad_d1 with the BRAM data that is currently
    // on the wire. The IFM/WGT data is used directly (no extra register), so
    // the PE samples (data, tap, control) all on the same cycle.
    //-------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_vld <= 1'b0;
            tap_d1   <= 4'b0;
            pad_d1   <= 1'b0;
        end else begin
            data_vld <= a_en;
            tap_d1   <= wgt_idx;
            pad_d1   <= pad_valid;
        end
    end

    //-------------------------------------------------------------------------
    // Padding: feed 0 to the PE when the aligned tap is a pad.
    //-------------------------------------------------------------------------
    wire signed [DATA_W-1:0] ifm_to_pe;
    assign ifm_to_pe = pad_d1 ? {DATA_W{1'b0}} : ifm_data;

    //-------------------------------------------------------------------------
    // PE (single MAC).
    //-------------------------------------------------------------------------
    wire signed [ACC_W-1:0] acc_out;
    pe_mac #(
        .DATA_W (DATA_W),
        .ACC_W  (ACC_W)
    ) u_pe (
        .clk     (clk),
        .rst_n   (rst_n),
        .ifm_data(ifm_to_pe),
        .wgt_data(wgt_data),
        .acc_clr (acc_clr),
        .acc_en  (acc_en),
        .acc_out (acc_out)
    );

    //-------------------------------------------------------------------------
    // Bias + arithmetic shift + saturation (combinational).
    //-------------------------------------------------------------------------
    wire signed [ACC_W-1:0] bias_ext;
    assign bias_ext = {{(ACC_W-DATA_W){bias_hold[DATA_W-1]}}, bias_hold};

    wire signed [ACC_W-1:0] acc_plus_bias = acc_out + bias_ext;
    wire signed [ACC_W-1:0] shifted = acc_plus_bias >>> SHIFT_BITS;

    // NOTE: each brace concatenation below must total ACC_W bits exactly.
    //   pos_max = +0x7FFF, neg_min = -0x8000  (as ACC_W-bit signed).
    wire signed [ACC_W-1:0] pos_max = {{(ACC_W-DATA_W+1){1'b0}}, {(DATA_W-1){1'b1}}};
    wire signed [ACC_W-1:0] neg_min = {{(ACC_W-DATA_W+1){1'b1}}, {(DATA_W-1){1'b0}}};

    reg signed [DATA_W-1:0] result_sat;
    always @* begin
        if (shifted > pos_max)      result_sat = {1'b0, {(DATA_W-1){1'b1}}};
        else if (shifted < neg_min) result_sat = {1'b1, {(DATA_W-1){1'b0}}};
        else                        result_sat = shifted[DATA_W-1:0];
    end

    //-------------------------------------------------------------------------
    // OFM write address: sample addr_gen.pix_cnt when the FIRST tap (tap0)
    // of a pixel arrives (data_vld high and tap_cnt==0). At that cycle
    // addr_gen.pix_cnt still equals P (the current pixel), so the write
    // (asserted later via registered ofm_wr_en) targets the correct pixel P.
    // Sampling only on tap0 avoids the address being overwritten during the
    // pixel's later taps.
    //-------------------------------------------------------------------------
    reg [7:0] ofm_wr_addr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ofm_wr_addr <= 8'b0;
        end else if (data_vld && (tap_d1 == 0)) begin
            ofm_wr_addr <= pix_cnt;
        end
    end

    //-------------------------------------------------------------------------
    // done: pulse when the last pixel's result is written.
    // ofm_wr_en is high on the write cycle for the pixel whose address is
    // currently in ofm_wr_addr; the last pixel is N_PIX-1.
    //-------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_r <= 1'b0;
        end else begin
            done_r <= ofm_wr_en && (ofm_wr_addr == N_PIX-1);
        end
    end
    assign done = done_r;

    //-------------------------------------------------------------------------
    // OFM BRAM (write port A = result; read port B = PS).
    //-------------------------------------------------------------------------
    bram_ofm #(
        .DATA_W   (DATA_W),
        .ADDR_W   (8),
        .INIT_FILE("")
    ) u_ofm (
        .clk    (clk),
        .we_a   (ofm_wr_en),
        .addr_a (ofm_wr_addr),
        .din_a  (result_sat),
        .addr_b (ofm_rd_addr),
        .dout_b (ofm_rd_data)
    );

endmodule
