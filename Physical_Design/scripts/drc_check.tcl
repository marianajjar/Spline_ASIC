foreach dat {top_signoff top_repaired2} {
  restoreDesign ../dataout/design_saves/${dat}.dat top
  setVerifyGeometryMode -area {0 0 0 0}
  verifyGeometry -report ./${dat}_geom.rpt
  puts "==DRC== $dat : [dbGet top.markers.subType]"
}
puts "DRC_CHECK_DONE"
exit
