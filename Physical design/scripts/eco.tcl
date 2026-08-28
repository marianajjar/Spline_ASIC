restoreDesign ../dataout/design_saves/top_repaired2.dat top
set_analysis_view -setup {SlowView} -hold {FastView}
setExtractRCMode -engine postRoute -effortLevel low
catch { extractRC }
timeDesign -postRoute -setup -outDir ./eco_pre_reports
# setup-only ECO, no hold degradation
setOptMode -fixCap true -fixTran true -fixFanoutLoad false
optDesign -postRoute -setup -incr -outDir ./eco_opt_reports
# reroute the ECO nets
setNanoRouteMode -routeWithTimingDriven true
ecoRoute
extractRC
timeDesign -postRoute -setup -outDir ./eco_post_reports
saveDesign ../dataout/design_saves/top_eco_setup.dat
puts "ECO_DONE"
exit
