`timescale 1ns/1ps

module spi_cfg4_formal_checker (
  input logic       clk,
  input logic       reset,
  input logic       serial_in,
  input logic [2:0] L_ctrl,
  input logic       cfg_done,
  input logic       cfg_ready_now,
  input logic [1:0] cnt,
  input logic       got_marker,
  input logic [2:0] l_tmp
);
  default clocking cb @(posedge clk); endclocking

  a_reset_values: assert property (
    reset |-> (L_ctrl == 3'd2 && cfg_done == 1'b0 && cfg_ready_now == 1'b0)
  );

  default disable iff (reset);

  a_ready_equation: assert property (
    cfg_ready_now == (cfg_done || (!cfg_done && got_marker && (cnt == 2'd2)))
  );

  a_done_sticky: assert property (
    cfg_done |=> cfg_done
  );

  a_lctrl_stable_after_done: assert property (
    cfg_done |=> $stable(L_ctrl)
  );

  a_done_rise_cause: assert property (
    $rose(cfg_done) |-> $past(got_marker && (cnt == 2'd2))
  );

  a_lctrl_load_value: assert property (
    $rose(cfg_done) |-> (L_ctrl == {$past(serial_in), $past(l_tmp[1:0])})
  );

  a_cnt_range: assert property (
    (!cfg_done && got_marker) |-> (cnt <= 2'd2)
  );

  a_marker_set_cause: assert property (
    $rose(got_marker) |-> $past(serial_in)
  );

  a_no_x_outputs: assert property (
    !$isunknown({L_ctrl, cfg_done, cfg_ready_now})
  );

  c_L0: cover property (cfg_done && L_ctrl == 3'd0);
  c_L1: cover property (cfg_done && L_ctrl == 3'd1);
  c_L2: cover property (cfg_done && L_ctrl == 3'd2);
  c_L3: cover property (cfg_done && L_ctrl == 3'd3);
  c_L4: cover property (cfg_done && L_ctrl == 3'd4);
  c_L5: cover property (cfg_done && L_ctrl == 3'd5);
  c_L6: cover property (cfg_done && L_ctrl == 3'd6);
  c_L7: cover property (cfg_done && L_ctrl == 3'd7);
  c_leading_zero_then_marker: cover property (
    (!got_marker && !serial_in) ##1 (!got_marker && serial_in) ##[1:4] cfg_done
  );
endmodule

bind spi_cfg4_nomode spi_cfg4_formal_checker u_spi_cfg4_fchk (
  .clk(clk),
  .reset(reset),
  .serial_in(serial_in),
  .L_ctrl(L_ctrl),
  .cfg_done(cfg_done),
  .cfg_ready_now(cfg_ready_now),
  .cnt(cnt),
  .got_marker(got_marker),
  .l_tmp(l_tmp)
);
