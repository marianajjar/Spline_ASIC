restoreDesign top_final_final.dat top
set fp [open /project/verif/users/marianajjar/ws/spline_3_1_rerun/virtuoso_fixed/port_layers.rpt w]
puts $fp "=== top_final_final : top-level port pin layers ==="
foreach net {VDD VSS VDDPST VSSPST POC clk reset serial_in_I dac_I\[0\] dac_Q\[0\]} {
  set t [dbGetTermByName top $net]
  if {$t == "0x0" || $t == ""} { puts $fp [format "%-12s : (no term)" $net]; continue }
  set layers ""
  foreach pin [dbGet -e $t.pins] {
    foreach fig [dbGet -e $pin.allShapes.shapes] {
      set ly [dbGet -e $fig.layer.name]
      if {$ly != "" && [lsearch $layers $ly]<0} { lappend layers $ly }
    }
  }
  puts $fp [format "%-12s : %s" $net $layers]
}
close $fp
puts "PORTLAYERS_DONE"
exit
