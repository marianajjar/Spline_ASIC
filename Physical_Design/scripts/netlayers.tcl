restoreDesign top_final_final.dat top
set fp [open /project/verif/users/marianajjar/ws/spline_3_1_rerun/virtuoso_fixed/net_layers.rpt w]
puts $fp "=== top_final_final : power/ground net routing layers ==="
foreach net {VDD VSS VDDPST VSSPST POC} {
  set n [dbGetNetByName top $net]
  if {$n=="0x0"||$n==""} { puts $fp [format "%-10s : (no net)" $net]; continue }
  set layers {}
  foreach coll [list [dbGet -e $n.sWires] [dbGet -e $n.wires]] {
    foreach s $coll { set l [dbGet -e $s.layer.name]; if {$l!="" && [lsearch $layers $l]<0} {lappend layers $l} }
  }
  puts $fp [format "%-10s : %s" $net [lsort $layers]]
}
# a signal port too (which layer the pad core-pin exposes)
foreach net {clk dac_I\[0\]} {
  set n [dbGetNetByName top $net]
  if {$n=="0x0"||$n==""} continue
  set layers {}
  foreach s [dbGet -e $n.wires] { set l [dbGet -e $s.layer.name]; if {$l!="" && [lsearch $layers $l]<0} {lappend layers $l} }
  puts $fp [format "%-10s : %s" $net [lsort $layers]]
}
close $fp
puts "NETLAYERS_DONE"
exit
