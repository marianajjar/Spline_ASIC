restoreDesign top_final_final.dat top
set fp [open /project/verif/users/marianajjar/ws/spline_3_1_rerun/virtuoso_fixed/cell_check.rpt w]
foreach inst {I0/fir_I_u/FE_PHC15020_N42 I0/fir_I_u/FE_PHC10195_N35 I0/fir_I_u/FE_PHC9564_N35 I0/fir_Q_u/FE_PHC9585_N35} {
  set i [dbGetInstByName top $inst]
  if {$i=="0x0"||$i==""} { puts $fp "$inst : NOT FOUND"; continue }
  set cell [dbGet -e $i.cell.name]
  set base [dbGet -e $i.baseCell.name]
  puts $fp [format "%-38s cell=%s baseCell=%s" $inst $cell $base]
}
close $fp
puts "CELLCHECK_DONE"
exit
