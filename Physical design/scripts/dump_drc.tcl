restoreDesign top_final_final.dat top
catch { loadDrcErrorFile /project/verif/users/marianajjar/ws/spline_3_1_rerun/virtuoso_fixed/top_final_final.drc.results } e1
puts "loadDRC: $e1"
fit
catch { gui_fit } 
gui_dump_picture /project/verif/users/marianajjar/ws/spline_3_1_rerun/virtuoso_fixed/ff_layout.png -format PNG -width 1920 -height 1080
puts "DUMP_DONE"
exit
