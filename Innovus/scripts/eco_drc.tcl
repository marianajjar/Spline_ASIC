restoreDesign ../dataout/design_saves/top_eco_setup.dat top
setVerifyGeometryMode -area {0 0 0 0}
verifyGeometry -report ./top_eco_setup.geom.rpt
verifyConnectivity -type all -report ./top_eco_setup.conn.rpt
puts "ECO_DRC_DONE"
exit
