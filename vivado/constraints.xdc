#=============================================================================
# constraints.xdc - single_pe_conv3x3 约束文件
#--------------------------------------------------------------------------
# 器件：普志 PZSDR-P201 (Zynq-7000 XC7Z020-2CLG400I -> xc7z020clg400-2)
# 上板顶层：top_conv3x3_onboard（含 LED 自测）
#=============================================================================

#=============================================================================
# 时钟约束：板载 50MHz 晶振（PL_CLK_50M）
#--------------------------------------------------------------------------
# PL_CLK_50M -> FPGA 引脚 U18（IO_L11P_T1_SRCC_34，Bank34 SRCC 时钟引脚，P 端）。
# 说明：U18 = IOB_X1Y76，为 U15(IOB_X1Y77) 差分对的 P 端；单端时钟须用 P 端。
#   （之前误用 U15 是 N 端，触发 [DRC PLIO-9]，已修正为 U18。）
# IOSTANDARD：按 Y2 晶振 3V3 用 LVCMOS33；若板卡 Bank34 为 1.8V 需改 LVCMOS18。
#=============================================================================
create_clock -name sys_clk -period 20.000 [get_ports clk]
set_property PACKAGE_PIN U18 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

#=============================================================================
# 复位（低有效）：PL_nGRST -> N18（IO_L12N_T1_MRCC_34，与 clk 同 Bank34）
#--------------------------------------------------------------------------
# 注：U18 已用作 PL_CLK_50M；PL_nGRST 从原理图定位到 N18（IO_L12N_T1_MRCC_34）。
#=============================================================================
set_property PACKAGE_PIN N18 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_false_path -from [get_ports rst_n] -to [all_registers]

#=============================================================================
# LED（上板自测指示，Bank35，LVCMOS33）
#--------------------------------------------------------------------------
# 板上仅 2 个用户 LED：led_run=C20、led_status(合并 pass/fail)=B20。
#   led_run    : 运行/完成（配置/推理闪烁，完成常亮）
#   led_status : 全对=亮(通过)，出错=灭(失败)
#=============================================================================
set_property PACKAGE_PIN C20 [get_ports led_run]
set_property IOSTANDARD LVCMOS33 [get_ports led_run]

set_property PACKAGE_PIN B20 [get_ports led_status]
set_property IOSTANDARD LVCMOS33 [get_ports led_status]
