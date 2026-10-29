# top_conv3x3.v — 单PE 3×3卷积加速器顶层（README）

## 功能
串起整个最小卷积闭环：加载输入/权重 → 单PE时分复用计算 → 偏置/移位/饱和 → 写回输出 → PS读取比对。

```
IFM_BRAM ─┐
WGT_BRAM ─┤→ addr_gen → PE(MAC) → [bias+shift+sat] → OFM_BRAM
conv_ctrl_fsm 调度全流程
```

## 定点规则
- 输入/权重/偏置：int16（Q8.7）
- 累加器：int32
- 结果：`saturate( (acc + bias) >>> SHIFT_BITS )` → int16

## 参数
| 参数 | 默认 | 含义 |
|---|---|---|
| DATA_W | 16 | 数据位宽 |
| ACC_W | 32 | 累加位宽 |
| SHIFT_BITS | 4 | 缩放右移位数 |
| IMG_H / IMG_W | 16 | 输出特征图尺寸 |
| K_SIZE / PAD | 3 / 1 | 卷积核 / 补零 |
| IFM_INIT / WGT_INIT | "" | 可选 .hex 初始化（tb用） |

## 接口（非 AXI，本阶段简化）
| 信号 | 方向 | 说明 |
|---|---|---|
| start / busy / done | in/out | 启动 / 忙 / 完成 |
| ifm_we / ifm_wr_addr / ifm_din | in | IFM 预载（PS） |
| wgt_we / wgt_wr_addr / wgt_din | in | WGT 预载（PS） |
| ofm_rd_addr / ofm_rd_data | in/out | OFM 读取（PS） |

## 时序对齐模型（关键，务必理解）
BRAM 同步读 1 拍延迟。`addr_gen` 在 `addr_en` 沿推进 tap；**同一沿 BRAM 锁存的是
上一 tap 的地址**，因此数据比地址晚 1 拍稳定。
```
周期 N   : addr_en=1，addr_gen 推进到 tapK+1；BRAM 锁存 tapK 地址
周期 N+1 : BRAM 输出 tapK 数据；data_vld/tap_d1/pad_d1（= a_en/wgt_idx/pad_valid 打 1 拍）同步到位
周期 N+1 : PE（时序）在下一沿采样，ifm_data/wgt_data 与组合 acc_clr/acc_en 同拍
```
- **IFM/WGT 数据直接用 BRAM 原始输出（不再寄存）**，避免多打一拍造成错位。
- **acc_clr/acc_en 用组合 assign**（基于 data_vld/tap_d1），使 PE 与数据同拍采样。
- tap8 数据在 N+1 返回；`addr_gen.pix_cnt` 在 tap 回绕时进到 P+1。
- **因此 OFM 写地址在 tap0 数据拍（data_vld && tap_d1==0）采样 pix_cnt**，得到像素 P；
  `ofm_wr_en`（tap8 后寄存拉高）写入正确的 P。这是本设计最容易错位的地方。

## 偏置处理
- 偏置由 PS 通过 `wgt_wr_addr==9` 写入独立寄存器 `bias_hold`。
- 与权重 BRAM 读（wgt_idx 0..8）解耦，避免读端口冲突，且在 tap8 结果有效时始终可用。

## padding 处理
- `addr_gen` 判定越界 tap → `pad_valid=1`。
- 顶层将 `pad_d1`（打 1 拍对齐）送入 PE：`ifm_to_pe = pad_d1 ? 0 : ifm_data`，
  保证 padding 处乘 0。

## 合规性（AGENTS.md）
- 纯 Verilog-2001；时序非阻塞；显式低有效复位；单时钟域；无频率假设。
- 组合逻辑（饱和、移位、译码、acc 控制）用阻塞赋值/连续赋值。

## 资源（估算）
- DSP48E1 = 1；BRAM18K = 3；LUT ≈ 250；FF ≈ 200（含上板自测，量级）。
- 注：真实资源以综合后 report 为准，此表为预期。
