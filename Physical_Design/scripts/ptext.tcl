restoreDesign top_final_final.dat top
set fp [open /project/verif/users/marianajjar/ws/spline_3_1_rerun/virtuoso_fixed/power_text_points.txt w]
# VDD/VSS : center of a shape on M1
foreach net {VDD VSS} {
  set n [dbGetNetByName top $net]
  set done 0
  foreach sw [dbGet -e $n.sWires] {
    if {$done} break
    if {[dbGet -e $sw.layer.name]=="M1"} {
      set b [dbGet -e $sw.box]
      set cx [expr ([lindex $b 0]+[lindex $b 2])/2.0]
      set cy [expr ([lindex $b 1]+[lindex $b 3])/2.0]
      puts $fp "$net $cx $cy M1"
      set done 1
    }
  }
  if {!$done} { puts $fp "$net NOTFOUND_M1 - -" }
}
# VDDPST/VSSPST/POC : from pad instance pins
foreach net {VDDPST VSSPST POC} {
  set n [dbGetNetByName top $net]
  if {$n=="0x0"||$n==""} {
    # search pad instances for a pin on this net
    puts $fp "$net NOTOPNET - -"
    continue
  }
  set done 0
  foreach t [dbGet -e $n.instTerms] {
    if {$done} break
    set box [dbGet -e $t.pin.allShapes.shapes.box]
    if {$box!=""} {
      set b [lindex $box 0]
      set cx [expr ([lindex $b 0]+[lindex $b 2])/2.0]
      set cy [expr ([lindex $b 1]+[lindex $b 3])/2.0]
      set ly [dbGet -e $t.pin.allShapes.shapes.layer.name]
      puts $fp "$net $cx $cy [lindex $ly 0]"
      set done 1
    }
  }
  if {!$done} { puts $fp "$net NOPIN - -" }
}
close $fp
# also dump the GDS layer numbers for M1..M9 + AP from the map
puts "PTEXT_DONE"
exit
