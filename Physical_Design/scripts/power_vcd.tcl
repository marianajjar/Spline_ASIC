# power_vcd.tcl -- real spline I0 power from the gate-sim VCD
restoreDesign ../dataout/design_saves/top_signoff.dat top
catch { set_analysis_view -setup SlowView -hold FastView }
setExtractRCMode -engine postRoute -effortLevel low
catch { extractRC }
file mkdir ./power_signoff ./power_signoff/vcd
set_power_analysis_mode -reset
set_power_analysis_mode -method static -analysis_view SlowView -honor_negative_energy true -ignore_control_signals true
set_default_switching_activity -reset
read_activity_file -reset
set VCD /project/verif/users/marianajjar/ws/spline_3_1_rerun/power_sim/top_interpolator_dac.vcd
read_activity_file -format VCD $VCD -scope tb_top_interpolator_dac/DUT -block I0
report_power -instances I0 -outfile ./power_signoff/vcd/core_I0_vcd.rpt
report_power -outfile ./power_signoff/vcd/chip_vcd.rpt
puts "POWER_VCD_DONE"
exit
