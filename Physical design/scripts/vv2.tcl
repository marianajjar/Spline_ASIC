restoreDesign top_final_final.dat top
set fp [open /project/verif/users/marianajjar/ws/spline_3_1_rerun/virtuoso_fixed/vddvss_points.txt w]
foreach net {VDD VSS} {
  set out "$net FAIL"
  set n [dbGetNetByName top $net]
  if {$n ne "" && $n ne "0x0"} {
    foreach sw [dbGet -p -e $n.sWires] {
      if {[dbGet -e $sw.layer.name] ne "M2"} { continue }
      set b [dbGet -e $sw.box]
      set nums {}
      foreach tok [split [string map {\{ " " \} " "} $b] " "] {
        if {[string is double -strict $tok]} { lappend nums $tok }
      }
      if {[llength $nums] >= 4} {
        set cx [expr {([lindex $nums 0]+[lindex $nums 2])/2.0}]
        set cy [expr {([lindex $nums 1]+[lindex $nums 3])/2.0}]
        set out "$net $cx $cy"
        break
      }
    }
  }
  puts $fp $out
}
close $fp
puts "VV2_DONE"
exit
