# task.md — single_pe_conv3x3 任务与完成状态

> 按 AGENTS.md：实施完成后更新本文件完成状态。实时状态以本文件为准。

## 工程
最小可综合上板单 PE 3×3 卷积加速器（16×16×1，int16 Q8.7，单 MAC 时分复用），普志 PZSDR-P201（XC7Z020-2CLG400I）。

## 任务状态

| # | 任务 | 状态 | 说明 |
|---|---|---|---|
| 1 | 参考库盘点选型（research.md） | ✅ 完成 | 选定 axis_conv3x3_mc 定点参考、on_board 上板参考 |
| 2 | 实施计划（plan.md） | ✅ 完成 | 阶段 A RTL→B golden→C 仿真→D 上板 |
| 3 | 7 个 RTL 模块 + README | ✅ 完成 | pe_mac/addr_gen_slide/conv_ctrl_fsm/bram×3/top_conv3x3 |
| 4 | py 黄金向量链路 + README | ✅ 完成 | gen_golden(seed=42)/check_result，ifm/wgt/golden hex |
| 5 | ModelSim 仿真验证 | ✅ 完成 | 256/256 PASS（修 3 个实质 bug） |
| 6 | 纯计算顶层综合 | ✅ 完成 | DSP=1、BRAM=2、LUT=158、FF=46，0 error，时序收敛 |
| 7 | 上板自测顶层 | ✅ 完成 | top_conv3x3_onboard（ROM 自测 + 2×LED） |
| 8 | 引脚定稿 + 实现 + 比特流 | ✅ 完成 | clk=U18(P端)/rst=N18/led_run=C20/led_status=B20；bit 已生成，时序收敛 |
| 9 | 上板下载验证（LED） | ⬜ 待办 | Hardware Manager 下载 bit → 看 LED |

## 上板自测判定
- `led_run`（C20）：配置/推理闪烁 → 完成常亮
- `led_status`（B20）：比对全对=亮（PASS），出错=灭（FAIL）
- 结论：**常亮 + 亮 = 全 PASS**；**常亮 + 灭 = FAIL**

## 关键交付物
- 仿真 PASS：`PASS: all 256 samples match golden`
- 比特流：`vivado/project_onboard/.../impl_1/top_conv3x3_onboard.bit`
- 资源报告：`vivado/SYNTH_RESULT.md`（综合真实资源单独报告，不并入设计文档）
