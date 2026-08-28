restoreDesign ../dataout/design_saves/top_signoff.dat top
create_delay_corner -name TypDC -library_set {Typ} -rc_corner {FastRC}
create_analysis_view -name TypView -constraint_mode {TypCM} -delay_corner {TypDC}
set_analysis_view -setup {TypView} -hold {TypView}
setExtractRCMode -engine postRoute -effortLevel low
catch { extractRC }
file mkdir ./power_signoff/perL_typ
set PS /project/verif/users/marianajjar/ws/spline_3_1_rerun/power_sim
puts "GATECOUNT I0_insts=[llength [dbGet -p2 top.insts.name I0/* ]]"
foreach L {2 3 4 5} {
  set_power_analysis_mode -reset
  set_power_analysis_mode -method static -analysis_view TypView -honor_negative_energy true
  read_activity_file -reset
  catch { read_activity_file -format SAIF $PS/core_sf_L${L}.saif -scope tb_top_interpolator_dac/DUT -block I0 }
  report_power -instances I0 -outfile ./power_signoff/perL_typ/core_I0_L${L}.rpt
  puts "TYP L=$L done"
}
puts "POWER_TYP_DONE"
exit
