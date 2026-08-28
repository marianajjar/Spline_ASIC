# ============================================================
# Larger symmetric floorplan
# ============================================================

setFPlanMode -snapPlaceBlockageGrid manufacturing
setFPlanMode -snapDieGrid manufacturing
setFPlanMode -snapCoreGrid manufacturing

floorPlan -site core -b \
    0.0 0.0 1000.0 950.0 \
    137.0 137.0 863.0 813.0 \
    177.0 177.0 823.0 773.0

checkFPlan

# ============================================================
# Add I/O filler cells
# ============================================================

set io_filler_cells \
    [get_db [get_db base_cells -if {.class == pad_spacer}] .name]

addIoFiller -cell $io_filler_cells -prefix IO_FILLER_N -side n
addIoFiller -cell $io_filler_cells -prefix IO_FILLER_S -side s
addIoFiller -cell $io_filler_cells -prefix IO_FILLER_W -side w
addIoFiller -cell $io_filler_cells -prefix IO_FILLER_E -side e

checkFPlan

saveDesign ../dataout/design_saves/top_floorplan
