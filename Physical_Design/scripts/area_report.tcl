restoreDesign ../dataout/design_saves/top_signoff.dat top
setDesignMode -process 65
# ---- area / utilization / gate count ----
set fp [open area_util.rpt w]
set die  [dbGet top.fPlan.box]
set core [dbGet top.fPlan.coreBox]
puts $fp "DIE_BOX  $die"
puts $fp "CORE_BOX $core"
set corearea [dbGet top.fPlan.coreBox_area]
puts $fp "CORE_AREA_um2 $corearea"
# std cell area of I0 core
set I0 [dbGetInstByName I0]
puts $fp "CORE_UTIL [dbGet top.fPlan.coreUtil]"
puts $fp "DENSITY   [dbGet top.fPlan.density]"
close $fp
summaryReport -noHtml -outfile summary_area.rpt
catch { reportGateCount -level 2 -outfile gatecount.rpt }
puts "AREA_REPORT_DONE"
# ---- list the analysis views available (for the power corner) ----
puts "VIEWS_SETUP: [all_setup_analysis_views]"
puts "VIEWS_HOLD:  [all_hold_analysis_views]"
exit
