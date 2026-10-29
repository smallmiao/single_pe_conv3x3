# conv_ctrl_fsm.v — 卷积控制状态机（README）

## 功能
单 PE 3×3 卷积的主调度器，状态机：`IDLE → CALC → (finish 脉冲) → IDLE`。
本模块只做**调度与使能**，不做数据计算（数据在 PE，地址在 addr_gen）。

## 流水线对齐模型（关键）
BRAM 是**同步读（1 拍延迟）**。顶层把 `addr_en`、`wgt_idx`、`pad_valid`
各延迟 1 拍，得到与 BRAM 数据同拍的 `data_vld / tap_d1 / pad_d1`。
本模块根据这两者**组合**生成 PE 控制：
- `acc_clr` / `acc_en` 是**组合输出**（`assign`），让 PE 在采样数据的同一个
  时钟沿同时采到正确的控制，避免寄存器晚 1 拍造成错位。
- `ofm_wr_en` 是**寄存器**，在 tap_d1==8 的下一拍拉高，此时累加器已收敛，
  写回 OFM。

## 接口
| 端口 | 方向 | 说明 |
|---|---|---|
| clk / rst_n | in | 时钟 / 低有效复位 |
| start | in | 启动卷积（脉冲） |
| busy | out | 计算中（组合，state==CALC） |
| addr_en | out | 每拍推进滑窗地址 |
| data_vld | in | 顶层对齐后：某 tap 数据有效拍 |
| tap_d1 | in | 顶层对齐后：当前数据对应的 tap 序号 0..8 |
| finish | in | 顶层 done 脉冲，回到 IDLE |
| acc_clr / acc_en | out | 组合：载入首乘积 / 累加 |
| ofm_wr_en | out | 寄存器：结果写回 OFM（+1 拍） |

> `done` 与 `ofm_wr_addr` **不在此模块**：done 由顶层在最后一像素写时产生，
> `ofm_wr_addr` 由顶层从 `addr_gen.pix_cnt` 采样提供。FSM 只管调度与使能（单一职责）。

## 每像素时序（9 taps）
| tap_d1 | 动作 |
|---|---|
| 0 | acc_clr=1（组合，载入首乘积） |
| 1..8 | acc_en=1（组合，累加，含第 9 个 tap） |
| 8 | ofm_wr_en 寄存拉高（下一拍写 OFM） |

> 注意：tap0 用 acc_clr 载入，tap1..8 用 acc_en 累加，**9 个乘积全覆盖**，
> 不漏掉 tap8（早期版本只累加到 tap7 导致结果偏小）。

## 合规性（AGENTS.md）
- 纯 Verilog-2001；时序非阻塞；显式低有效复位；单时钟域。
- 跨时钟域：本模块单时钟，无跨域信号（跨域归顶层/接口）。

## 资源（估算）
- FF：state(2) + ofm_wr_en(1) ≈ 3。
- LUT：状态译码 + 组合 acc_clr/acc_en ≈ 10。
