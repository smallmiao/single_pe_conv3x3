# 推送前便携化调研

## 目标
在推送到 `smallmiao/single_pe_conv3x3` 前，去除工程文件中的本机绝对路径，避免泄露本机目录并保证工程可在其他目录复现。

## 调研结果
- `onboard/top_conv3x3_onboard.v` 的 `DATA_PATH` 默认值指向本机工程目录，供 ROM 初始化读取 HEX 向量。
- `tb/tb_top_conv3x3.v` 使用本机绝对路径定位 `py` 目录。
- `vivado/create_project.tcl`、`synth_only.tcl`、`onboard_synth.tcl`、`onboard_impl.tcl` 和 `pin_probe.tcl` 包含本机绝对路径。
- `tb/run_sim.do` 与 testbench 依赖从 `tb/` 执行的相对路径；ModelSim 的 `info script` 在此环境返回执行程序路径而非 `.do` 文件路径，因此保留已有的 `tb/` 工作目录约定。
- 相关 README 中的本机路径已改为可移植描述。
- 仿真工作目录、ModelSim 日志及 Vivado 工程/运行目录和生成文件通过 `.gitignore` 排除；RTL、testbench、约束、可复现脚本和必要 HEX 输入保留。

## 方案
以各 Tcl/DO 脚本自身所在目录推导工程根目录；RTL 文件中的 HEX 目录默认值改为可覆盖的相对路径/参数。保持模块接口及计算逻辑不变。
