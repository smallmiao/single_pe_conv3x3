# addr_gen_slide.v — 滑窗地址生成器（README）

## 功能
为 3×3 卷积生成**滑动窗口的读取地址**，并处理 **padding 补零**边界。

- 遍历所有输出像素（行主序），每个像素遍历 3×3 核的 9 个 tap。
- 每个 tap 计算 IFM 读地址 + 权重索引，并标记该 tap 是否落在输入范围外（padding）。

## 坐标模型（padding=1）
```
输出像素 (row, col) → 窗口覆盖 IFM(row-1+r, col-1+c)，r,c ∈ {0,1,2}
越界坐标 → pad（数据视为 0），由 pad_valid=1 通知下游喂 0。
```

## 接口
| 端口 | 方向 | 说明 |
|---|---|---|
| clk / rst_n | in | 时钟 / 低有效复位 |
| en | in | 每拍推进一个 tap |
| clr | in | 复位计数到像素(0,0)、tap(0,0) |
| ifm_addr | out | IFM BRAM 读地址（pad 时输出 0） |
| pad_valid | out | 1 = 该 tap 为 padding，数据须置 0 |
| wgt_idx | out | 权重索引 0..8（= tap 线性索引） |
| pix_done | out | 最后一个像素的最后一个 tap 完成时脉冲 |
| pix_cnt | out | 当前输出像素索引（行主序） |

## 计数器设计（无除法/取模，低 LUT）
- `tap_r / tap_c`（0..2）：独立计数，不进位即无除法。
- `row / col`（0..15）：像素位置，独立计数。
- `wgt_idx = tap_r*K_SIZE + tap_c`、`pix_cnt = row*IMG_W + col` 用乘法合成，避免综合器生成除法器。

## 合规性（AGENTS.md）
- 纯 Verilog-2001；时序非阻塞；显式低有效复位；单时钟域。
- 有符号坐标用 `$signed` + PAD 做越界判断，消除无符号/有符号混用告警。

## 资源（估算）
- FF：tap_r/tap_c/row/col ≈ 2+2+4+4 = 12。
- LUT：范围比较 + 地址合成 ≈ 30。
