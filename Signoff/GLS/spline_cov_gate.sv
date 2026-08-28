// ============================================================================
// spline_cov_gate.sv  -  GATE-LEVEL functional coverage for top_interpolator_dac
//
// IMPORTANT - read this first:
//   The synthesized netlist is FLATTENED. Only ONE design module exists
//   (top_interpolator_dac); the RTL submodules sample_shift_ntaps_I,
//   fir20_q16_fromx and minaj2_interp_3samp_internalSlope NO LONGER EXIST,
//   so the original RTL binds to them cannot compile. Several internal
//   signals the RTL coverage probed were also synthesized away:
//       y_next  (FIR pre-register output)  -> GONE
//       raw_m   (24-bit slope before sat)  -> GONE
//       en_iq / strobe_iq / shift_strobe_iq (combinational ANDs) -> GONE
//
//   Therefore the FIR-internal and slope-internal covergroups cannot be
//   reproduced on the gate netlist. Functional coverage of those nodes
//   belongs on the RTL run (keep using the original spline_cov.sv there).
//
//   What CAN be covered on the gate netlist - using only top-level nets that
//   survive synthesis (L_ctrl_int, coeff_done, phase_shared,
//   shift_strobe_common, dac_I/dac_Q) - is collected below:
//       * L value           (2,3,4,5)
//       * L -> L transition (12 off-diagonal)
//       * phase x L
//       * DAC output rail saturation (stand-in for FIR y_next saturation)
//
//   For everything else at gate level, use the simulator's toggle coverage
//   (e.g. VCS  -cm tgl) rather than functional covergroups.
//
//   Run (VCS):  vcs -sverilog -cm tgl+line+cond \
//                 tb_corner_gate.sv top_interpolator_dac.v <cell_sims>.v \
//                 spline_cov_gate.sv ; simv -cm tgl +MANIFEST=manifest.txt
// ============================================================================

module gate_cov (
  input logic        clk,
  input logic        reset,
  input logic [2:0]  L_ctrl_int,
  input logic        coeff_done,
  input logic [2:0]  phase_shared,
  input logic        shift_strobe_common,
  input logic signed [15:0] dac_I,
  input logic signed [15:0] dac_Q
);
  // ---- track current/previous decoded L across reset-bracketed segments ----
  logic [2:0] L_curr, L_prev;
  logic       dprev, have_prev;

  initial begin L_curr='0; L_prev='0; dprev=1'b0; have_prev=1'b0; end

  always @(posedge clk) begin
	if (coeff_done && !dprev) begin            // rising edge of coeff_done = new segment
	  L_prev <= L_curr;
	  L_curr <= L_ctrl_int;
	  if (L_curr inside {3'd2,3'd3,3'd4,3'd5}) have_prev <= 1'b1;
	end
	dprev <= coeff_done;
  end

  // ---- L value coverage ----
  covergroup cg_L @(posedge clk iff (coeff_done && !dprev));
	cp_L : coverpoint L_ctrl_int {
	  bins L2 = {2}; bins L3 = {3}; bins L4 = {4}; bins L5 = {5};
	  ignore_bins bad = {0,1,6,7};
	}
  endgroup

  // ---- L -> L transition coverage (12 off-diagonal pairs) ----
  covergroup cg_trans @(posedge clk iff (coeff_done && !dprev && have_prev));
	cp_prev : coverpoint L_prev { bins v[] = {2,3,4,5}; }
	cp_curr : coverpoint L_curr { bins v[] = {2,3,4,5}; }
	x_trans : cross cp_prev, cp_curr {
	  ignore_bins same = binsof(cp_prev) intersect {2} && binsof(cp_curr) intersect {2}
					   || binsof(cp_prev) intersect {3} && binsof(cp_curr) intersect {3}
					   || binsof(cp_prev) intersect {4} && binsof(cp_curr) intersect {4}
					   || binsof(cp_prev) intersect {5} && binsof(cp_curr) intersect {5};
	}
  endgroup

  // ---- phase x L coverage ----
  // Original probed sample_shift_ntaps_I (phase,en,shift_strobe). At top level
  // the survivors are phase_shared, L_ctrl_int and shift_strobe_common; the
  // 'en' gate (en_iq = en_stream & coeff_done) is represented by coeff_done.
  covergroup cg_phase @(posedge clk iff (coeff_done && shift_strobe_common && !reset));
	cp_phase : coverpoint phase_shared { bins p[] = {[0:4]}; }
	cp_L     : coverpoint L_ctrl_int   { bins v[] = {2,3,4,5}; }
	x_pL     : cross cp_phase, cp_L {
	  // phase counts 0..L-1, so phase >= L is unreachable by design:
	  //   L=2 -> phase 2,3,4 ;  L=3 -> phase 3,4 ;  L=4 -> phase 4
	  ignore_bins impossible =
		   binsof(cp_phase) intersect {[2:4]} && binsof(cp_L) intersect {2}
		|| binsof(cp_phase) intersect {[3:4]} && binsof(cp_L) intersect {3}
		|| binsof(cp_phase) intersect {4}     && binsof(cp_L) intersect {4};
	}
  endgroup

  // ---- DAC output rail saturation (stand-in for the FIR y_next saturation,
  //      which is not observable on the flattened netlist) ----
  localparam logic signed [15:0] MAXQ = 16'sh7FFF;   // +32767
  localparam logic signed [15:0] MINQ = 16'sh8000;   // -32768
  covergroup cg_dac_rail @(posedge clk iff (coeff_done && shift_strobe_common && !reset));
	cp_i : coverpoint dac_I {
	  bins hi_rail = {MAXQ}; bins lo_rail = {MINQ}; bins mid = {[MINQ+1 : MAXQ-1]};
	}
	cp_q : coverpoint dac_Q {
	  bins hi_rail = {MAXQ}; bins lo_rail = {MINQ}; bins mid = {[MINQ+1 : MAXQ-1]};
	}
  endgroup

  cg_L        u_cg_L        = new();
  cg_trans    u_cg_trans    = new();
  cg_phase    u_cg_phase    = new();
  cg_dac_rail u_cg_dac_rail = new();
endmodule

// Single bind into the only module that exists in the netlist.
// All connected nets are real top-level signals in top_interpolator_dac.
bind top_interpolator_dac gate_cov u_gate_cov (
  .clk(clk),
  .reset(reset),
  .L_ctrl_int(L_ctrl_int),
  .coeff_done(coeff_done),
  .phase_shared(phase_shared),
  .shift_strobe_common(shift_strobe_common),
  .dac_I(dac_I),
  .dac_Q(dac_Q)
);

// ----------------------------------------------------------------------------
// NOT reproducible on the gate netlist (kept here only as a record):
//   * FIR y_next saturation  - y_next is synthesized away; use cg_dac_rail above.
//   * slope raw_m saturation - raw_m (24-bit pre-saturation slope) is gone.
//   Collect these on the RTL run with the original spline_cov.sv.
// ----------------------------------------------------------------------------