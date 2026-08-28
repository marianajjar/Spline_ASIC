#=========================================================
# CTS
#=========================================================

set_interactive_constraint_modes [all_constraint_modes -active]

create_ccopt_clock_tree_spec -file ccopt.spec
source ccopt.spec

ccopt_design -cts

set_propagated_clock [all_clocks]

timeDesign \
    -postCTS \
    -pathReports \
    -drvReports \
    -slackReports \
    -numPaths 50 \
    -prefix top_postCTS \
    -outDir timingReports

saveDesign ../dataout/design_saves/top_cts


#=========================================================
# Post-CTS Optimization
#=========================================================

setRouteMode \
    -earlyGlobalHonorMsvRouteConstraint false \
    -earlyGlobalRoutePartitionPinGuide true

setEndCapMode -reset
setEndCapMode -boundary_tap false

# Disable useful-skew optimization.
# This avoids excessive skew-buffer insertion.
set_db opt_skew false

# Keep tie-cell settings available in case optimization
# creates new constant connections.
setTieHiLoMode -reset
setTieHiLoMode \
    -cell {TIELHVT TIEHHVT} \
    -maxDistance 10 \
    -maxFanOut 4 \
    -honorDontTouch false

optDesign -postCTS

timeDesign \
    -postCTS \
    -pathReports \
    -drvReports \
    -slackReports \
    -numPaths 50 \
    -prefix top_postCTS_opt \
    -outDir timingReports

saveDesign ../dataout/design_saves/top_cts_opt
