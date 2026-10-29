# onboard/ — 上板自测顶层（普志 PZSDR-P201）

## 文件
- `top_conv3x3_onboard.v` — 上板自测顶层：片上 ROM（`py/*.hex`）→ 自动配置
  IFM/WGT/BIAS → 触发推理 → 采集 OFM → 比对 golden → LED 指示（run + status）
- `README.md`

## 端口（4 个 PL 引脚，已定稿）
| 端口 | FPGA 引脚 | 说明 |
|---|---|---|
| `clk` | **U18** | 板载 PL 时钟（50MHz 晶振，IO_L11P_T1_SRCC_34 P 端），LVCMOS33 |
| `rst_n` | **N18** | 低有效复位（PL_nGRST，IO_L12N_T1_MRCC_34），LVCMOS33 |
| `led_run` | **C20** | 运行/完成（Bank35 LED1），LVCMOS33 |
| `led_status` | **B20** | 结果（Bank35 LED2），LVCMOS33 |

> 说明：板上仅 2 个用户 LED，故将原 led_pass/led_fail 合并为 `led_status`
> （全对=亮/通过，出错=灭/失败），与 `led_run` 一起正好用满 2 个 LED。
> 引脚约束见 `vivado/constraints.xdc`。

## 自测数据
- 复用 `py/ifm.hex`（256）、`py/wgt.hex`（10，含偏置）、`py/golden_output.hex`（256）
- 由 `py/gen_golden.py`（seed=42）生成，与仿真验证同一套数据

## 时序要点
- `top_conv3x3` 的 OFM 为同步读 BRAM（延迟 1 拍），`ofm_rd_data` 比地址晚 1 拍。
- 本顶层采用"**先采集到 RAM、再统一比对**"（ST_READ → ST_COMPARE），ST_READ 多跑 1 拍
  补齐读延迟对齐，避免逐拍直接比对错位。

## 上板流程（已跑通实现+比特流）
1. 引脚已定稿写入 `vivado/constraints.xdc`。
2. 顶层 `top_conv3x3_onboard`，跑 `vivado/onboard_impl.tcl`（综合+实现+布线+比特流）。
3. Hardware Manager 下载 `.../impl_1/top_conv3x3_onboard.bit`。
4. 观察 LED：`led_run` 闪烁→常亮 = 推理完成；`led_status` 常亮 = **比对通过**，灭 = **失败**。
   （结论：常亮+亮 = 全 PASS；常亮+灭 = FAIL）

## 参考
- 采用通用的 FPGA 上板自测顶层结构。
