# bram_ifm.v / bram_wgt.v / bram_ofm.v — 三个同步读 BRAM（README）

三个模块**结构完全相同**（同接口、同行为），仅存储用途与深度不同。按 AGENTS.md"不随意改公共接口"原则各自独立成文件。

## 通用结构
简单双口（Simple Dual-Port）：
- **Port A（写）**：同步写，`we_a` 有效时写入 `din_a` 到 `addr_a`。
- **Port B（读）**：同步读，`dout_b` 在 `addr_b` 有效后 **1 拍**输出（BRAM 特性）。

## 参数
| 参数 | 含义 |
|---|---|
| DATA_W | 数据位宽（本工程统一 16） |
| ADDR_W | 地址位宽 |
| INIT_FILE | 可选 .hex 初始化文件（空串 = 不用；供 tb / 片上 ROM 用） |

## 三个实例
| 模块 | 深度 | ADDR_W | 用途 | 写入方 | 读取方 |
|---|---|---|---|---|---|
| bram_ifm | 256×16 | 8 | 输入特征图 16×16 | PS 预载 | 卷积流水（addr_gen） |
| bram_wgt | 10×16 | 4 | 9 权重 + 1 偏置 | PS 预载 | 卷积流水（wgt_idx） |
| bram_ofm | 256×16 | 8 | 输出特征图 16×16 | 卷积结果 | PS 读取比对 |

## 行为要点
- **同步读 1 拍延迟**：地址在 clk 沿锁存，下 1 拍 `dout_b` 有效。FSM 已据此对齐（见 conv_ctrl_fsm）。
- 用 `reg [DATA_W-1:0] mem[...]` 数组，综合工具推断为 BRAM（非 LUTRAM）。
- 复位：本模块为纯存储，读数据寄存器不接复位（BRAM 常规做法，不违反 AGENTS.md——复位策略针对控制寄存器）。

## 合规性（AGENTS.md）
- 纯 Verilog-2001；同步写用非阻塞；单时钟域。

## 资源（估算）
- BRAM18K：每块 1（IFM/OFM 各 1，WGT 1）；合计 3。
