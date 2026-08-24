// ============================================================================
// spline_cov.sv  -  Functional coverage for the QAM-64 spline interpolator
//
// Bound into the RTL (same idea as spline_sva.sv). Run with VCS/Questa/Xcelium
// and coverage enabled; iverilog cannot compile covergroups, so only include
// this file in the coverage run, not the iverilog functional run.
//
//   VCS:    vcs -sverilog -cm line+cond+fsm+tgl+branch -assert svaext \
//                tb_multi.sv <rtl...> spline_cov.sv ; simv -cm ... +MANIFEST=manifest.txt
//   Questa: vlog +cover=bcefsx tb_multi.sv <rtl...> spline_cov.sv ; vsim -coverage ...
//
// Coverage goals:
//   - every interpolation factor L = 2,3,4,5 reached
//   - every ordered mode transition  L_prev -> L_curr  (the 12 off-diagonal)
//   - every phase value, crossed with L
//   - FIR output saturation, both rails
//   - slope (m_new) saturation, both rails
//   - coefficient load completes; reset seen while running
// ============================================================================

// ----------------------------------------------------------------------------
// TOP: L value, L-transition, protocol coverage
// ----------------------------------------------------------------------------
module top_cov (
  input logic       clk,
  input logic       reset,
  input logic [2:0] L_ctrl_int,
  input logic       coeff_done,
  input logic       en_iq
);
  // Track current/previous decoded L across reset-bracketed segments.
  logic [2:0] L_curr, L_prev;
  logic       dprev, have_prev;

  initial begin L_curr='0; L_prev='0; dprev=1'b0; have_prev=1'b0; end

  always @(posedge clk) begin
	if (coeff_done && !dprev) begin           // rising edge of coeff_done = new segment locked in
	  L_prev    <= L_curr;
	  L_curr    <= L_ctrl_int;
	  if (L_curr inside {3'd2,3'd3,3'd4,3'd5}) have_prev <= 1'b1;
	end
	dprev <= coeff_done;
  end

  // ---- L value coverage (sampled when a segment locks in) ----
  covergroup cg_L @(posedge clk iff (coeff_done && !dprev));
	cp_L : coverpoint L_ctrl_int {
	  bins L2 = {2}; bins L3 = {3}; bins L4 = {4}; bins L5 = {5};
	  ignore_bins bad = {0,1,6,7};   // illegal L (e.g. badhdr stress test) -> not counted, not fatal
	}
  endgroup

  // ---- L transition coverage: prev -> curr, the 12 off-diagonal pairs ----
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

  cg_L     u_cg_L     = new();
  cg_trans u_cg_trans = new();
endmodule

bind top_interpolator_dac top_cov u_top_cov (
  .clk(clk), .reset(reset), .L_ctrl_int(L_ctrl_int), .coeff_done(coeff_done), .en_iq(en_iq)
);

// ----------------------------------------------------------------------------
// SHIFT: phase coverage, crossed with L
// ----------------------------------------------------------------------------
module shift_cov (
  input logic       clk,
  input logic       reset,
  input logic [2:0] phase,
  input logic [2:0] L_ctrl,
  input logic       en,
  input logic       shift_strobe
);
  covergroup cg_phase @(posedge clk iff (en && shift_strobe && !reset));
	cp_phase : coverpoint phase { bins p[] = {[0:4]}; }
	cp_L     : coverpoint L_ctrl { bins v[] = {2,3,4,5}; }
	x_pL     : cross cp_phase, cp_L {
	  // phase always counts 0..L-1, so phase >= L is unreachable by design
	  // (proven by a_phase_bound in spline_sva.sv). Exclude those 6 bins:
	  //   L=2 -> phase 2,3,4 ;  L=3 -> phase 3,4 ;  L=4 -> phase 4
	  ignore_bins impossible =
		   binsof(cp_phase) intersect {[2:4]} && binsof(cp_L) intersect {2}
		|| binsof(cp_phase) intersect {[3:4]} && binsof(cp_L) intersect {3}
		|| binsof(cp_phase) intersect {4}     && binsof(cp_L) intersect {4};
	}
  endgroup
  cg_phase u_cg_phase = new();
endmodule

bind sample_shift_ntaps_I shift_cov u_shift_cov (
  .clk(clk), .reset(reset), .phase(phase), .L_ctrl(L_ctrl), .en(en), .shift_strobe(shift_strobe)
);

// ----------------------------------------------------------------------------
// FIR: output saturation coverage (both rails)
// ----------------------------------------------------------------------------
module fir_cov #(parameter int WL = 16) (
  input logic                 clk,
  input logic                 reset,
  input logic                 en,
  input logic signed [WL-1:0] y_next
);
  localparam logic signed [WL-1:0] MAXQ = {1'b0, {(WL-1){1'b1}}};
  localparam logic signed [WL-1:0] MINQ = {1'b1, {(WL-1){1'b0}}};
  covergroup cg_sat @(posedge clk iff (en && !reset));
	cp_sat : coverpoint y_next {
	  bins hi_rail  = {MAXQ};
	  bins lo_rail  = {MINQ};
	  bins mid      = {[MINQ+1 : MAXQ-1]};
	}
  endgroup
  cg_sat u_cg_sat = new();
endmodule

bind fir20_q16_fromx fir_cov #(.WL(WL)) u_fir_cov (
  .clk(clk), .reset(reset), .en(en), .y_next(y_next)
);

// ----------------------------------------------------------------------------
// SLOPE: m_new saturation coverage (both rails)
// ----------------------------------------------------------------------------
module slope_cov (
  input logic               clk,
  input logic               reset,
  input logic               en,
  input logic               strobe,
  input logic signed [23:0] raw_m
);
  covergroup cg_mslope @(posedge clk iff (en && strobe && !reset));
	cp_m : coverpoint raw_m {
	  bins hi_sat = {[24'sd32768 : 24'sd8388607]};
	  bins lo_sat = {[-24'sd8388608 : -24'sd32769]};
	  bins linear = {[-24'sd32768 : 24'sd32767]};
	}
  endgroup
  cg_mslope u_cg_mslope = new();
endmodule

bind minaj2_interp_3samp_internalSlope slope_cov u_slope_cov (
  .clk(clk), .reset(reset), .en(en), .strobe(strobe), .raw_m(raw_m)
);