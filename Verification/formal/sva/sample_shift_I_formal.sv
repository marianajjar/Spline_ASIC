`timescale 1ns/1ps

module sample_shift_I_formal_checker #(parameter int WL = 16, parameter int NTAPS = 10) (
  input logic                     clk,
  input logic                     reset,
  input logic                     en,
  input logic [2:0]               L_ctrl,
  input logic                     strobe,
  input logic                     shift_strobe,
  input logic [2:0]               phase,
  input logic [2:0]               phase_out,
  input logic signed [WL-1:0]     sample_sel,
  input logic signed [WL-1:0]     x [0:NTAPS-1]
);
  default clocking cb @(posedge clk); endclocking
  default disable iff (reset);

  wire legal_L = (L_ctrl inside {3'd2,3'd3,3'd4,3'd5});

  // Real top only uses legal L after SPI config is complete.
  am_legal_L_when_enabled: assume property (
    en |-> legal_L
  );

  // At the chip level L_ctrl is loaded before the active segment and then
  // stays fixed while the shifter is enabled. Without this, formal can jump
  // from a large L to a small L while phase is already high, which is not a
  // real operating mode for this block.
  am_L_stable_while_enabled: assume property (
    en && $past(en) |-> $stable(L_ctrl)
  );

  // If a block-level proof starts/restarts the shifter without reset, require
  // the existing phase to be valid for the selected L. The RTL holds phase
  // while disabled; the real top resets/reconfigures between segments.
  am_valid_phase_on_enable: assume property (
    $rose(en) |-> (phase <= (L_ctrl - 3'd1))
  );

  a_phase_out_matches_internal: assert property (
    phase_out == phase
  );

  a_no_x_phase: assert property (
    !$isunknown({phase, phase_out})
  );

  a_phase_range: assert property (
    en && legal_L |-> (phase <= (L_ctrl - 3'd1))
  );

  a_phase_reset_on_strobe: assert property (
    en && strobe |=> (phase == 3'd0)
  );

  a_phase_inc: assert property (
    en && !strobe && shift_strobe && (phase < (L_ctrl - 3'd1)) |=>
      (phase == $past(phase) + 3'd1)
  );

  a_phase_hold_at_max: assert property (
    en && !strobe && shift_strobe && (phase >= (L_ctrl - 3'd1)) |=>
      (phase == $past(phase))
  );

  a_phase_hold_no_en: assert property (
    !en |=> $stable(phase)
  );

  a_x0_shift: assert property (
    en && shift_strobe |=> (x[0] == $past(sample_sel))
  );

  genvar gi;
  generate
    for (gi = 0; gi < NTAPS; gi++) begin : g_x_nox
      property p_x_no_x;
        @(posedge clk) disable iff (reset)
          !$isunknown(x[gi]);
      endproperty
      assert property (p_x_no_x);
    end

    for (gi = 1; gi < NTAPS; gi++) begin : g_xshift
      property p_x_shift;
        @(posedge clk) disable iff (reset)
          en && shift_strobe |=> (x[gi] == $past(x[gi-1]));
      endproperty
      assert property (p_x_shift);
    end

    for (gi = 0; gi < NTAPS; gi++) begin : g_xhold
      property p_x_hold_without_shift;
        @(posedge clk) disable iff (reset)
          !(en && shift_strobe) |=> $stable(x[gi]);
      endproperty
      assert property (p_x_hold_without_shift);
    end
  endgenerate

  c_L2_phase_max: cover property (en && L_ctrl == 3'd2 && phase == 3'd1);
  c_L3_phase_max: cover property (en && L_ctrl == 3'd3 && phase == 3'd2);
  c_L4_phase_max: cover property (en && L_ctrl == 3'd4 && phase == 3'd3);
  c_L5_phase_max: cover property (en && L_ctrl == 3'd5 && phase == 3'd4);
  c_strobe_shift_collision: cover property (en && strobe && shift_strobe);
endmodule

bind sample_shift_ntaps_I sample_shift_I_formal_checker #(.WL(WL), .NTAPS(NTAPS)) u_shift_I_fchk (
  .clk(clk),
  .reset(reset),
  .en(en),
  .L_ctrl(L_ctrl),
  .strobe(strobe),
  .shift_strobe(shift_strobe),
  .phase(phase),
  .phase_out(phase_out),
  .sample_sel(sample_sel),
  .x(x)
);
