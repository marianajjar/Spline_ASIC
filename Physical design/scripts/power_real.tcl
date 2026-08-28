restoreDesign ../dataout/design_saves/top_signoff.dat top
setExtractRCMode -engine postRoute -effortLevel low
catch { extractRC }
set_analysis_view -setup {SlowView} -hold {FastView}
file mkdir ./power_signoff/perL_real
set PS /project/verif/users/marianajjar/ws/spline_3_1_rerun/power_sim
foreach L {2 3 4 5} {
  set_power_analysis_mode -reset
  set_power_analysis_mode -method static -analysis_view SlowView -honor_negative_energy true
  read_activity_file -reset
  catch { read_activity_file -format SAIF $PS/core_real_L${L}.saif -scope tb_top_interpolator_dac/DUT -block I0 }
  report_power -instances I0 -outfile ./power_signoff/perL_real/core_I0_L${L}.rpt
  puts "REAL L=$L done"
}
puts "POWER_REAL_DONE"
exit
