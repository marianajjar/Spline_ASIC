`timescale 1ns/1ps

module window_latch_formal_checker #(parameter int WL = 16) (
  input logic                 clk,
  input logic                 reset,
  input logic                 en,
  input logic                 strobe,
  input logic signed [WL-1:0] y0,
  input logic signed [WL-1:0] y1,
  input logic signed [WL-1:0] y2,
  input logic signed [WL-1:0] y3,
  input logic signed [WL-1:0] y4,
  input logic signed [WL-1:0] y0_r,
  input logic signed [WL-1:0] y1_r,
  input logic signed [WL-1:0] y2_r,
  input logic signed [WL-1:0] y3_r,
  input logic signed [WL-1:0] y4_r
);
  default clocking cb @(posedge clk); endclocking

  a_reset: assert property (
    reset |-> ({y0_r,y1_r,y2_r,y3_r,y4_r} == '0)
  );

  default disable iff (reset);

  a_no_x_outputs: assert property (
    !$isunknown({y0_r,y1_r,y2_r,y3_r,y4_r})
  );

  a_capture: assert property (
    en && strobe |=> (y0_r == $past(y0) && y1_r == $past(y1) && y2_r == $past(y2) &&
                      y3_r == $past(y3) && y4_r == $past(y4))
  );

  a_hold_no_en: assert property (
    !en |=> $stable({y0_r,y1_r,y2_r,y3_r,y4_r})
  );

  a_hold_no_strobe: assert property (
    en && !strobe |=> $stable({y0_r,y1_r,y2_r,y3_r,y4_r})
  );

  c_capture: cover property (en && strobe);
  c_gated_strobe: cover property (!en && strobe);
endmodule

bind minaj2_window_latch window_latch_formal_checker #(.WL(WL)) u_window_fchk (
  .clk(clk),
  .reset(reset),
  .en(en),
  .strobe(strobe),
  .y0(y0), .y1(y1), .y2(y2), .y3(y3), .y4(y4),
  .y0_r(y0_r), .y1_r(y1_r), .y2_r(y2_r), .y3_r(y3_r), .y4_r(y4_r)
);
