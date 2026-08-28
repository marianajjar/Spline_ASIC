restoreDesign top_final_final.dat top
set excluded_physical_cells [concat \
    [get_db [get_db base_cells -if {.class == pad_spacer}] .name] \
    [get_db [get_db base_cells -if {.name == *FILL*}] .name] \
    [get_db [get_db base_cells -if {.name == *DCAP*}] .name]]
streamOut /project/verif/users/marianajjar/ws/spline_3_1_rerun/virtuoso_fixed/top_eco_fixed.gds \
    -mapFile gds2.map -libName DesignLib \
    -merge { \
        /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/gds/tcbn65lp_200a/tcbn65lp.gds \
        /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/gds/tcbn65lphvt_200a/tcbn65lphvt.gds \
        /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/gds/tcbn65lplvt_200a/tcbn65lplvt.gds \
        /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/gds/tpdn65lpnv2od3_140b/mt_2/9lm/tpdn65lpnv2od3.gds \
    } -units 1000 -mode ALL
saveNetlist /project/verif/users/marianajjar/ws/spline_3_1_rerun/virtuoso_fixed/top_eco_fixed_pwr.v -phys -excludeLeafCell -excludeCellInst $excluded_physical_cells
puts "ECO_STREAM_DONE"
exit
