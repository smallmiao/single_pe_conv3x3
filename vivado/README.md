# vivado/ — Vivado 工程（普志 PZSDR / Zynq-7020）

## 文件
- `create_project.tcl` — 创建工程 + 综合 + 实现 + 生成比特流（器件 `xc7z020clg400-2`）
- `synth_only.tcl` — 只综合 + 资源报告（快速验证）
- `constraints.xdc` — 时钟约束 100MHz；上板引脚待按普志 SDR 原理图确认
- `project/` — 生成的 Vivado 工程 + 报告
- `SYNTH_RESULT.md` — **综合真实资源报告（已出，见下）**

## 器件确认
- 普志（Puzhi）**PZSDR-P201**：Zynq-7000 **XC7Z020-2CLG400I** → part `xc7z020clg400-2`
  （官方产品规格确认；原理图标 CLG484 为模板误差）
- PL 时钟：板载 **50MHz** 晶振（`PL_CLK_50M`），非 100MHz
- 综合资源与速度等级无关，以下结果对 -1/-2 均有效。

## 综合结果（已跑通，Vivado 2024.2，xc7z020clg400-2）
- **纯计算顶层 top_conv3x3（100MHz 约束）**：约 80 秒，0 error；时序收敛
  （Setup WNS=+1.92ns）。资源：**DSP=1、RAMB18=2、LUT=158、FF=46**。
- **上板自测顶层 top_conv3x3_onboard（50MHz 约束）**：0 error，时序收敛
  （Setup WNS=+13.17ns）。资源：**DSP=1、RAMB18=2、LUT=1705、FF=4224**
  （自测 ROM 用 LUT 实现）。验证脚本 `onboard_synth.tcl`。
- 详细见 `SYNTH_RESULT.md`。

## 用法（Windows）
```bat
cd /d <repo>\vivado
vivado -mode batch -source synth_only.tcl      # 纯计算顶层综合 + 资源报告
vivado -mode batch -source onboard_synth.tcl   # 上板自测顶层综合验证
vivado -mode batch -source create_project.tcl  # 综合 + 实现 + 比特流
```

## 引脚确认（普志 PZSDR-P201，clg400）——已定稿
| 端口 | FPGA 引脚 | 说明 |
|---|---|---|
| `clk`（50MHz 晶振 PL_CLK_50M） | **U18** | IO_L11P_T1_SRCC_34（Bank34 SRCC，**P 端**），LVCMOS33 |
| `rst_n`（低有效 PL_nGRST） | **N18** | IO_L12N_T1_MRCC_34，LVCMOS33 |
| `led_run` | **C20** | Bank35 用户 LED1，LVCMOS33 |
| `led_status`（合并 pass/fail） | **B20** | Bank35 用户 LED2，LVCMOS33 |

> 关键：U18=IOB_X1Y76，为 U15(IOB_X1Y77) 差分对的 **P 端**；单端时钟必须用 P 端。
> 之前误用 U15（N 端）触发 `[DRC PLIO-9]`，改 U18 后 DRC 0 error。

## 上板实现结果（已跑通，onboard 顶层 top_conv3x3_onboard，50MHz）
- **综合 + 实现 + 布线 + 比特流全部成功**：`project_onboard/.../impl_1/top_conv3x3_onboard.bit`
- 实现后资源：**DSP=1、BRAM Tile=1、LUT=1659(3.1%)、FF=4223(4.0%)**、IOB=5
- 时序：Setup WNS=**+9.31ns**、Hold=0.124ns，**0 违规**，全收敛
- 脚本：`onboard_impl.tcl`（顶层 top_conv3x3_onboard，part xc7z020clg400-2）

## 阶段说明
- **已完成**：纯计算顶层综合；上板顶层实现 + 比特流（引脚 clk/rst/2×LED 已全部定稿）；
  LED 由 3 个合并为 2 个（led_run + led_status），匹配板上 2 个用户 LED。
- **待办（上板）**：①Hardware Manager 下载 `top_conv3x3_onboard.bit` → 看 LED
  （常亮+亮=全 PASS，常亮+灭=FAIL）；②LED 结果验证后再总结。

## 参考
- 采用通用的 FPGA 上板自测工程流程。
