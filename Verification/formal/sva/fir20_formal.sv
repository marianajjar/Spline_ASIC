`timescale 1ns/1ps

module fir20_formal_checker #(
  parameter int WL = 16,
  parameter int NTAPS = 10,
  parameter int IDXW = (NTAPS <= 1) ? 1 : $clog2(NTAPS)
) (
  input logic                         clk,
  input logic                         reset,
  input logic                         en,
  input logic                         coeff_load_en,
  input logic                         coeff_strobe,
  input logic signed [WL-1:0]         coeff_word,
  input logic signed [WL-1:0]         y,
  input logic signed [WL-1:0]         y_next,
  input logic signed [WL-1:0]         check,
  input logic [IDXW-1:0]              load_idx
);
  default clocking cb @(posedge clk); endclocking

  a_reset: assert property (
    reset |-> (y == '0 && check == '0 && load_idx == '0)
  );

  default disable iff (reset);

  a_no_x_outputs: assert property (
    !$isunknown({y, y_next, check, load_idx})
  );

  a_y_updates_when_enabled: assert property (
    en |=> (y == $past(y_next))
  );

  a_y_holds_when_disabled: assert property (
    !en |=> $stable(y)
  );

  a_loadidx_inc: assert property (
    coeff_load_en && coeff_strobe && (load_idx < NTAPS-1) |=>
      (load_idx == $past(load_idx) + 1'b1)
  );

  a_loadidx_sat: assert property (
    coeff_load_en && coeff_strobe && (load_idx == NTAPS-1) |=>
      (load_idx == $past(load_idx))
  );

  a_check_loads: assert property (
    coeff_load_en && coeff_strobe |=> (check == $past(coeff_word))
  );

  a_check_holds_when_not_loading: assert property (
    !coeff_load_en |=> $stable(check)
  );

  c_load_last_coeff: cover property (coeff_load_en && coeff_strobe && load_idx == NTAPS-1);
  c_compute: cover property (en);
endmodule

bind fir20_q16_fromx fir20_formal_checker #(.WL(WL), .NTAPS(NTAPS)) u_fir_fchk (
  .clk(clk),
  .reset(reset),
  .en(en),
  .coeff_load_en(coeff_load_en),
  .coeff_strobe(coeff_strobe),
  .coeff_word(coeff_word),
  .y(y),
  .y_next(y_next),
  .check(check),
  .load_idx(load_idx)
);
