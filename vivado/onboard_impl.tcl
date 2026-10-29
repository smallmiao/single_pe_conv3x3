#=============================================================================
# onboard_impl.tcl - 上板自测顶层完整流程（综合 + 实现 + 比特流）
#--------------------------------------------------------------------------
# 顶层：top_conv3x3_onboard（普志 PZSDR-P201）
# 约束：vivado/constraints.xdc（已含 clk=U15 / rst_n=U18；LED 待补）
#
# 用法：vivado -mode batch -source onboard_impl.tcl
# 产出：比特流 project_onboard/single_pe_conv3x3_onboard.runs/impl_1/xxx.bit
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
add_files -fileset constrs_1 -norecurse [file join $script_dir constraints.xdc]

#----- 综合 -----
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
    puts "ERROR: 综合失败！"; exit 1
}
open_run synth_1
report_utilization -file "$project_dir/synth_utilization.rpt"
report_timing_summary -file "$project_dir/synth_timing.rpt"

#----- 实现 -----
launch_runs impl_1 -jobs 4
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] != "route_design Complete!"} {
    puts "ERROR: 实现失败！"; exit 1
}
open_run impl_1
report_utilization -file "$project_dir/impl_utilization.rpt"
report_timing_summary -file "$project_dir/impl_timing.rpt"
report_power -file "$project_dir/impl_power.rpt"

#----- 比特流 -----
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set bit_file "$project_dir/${project_name}.runs/impl_1/${top_module}.bit"
if {[file exists $bit_file]} {
    puts "比特流生成成功: $bit_file"
} else {
    puts "ERROR: 比特流生成失败！"; exit 1
}
puts "ONBOARD_IMPL_DONE"
