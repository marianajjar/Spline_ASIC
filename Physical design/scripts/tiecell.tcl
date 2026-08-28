# ============================================================================
# tiecell.tcl
# Insert tie-high / tie-low cells for floating logic constants.
# TSMC65 LP -- HVT tie cells only (LVT pack has no tie cells in this kit).
# Tie cells are static, don't toggle, so HVT-only is fine everywhere.
# ============================================================================

# ---------------------------------------------------------------------------
# Diagnostic: print tie cells + their output pin names.
# Uses lib_pins (correct for lib_cells) and .direction==output (full word).
# ---------------------------------------------------------------------------
puts "===== Available TIE cells in linked libraries ====="
foreach c [get_db lib_cells *TIE*HVT*] {
    set cn   [get_db $c .base_name]
    set outp [get_db [get_db lib_pins -of $c -if {.direction==output}] .name]
    puts "  $cn   output pin = $outp"
}
puts "==================================================="

# ---------------------------------------------------------------------------
# Tie-cell pair (HVT only)
# Try first WITHOUT explicit pin -- Innovus auto-detects from .lib function.
# If that gives IMPSP-5130, edit to add /<pin> after each name.
# ---------------------------------------------------------------------------
if { [is_common_ui_mode]==1 } {
    set_db add_tieoffs_cells {TIELHVT TIEHHVT}
} else {
    setTieHiLoMode -cell {TIELHVT TIEHHVT}
}

# --- If IMPSP-5130 returns, comment the block above and use this instead, --
# --- replacing <PIN> with whatever the diagnostic prints (usually Z): ------
# if { [is_common_ui_mode]==1 } {
#     set_db add_tieoffs_cells {TIELHVT/Z TIEHHVT/Z}
# } else {
#     setTieHiLoMode -cell {TIELHVT/Z TIEHHVT/Z}
# }

# ---------------------------------------------------------------------------
# Insertion controls
# ---------------------------------------------------------------------------
if { [is_common_ui_mode]==1 } {
    set_db add_tieoffs_max_fanout 4
} else {
    setTieHiLoMode -maxFanout 4
}

if { [is_common_ui_mode]==1 } {
    set_db add_tieoffs_max_distance 10
} else {
    setTieHiLoMode -maxDistance 10
}

if { [is_common_ui_mode]==1 } {
    set_db add_tieoffs_prefix TIEOFF
} else {
    setTieHiLoMode -prefix TIEOFF
}

# ---------------------------------------------------------------------------
# Run insertion
# ---------------------------------------------------------------------------
if { [is_common_ui_mode]==1 } {
    add_tieoffs
} else {
    addTieHiLo
}

# ---------------------------------------------------------------------------
# Post-insertion check
# ---------------------------------------------------------------------------
puts "===== Inserted TIE instances ====="
set tie_insts [get_db insts TIEOFF*]
puts "  count = [llength $tie_insts]"
puts "=================================="
