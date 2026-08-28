##### synthesis script #####
# setup vars
# setup for typical cells

# ---- CHANGED: library dirs -> full multi-Vt mix (RVT + LVT + HVT) ----
set TSMC65_DIR "/data/tsmc/65LP/dig_libs/TSMCHOME/digital/Front_End/timing_power_noise/NLDM"

define_design_lib WORK -path "."

set search_path [concat $search_path "." \
"$TSMC65_DIR/tcbn65lp_220a" \
"$TSMC65_DIR/tcbn65lplvt_220a" \
"$TSMC65_DIR/tcbn65lphvt_220a" ]
set target_library [list \
"tcbn65lptc1d0.db" \
"tcbn65lplvttc1d0.db" \
"tcbn65lphvttc1d0.db" ]
# ---------------------------------------------------------------------

set plot_command "lpr -Pbp"
set synthetic_library " dw_foundation.sldb "
#set synthetic_library "dw01.sldb dw02.sldb dw03.sldb dw04.sldb \
# dw05.sldb dw06.sldb dw_foundation.sldb"
set link_library [concat * $target_library $synthetic_library]
set verilogout_no_tri true
set verilog_show_unconnected_pins false
set verilog_unconnected_Prefix true
set hdlout_internal_busses true
set bus_inference_style {%s[%d]}
set verilogout_single_bit false
#set bus_naming_style "%s_%d"
set bus_naming_style {%s[%d]}

puts -nonewline "\033\[1;31m"; #RED
puts "STARTING SYNTHESIS"
puts -nonewline "\033\[0m";# Reset
puts ""

set TopModule top_interpolator_dac

# List here ALL libraries you are going to use
# no need to add IO PADs libs here
# do not remove dw_foundation.sldb
# review link_library list with your supervisor

#set link_library " dw_foundation.sldb \
#/tools/kits/tower/PDK_TS18SL/FS120_STD_Cells_0_18um_2005_12/DW_TOWER_tsl18fs120/2005.12/synopsys/2004.12/models/tsl18fs120_typ.db"
#

# List here your RTL ( VHDL / Verilog ) files to be synthesized
# defines and constants files should be listed first
# Top Module file should be just after defines and constants

analyze -library WORK -format sverilog { \
../datain/rtl/filter4tweny.v \
../datain/rtl/spi_i.v \
../datain/rtl/spi_register.v \
../datain/rtl/shift_30_I.v \
../datain/rtl/spi_L.v \
../datain/rtl/spline_reg_out.v \
../datain/rtl/top_spline.v \
../datain/rtl/shift_30_Q.v \
../datain/rtl/spi_q.v \
../datain/rtl/spline.v \
}

elaborate ${TopModule} -architecture verilog -library WORK -update
current_design ${TopModule}

set filename "../report/post_elaborate.rpt"
redirect $filename { report_timing -delay_type max}
redirect -append $filename { report_timing -delay_type min}
redirect -append $filename { report_area }
redirect -append $filename { report_constraint -all_violators}
redirect -append $filename { check_design }

link

# read SDC

#=========================================================
# SDC Version / Design
#=========================================================
set sdc_version 2.1
current_design top_interpolator_dac

set MC_PATH_L 2
set MC_PATH_I 15
set MC_PATH_DAC 3

#=========================================================
# Clock Definition
#=========================================================
create_clock \
-name clk \
-period 1.041666 \
-waveform {0 0.520833} \
[get_ports clk]

set_clock_uncertainty 0.05 [get_clocks clk]
set_clock_transition -max 0.2 [get_clocks clk]

#=========================================================
# MC_PATH_L -> Multicycle Constraint
#=========================================================

# shift registers
# shift_I phase is single CP, while x is 2 MCP with shift_strobe
# shift_Q phase is single CP, while x is 2 MCP with shift_strobe

# set shift_regs_pin_D [get_cells -of_objects [filter_collection [get_pins -of_objects [all_registers -clock clk]] "full_name =~ shift_*/x*/data_in"]]

# Multicycle paths
# set_multicycle_path $MC_PATH_L \
# -setup \
# -to $shift_regs_pin_D

# set_multicycle_path [expr {$MC_PATH_L - 1}] \
# -hold \
# -to $shift_regs_pin_D

#=========================================================
# MC_PATH_DAC -> Multicycle Constraint
#=========================================================

# fir registers
set fir_regs_pin_D [get_cells -of_objects [filter_collection [get_pins -of_objects [all_registers -clock clk]] "full_name =~ fir_*u/y*/data_in"]]
# Multicycle paths
set_multicycle_path $MC_PATH_DAC \
-setup \
-to $fir_regs_pin_D

set_multicycle_path [expr {$MC_PATH_DAC - 1}] \
-hold \
-to $fir_regs_pin_D

set_multicycle_path $MC_PATH_DAC \
-setup \
-from $fir_regs_pin_D

set_multicycle_path [expr {$MC_PATH_DAC - 1}] \
-hold \
-from $fir_regs_pin_D

#=========================================================
# MC_PATH_I -> Multicycle Constraint
#=========================================================

# hist_I 15/16 MCP after strobe from spi_I
# hist_Q 15/16 MCP after strobe from spi_Q
# latch_I 15/16 MCP after strobe
# latch_Q 15/16 MCP after strobe
# minaj2_I 15/16 MCP after strobe
# minaj2_Q 15/16 MCP after strobe

# hist registers
# set hist_regs_pin_D [get_cells -of_objects [filter_collection [get_pins -of_objects [all_registers -clock clk]] "full_name =~ hist_*/*/data_in"]]

# # Multicycle paths
# set_multicycle_path $MC_PATH_I \
# -setup \
# -to $hist_regs_pin_D

# set_multicycle_path [expr {$MC_PATH_I - 1}] \
# -hold \
# -to $hist_regs_pin_D

# latch registers
set latch_regs_pin_D [get_cells -of_objects [filter_collection [get_pins -of_objects [all_registers -clock clk]] "full_name =~ latch_*/*/data_in"]]

# Multicycle paths
set_multicycle_path $MC_PATH_I \
-setup \
-to $latch_regs_pin_D

set_multicycle_path [expr {$MC_PATH_I - 1}] \
-hold \
-to $latch_regs_pin_D

# minaj2 registers
set minaj2_regs_pin_D [get_cells -of_objects [filter_collection [get_pins -of_objects [all_registers -clock clk]] "full_name =~ minaj2_*/*/data_in"]]

# Multicycle paths
set_multicycle_path $MC_PATH_I \
-setup \
-to $minaj2_regs_pin_D

set_multicycle_path [expr {$MC_PATH_I - 1}] \
-hold \
-to $minaj2_regs_pin_D

#=========================================================
# Input Constraints
#=========================================================

set all_in_no_clk [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay 0.1 -clock clk $all_in_no_clk

#=========================================================
# Output Constraints
#=========================================================

set_output_delay 0.1 -clock clk [all_outputs]
set_load 0.05 [all_outputs]


write_sdc -nosplit ../dataout/${TopModule}.sdc
current_design ${TopModule}

# save initial DB for future debug
write -format ddc -hierarchy -output ../dataout/initial.${TopModule}.ddc ${TopModule}

# Compile ultra settings
# leave unloaded sequential cells ( FFs )
# 1. good for early stages of design , when some FFs are mistakenly disconnected
# 2. good for last minute ECO when we want you use previously unused FFs

set compile_delete_unloaded_sequential_cells true
set compile_seqmap_propagate_constants false
set compile_seqmap_propagate_high_effort false

# enable constant propagation through combinatorial cells (not FFs ) -> realistic timing analysis

set case_analysis_with_logic_constants true
set template_separator_style "_"

# Add Clock Gating
set_clock_gating_style -sequential_cell latch -minimum_bitwidth 3
insert_clock_gating

# keep preserved hierarchy even after clock-gating step
set_ungroup [get_cells {minaj2_I minaj2_Q fir_I_u fir_Q_u shift_I shift_Q}] false

# disable register merging , LEC will pass easier set_register_merging [ get_designs ${TopModule} ] false
# Compile, Synthesize
puts -nonewline "\033\[1;31m"; #RED
puts "##### STARTING COMPILATION #####"
puts -nonewline "\033\[0m";# Reset
puts ""
# Create vsdc file to help LEC
set_vsdc compile.vsdc
#
#compile_ultra
compile_ultra
puts -nonewline "\033\[1;31m"; #RED
puts "##### FINISHED COMPILATION #####"
puts -nonewline "\033\[0m";# Reset
puts ""
# reports

set filename "../report/post_compile.rpt"
redirect $filename { report_timing -delay_type max}
redirect -append $filename { report_timing -delay_type min}
redirect -append $filename { report_area }
redirect -append $filename { report_constraint -all_violators}
redirect -append $filename { check_design }

# enter scan chain, don't ignore Shift-registers
# set_scan_configuration -style multiplexed_flip_flop
# set compile_seqmap_identify_shift_registers false

# create scan ports
# create_port -dir in scan_en
#create_port -dir in scan_reset //not a must have
# create_port -dir in {scan_in1 scan_in2 scan_in3}
# create_port -dir out {scan_out1 scan_out2 scan_out3}

#set_dft_signal -view spec -type Reset -port scan_reset -active_state 1 //not a must have
# set_dft_signal -view existing_dft -type ScanClock -port clk -timing {45 55};
# set_dft_signal -view existing_dft -type ScanEnable -port scan_en - active_state 1
# set_dft_signal -view existing_dft -type ScanDataIn -port {scan_in1 scan_in2 scan_in3}
# set_dft_signal -view existing_dft -type ScanDataOut -port {scan_out1 scan_out2 scan_out3}

# set_scan_configuration -chain_count 3

#do scan synthesis
# create_test_protocol -infer_asynch
# dft_drc -verbose
# set_dft_configuration -scan enable
# set_dft_configuration -fix_set enable
# insert_dft

#show all chains created in a file name scanfed
# write_scan_def -output ../dataout/scandef

### write final files

write -format ddc -hierarchy -output ../dataout/final.${TopModule}.ddc ${TopModule}
set filename "../report/post_scan_chain.rpt"
redirect $filename { report_timing -delay_type max}
redirect -append $filename { report_timing -delay_type min}
redirect -append $filename { report_area }
redirect -append $filename { report_constraint -all_violators}
redirect -append $filename { check_design }

set verilogout_no_tri true
set verilog_show_unconnected_pins false
set hdlout_internal_busses true
set bus_inference_style {%s[%d]}
set verilogout_single_bit false
set bus_naming_style {%s[%d]}

write -format verilog -hierarchy -output ../dataout/${TopModule}.v


# write_sdc -nosplit ../dataout/${TopModule}.sdc
# write_test_protocol -out ../dataout/${TopModule}.spf
