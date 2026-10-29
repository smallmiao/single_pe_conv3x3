#=============================================================================
# run_sim.do - ModelSim automation for single-PE 3x3 conv
#--------------------------------------------------------------------------
# Prerequisites:
#   - ModelSim installed
#   - py/gen_golden.py already run (produces ifm.hex / wgt.hex /
#     golden_output.hex)
#   - run this from the tb/ directory (so relative paths resolve)
#
# Usage (from ModelSim console, cwd = tb/):
#   do run_sim.do
#
# Steps: clean -> compile RTL + tb -> run -> auto-compare via python.
#=============================================================================

#---------------------------- project paths ----------------------------------
set src_dir "../src"

#---------------------------- [1/6] clean -------------------------------------
echo "\[1/6\] clean previous compile..."
if {[file exists work]} {
    vdel -all -lib work
}
vlib work
vmap work work

#---------------------------- [2/6] compile RTL ------------------------------
echo "\[2/6\] compile RTL..."
vlog -reportprogress 300 -work work $src_dir/pe_mac.v
vlog -reportprogress 300 -work work $src_dir/addr_gen_slide.v
vlog -reportprogress 300 -work work $src_dir/conv_ctrl_fsm.v
vlog -reportprogress 300 -work work $src_dir/bram_ifm.v
vlog -reportprogress 300 -work work $src_dir/bram_wgt.v
vlog -reportprogress 300 -work work $src_dir/bram_ofm.v
vlog -reportprogress 300 -work work $src_dir/top_conv3x3.v

#---------------------------- [3/6] compile tb -------------------------------
echo "\[3/6\] compile testbench..."
vlog -reportprogress 300 -work work tb_top_conv3x3.v

#---------------------------- [4/6] run --------------------------------------
echo "\[4/6\] run simulation..."
vsim -voptargs="+acc" work.tb_top_conv3x3

#---------------------------- [5/6] add waves --------------------------------
echo "\[5/6\] add waves..."
add wave -divider "Control"
add wave /tb_top_conv3x3/clk
add wave /tb_top_conv3x3/rst_n
add wave /tb_top_conv3x3/start
add wave /tb_top_conv3x3/busy
add wave /tb_top_conv3x3/done
add wave -divider "FSM (dut)"
add wave /tb_top_conv3x3/dut/u_fsm/state
add wave /tb_top_conv3x3/dut/u_fsm/addr_en
add wave /tb_top_conv3x3/dut/u_fsm/acc_clr
add wave /tb_top_conv3x3/dut/u_fsm/acc_en
add wave /tb_top_conv3x3/dut/u_fsm/ofm_wr_en
add wave -divider "AddrGen"
add wave /tb_top_conv3x3/dut/u_addr/tap_r
add wave /tb_top_conv3x3/dut/u_addr/tap_c
add wave /tb_top_conv3x3/dut/u_addr/row
add wave /tb_top_conv3x3/dut/u_addr/col
add wave /tb_top_conv3x3/dut/u_addr/pad_valid
add wave -radix decimal /tb_top_conv3x3/dut/u_addr/ifm_addr
add wave -divider "PE"
add wave -radix decimal /tb_top_conv3x3/dut/u_pe/acc_out
add wave -radix decimal /tb_top_conv3x3/dut/u_pe/product
add wave -divider "Output"
add wave -radix decimal /tb_top_conv3x3/dut/result_sat
add wave /tb_top_conv3x3/dut/ofm_wr_addr

#---------------------------- [6/6] run + report -----------------------------
echo "\[6/6\] run..."
run -all

echo "=== SIMULATION COMPLETE (see transcript for PASS/FAIL) ==="
