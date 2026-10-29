# 综合结果报告（single_pe_conv3x3）

> 综合后真实资源单独报告，不并入 design_spec。仿真 PASS 后于 Vivado 2024.2 实测。

## 环境
- 工具：Vivado 2024.2（win64，Build 5239630）
- 器件：`xc7z020clg400-2`（普志 PZSDR，XC7Z020-2CLG400I）
- 时钟约束：100MHz（`create_clock -period 10.000`）
- 顶层：`top_conv3x3`，7 个 RTL 源文件

## 真实资源占用（综合后）

| 资源 | 实际 | 可用 | 占用率 | 估算对照 |
|---|---|---|---|---|
| **DSP48E1** | **1** | 220 | 0.45% | 1 ✓ 精确命中 |
| **BRAM (RAMB18)** | **2** | 280 | 0.71% | 3（IFM+OFM 各1；权重太小走 LUT RAM 未进 BRAM） |
| **Slice LUT** | **158** | 53200 | 0.30% | 250（更省，含 12 LUT 作权重分布式 RAM） |
| **Slice FF** | **46** | 106400 | 0.04% | 200（综合优化打拍，更省） |
| BUFG | 1 | 32 | 3.13% | - |
| Bonded IOB | 75 | 125 | 60% | 上板做片上自测 wrapper 后会大幅减少 |

**存储分布**：IFM（256×16）→1×RAMB18E1；OFM（256×16）→1×RAMB18E1；WGT（10×16）→分布式 RAM（RAM32M×3，12 LUT）。

## 时序（100MHz，period 10ns）

| 项 | 结果 | 状态 |
|---|---|---|
| Setup | WNS = **1.920ns**（slack MET），0 Failing | ✅ 收敛，还有 1.92ns 余量 |
| Hold | WHS = 0.142ns，0 Failing | ✅ |
| Pulse Width | 0 Failing | ✅ |

> WNS 1.92ns 意味着实际可跑到约 `1/(10-1.92) ≈ 123MHz` 才到临界，100MHz 稳健。

## 综合耗时
约 **80 秒**（wait_on_runs elapsed 00:01:20）。对比原 axis_conv3x3_mc 铺 54 个并行乘法器综合数小时跑不动/报错——**单 PE 时分复用把资源压到物理下限，综合恢复正常**。

## 结论
- 设计**可综合**，0 error，资源占用极低（DSP 1/220、LUT 158/53200、FF 46/106400）。
- 时序收敛、余量充足，100MHz 上板无风险。
- 满足"最小可综合"目标：DSP=1（物理下限），BRAM=2，逻辑逻辑占比 <0.5%。

## 复现
```bat
cd /d ...\single_pe_conv3x3\vivado
vivado -mode batch -source synth_only.tcl   # 只综合+资源报告
vivado -mode batch -source create_project.tcl # 综合+实现+比特流（上板前用）
```

## 下一步（上板）
1. 按普志 PZSDR 板原理图确认时钟/复位/LED 引脚 → 补 constraints.xdc（器件已定为 xc7z020clg400-2）。
2. 写 onboard wrapper（片上 ROM 自测 + LED）。
3. 跑 create_project.tcl 实现+比特流 → Hardware Manager 下载验证。

---

# 上板实现结果（onboard 顶层，已跑通）

> 器件 xc7z020clg400-2，时钟 50MHz（板载晶振），顶层 `top_conv3x3_onboard`
> （片上 ROM 自测 + 2×LED：led_run + led_status），`onboard_impl.tcl` 全流程
> 综合→实现→布线→比特流。

## 真实资源占用（实现后）

| 资源 | 实际 | 可用 | 占用率 |
|---|---|---|---|
| **DSP48E1** | **1** | 220 | 0.45% |
| **Block RAM Tile** | **1** | 140 | 0.71% |
| **Slice LUT** | **1659** | 53200 | 3.12% |
| Slice Registers | **4223** | 106400 | 3.97% |
| F7 Muxes / F8 Muxes | 586 / 291 | - | - |
| Bonded IOB | 5 | - | - |

> 自测 ROM（ifm/wgt/golden 各 256×16）用 LUT/FF 实现，故 LUT/FF 明显高于纯计算顶层
> （LUT 158/FF 46）；DSP=1、BRAM=1 仍是物理下限。

## 时序（50MHz，period 20ns）

| 项 | 结果 | 状态 |
|---|---|---|
| Setup | WNS = **9.313ns**，0 Failing | ✅ 余量充足 |
| Hold | WHS = 0.124ns，0 Failing | ✅ |

## 比特流
- `project_onboard/single_pe_conv3x3_onboard.runs/impl_1/top_conv3x3_onboard.bit` ✅

## 复现
```bat
cd /d ...\single_pe_conv3x3\vivado
vivado -mode batch -source onboard_impl.tcl   # 综合+实现+布线+比特流
```
