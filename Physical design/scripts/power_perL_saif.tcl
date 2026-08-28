restoreDesign ../dataout/design_saves/top_signoff.dat top
catch { set_analysis_view -setup SlowView -hold FastView }
setExtractRCMode -engine postRoute -effortLevel low
catch { extractRC }
file mkdir ./power_signoff/perL_saif
set PS /project/verif/users/marianajjar/ws/spline_3_1_rerun/power_sim
foreach L {2 3 4 5} {
  set_power_analysis_mode -reset
  set_power_analysis_mode -method static -analysis_view SlowView -honor_negative_energy true -ignore_control_signals true
  read_activity_file -reset
  if {[catch { read_activity_file -format SAIF $PS/core_L${L}.saif -scope tb_top_interpolator_dac/DUT -block I0 } e]} { puts "L=$L SAIF read err: $e" }
  report_power -instances I0 -outfile ./power_signoff/perL_saif/core_I0_L${L}.rpt
  puts "SAIF L=$L reported"
}
puts "PERL_SAIF_DONE"
exit
