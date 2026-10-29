#=============================================================================
# onboard_synth.tcl - 上板自测顶层综合验证（快速确认可综合）
#--------------------------------------------------------------------------
# 顶层：top_conv3x3_onboard（普志 PZSDR-P201，PL 时钟 50MHz）
# 只做综合+资源报告，用于验证 onboard 自测逻辑可综合、无错误。
# 上板完整实现需补引脚约束后再走 create_project.tcl（顶层改 onboard）。
#
# 用法：vivado -mode batch -source onboard_synth.tcl
#=============================================================================

set project_name "single_pe_conv3x3_onboard"
set script_dir   [file dirname [file normalize [info script]]]
set repo_root    [file normalize [file join $script_dir ..]]
set project_dir  [file join $script_dir project_onboard]
set part         "xc7z020clg400-2"
set top_module   "top_conv3x3_onboard"
set rtl_root     [file join $repo_root src]
set ob_root      [file join $repo_root onboard]
set data_path    [file normalize [file join $repo_root py]]

create_project $project_name $project_dir -part $part -force

add_files -norecurse [list \
    "$rtl_root/pe_mac.v" \
    "$rtl_root/addr_gen_slide.v" \
    "$rtl_root/conv_ctrl_fsm.v" \
    "$rtl_root/bram_ifm.v" \
    "$rtl_root/bram_wgt.v" \
    "$rtl_root/bram_ofm.v" \
    "$rtl_root/top_conv3x3.v" \
    "$ob_root/top_conv3x3_onboard.v" \
]
set_property top $top_module [current_fileset]
set_property generic [format {DATA_PATH={"%s/"}} $data_path] [current_fileset]

launch_runs synth_1 -jobs 4
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "综合状态: $synth_status"
if {$synth_status != "synth_design Complete!"} {
    puts "ERROR: 综合失败！"
    exit 1
}

open_run synth_1
# PL 时钟 50MHz（普志板晶振）；仅用于时序分析
create_clock -name sys_clk -period 20.000 [get_ports clk]
report_utilization -file "$project_dir/synth_utilization.rpt"
report_timing_summary -file "$project_dir/synth_timing.rpt"
puts "资源报告: $project_dir/synth_utilization.rpt"
puts "时序报告: $project_dir/synth_timing.rpt"
puts "ONBOARD_SYNTH_DONE"
