# ============================================================
# Add decap cells
# ============================================================

addFiller \
    -cell {DCAP64 DCAP32 DCAP16 DCAP8 DCAP4} \
    -prefix DCAP_FILL \
    -area {172.4575 273.709 786.781 644.7665}

# ============================================================
# Add standard-cell fillers
# ============================================================

addFiller \
    -cell {FILL64HVT FILL32HVT FILL16HVT FILL2HVT FILL1HVT} \
    -prefix STD_FILL \
    -doDRC

# Fillers are being inserted after routing
ecoRoute -target

# ============================================================
# Final verification
# ============================================================

verifyGeometry
verifyConnectivity -type all

saveDesign ../dataout/design_saves/top_with_fillers

# ============================================================
# Write GDS
# ============================================================

streamOut ../dataout/top.gds \
    -mapFile /project/verif/users/marianajjar/ws/spline_3_1_rerun/innovus/work/gds2.map \
    -libName DesignLib \
    -merge { \
        /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/gds/tcbn65lp_200a/tcbn65lp.gds \
        /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/gds/tcbn65lphvt_200a/tcbn65lphvt.gds \
        /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/gds/tcbn65lplvt_200a/tcbn65lplvt.gds \
        /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/gds/tpdn65lpnv2od3_140b/mt_2/9lm/tpdn65lpnv2od3.gds \
    } \
    -units 1000 \
    -mode ALL

saveDesign ../dataout/design_saves/top_signoff

# ============================================================
# Write SPEF
# ============================================================

file mkdir ../dataout/eco

reset_parasitics
extractRC
rcOut \
    -rc_corner SlowRC \
    -spef ../dataout/eco/top_slow.SPEF

reset_parasitics
extractRC
rcOut \
    -rc_corner FastRC \
    -spef ../dataout/eco/top_fast.SPEF
