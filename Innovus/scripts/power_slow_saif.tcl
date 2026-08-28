# =============================================================================
# SLOW-CORNER SAIF POWER ANALYSIS
# L = 2, 3, 4, 5
#
# Expected repository location:
#   Innovus/scripts/power_slow_saif.tcl
#
# SAIF input:
#   Innovus/datain/saif/core_sf_L2.saif
#   Innovus/datain/saif/core_sf_L3.saif
#   Innovus/datain/saif/core_sf_L4.saif
#   Innovus/datain/saif/core_sf_L5.saif
#
# Output:
#   Innovus/work/power_signoff/slowRC_saif/
# =============================================================================

# -----------------------------------------------------------------------------
# Resolve all paths relative to this TCL script.
# -----------------------------------------------------------------------------
set script_dir  [file dirname [file normalize [info script]]]
set innovus_dir [file normalize [file join $script_dir ".."]]

set design_db   [file join $innovus_dir "dataout" "design_saves" "top_signoff.dat"]
set saif_dir    [file join $innovus_dir "datain" "saif"]

set power_root  [file join $innovus_dir "work" "power_signoff"]
set slow_dir    [file join $power_root "slowRC_saif"]

set L_values {2 3 4 5}

file mkdir $power_root
file mkdir $slow_dir

puts "Innovus directory : $innovus_dir"
puts "SAIF directory    : $saif_dir"
puts "Design database   : $design_db"
puts "Output directory  : $slow_dir"

# =============================================================================
# Restore final signoff design
# =============================================================================
if {![file exists $design_db]} {
    error "Missing design database: $design_db"
}

restoreDesign $design_db top

set_analysis_view \
    -setup {SlowView} \
    -hold  {FastView}

setExtractRCMode -engine postRoute -effortLevel low

if {[catch {extractRC} extract_err]} {
    error "SLOW extractRC failed: $extract_err"
}

# =============================================================================
# Check SAIF files
# =============================================================================
foreach L $L_values {
    set saif_file [file join $saif_dir "core_sf_L${L}.saif"]

    if {![file exists $saif_file]} {
        error "Missing SAIF file for L=$L: $saif_file"
    }

    if {[file size $saif_file] == 0} {
        error "Empty SAIF file for L=$L: $saif_file"
    }
}

# =============================================================================
# Run SlowView power for each interpolation factor
# =============================================================================
foreach L $L_values {

    # Match the real clock used by each operating mode.
    if {$L == 2 || $L == 4} {
        set period 1.041666667
    } else {
        set period 1.111111111
    }

    set saif_file   [file join $saif_dir "core_sf_L${L}.saif"]
    set report_file [file join $slow_dir "core_I0_L${L}.rpt"]

    puts ""
    puts "------------------------------------------------------------"
    puts "SLOW SAIF POWER FOR L=$L"
    puts "Clock period : $period ns"
    puts "SAIF file    : $saif_file"
    puts "------------------------------------------------------------"

    set_power_analysis_mode -reset
    read_activity_file -reset
    catch {set_power -reset}
    catch {set_dynamic_power_simulation -reset}

    # Defaults are used only for signals not annotated by the SAIF.
    set_default_switching_activity -reset
    set_default_switching_activity \
        -input_activity 0.2 \
        -period $period \
        -seq_activity 0.2

    set_power_analysis_mode \
        -method static \
        -analysis_view SlowView \
        -honor_negative_energy true \
        -ignore_control_signals true

    if {[catch {
        read_activity_file \
            -format SAIF \
            $saif_file \
            -scope tb_top_interpolator_dac/DUT \
            -block I0
    } activity_err]} {
        error "SLOW L=$L SAIF read failed: $activity_err"
    }

    report_power \
        -instances I0 \
        -outfile $report_file

    puts "Created: $report_file"
}

puts ""
puts "============================================================"
puts "SLOW SAIF POWER ANALYSIS COMPLETED"
puts "Reports:"
puts "  $slow_dir"
puts "============================================================"

exit
