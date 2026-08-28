# ============================================================
# createPP.tcl
# Guide-style Voltus power source file generation
#
# Uses only:
#   PVDD1CDG / pvdc pads: PAD_I3, PAD_I4
#   PVSS1CDG / pv0c pads: PAD_G3, PAD_G4
#
# Output:
#   vddtop.pp
#   vsstop.pp
# ============================================================

remove_gui_marker -all

set VSS_pp_file_name "vsstop.pp"
set VDD_pp_file_name "vddtop.pp"

set VSS_fd [open $VSS_pp_file_name w+]
set VDD_fd [open $VDD_pp_file_name w+]

# Guide-style connected core power pads only
set VDD_pad_type "PVDD1CDG"
set VSS_pad_type "PVSS1CDG"

# ------------------------------------------------------------
# Corrected offsets for your current layout
# ------------------------------------------------------------

# VDD:
#   bottom R0    moved left by 18
#   top R180     moved right by 18
set x_corr_VDD_R0   18
set x_corr_VDD_R180 18

# VSS:
#   bottom R0    moved left by 29
#   top R180     corrected to -10
set x_corr_VSS_R0    29
set x_corr_VSS_R180 -10

# Y offset from pad edge
set y_corr 7

# Get only guide-style VDD/VSS pads
set VSS_pads [dbGet -p2 top.insts.cell.name $VSS_pad_type]
set VDD_pads [dbGet -p2 top.insts.cell.name $VDD_pad_type]

puts "Found [llength $VSS_pads] VSS pads of type $VSS_pad_type"
puts "Found [llength $VDD_pads] VDD pads of type $VDD_pad_type"

# ============================================================
# VSS sources: PAD_G3 and PAD_G4
# ============================================================

set i 1

foreach pad $VSS_pads {
    set orient [dbGet $pad.orient]
    set metal "M2"

    if {$orient == "R0"} {
        # Bottom VSS pad: PAD_G4
        set src_point "[expr [dbGet $pad.box_urx] - 15 - $x_corr_VSS_R0] [expr [dbGet $pad.box_ury] + $y_corr]"

    } elseif {$orient == "R180"} {
        # Top VSS pad: PAD_G3
        set src_point "[expr [dbGet $pad.box_llx] + 44 + $x_corr_VSS_R180] [expr [dbGet $pad.box_lly] - $y_corr]"

    } else {
        puts "WARNING: Skipping VSS pad [dbGet $pad.name] because orientation $orient is not R0/R180"
        continue
    }

    puts "VSSsrc${i} [dbGet $pad.name] orient=$orient point=$src_point $metal"
    add_gui_marker -pt "$src_point" -color red -name VSS_SRC -type TICK
    puts $VSS_fd "VSSsrc${i} $src_point $metal"

    incr i
}

# ============================================================
# VDD sources: PAD_I3 and PAD_I4
# ============================================================

set i 1

foreach pad $VDD_pads {
    set orient [dbGet $pad.orient]
    set metal "M2"

    if {$orient == "R0"} {
        # Bottom VDD pad: PAD_I4
        set src_point "[expr [dbGet $pad.box_urx] - 25 - $x_corr_VDD_R0] [expr [dbGet $pad.box_ury] + $y_corr]"

    } elseif {$orient == "R180"} {
        # Top VDD pad: PAD_I3
        set src_point "[expr [dbGet $pad.box_llx] + 24 + $x_corr_VDD_R180] [expr [dbGet $pad.box_lly] - $y_corr]"

    } else {
        puts "WARNING: Skipping VDD pad [dbGet $pad.name] because orientation $orient is not R0/R180"
        continue
    }

    puts "VDDsrc${i} [dbGet $pad.name] orient=$orient point=$src_point $metal"
    add_gui_marker -pt "$src_point" -color blue -name VDD_SRC -type TICK
    puts $VDD_fd "VDDsrc${i} $src_point $metal"

    incr i
}

close $VSS_fd
close $VDD_fd

puts "Created $VSS_pp_file_name and $VDD_pp_file_name"

puts "----- VDD sources -----"
puts [exec cat $VDD_pp_file_name]

puts "----- VSS sources -----"
puts [exec cat $VSS_pp_file_name]
