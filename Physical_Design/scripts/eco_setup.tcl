restoreDesign ../dataout/design_saves/top_signoff.dat top
setAnalysisMode -analysisType onChipVariation -cppr both
setExtractRCMode -engine postRoute -effortLevel low
extractRC
setOptMode -setupTargetSlack 0.07 -holdTargetSlack 0.02 -fixFanoutLoad true
optDesign -postRoute -setup -incr
ecoRoute
reset_parasitics
extractRC
rcOut -rc_corner SlowRC -spef ../dataout/eco/top_slow.SPEF
rcOut -rc_corner FastRC -spef ../dataout/eco/top_fast.SPEF
saveNetlist top_post_layout.v -excludeLeafCell
saveDesign ../dataout/design_saves/top_signoff
verifyConnectivity -type regular
timeDesign -postRoute -prefix eco -outDir timingReports_eco
puts "ECO_SETUP_DONE"
exit
