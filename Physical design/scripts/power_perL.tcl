# power_perL.tcl -- per-L (2/3/4/5) core I0 power from per-L VCDs
restoreDesign ../dataout/design_saves/top_signoff.dat top
catch { set_analysis_view -setup SlowView -hold FastView }
setExtractRCMode -engine postRoute -effortLevel low
catch { extractRC }
file mkdir ./power_signoff/perL
set PS /project/verif/users/marianajjar/ws/spline_3_1_rerun/power_sim
foreach L {2 3 4 5} {
  set_power_analysis_mode -reset
  set_power_analysis_mode -method static -analysis_view SlowView -honor_negative_energy true -ignore_control_signals true
  read_activity_file -reset
  if {[catch { read_activity_file -format VCD $PS/vcd_L${L}.vcd -scope tb_top_interpolator_dac/DUT -block I0 } e]} {
     puts "PERL L=$L read_activity FAILED: $e"
  }
  report_power -instances I0 -outfile ./power_signoff/perL/core_I0_L${L}.rpt
  puts "PERL L=$L power reported"
}
puts "PERL_POWER_DONE"
exit
