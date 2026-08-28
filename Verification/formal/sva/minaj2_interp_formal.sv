`timescale 1ns/1ps

module minaj2_interp_formal_checker (
  input logic               clk,
  input logic               reset,
  input logic               en,
  input logic               strobe,
  input logic [2:0]         L_ctrl,
  input logic signed [15:0] x_prev,
  input logic signed [15:0] y0,
  input logic signed [15:0] y1,
  input logic signed [15:0] y2,
  input logic signed [15:0] y3,
  input logic signed [15:0] y4,
  input logic signed [15:0] m_p,
  input logic signed [15:0] m_new,
  input logic signed [23:0] raw_m
);
  default clocking cb @(posedge clk); endclocking

  a_reset_mp: assert property (
    reset |-> (m_p == 16'sd0)
  );

  default disable iff (reset);

  wire legal_L = (L_ctrl inside {3'd2,3'd3,3'd4,3'd5});

  am_legal_L_when_enabled: assume property (
    en |-> legal_L
  );

  a_no_x_used_outputs: assert property (
    !$isunknown({y0, y1, y2, y3, y4, m_p, m_new, raw_m})
  );

  a_y0_eq_xprev: assert property (
    y0 == x_prev
  );

  a_unused_zero_L2: assert property (
    L_ctrl == 3'd2 |-> (y2 == 16'sd0 && y3 == 16'sd0 && y4 == 16'sd0)
  );

  a_unused_zero_L3: assert property (
    L_ctrl == 3'd3 |-> (y3 == 16'sd0 && y4 == 16'sd0)
  );

  a_unused_zero_L4: assert property (
    L_ctrl == 3'd4 |-> (y4 == 16'sd0)
  );

  a_mp_update: assert property (
    en && strobe |=> (m_p == $past(m_new))
  );

  a_mp_hold: assert property (
    !(en && strobe) |=> $stable(m_p)
  );

  a_mnew_sat_hi: assert property (
    raw_m > 24'sd32767 |-> (m_new == 16'sd32767)
  );

  a_mnew_sat_lo: assert property (
    raw_m < -24'sd32768 |-> (m_new == -16'sd32768)
  );

  c_L2: cover property (en && L_ctrl == 3'd2);
  c_L3: cover property (en && L_ctrl == 3'd3);
  c_L4: cover property (en && L_ctrl == 3'd4);
  c_L5: cover property (en && L_ctrl == 3'd5);
  c_mnew_hi_sat: cover property (raw_m > 24'sd32767);
  c_mnew_lo_sat: cover property (raw_m < -24'sd32768);
endmodule

bind minaj2_interp_3samp_internalSlope minaj2_interp_formal_checker u_minaj2_fchk (
  .clk(clk),
  .reset(reset),
  .en(en),
  .strobe(strobe),
  .L_ctrl(L_ctrl),
  .x_prev(x_prev),
  .y0(y0), .y1(y1), .y2(y2), .y3(y3), .y4(y4),
  .m_p(m_p),
  .m_new(m_new),
  .raw_m(raw_m)
);
