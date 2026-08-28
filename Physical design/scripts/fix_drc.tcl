restoreDesign ../dataout/design_saves/top_signoff.dat top
setAnalysisMode -analysisType onChipVariation
# ---- diagnose BEFORE ----
verifyConnectivity -type all -error 200 -report vc_before.rpt
verifyGeometry -report vg_before.rpt
puts "==BEFORE== shorts+DRC reported"
# ---- remove DCAP fillers (M1-short culprit) + any leftover fill ----
catch { deleteFiller -cell {DCAP64 DCAP32 DCAP16 DCAP8 DCAP4} }
catch { deleteFiller -prefix DCAP_FILL }
catch { deleteFiller -prefix STD_FILL }
# ---- repair routing DRCs ----
setNanoRouteMode -drouteAutoStop false
ecoRoute -fix_drc
ecoRoute -fix_drc
# ---- re-add standard fillers ONLY (no DCAP) with DRC ----
addFiller -cell {FILL64HVT FILL32HVT FILL16HVT FILL2HVT FILL1HVT} -prefix STD_FILL -doDRC
ecoRoute -fix_drc
# ---- verify AFTER ----
verifyGeometry -report vg_after.rpt
verifyConnectivity -type all -error 200 -report vc_after.rpt
saveDesign ../dataout/design_saves/top_clean
puts "FIX_DRC_DONE"
exit
