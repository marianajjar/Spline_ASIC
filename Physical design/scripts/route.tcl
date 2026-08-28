# ============================================================
# Special route: connect VDD/VSS pads, rings, stripes, and rails
# ============================================================

setSrouteMode -viaConnectToShape {ring stripe followpin}

sroute \
    -nets {VDD VSS} \
    -connect {padPin corePin floatingStripe} \
    -padPinTarget {nearestTarget} \
    -corePinTarget {firstAfterRowEnd} \
    -floatingStripeTarget {ring stripe followpin} \
    -allowJogging 1 \
    -allowLayerChange 1 \
    -layerChangeRange {M1(1) M7(7)} \
    -crossoverViaLayerRange {M1(1) M7(7)} \
    -targetViaLayerRange {M1(1) M7(7)}

verifyConnectivity -type special


# ============================================================
# Signal routing
# ============================================================

setAnalysisMode -analysisType onChipVariation -cppr both

setRouteMode \
    -earlyGlobalHonorMsvRouteConstraint false \
    -earlyGlobalRoutePartitionPinGuide true

setEndCapMode -reset
setEndCapMode -boundary_tap false

# Keep useful-skew optimization disabled
set_db opt_skew false

setTieHiLoMode -reset
setTieHiLoMode \
    -cell {TIELHVT TIEHHVT} \
    -maxDistance 10 \
    -maxFanOut 4 \
    -honorDontTouch false \
    -createHierPort false

setNanoRouteMode -quiet -drouteFixAntenna true
setNanoRouteMode -quiet -droutePostRouteLithoRepair true
setNanoRouteMode -quiet -droutePostRouteSwapVia multiCut
setNanoRouteMode -quiet -droutePostRouteWidenWire widen
setNanoRouteMode -quiet -drouteUseMultiCutViaEffort high
setNanoRouteMode -quiet -routeInsertAntennaDiode true
setNanoRouteMode -quiet -routeWithLithoDriven true
setNanoRouteMode -quiet -routeWithSiDriven true
setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -quiet -routeWithEco 0
setNanoRouteMode -quiet -drouteAutoStop 0
setNanoRouteMode -quiet -routeSelectedNetOnly 0
setNanoRouteMode -quiet -routeTopRoutingLayer 7
setNanoRouteMode -quiet -routeBottomRoutingLayer 1
setNanoRouteMode -quiet -drouteEndIteration 1

routeDesign -globalDetail -viaOpt -wireOpt

verifyGeometry
verifyConnectivity -type all

saveDesign ../dataout/design_saves/top_route


# ============================================================
# Post-route optimization
# ============================================================

setRouteMode \
    -earlyGlobalHonorMsvRouteConstraint false \
    -earlyGlobalRoutePartitionPinGuide true

setEndCapMode -reset
setEndCapMode -boundary_tap false

set_db opt_skew false

setTieHiLoMode -reset
setTieHiLoMode \
    -cell {TIELHVT TIEHHVT} \
    -maxDistance 10 \
    -maxFanOut 4 \
    -honorDontTouch false \
    -createHierPort false

setOptMode \
    -fixCap true \
    -fixTran true \
    -fixFanoutLoad true

optDesign -hold -postRoute
optDesign -setup -postRoute


# ============================================================
# Post-route timing before DRC repair
# ============================================================

timeDesign \
    -postRoute \
    -pathReports \
    -drvReports \
    -slackReports \
    -numPaths 50 \
    -prefix top_postRoute_setup \
    -outDir timingReports

timeDesign \
    -postRoute \
    -hold \
    -pathReports \
    -slackReports \
    -numPaths 50 \
    -prefix top_postRoute_hold \
    -outDir timingReports


# ============================================================
# Fix remaining routing DRC violations
# ============================================================

ecoRoute -fix_drc

verifyGeometry
verifyConnectivity -type all


# ============================================================
# Final timing after ECO routing
# ============================================================

timeDesign \
    -postRoute \
    -pathReports \
    -drvReports \
    -slackReports \
    -numPaths 50 \
    -prefix top_postRoute_final_setup \
    -outDir timingReports

timeDesign \
    -postRoute \
    -hold \
    -pathReports \
    -slackReports \
    -numPaths 50 \
    -prefix top_postRoute_final_hold \
    -outDir timingReports

saveDesign ../dataout/design_saves/top_route_opt


# ============================================================
# Save post-layout netlists
# ============================================================

set excluded_physical_cells [concat \
    [get_db [get_db base_cells -if {.class == pad_spacer}] .name] \
    [get_db [get_db base_cells -if {.name == *FILL*}] .name] \
    [get_db [get_db base_cells -if {.name == *DCAP*}] .name]]

saveNetlist top_post_layout.v \
    -excludeLeafCell \
    -excludeCellInst $excluded_physical_cells

saveNetlist top_post_layout_pwr.v \
    -phys \
    -excludeLeafCell \
    -excludeCellInst $excluded_physical_cells
