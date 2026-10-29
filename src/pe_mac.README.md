# pe_mac.v — 单 PE 乘加单元（README）

## 功能
一个**有符号乘法 + 累加（MAC）**单元，3×3 卷积的核心算子。

- `product = ifm_data × wgt_data`（组合逻辑，由综合工具推断为 DSP48E1）
- `acc = acc + product`（时序逻辑，32bit 累加）

## 定点规则
| 信号 | 位宽 | 格式 |
|---|---|---|
| ifm_data / wgt_data | 16 | int16，Q8.7 |
| acc_out | 32 | int32（防 9 次累加溢出） |

> bias 加法、算术右移、饱和截断**不在本模块**，由顶层 `top_conv3x3` 完成。

## 接口
| 端口 | 方向 | 说明 |
|---|---|---|
| clk / rst_n | in | 时钟 / 低有效复位 |
| ifm_data / wgt_data | in | 特征像素 / 权重（有符号） |
| acc_clr | in | 清零累加器（每个输出像素开始时拉高一拍） |
| acc_en | in | 累加使能（每做一次 MAC 拉高一拍） |
| acc_out | out | 32bit 累加结果 |

## 控制时序
优先级：`reset > acc_clr > acc_en > hold`。
- `acc_clr`：每像素第 1 拍拉高，**载入首拍乘积**（而非清零），tap 0 直接进累加。
- `acc_en`：第 2~9 拍拉高，逐个累加后续乘积。
- 9 拍完成一个输出像素的 9 次 MAC。

## 合规性（AGENTS.md）
- 纯 Verilog-2001（`module #()` + `reg/wire`），无 SV 语法。
- 时序逻辑非阻塞 `<=`，显式低有效复位。
- 单时钟域，无频率假设。

## 资源
- DSP48E1 = 1（一个乘法器，被累加复用）。
- FF：约 32（acc_out）。
