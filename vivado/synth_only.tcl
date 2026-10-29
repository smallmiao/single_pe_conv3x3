#=============================================================================
# synth_only.tcl - 只做综合 + 资源报告（快速验证真实资源占用）
#--------------------------------------------------------------------------
# 与 create_project.tcl 共用工程设置，但只跑到综合，输出 utilization 报告。
# 用于快速确认 DSP/BRAM/LUT/FF 真实占用，再决定是否走实现/上板。
#
# 用法：
#   vivado -mode batch -source synth_only.tcl
#=============================================================================

set project_name "single_pe_conv3x3"
set script_dir   [file dirname [file normalize [info script]]]
set repo_root    [file normalize [file join $script_dir ..]]
set project_dir  [file join $script_dir project]
set part         "xc7z020clg400-2"
set top_module   "top_conv3x3"
set rtl_root     [file join $repo_root src]

create_project $project_name $project_dir -part $part -force

add_files -norecurse [list \
    "$rtl_root/pe_mac.v" \
    "$rtl_root/addr_gen_slide.v" \
    "$rtl_root/conv_ctrl_fsm.v" \
    "$rtl_root/bram_ifm.v" \
    "$rtl_root/bram_wgt.v" \
    "$rtl_root/bram_ofm.v" \
    "$rtl_root/top_conv3x3.v" \
]
set_property top $top_module [current_fileset]

add_files -fileset constrs_1 -norecurse [file join $script_dir constraints.xdc]

launch_runs synth_1 -jobs 4
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "综合状态: $synth_status"
if {$synth_status != "synth_design Complete!"} {
    puts "ERROR: 综合失败！"
    exit 1
}

open_run synth_1
report_utilization -file "$project_dir/synth_utilization.rpt"
report_timing_summary -file "$project_dir/synth_timing.rpt"
puts "资源报告: $project_dir/synth_utilization.rpt"
puts "时序报告: $project_dir/synth_timing.rpt"
puts "SYNTH_DONE"
