# 查 clg400 中 LED 相关引脚 C20/B20/B19 的实际 site/IO 名
set script_dir [file dirname [file normalize [info script]]]
open_project [file join $script_dir project_onboard single_pe_conv3x3_onboard.xpr]
open_run synth_1

foreach pn {C20 B20 B19} {
    set s [get_sites -of_objects [get_package_pins $pn]]
    puts "pin=$pn site=$s"
}
puts "PROBE_DONE"
