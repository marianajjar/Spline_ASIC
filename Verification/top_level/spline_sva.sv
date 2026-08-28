// ============================================================================
// spline_sva.sv
// Formal property checkers for QAM-64 spline interpolator
// ============================================================================

module top_checker #(parameter int NTAPS = 10) (
  input logic        clk,
  input logic        reset,
  input logic [3:0]  coeff_count,
  input logic        coeff_done,
  input logic        en_stream,
  input logic        en_iq,
  input logic        strobe_common,
  input logic        strobe_iq,
  input logic        shift_strobe_iq,
  input logic [2:0]  L_ctrl_int
);
  default clocking cb @(posedge clk); endclocking
  default disable iff (reset);

  wire valid_L = (L_ctrl_int inside {3'd2, 3'd3, 3'd4, 3'd5});

  // ==========================================================================
  // ENVIRONMENT ASSUMPTION
  // ==========================================================================
  // Formal can invent illegal serial headers. Real tests only use:
  //   L=2 -> 0101
  //   L=3 -> 0111
  //   L=4 -> 1001
  //   L=5 -> 1011
  //
  // So once the config stream is active, constrain the decoded L to legal modes.
  am_valid_L: assume property (
	en_stream |-> valid_L
  );

  // ==========================================================================
  // TOP-LEVEL ASSERTIONS
  // ==========================================================================

  // Config must be legal after coefficient loading is done.
  a_valid_L_after_coeff_done: assert property (
	coeff_done |-> valid_L
  );

  // L must not change after configuration/coefficient loading.
  a_L_stable_after_coeff_done: assert property (
	coeff_done |=> $stable(L_ctrl_int)
  );

  // coeff_count never runs past the last tap.
  a_coeff_count_bound: assert property (
	coeff_count <= $unsigned(NTAPS-1)
  );

  // coeff_done is sticky until reset.
  a_coeff_done_sticky: assert property (
	coeff_done |=> coeff_done
  );

  // once loading is done, the coefficient counter is frozen.
  a_coeff_count_frozen: assert property (
	coeff_done |=> $stable(coeff_count)
  );

  // no IQ activity is allowed before coefficient load completes.
  a_no_strobe_early: assert property (
	strobe_iq |-> coeff_done
  );

  a_no_sstrobe_early: assert property (
	shift_strobe_iq |-> coeff_done
  );

  a_en_iq_done: assert property (
	en_iq |-> coeff_done
  );

  // coeff_done may only rise on the strobe that loads the 10th coefficient.
  a_coeff_done_cause: assert property (
	$rose(coeff_done) |->
	  $past(en_stream && !coeff_done && strobe_common &&
			(coeff_count == $unsigned(NTAPS-1)))
  );

  // ==========================================================================
  // RATE CHECK
  // ==========================================================================
  // Count DAC output strobes after the first real IQ word strobe.
  // This avoids a false formal failure during the boundary between coefficient
  // loading and the first IQ word.
  int unsigned sh_count;
  logic        seen_iq_word;

  always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
	  sh_count     <= 0;
	  seen_iq_word <= 1'b0;
	end else if (!en_iq) begin
	  sh_count     <= 0;
	  seen_iq_word <= 1'b0;
	end else if (strobe_iq) begin
	  seen_iq_word <= 1'b1;
	  sh_count     <= shift_strobe_iq ? 32'd1 : 32'd0;
	end else if (shift_strobe_iq) begin
	  sh_count <= sh_count + 1'b1;
	end
  end

  // For each input IQ word, the design must not produce more than L DAC strobes.
  a_rate_no_overrun: assert property (
	(seen_iq_word && en_iq && valid_L) |-> (sh_count <= L_ctrl_int)
  );

  // ==========================================================================
  // COVERS
  // ==========================================================================

  c_L2: cover property (coeff_done && (L_ctrl_int == 3'd2));
  c_L3: cover property (coeff_done && (L_ctrl_int == 3'd3));
  c_L4: cover property (coeff_done && (L_ctrl_int == 3'd4));
  c_L5: cover property (coeff_done && (L_ctrl_int == 3'd5));

  c_rate_L2: cover property (seen_iq_word && (L_ctrl_int == 3'd2) && (sh_count == 2));
  c_rate_L3: cover property (seen_iq_word && (L_ctrl_int == 3'd3) && (sh_count == 3));
  c_rate_L4: cover property (seen_iq_word && (L_ctrl_int == 3'd4) && (sh_count == 4));
  c_rate_L5: cover property (seen_iq_word && (L_ctrl_int == 3'd5) && (sh_count == 5));

endmodule

bind top_interpolator_dac top_checker #(.NTAPS(NTAPS)) u_top_chk (
  .clk             (clk),
  .reset           (reset),
  .coeff_count     (coeff_count),
  .coeff_done      (coeff_done),
  .en_stream       (en_stream),
  .en_iq           (en_iq),
  .strobe_common   (strobe_common),
  .strobe_iq       (strobe_iq),
  .shift_strobe_iq (shift_strobe_iq),
  .L_ctrl_int      (L_ctrl_int)
);

// ============================================================================
// FIR checker
// ============================================================================
module fir_checker #(parameter int NTAPS = 10,
					 parameter int WL = 16,
					 parameter int ACC_W = 48) (
  input logic                    clk,
  input logic                    reset,
  input logic [3:0]              load_idx,
  input logic                    coeff_load_en,
  input logic                    coeff_strobe,
  input logic signed [ACC_W-1:0] fir_shift,
  input logic signed [WL-1:0]    y_next
);
  default clocking cb @(posedge clk); endclocking
  default disable iff (reset);

  localparam logic signed [WL-1:0] MAXQ = {1'b0, {(WL-1){1'b1}}};
  localparam logic signed [WL-1:0] MINQ = {1'b1, {(WL-1){1'b0}}};

  a_loadidx_bound: assert property (
	load_idx <= $unsigned(NTAPS-1)
  );

  a_loadidx_freeze: assert property (
	(coeff_load_en && coeff_strobe && (load_idx == $unsigned(NTAPS-1))) |=>
	(load_idx == $unsigned(NTAPS-1))
  );

  a_sat_hi: assert property (
	(fir_shift > MAXQ) |-> (y_next == MAXQ)
  );

  a_sat_lo: assert property (
	(fir_shift < MINQ) |-> (y_next == MINQ)
  );

  a_sat_mid: assert property (
	(fir_shift >= MINQ && fir_shift <= MAXQ) |-> (y_next == fir_shift[WL-1:0])
  );

  a_y_in_range: assert property (
	(y_next >= MINQ) && (y_next <= MAXQ)
  );
endmodule

bind fir20_q16_fromx fir_checker #(.NTAPS(NTAPS), .WL(WL), .ACC_W(ACC_W)) u_fir_chk (
  .clk           (clk),
  .reset         (reset),
  .load_idx      (load_idx),
  .coeff_load_en (coeff_load_en),
  .coeff_strobe  (coeff_strobe),
  .fir_shift     (fir_shift),
  .y_next        (y_next)
);

// ============================================================================
// Shift checker
// ============================================================================
module shift_checker (
  input logic       clk,
  input logic       reset,
  input logic [2:0] phase,
  input logic [2:0] L_ctrl,
  input logic       en,
  input logic       strobe,
  input logic       shift_strobe
);
  default clocking cb @(posedge clk); endclocking
  default disable iff (reset);

  wire valid_L = (L_ctrl inside {3'd2, 3'd3, 3'd4, 3'd5});

  // Same legal-environment assumption locally, so this block is not checked
  // under impossible L values.
  am_shift_valid_L: assume property (
	en |-> valid_L
  );

  a_phase_bound: assert property (
	valid_L |-> (phase <= L_ctrl - 3'd1)
  );

  a_phase_reset: assert property (
	(en && strobe) |=> (phase == 3'd0)
  );

  a_phase_inc: assert property (
	(en && !strobe && shift_strobe && valid_L && (phase < L_ctrl - 3'd1)) |=>
	(phase == $past(phase) + 3'd1)
  );

  c_phase_max_L2: cover property (valid_L && (L_ctrl == 3'd2) && (phase == 3'd1));
  c_phase_max_L3: cover property (valid_L && (L_ctrl == 3'd3) && (phase == 3'd2));
  c_phase_max_L4: cover property (valid_L && (L_ctrl == 3'd4) && (phase == 3'd3));
  c_phase_max_L5: cover property (valid_L && (L_ctrl == 3'd5) && (phase == 3'd4));
endmodule

bind sample_shift_ntaps_I shift_checker u_shift_chk (
  .clk          (clk),
  .reset        (reset),
  .phase        (phase),
  .L_ctrl       (L_ctrl),
  .en           (en),
  .strobe       (strobe),
  .shift_strobe (shift_strobe)
);

// ============================================================================
// Slope checker
// ============================================================================
module slope_checker (
  input logic               clk,
  input logic               reset,
  input logic signed [23:0] raw_m,
  input logic signed [15:0] m_new,
  input logic signed [15:0] m_p,
  input logic               en,
  input logic               strobe
);
  default clocking cb @(posedge clk); endclocking
  default disable iff (reset);

  a_mnew_sat_hi: assert property (
	(raw_m > 24'sd32767) |-> (m_new == 16'sd32767)
  );

  a_mnew_sat_lo: assert property (
	(raw_m < -24'sd32768) |-> (m_new == -16'sd32768)
  );

  a_mp_update: assert property (
	(en && strobe) |=> (m_p == $past(m_new))
  );

  a_mp_hold: assert property (
	(!en) |=> $stable(m_p)
  );

  c_mnew_hi: cover property (raw_m > 24'sd32767);
  c_mnew_lo: cover property (raw_m < -24'sd32768);
  c_mnew_mid: cover property ((raw_m >= -24'sd32768) && (raw_m <= 24'sd32767));
endmodule

bind minaj2_interp_3samp_internalSlope slope_checker u_slope_chk (
  .clk    (clk),
  .reset  (reset),
  .raw_m  (raw_m),
  .m_new  (m_new),
  .m_p    (m_p),
  .en     (en),
  .strobe (strobe)
);
