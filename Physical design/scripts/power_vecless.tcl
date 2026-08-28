restoreDesign ../dataout/design_saves/top_signoff.dat top
setExtractRCMode -engine postRoute -effortLevel low
catch { extractRC }
set_analysis_view -setup {SlowView} -hold {FastView}
set_power_analysis_mode -reset
set_power_analysis_mode -method static -analysis_view SlowView
read_activity_file -reset
set_default_switching_activity -reset
set_default_switching_activity -input_activity 0.2 -period 1.041666 -seq_activity 0.2
report_power -instances I0 -outfile power_vecless_02.rpt
puts "VECLESS_DONE"
exit
