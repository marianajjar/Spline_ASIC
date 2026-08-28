restoreDesign top_final_final.dat top
set RD /project/verif/users/marianajjar/ws/spline_3_1_rerun/innovus/final_final_reports
file mkdir $RD
# ---------- AREA / DENSITY (before fillers) ----------
set fp [open $RD/area_density.rpt w]
puts $fp "===== top_final_final : AREA / DENSITY ====="
puts $fp "Die box            : [dbGet top.fPlan.box]"
puts $fp "Core box           : [dbGet top.fPlan.coreBox]"
puts $fp "Core area (um^2)    : [dbGet top.fPlan.coreBox_area]"
puts $fp "Core utilization   : [dbGet top.fPlan.coreUtil]   (placement density = BEFORE fillers)"
puts $fp "Core density(total): [dbGet top.fPlan.density]"
# std-cell area excluding fillers
set stdarea 0.0 ; set fillarea 0.0
foreach_in_collection i [get_cells -hier -filter "is_physical_only==false"] { }
close $fp
catch { reportGateCount -level 1 -outfile $RD/gatecount.rpt }
catch { summaryReport -noHtml -outfile $RD/summary.rpt }
# explicit density-before-fill via reportDensity
catch { reportDensity > $RD/density_report.rpt }
# ---------- CTS / clock tree ----------
catch { report_ccopt_clock_trees -filename $RD/cts_ccopt.rpt }
catch { reportClockTree -postRoute -file $RD/clocktree.rpt }
catch { report_clocks > $RD/clocks.rpt }
# ---------- POST-ROUTE timing ----------
setAnalysisMode -analysisType onChipVariation
setExtractRCMode -engine postRoute -effortLevel low
catch { extractRC }
catch { timeDesign -postRoute -setup -outDir $RD/postroute_setup -prefix ff }
catch { timeDesign -postRoute -hold  -outDir $RD/postroute_hold  -prefix ff }
puts "FF_REPORTS_DONE"
exit
