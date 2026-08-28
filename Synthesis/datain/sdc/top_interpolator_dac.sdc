#=========================================================
# SDC Version / Design
#=========================================================
set sdc_version 2.1
current_design top_interpolator_dac

set MC_PATH_L 2
set MC_PATH_I 15
set MC_PATH_DAC 8

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
# shift_I     phase is single CP, while x is 2 MCP with shift_strobe
# shift_Q     phase is single CP, while x is 2 MCP with shift_strobe

# set shift_regs_pin_D [get_cells -of_objects [filter_collection [get_pins -of_objects [all_registers -clock clk]] "full_name =~ shift_*/x*/data_in"]]

# Multicycle paths
# set_multicycle_path $MC_PATH_L \
#     -setup \
#     -to $shift_regs_pin_D

# set_multicycle_path [expr {$MC_PATH_L - 1}] \
#     -hold \
#     -to   $shift_regs_pin_D

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
    -to   $fir_regs_pin_D

set_multicycle_path $MC_PATH_DAC \
    -setup \
    -from $fir_regs_pin_D

set_multicycle_path [expr {$MC_PATH_DAC - 1}] \
    -hold \
    -from   $fir_regs_pin_D

#=========================================================
# MC_PATH_I -> Multicycle Constraint
#=========================================================

# hist_I      15/16 MCP after strobe from spi_I
# hist_Q      15/16 MCP after strobe from spi_Q
# latch_I     15/16 MCP after strobe
# latch_Q     15/16 MCP after strobe
# minaj2_I    15/16 MCP after strobe
# minaj2_Q    15/16 MCP after strobe

# hist registers
# set hist_regs_pin_D [get_cells -of_objects [filter_collection [get_pins -of_objects [all_registers -clock clk]] "full_name =~ hist_*/*/data_in"]]

# # Multicycle paths
# set_multicycle_path $MC_PATH_I \
#     -setup \
#     -to $hist_regs_pin_D

# set_multicycle_path [expr {$MC_PATH_I - 1}] \
#     -hold \
#     -to   $hist_regs_pin_D

# latch registers
set latch_regs_pin_D [get_cells -of_objects [filter_collection [get_pins -of_objects [all_registers -clock clk]] "full_name =~ latch_*/*/data_in"]]

# Multicycle paths
set_multicycle_path $MC_PATH_I \
    -setup \
    -to $latch_regs_pin_D

set_multicycle_path [expr {$MC_PATH_I - 1}] \
    -hold \
    -to   $latch_regs_pin_D

# minaj2 registers
set minaj2_regs_pin_D [get_cells -of_objects [filter_collection [get_pins -of_objects [all_registers -clock clk]] "full_name =~ minaj2_*/*/data_in"]]

# Multicycle paths
set_multicycle_path $MC_PATH_I \
    -setup \
    -to $minaj2_regs_pin_D

set_multicycle_path [expr {$MC_PATH_I - 1}] \
    -hold \
    -to   $minaj2_regs_pin_D

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

