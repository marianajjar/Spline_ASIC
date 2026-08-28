# CTS
set_interactive_constraint_modes [all_constraint_modes -active]

create_ccopt_clock_tree_spec -file ccopt.spec
source ccopt.spec

ccopt_design

set_propagated_clock [all_clocks]

update_io_latency -verbose

saveDesign ../dataout/design_saves/top_cts


# Post CTS Optimizations
setRouteMode \
    -earlyGlobalHonorMsvRouteConstraint false \
    -earlyGlobalRoutePartitionPinGuide true

setEndCapMode -reset
setEndCapMode -boundary_tap false

setUsefulSkewMode \
    -noBoundary false \
    -maxAllowedDelay 1

setTieHiLoMode -reset
setTieHiLoMode \
    -cell {{TIELHVT TIEHHVT}} \
    -maxDistance 10 \
    -maxFanOut 4 \
    -honorDontTouch false \
    -createHierPort false

setRouteMode \
    -earlyGlobalHonorMsvRouteConstraint false \
    -earlyGlobalRoutePartitionPinGuide true

setEndCapMode -reset
setEndCapMode -boundary_tap false

setUsefulSkewMode \
    -noBoundary false \
    -maxAllowedDelay 1

setTieHiLoMode -reset
setTieHiLoMode \
    -cell {{TIELHVT TIEHHVT}} \
    -maxDistance 10 \
    -maxFanOut 4 \
    -honorDontTouch false \
    -createHierPort false

setOptMode \
    -fixCap true \
    -fixTran true \
    -fixFanoutLoad true

optDesign -postCTS

saveDesign ../dataout/design_saves/top_cts_opt
