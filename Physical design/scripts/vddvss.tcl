restoreDesign top_final_final.dat top
set fp [open /project/verif/users/marianajjar/ws/spline_3_1_rerun/virtuoso_fixed/vddvss_points.txt w]
foreach net {VDD VSS} {
  set n [dbGetNetByName top $net]
  set out "$net FAIL"
  foreach sw [dbGet -p -e $n.sWires] {
    set lyn [dbGet -e $sw.layer.name]
    if {$lyn eq "M2"} {
      set b [dbGet -e $sw.box]
      set flat [join $b]
      if {[llength $flat] >= 4} {
        set cx [expr {([lindex $flat 0]+[lindex $flat 2])/2.0}]
        set cy [expr {([lindex $flat 1]+[lindex $flat 3])/2.0}]
        set out "$net $cx $cy M2"
        break
      }
    }
  }
  puts $fp $out
}
close $fp
puts "VDDVSS_DONE"
exit
