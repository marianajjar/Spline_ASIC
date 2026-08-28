# Placement
setRouteMode -earlyGlobalHonorMsvRouteConstraint false -earlyGlobalRoutePartitionPinGuide true

setEndCapMode -reset
setEndCapMode -boundary_tap false

setNanoRouteMode -quiet -drouteAutoStop 0
setNanoRouteMode -quiet -drouteFixAntenna 0
setNanoRouteMode -quiet -droutePostRouteSwapVia {}
setNanoRouteMode -quiet -droutePostRouteSpreadWire 1
setNanoRouteMode -quiet -drouteUseMultiCutViaEffort {}
setNanoRouteMode -quiet -drouteOnGridOnly 0
setNanoRouteMode -quiet -routeIgnoreAntennaTopCellPin 0
setNanoRouteMode -quiet -timingEngine {}

setUsefulSkewMode -noBoundary false -maxAllowedDelay 1

setPlaceMode -reset

setPlaceMode \
    -congEffort high \
    -timingDriven 1 \
    -clkGateAware 1 \
    -powerDriven 1 \
    -ignoreScan 1 \
    -reorderScan 0 \
    -ignoreSpare 0 \
    -placeIOPins 0 \
    -moduleAwareSpare 0 \
    -maxDensity 0.5 \
    -preserveRouting 1 \
    -rmAffectedRouting 0 \
    -checkRoute 0 \
    -swapEEQ 0

setPlaceMode -fp false

place_design

checkFPlan -reportUtil

redirect -quiet {
    set honorDomain [getAnalysisMode -honorClockDomains]
} > /dev/null

timeDesign \
    -preCTS \
    -pathReports \
    -drvReports \
    -slackReports \
    -numPaths 50 \
    -prefix top_preCTS \
    -outDir timingReports

saveDesign ../dataout/design_saves/top_placement

# Post placement optimizations
setRouteMode -earlyGlobalHonorMsvRouteConstraint false -earlyGlobalRoutePartitionPinGuide true
setEndCapMode -reset
setEndCapMode -boundary_tap false
setUsefulSkewMode -noBoundary false -maxAllowedDelay 1
setOptMode -effort high -powerEffort high -leakageToDynamicRatio 1 -reclaimArea true -simplifyNetlist true -allEndPoints true -setupTargetSlack 0.5 -holdTargetSlack 0.5 -maxDensity 0.95 -drcMargin 0 -usefulSkew true
setOptMode -fixCap true -fixTran true -fixFanoutLoad true
optDesign -preCTS
saveDesign ../dataout/design_saves/top_placement_opt
