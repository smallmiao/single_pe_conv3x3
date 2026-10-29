# tb/ — testbench + ModelSim 脚本（README）

## 文件
| 文件 | 说明 |
|---|---|
| tb_top_conv3x3.v | 顶层 testbench |
| run_sim.do | ModelSim 一键编译+仿真+自动比对脚本 |

## 仿真流程（run_sim.do 自动执行）
1. 编译 src/ 全部 7 个 RTL + tb。
2. 运行仿真：
   - 加载 ifm.hex / wgt.hex（从内存数组经 PS 写端口灌入 DUT）
   - 拉 start，等 done
   - 读 256 个 OFM，写 rtl_out.hex
   - 调用 `py/check_result.py rtl_out.hex golden_output.hex` 自动比对
3. 打印 PASS/FAIL。

## 前置
- 先运行 `py/gen_golden.py`（生成 ifm.hex / wgt.hex / golden_output.hex）。
- 在 **tb/ 目录**下执行 `do run_sim.do`（脚本从此目录使用相对路径）。

## 覆盖的边界场景（AGENTS.md 要求说明）
| 场景 | 覆盖方式 |
|---|---|
| 四边 padding | golden 计算内含 padding 逻辑，全帧比对即覆盖 |
| 最后一像素 / 最后一 tap | done 脉冲 + busy 回落检查 |
| 复位后空闲稳定 | 复位后检查 busy/done 均为 0 |
| 全帧 256 像素 | 全量比对 |
| 超时保护 | 200us 未完成即报 TIMEOUT |

## 合规性（AGENTS.md）
- 纯 Verilog-2001 testbench；`timescale` 定义。
- 修改 RTL 后须同步更新本 tb 与 run_sim.do。
