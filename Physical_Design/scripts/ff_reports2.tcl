restoreDesign top_final_final.dat top
set RD /project/verif/users/marianajjar/ws/spline_3_1_rerun/innovus/final_final_reports
file mkdir $RD
# ---------- AREA (dbGet keys that work) ----------
set fp [open $RD/area_density.rpt w]
puts $fp "===== top_final_final : AREA ====="
puts $fp "Die box         : [dbGet top.fPlan.box]"
puts $fp "Core box        : [dbGet top.fPlan.coreBox]"
puts $fp "Core area (um^2) : [dbGet top.fPlan.coreBox_area]"
catch { puts $fp "Std-cell inst count : [llength [dbGet top.insts.name -e]]" }
close $fp
# ---------- DENSITY (before fillers) via summaryReport + reportDensity ----------
catch { summaryReport -noHtml -outfile $RD/summary.rpt } e1
catch { redirect $RD/density_before_fill.rpt { reportDensity } } e2
catch { redirect $RD/gatecount.rpt { reportGateCount -level 2 } } e3
# ---------- CTS / clock tree ----------
catch { report_ccopt_clock_trees -summary -file $RD/cts_summary.rpt } e4
catch { redirect $RD/clocktree.rpt { reportClockTree -postRoute } } e5
# ---------- POST-ROUTE timing ----------
setAnalysisMode -analysisType onChipVariation
setExtractRCMode -engine postRoute -effortLevel low
catch { extractRC }
catch { timeDesign -postRoute -setup -outDir $RD/postroute_setup -prefix ff } e6
catch { timeDesign -postRoute -hold  -outDir $RD/postroute_hold  -prefix ff } e7
puts "ERR: $e1 | $e2 | $e4 | $e6"
puts "FF_REPORTS2_DONE"
exit
