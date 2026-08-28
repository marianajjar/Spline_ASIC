# ------------------------------------------------------------
# PGV / .cl libraries must match the MMMC timing corner.
# For SlowView / worst corner, use wc_dv.cl, not wc0d9_dv.cl.
# ------------------------------------------------------------

set LP_PGV  /tech/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/voltage_storm/tcbn65lp_200b/tcbn65lp_9lmT2_wc_dv.cl
set LVT_PGV /tech/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/voltage_storm/tcbn65lplvt_200b/tcbn65lplvt_9lmT2_wc_dv.cl
set HVT_PGV /tech/tsmc/65LP/dig_libs/TSMCHOME/digital/Back_End/voltage_storm/tcbn65lphvt_200b/tcbn65lphvt_9lmT2_wc_dv.cl

# ------------------------------------------------------------
# Make sure VDD/VSS are logically connected to std-cell PG pins
# ------------------------------------------------------------

globalNetConnect VDD -type pgpin -pin VDD -all
globalNetConnect VSS -type pgpin -pin VSS -all
globalNetConnect VDD -type tiehi -all
globalNetConnect VSS -type tielo -all
applyGlobalNets

verifyConnectivity -type special

# ------------------------------------------------------------
# Rail setup
# ------------------------------------------------------------

set_rail_analysis_mode \
    -method static \
    -accuracy hd \
    -analysis_view SlowView \
    -power_grid_library [list $LP_PGV $LVT_PGV $HVT_PGV] \
    -enable_rlrp_analysis true \
    -verbosity true \
    -temperature 125

set_pg_nets -net VDD -voltage 1.2 -threshold 1.1
set_pg_nets -net VSS -voltage 0.0 -threshold 0.1

set_rail_analysis_domain -name PD_Digital \
    -pwrnets VDD \
    -gndnets VSS \
    -threshold 0.10

set_power_pads -reset

set_power_pads \
    -net VDD \
    -format xy \
    -file ./vddtop.pp

set_power_pads \
    -net VSS \
    -format xy \
    -file ./vsstop.pp

set_power_data -reset

set_power_data \
    -format current [list \
        ./power_signoff/slowRC/static_VDD.ptiavg \
        ./power_signoff/slowRC/static_VSS.ptiavg \
    ]

analyze_rail \
    -results_directory ./power_signoff/ \
    -type domain \
    PD_Digital


set_power_rail_display -plot none
read_power_rail_results -reset

set rail_dirs [glob -nocomplain ./power_signoff/PD_Digital_125C_avg_*]

if {[llength $rail_dirs] == 0} {
    puts "ERROR: no rail result directory found"
} else {
    set rail_dir [lindex [lsort -dictionary $rail_dirs] end]
    puts "Reading rail results from $rail_dir"

    read_power_rail_results \
        -power_db ./power_signoff/power_mode1.db \
        -rail_directory $rail_dir

    set_power_rail_display -plot ir
}
