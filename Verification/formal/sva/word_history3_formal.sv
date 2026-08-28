`timescale 1ns/1ps

module word_history3_formal_checker #(parameter int WL = 16) (
  input logic          clk,
  input logic          reset,
  input logic          shift_en,
  input logic          strobe,
  input logic [WL-1:0] word_in,
  input logic [WL-1:0] w0,
  input logic [WL-1:0] w1,
  input logic [WL-1:0] w2
);
  default clocking cb @(posedge clk); endclocking

  a_reset: assert property (
    reset |-> (w0 == '0 && w1 == '0 && w2 == '0)
  );

  default disable iff (reset);

  a_no_x_outputs: assert property (
    !$isunknown({w0, w1, w2})
  );

  a_hold_without_push: assert property (
    !(shift_en && strobe) |=> ($stable(w0) && $stable(w1) && $stable(w2))
  );

  a_push_w0: assert property (
    shift_en && strobe |=> (w0 == $past(word_in))
  );

  a_push_w1: assert property (
    shift_en && strobe |=> (w1 == $past(w0))
  );

  a_push_w2: assert property (
    shift_en && strobe |=> (w2 == $past(w1))
  );

  c_push: cover property (shift_en && strobe);
  c_hold_shift_only: cover property (shift_en && !strobe);
  c_hold_strobe_only: cover property (!shift_en && strobe);
endmodule

bind word_history3 word_history3_formal_checker #(.WL(WL)) u_hist_fchk (
  .clk(clk),
  .reset(reset),
  .shift_en(shift_en),
  .strobe(strobe),
  .word_in(word_in),
  .w0(w0),
  .w1(w1),
  .w2(w2)
);
