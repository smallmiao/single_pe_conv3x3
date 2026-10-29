#=============================================================================
# create_project.tcl - Vivado 工程创建脚本 (single_pe_conv3x3)
#--------------------------------------------------------------------------
# 器件目标：普志 PZSDR (Zynq-7000 XC7Z020-2CLG400I -> xc7z020clg400-2)
#   - 综合阶段不需要引脚约束即可看资源；XDC 里放了通用时钟约束。
#   - 上板阶段需按普志 SDR 板原理图补 PACKAGE_PIN / IOSTANDARD。
#
# 使用方法（Windows，Vivado 2024.2）：
#   vivado -mode batch -source create_project.tcl
#   （或打开 Vivado Tcl Console，cd 到本目录后 source create_project.tcl）
#
# 流程：创建工程 -> 加 RTL -> 综合 -> 输出资源/时序报告 -> 实现 -> 生成比特流
#=============================================================================

#==================== 工程设置 ====================
set project_name "single_pe_conv3x3"
set script_dir   [file dirname [file normalize [info script]]]
set repo_root    [file normalize [file join $script_dir ..]]
set project_dir  [file join $script_dir project]
set part         "xc7z020clg400-2"
set top_module   "top_conv3x3"

# RTL 源码目录
set rtl_root [file join $repo_root src]

#==================== 创建工程 ====================
create_project $project_name $project_dir -part $part -force

#==================== 添加 RTL 源文件 ====================
add_files -norecurse [list \
    "$rtl_root/pe_mac.v" \
    "$rtl_root/addr_gen_slide.v" \
    "$rtl_root/conv_ctrl_fsm.v" \
    "$rtl_root/bram_ifm.v" \
    "$rtl_root/bram_wgt.v" \
    "$rtl_root/bram_ofm.v" \
    "$rtl_root/top_conv3x3.v" \
]

# 设置顶层模块
set_property top $top_module [current_fileset]

#==================== 添加约束文件 ====================
add_files -fileset constrs_1 -norecurse [file join $script_dir constraints.xdc]

#==================== 运行综合 ====================
puts "============================================================"
puts "开始综合 (Synthesis)..."
puts "============================================================"
launch_runs synth_1 -jobs 4
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "综合状态: $synth_status"
if {$synth_status != "synth_design Complete!"} {
    puts "ERROR: 综合失败！请查看综合报告。"
    exit 1
}

# 综合后资源报告
open_run synth_1
report_utilization -file "$project_dir/synth_utilization.rpt"
report_timing_summary -file "$project_dir/synth_timing.rpt"
puts "综合资源报告: $project_dir/synth_utilization.rpt"
puts "综合时序报告: $project_dir/synth_timing.rpt"

#==================== 运行实现 ====================
puts "============================================================"
puts "开始实现 (Implementation)..."
puts "============================================================"
launch_runs impl_1 -jobs 4
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "实现状态: $impl_status"
if {$impl_status != "route_design Complete!"} {
    puts "ERROR: 实现失败！请查看实现报告。"
    exit 1
}

open_run impl_1
report_utilization -file "$project_dir/impl_utilization.rpt"
report_timing_summary -file "$project_dir/impl_timing.rpt"
report_power -file "$project_dir/impl_power.rpt"
puts "实现资源报告: $project_dir/impl_utilization.rpt"
puts "实现时序报告: $project_dir/impl_timing.rpt"
puts "实现功耗报告: $project_dir/impl_power.rpt"

#==================== 生成比特流 ====================
puts "============================================================"
puts "生成比特流 (Bitstream Generation)..."
puts "============================================================"
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set bit_file "$project_dir/${project_name}.runs/impl_1/${top_module}.bit"
if {[file exists $bit_file]} {
    puts "比特流生成成功: $bit_file"
} else {
    puts "ERROR: 比特流生成失败！"
    exit 1
}

puts "============================================================"
puts "全部流程完成！"
puts "============================================================"
