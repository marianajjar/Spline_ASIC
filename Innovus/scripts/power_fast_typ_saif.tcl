# =============================================================================
# FAST + TYPICAL SAIF POWER ANALYSIS
# L = 2, 3, 4, 5
#
# Expected repository location:
#   Innovus/scripts/power_fast_typ_saif.tcl
#
# SAIF input:
#   Innovus/datain/saif/core_sf_L2.saif
#   Innovus/datain/saif/core_sf_L3.saif
#   Innovus/datain/saif/core_sf_L4.saif
#   Innovus/datain/saif/core_sf_L5.saif
#
# Outputs:
#   Innovus/work/power_signoff/fastRC_saif/
#   Innovus/work/power_signoff/typ_saif/
#
# Final views restored at end:
#   setup = SlowView
#   hold  = FastView
# =============================================================================

# -----------------------------------------------------------------------------
# Resolve all repository paths relative to this TCL script.
# -----------------------------------------------------------------------------
set script_dir  [file dirname [file normalize [info script]]]
set innovus_dir [file normalize [file join $script_dir ".."]]

set work_dir    [file join $innovus_dir "work"]
set design_db   [file join $innovus_dir "dataout" "design_saves" "top_signoff.dat"]
set saif_dir    [file join $innovus_dir "datain" "saif"]

set power_root  [file join $work_dir "power_signoff"]
set fast_dir    [file join $power_root "fastRC_saif"]
set typ_dir     [file join $power_root "typ_saif"]

set L_values {2 3 4 5}

file mkdir $power_root
file mkdir $fast_dir
file mkdir $typ_dir

puts "Innovus directory : $innovus_dir"
puts "SAIF directory    : $saif_dir"
puts "Design database   : $design_db"

# =============================================================================
# Restore final signoff design
# =============================================================================
if {![file exists $design_db]} {
    error "Missing design database: $design_db"
}

restoreDesign $design_db top

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
# Helper procedure
# =============================================================================
proc run_saif_power {view_name output_dir label saif_dir L_values} {

    puts ""
    puts "============================================================"
    puts "$label POWER ANALYSIS"
    puts "View   : $view_name"
    puts "SAIF   : $saif_dir"
    puts "Output : $output_dir"
    puts "============================================================"

    set_analysis_view \
        -setup [list $view_name] \
        -hold  [list $view_name]

    setExtractRCMode -engine postRoute -effortLevel low

    if {[catch {extractRC} extract_err]} {
        error "$label extractRC failed: $extract_err"
    }

    foreach L $L_values {

        # Match the real system clock used by each operating mode.
        if {$L == 2 || $L == 4} {
            set period 1.041666667
        } else {
            set period 1.111111111
        }

        set saif_file  [file join $saif_dir "core_sf_L${L}.saif"]
        set report_file [file join $output_dir "core_I0_L${L}.rpt"]

        puts "------------------------------------------------------------"
        puts "$label SAIF POWER FOR L=$L"
        puts "Clock period : $period ns"
        puts "SAIF file    : $saif_file"
        puts "------------------------------------------------------------"

        set_power_analysis_mode -reset
        read_activity_file -reset
        catch {set_power -reset}
        catch {set_dynamic_power_simulation -reset}

        # Defaults are used only for activity that is not annotated by SAIF.
        # Use the correct mode clock period for those remaining signals.
        set_default_switching_activity -reset
        set_default_switching_activity \
            -input_activity 0.2 \
            -period $period \
            -seq_activity 0.2

        set_power_analysis_mode \
            -method static \
            -analysis_view $view_name \
            -honor_negative_energy true \
            -ignore_control_signals true

        if {[catch {
            read_activity_file \
                -format SAIF \
                $saif_file \
                -scope tb_top_interpolator_dac/DUT \
                -block I0
        } activity_err]} {
            error "$label L=$L SAIF read failed: $activity_err"
        }

        report_power \
            -instances I0 \
            -outfile $report_file

        puts "Created: $report_file"
    }
}

# =============================================================================
# FAST CORNER
# Existing project view:
#   FastView -> FastDC -> min libraries + FastRC
# =============================================================================
run_saif_power \
    FastView \
    $fast_dir \
    "FAST" \
    $saif_dir \
    $L_values

# =============================================================================
# CREATE / CHECK TYPICAL MMMC OBJECTS
# =============================================================================
puts ""
puts "============================================================"
puts "CREATING / CHECKING TYPICAL MMMC OBJECTS"
puts "============================================================"

catch {
    create_library_set -name Typ -timing {
        /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn65lplvt_220a/tcbn65lplvttc.lib
        /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn65lphvt_220a/tcbn65lphvttc.lib
        /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn65lp_220a/tcbn65lptc.lib
        /data/tsmc/65LP/dig_libs/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tpdn65lpnv2od3_200a/tpdn65lpnv2od3tc.lib
    }
} typ_lib_err

# Constraint mode fallback if TypCM is not already present in the restored DB.
set rerun_sdc [file join $innovus_dir "data_in" "top_interpolator_dac.sdc"]

if {[file exists $rerun_sdc]} {
    catch {
        create_constraint_mode \
            -name TypCM \
            -sdc_files [list $rerun_sdc]
    } typ_cm_err
}

catch {
    create_rc_corner \
        -name TypRC \
        -T {25} \
        -preRoute_res {1} \
        -preRoute_cap {1} \
        -preRoute_clkres {0} \
        -preRoute_clkcap {0} \
        -postRoute_res {1} \
        -postRoute_cap {1} \
        -postRoute_xcap {1} \
        -postRoute_clkres {0} \
        -postRoute_clkcap {0}
} typ_rc_err

catch {
    create_delay_corner \
        -name TypDC \
        -library_set {Typ} \
        -rc_corner {TypRC}
} typ_dc_err

catch {
    create_analysis_view \
        -name TypView \
        -constraint_mode {TypCM} \
        -delay_corner {TypDC}
} typ_view_err

if {[catch {
    set_analysis_view -setup {TypView} -hold {TypView}
} typ_activate_err]} {

    catch {
        set_analysis_view \
            -setup {SlowView} \
            -hold  {FastView}
    }

    error "Could not activate TypView: $typ_activate_err"
}

# =============================================================================
# TYPICAL CORNER
# =============================================================================
run_saif_power \
    TypView \
    $typ_dir \
    "TYPICAL" \
    $saif_dir \
    $L_values

# =============================================================================
# RESTORE NORMAL PROJECT VIEWS
# =============================================================================
puts ""
puts "============================================================"
puts "RESTORING NORMAL ANALYSIS VIEWS"
puts "============================================================"

set_analysis_view \
    -setup {SlowView} \
    -hold  {FastView}

puts ""
puts "============================================================"
puts "FAST + TYPICAL SAIF POWER ANALYSIS COMPLETED"
puts "============================================================"
puts "FAST reports:"
puts "  $fast_dir"
puts "TYPICAL reports:"
puts "  $typ_dir"
puts "Views restored:"
puts "  setup = SlowView"
puts "  hold  = FastView"
puts "============================================================"
