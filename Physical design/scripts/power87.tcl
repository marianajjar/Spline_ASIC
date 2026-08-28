# ============================================================
# Power ring setup
# ============================================================

setAddRingMode \
    -ring_target default \
    -extend_over_row 0 \
    -ignore_rows 0 \
    -avoid_short 0 \
    -skip_crossing_trunks none \
    -stacked_via_top_layer M7 \
    -stacked_via_bottom_layer M1 \
    -via_using_exact_crossover_size 1 \
    -orthogonal_only true \
    -skip_via_on_pin {standardcell} \
    -skip_via_on_wire_shape {noshape}


# ============================================================
# Closed core power ring
# ============================================================

addRing \
    -nets {VSS VDD} \
    -type core_rings \
    -follow core \
    -layer {top M7 bottom M7 left M6 right M6} \
    -width {top 2.6 bottom 2.6 left 2.6 right 2.6} \
    -spacing {top 2.6 bottom 2.6 left 2.6 right 2.6} \
    -offset {top 2.6 bottom 2.6 left 2.6 right 2.6} \
    -center 1 \
    -threshold 2.6 \
    -jog_distance 2.6 \
    -snap_wire_center_to_grid None


# ============================================================
# Stripe setup
# ============================================================

setAddStripeMode \
    -ignore_block_check false \
    -break_at none \
    -route_over_rows_only false \
    -rows_without_stripes_only false \
    -extend_to_closest_target none \
    -stop_at_last_wire_for_area false \
    -partial_set_thru_domain false \
    -ignore_nondefault_domains false \
    -trim_antenna_back_to_shape none \
    -spacing_type edge_to_edge \
    -spacing_from_block 0 \
    -stripe_min_length stripe_width \
    -stacked_via_top_layer M7 \
    -stacked_via_bottom_layer M1 \
    -via_using_exact_crossover_size false \
    -split_vias false \
    -orthogonal_only true \
    -allow_jog {padcore_ring block_ring} \
    -skip_via_on_pin {standardcell} \
    -skip_via_on_wire_shape {noshape}


# ============================================================
# Vertical stripes on M6
# They connect to the horizontal M7 ring at top and bottom.
# ============================================================

addStripe \
    -nets {VDD VSS} \
    -layer M6 \
    -direction vertical \
    -width 2.6 \
    -spacing 2.6 \
    -set_to_set_distance 26 \
    -start_from left \
    -start_offset 1 \
    -switch_layer_over_obs false \
    -max_same_layer_jog_length 2 \
    -padcore_ring_top_layer_limit M7 \
    -padcore_ring_bottom_layer_limit M1 \
    -block_ring_top_layer_limit M7 \
    -block_ring_bottom_layer_limit M1 \
    -use_wire_group 0 \
    -snap_wire_center_to_grid None \
    -skip_via_on_pin {standardcell} \
    -skip_via_on_wire_shape {noshape}


# ============================================================
# Horizontal stripes on M7
# They connect to the vertical M6 ring at left and right.
# ============================================================

addStripe \
    -nets {VDD VSS} \
    -layer M7 \
    -direction horizontal \
    -width 2.6 \
    -spacing 2.6 \
    -set_to_set_distance 26 \
    -start_from bottom \
    -start_offset 1 \
    -switch_layer_over_obs false \
    -max_same_layer_jog_length 2 \
    -padcore_ring_top_layer_limit M7 \
    -padcore_ring_bottom_layer_limit M1 \
    -block_ring_top_layer_limit M7 \
    -block_ring_bottom_layer_limit M1 \
    -use_wire_group 0 \
    -snap_wire_center_to_grid None \
    -skip_via_on_pin {standardcell} \
    -skip_via_on_wire_shape {noshape}


# ============================================================
# Save power plan
# ============================================================

saveDesign ../dataout/design_saves/top_powerplan
