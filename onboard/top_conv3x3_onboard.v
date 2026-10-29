//=============================================================================
// top_conv3x3_onboard.v - single_pe_conv3x3 上板自测顶层
//--------------------------------------------------------------------------
// 功能：片上 ROM 存测试数据 -> 自动配置 IFM/WGT/BIAS -> 触发推理 ->
//       读回 OFM（先采集到 RAM，再统一比对 golden）-> LED 指示 run/pass/fail
// 适用：普志 PZSDR-P201（XC7Z020-2CLG400I）
//
// 【引脚】clk=U18(IO_L11P_T1_SRCC_34 50MHz)、rst_n=N18(PL_nGRST)；
//         板上仅 2 个用户 LED：led_run=C20、led_status(合并 pass/fail)=B20（Bank35, LVCMOS33）。
//
// 【时序要点】top_conv3x3 的 OFM 是同步读 BRAM（读延迟 1 拍），
// ofm_rd_data 比 ofm_rd_addr 晚 1 拍，故采用"先采集到 RAM、再统一比对"
// 结构，避免逐拍直接比对产生错位。
//=============================================================================
module top_conv3x3_onboard #(
    parameter DATA_PATH = "py/",
    parameter N_PIX      = 256,   // 16x16 像素
    parameter WGT_CNT    = 10,    // 9 权重 + 1 偏置
    parameter DATA_W     = 16
)(
    input  wire       clk,        // 板载 PL 时钟（50MHz 晶振，U18）
    input  wire       rst_n,      // 低有效复位（N18）
    output reg        led_run,    // 运行指示灯：配置/推理闪烁，完成常亮
    output reg        led_status  // 结果指示灯：全对常亮(=通过)，出错熄灭(=失败)
);

//=============================================================================
// 片上 ROM（综合时初始化）
//=============================================================================
reg signed [DATA_W-1:0] ifm_rom    [0:N_PIX-1];
reg signed [DATA_W-1:0] wgt_rom    [0:WGT_CNT-1];
reg signed [DATA_W-1:0] golden_rom [0:N_PIX-1];

initial begin
    $readmemh({DATA_PATH, "ifm.hex"},          ifm_rom);
    $readmemh({DATA_PATH, "wgt.hex"},          wgt_rom);
    $readmemh({DATA_PATH, "golden_output.hex"}, golden_rom);
end

//=============================================================================
// 片上 RAM（存推理输出，供比对）
//=============================================================================
reg signed [DATA_W-1:0] ofm_ram [0:N_PIX-1];
integer ram_i;
initial begin
    for (ram_i = 0; ram_i < N_PIX; ram_i = ram_i + 1)
        ofm_ram[ram_i] = 'sd0;
end

//=============================================================================
// 加速器实例（单 PE 3x3 卷积）
//=============================================================================
reg        start;
wire       acc_busy, acc_done;
wire       ifm_we;
wire [7:0] ifm_wr_addr;
wire [DATA_W-1:0] ifm_din;
wire       wgt_we;
wire [3:0] wgt_wr_addr;
wire [DATA_W-1:0] wgt_din;
wire [7:0] ofm_rd_addr;
wire [DATA_W-1:0] ofm_rd_data;

top_conv3x3 #(
    .IMG_H(16), .IMG_W(16), .N_PIX(256), .K_SIZE(3), .PAD(1),
    .TAPS(9), .DATA_W(16), .ACC_W(32), .SHIFT_BITS(4)
) conv_inst (
    .clk(clk), .rst_n(rst_n),
    .start(start), .busy(acc_busy), .done(acc_done),
    .ifm_we(ifm_we), .ifm_wr_addr(ifm_wr_addr), .ifm_din(ifm_din),
    .wgt_we(wgt_we), .wgt_wr_addr(wgt_wr_addr), .wgt_din(wgt_din),
    .ofm_rd_addr(ofm_rd_addr), .ofm_rd_data(ofm_rd_data)
);

//=============================================================================
// 控制状态机
//=============================================================================
localparam ST_IDLE     = 4'd0;
localparam ST_CFG_IFM  = 4'd1;   // 写 256 个输入像素
localparam ST_CFG_WGT  = 4'd2;   // 写 9 权重 + 1 偏置
localparam ST_RUN      = 4'd3;   // 拉 start
localparam ST_WAIT     = 4'd4;   // 等 acc_done
localparam ST_READ     = 4'd5;   // 读 OFM 采集到 RAM（含 1 拍对齐）
localparam ST_COMPARE  = 4'd6;   // 遍历比对 golden
localparam ST_DONE     = 4'd7;
localparam ST_ERROR    = 4'd8;

reg [3:0]  state;
reg [8:0]  cfg_cnt;      // 配置计数（0-255 / 0-9）
reg [8:0]  rd_cnt;       // OFM 读采集计数（0-256，多 1 拍补对齐）
reg [8:0]  cmp_idx;      // 比对索引（0-255）
reg        cmp_error;

// 配置信号（组合）
assign ifm_we       = (state == ST_CFG_IFM);
assign ifm_wr_addr  = cfg_cnt[7:0];
assign ifm_din      = ifm_rom[cfg_cnt];

assign wgt_we       = (state == ST_CFG_WGT);
assign wgt_wr_addr  = cfg_cnt[3:0];
assign wgt_din      = wgt_rom[cfg_cnt];

assign ofm_rd_addr  = rd_cnt[7:0];   // 读地址由采集计数驱动

// 状态机主逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state      <= ST_IDLE;
        cfg_cnt    <= 'd0;
        rd_cnt     <= 'd0;
        cmp_idx    <= 'd0;
        cmp_error  <= 1'b0;
        start      <= 1'b0;
        led_status <= 1'b0;
    end else begin
        case (state)
            //----------------------------------------------------------
            ST_IDLE: begin
                cfg_cnt <= 'd0;
                state   <= ST_CFG_IFM;
            end

            // 配置输入像素 (256)
            ST_CFG_IFM: begin
                if (cfg_cnt == N_PIX - 1) begin
                    cfg_cnt <= 'd0;
                    state   <= ST_CFG_WGT;
                end else begin
                    cfg_cnt <= cfg_cnt + 1'd1;
                end
            end

            // 配置权重 + 偏置 (10)
            ST_CFG_WGT: begin
                if (cfg_cnt == WGT_CNT - 1) begin
                    cfg_cnt <= 'd0;
                    state   <= ST_RUN;
                end else begin
                    cfg_cnt <= cfg_cnt + 1'd1;
                end
            end

            // 触发推理
            ST_RUN: begin
                start <= 1'b1;
                state <= ST_WAIT;
            end

            // 等待完成
            ST_WAIT: begin
                start <= 1'b0;
                if (acc_done) begin
                    rd_cnt <= 'd0;
                    state  <= ST_READ;
                end
            end

            // 读 OFM 采集到 RAM（BRAM 读延迟 1 拍）
            // 拍 k：ofm_rd_data = 像素(k-1)（addr 于拍 k-1 组合为 k-1）
            // -> 写入 ofm_ram[k-1]；rd_cnt 到 N_PIX 时最后像素已采集完
            ST_READ: begin
                ofm_ram[rd_cnt - 1] <= ofm_rd_data;
                if (rd_cnt == N_PIX) begin
                    cmp_idx   <= 'd0;
                    cmp_error <= 1'b0;
                    state     <= ST_COMPARE;
                end else begin
                    rd_cnt <= rd_cnt + 1'd1;
                end
            end

            // 统一比对 golden
            ST_COMPARE: begin
                if (ofm_ram[cmp_idx] !== golden_rom[cmp_idx]) begin
                    cmp_error <= 1'b1;
                end
                if (cmp_idx == N_PIX - 1) begin
                    if (cmp_error || (ofm_ram[cmp_idx] !== golden_rom[cmp_idx])) begin
                        state <= ST_ERROR;
                    end else begin
                        state <= ST_DONE;
                    end
                end else begin
                    cmp_idx <= cmp_idx + 1'd1;
                end
            end

            ST_DONE: begin
                led_status <= 1'b1;   // 通过：结果 LED 常亮
            end

            ST_ERROR: begin
                led_status <= 1'b0;   // 失败：结果 LED 熄灭
            end

            default: state <= ST_IDLE;
        endcase
    end
end

//=============================================================================
// 运行指示灯（闪烁）
//=============================================================================
reg [23:0] blink_cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        blink_cnt <= 'd0;
        led_run   <= 1'b0;
    end else begin
        blink_cnt <= blink_cnt + 1'd1;
        if (state == ST_DONE)
            led_run <= 1'b1;          // 完成常亮
        else if (state == ST_ERROR)
            led_run <= 1'b0;          // 错误熄灭
        else
            led_run <= blink_cnt[23]; // 配置/推理阶段闪烁
    end
end

endmodule
