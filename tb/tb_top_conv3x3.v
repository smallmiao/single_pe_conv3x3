//=============================================================================
// tb_top_conv3x3.v - Testbench for single-PE 3x3 convolution
//--------------------------------------------------------------------------
// Flow:
//   1. Read ifm.hex / wgt.hex, load into the DUT via the PS write ports.
//   2. Assert start, wait for done.
//   3. Read all 256 OFM values, write to rtl_out.hex.
//   4. Invoke py/check_result.py to compare against golden.
//
// Covered edge scenarios (per AGENTS.md, must be documented):
//   - padding on all four borders (inherent in golden generation)
//   - last pixel / last tap -> done pulse
//   - reset before start (idle stability)
//   - full 256-pixel pass
//
// Design rules: pure Verilog-2001 testbench; `timescale defined.
//=============================================================================
`timescale 1ns/1ps

module tb_top_conv3x3;

    //-------------------------------------------------------------------------
    // Parameters (must match top_conv3x3 defaults).
    //-------------------------------------------------------------------------
    localparam IMG_H   = 16;
    localparam IMG_W   = 16;
    localparam N_PIX   = IMG_H * IMG_W;   // 256
    localparam N_WGT   = 10;              // 9 weights + 1 bias
    localparam CLK_PER = 10;              // 10 ns

    //-------------------------------------------------------------------------
    // Run run_sim.do from tb/ so paths resolve relative to the project root.
    //-------------------------------------------------------------------------
    localparam PY_DIR = "../py/";

    //-------------------------------------------------------------------------
    // DUT signals.
    //-------------------------------------------------------------------------
    reg                         clk;
    reg                         rst_n;
    reg                         start;
    wire                        busy;
    wire                        done;

    reg                         ifm_we;
    reg  [7:0]                  ifm_wr_addr;
    reg  signed [15:0]          ifm_din;

    reg                         wgt_we;
    reg  [3:0]                  wgt_wr_addr;
    reg  signed [15:0]          wgt_din;

    reg  [7:0]                  ofm_rd_addr;
    wire signed [15:0]          ofm_rd_data;

    //-------------------------------------------------------------------------
    // Memory to hold loaded vectors.
    //-------------------------------------------------------------------------
    reg signed [15:0] ifm_mem [0:N_PIX-1];
    reg signed [15:0] wgt_mem [0:N_WGT-1];
    integer i;

    //-------------------------------------------------------------------------
    // DUT instantiation (INIT_FILE empty -> load via write ports in tb).
    //-------------------------------------------------------------------------
    top_conv3x3 #(
        .IFM_INIT(""),
        .WGT_INIT("")
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .busy         (busy),
        .done         (done),
        .ifm_we       (ifm_we),
        .ifm_wr_addr  (ifm_wr_addr),
        .ifm_din      (ifm_din),
        .wgt_we       (wgt_we),
        .wgt_wr_addr  (wgt_wr_addr),
        .wgt_din      (wgt_din),
        .ofm_rd_addr  (ofm_rd_addr),
        .ofm_rd_data  (ofm_rd_data)
    );

    //-------------------------------------------------------------------------
    // Clock generation.
    //-------------------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PER/2) clk = ~clk;

    //-------------------------------------------------------------------------
    // Drive + check.
    //-------------------------------------------------------------------------
    integer fd;
    integer j;
    reg signed [15:0] ofm_val;

    initial begin
        // init
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        ifm_we = 1'b0; ifm_wr_addr = 8'b0; ifm_din = 16'sb0;
        wgt_we = 1'b0; wgt_wr_addr = 4'b0; wgt_din = 16'sb0;
        ofm_rd_addr = 8'b0;

        // load vectors (from py/ dir)
        $readmemh({PY_DIR, "ifm.hex"}, ifm_mem);
        $readmemh({PY_DIR, "wgt.hex"}, wgt_mem);

        // reset pulse
        #(CLK_PER*2);
        rst_n = 1'b1;
        #(CLK_PER);

        // --- SCENARIO 1: reset idle stability (done/busy low) ---
        if (busy !== 1'b0 || done !== 1'b0) begin
            $display("ERROR: busy/done not idle after reset");
            $finish;
        end

        // --- load IFM (PS write path) ---
        for (i = 0; i < N_PIX; i = i + 1) begin
            @(posedge clk);
            ifm_we      = 1'b1;
            ifm_wr_addr = i[7:0];
            ifm_din     = ifm_mem[i];
            @(posedge clk);
            ifm_we = 1'b0;
        end

        // --- load WGT (PS write path) ---
        for (i = 0; i < N_WGT; i = i + 1) begin
            @(posedge clk);
            wgt_we      = 1'b1;
            wgt_wr_addr = i[3:0];
            wgt_din     = wgt_mem[i];
            @(posedge clk);
            wgt_we = 1'b0;
        end

        // --- start convolution ---
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // --- wait for convolution to finish ---
        wait (done === 1'b1);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);   // let FSM return to IDLE, busy drops

        // --- SCENARIO 2: back to idle after done ---
        if (busy !== 1'b0) begin
            $display("ERROR: busy not released after done");
        end

        // --- read all OFM, write rtl_out.hex into py/ for easy compare ---
        fd = $fopen({PY_DIR, "rtl_out.hex"}, "w");
        for (j = 0; j < N_PIX; j = j + 1) begin
            ofm_rd_addr = j[7:0];
            @(posedge clk);   // addr applied, BRAM latches address
            @(posedge clk);   // dout_b <= mem[addr_b]
            @(posedge clk);   // extra settle
            ofm_val = ofm_rd_data;
            if (j < 3) $display("DBG read OFM[%0d] = %h", j, ofm_val);
            // hex format, 4 digits, two's complement (matches golden)
            $fwrite(fd, "%04X\n", ofm_val & 16'hFFFF);
        end
        $fclose(fd);
        $display("SIM: wrote rtl_out.hex (%0d samples)", N_PIX);

        // --- invoke python comparison ---
        $system({"python ", PY_DIR, "check_result.py ",
                 PY_DIR, "rtl_out.hex ",
                 PY_DIR, "golden_output.hex"});
        $finish;
    end

    //-------------------------------------------------------------------------
    // Simulation timeout guard.
    //-------------------------------------------------------------------------
    initial begin
        #200000;
        $display("SIM: TIMEOUT - simulation did not finish");
        $finish;
    end

endmodule
