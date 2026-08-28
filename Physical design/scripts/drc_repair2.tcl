restoreDesign ../dataout/design_saves/top_repaired.dat top
setAnalysisMode -analysisType onChipVariation
verifyGeometry -report vg_pre.rpt
# collect all nets named in SHORT/SPACING violations
set fp [open vg_pre.rpt r]; set nets {}
while {[gets $fp line] >= 0} {
  if {[regexp {(SHORT|SPACING)} $line]} {
    foreach {full n} [regexp -all -inline {Net (\S+)} $line] { lappend nets $n }
  }
}
close $fp
set nets [lsort -unique $nets]
puts "DRCREPAIR: [llength $nets] shorting nets to rip+reroute"
foreach n $nets { catch { editDelete -net $n -type Regular } }
setNanoRouteMode -drouteFixAntenna false -routeWithTimingDriven false
ecoRoute
ecoRoute -fix_drc
ecoRoute -fix_drc
verifyGeometry -report vg_repaired.rpt
verifyConnectivity -type all -error 100 -report vc_repaired.rpt
saveDesign ../dataout/design_saves/top_repaired2
puts "DRC_REPAIR_DONE"
exit
