# py/ — 软件黄金向量与比对脚本（README）

## gen_golden.py
生成最小单PE卷积的测试向量与黄金输出，**定点规则与 RTL 完全一致**：
- `ifm.hex`：256×int16 输入特征图（16×16，Q8.7）
- `wgt.hex`：10×int16，索引0..8=3×3权重，索引9=偏置
- `golden_output.hex`：256×int16 期望输出

### 黄金计算规则（与 top_conv3x3.v 严格一致）
```
acc  = sum(9 taps ifm*wgt) + bias          # int32
res  = acc >> SHIFT_BITS                   # 算术右移（Python >> 对负数即算术右移）
out  = saturate_to_int16(res)              # 饱和到 [-32768, 32767]
```
padding=1：输出像素 (row,col) 窗口覆盖 `ifm(row-1+r, col-1+c)`，越界视为 0。

### 用法
```
python gen_golden.py    # 生成三个 .hex（seed=42，可改 SEED）
```

## check_result.py
比对 RTL 仿真输出与黄金向量，输出 PASS/FAIL、错配数、最大误差、首个错配位置。

### 用法
```
python check_result.py <rtl_out.hex> <golden_out.hex>
# 退出码 0=PASS, 1=FAIL
```

## 合规性
- 与 AGENTS.md"验证要求"一致：修改 RTL 定点规则时，必须同步改本文件。
- 黄金规则以本文件为**唯一权威**，RTL 与之对齐（双向核对）。
