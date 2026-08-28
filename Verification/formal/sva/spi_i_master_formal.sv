`timescale 1ns/1ps

module spi_i_master_formal_checker #(parameter int W = 16) (
  input logic         clk,
  input logic         reset,
  input logic         en,
  input logic         din,
  input logic [2:0]   L,
  input logic         force16_word,
  input logic [W-1:0] word_out,
  input logic         strobe,
  input logic         shift_strobe,
  input logic         mode15_word,
  input logic [3:0]   count,
  input logic [3:0]   step_cnt,
  input logic         en_d,
  input logic [W-2:0] shreg
);
  default clocking cb @(posedge clk); endclocking
  default disable iff (reset);

  function automatic logic mode15_now(input logic [2:0] lv, input logic f16);
    mode15_now = f16 ? 1'b0 : ((lv == 3'd3) || (lv == 3'd5));
  endfunction

  function automatic logic [3:0] term_now(input logic m15);
    term_now = m15 ? 4'd14 : 4'd15;
  endfunction

  function automatic logic [3:0] div_now(input logic [2:0] lv);
    case (lv)
      3'd2: div_now = 4'd8;
      3'd3: div_now = 4'd5;
      3'd4: div_now = 4'd4;
      3'd5: div_now = 4'd3;
      default: div_now = 4'd8;
    endcase
  endfunction

  wire en_rise = en && !en_d;

  // Real top keeps L and force16 stable during an active serial word.
  am_mode_inputs_stable_while_enabled: assume property (
    en && $past(en) |-> (L == $past(L) && force16_word == $past(force16_word))
  );

  a_strobe_equation: assert property (
    strobe == (en && (count == term_now(mode15_word)))
  );

  a_strobe_one_cycle: assert property (
    strobe |=> !strobe
  );

  a_shift_strobe_one_cycle: assert property (
    shift_strobe |=> !shift_strobe
  );

  a_count_range: assert property (
    en |-> (count <= term_now(mode15_word))
  );

  a_en_rise_clears_count: assert property (
    $rose(en) |=> (count == 4'd0)
  );

  a_mode15_loads_on_en_rise: assert property (
    en_rise |=> (mode15_word == $past(mode15_now(L, force16_word)))
  );

  a_mode15_change_only_at_boundary: assert property (
    !$past(reset) && (mode15_word != $past(mode15_word)) |->
      ($past(en_rise) || ($past(count) == 4'd0))
  );

  a_no_strobe_when_disabled: assert property (
    !en |-> !strobe
  );

  a_shift_strobe_clears_when_disabled: assert property (
    !en |=> !shift_strobe
  );

  a_word15_signext: assert property (
    mode15_word |-> (word_out[15] == word_out[14])
  );

  a_shreg_loads_when_enabled: assert property (
    en |=> (shreg == $past(word_out[14:0]))
  );

  a_shreg_holds_when_disabled: assert property (
    !en |=> $stable(shreg)
  );

  a_stepcnt_range: assert property (
    en && $past(en) && (L == $past(L)) |-> (step_cnt < div_now(L))
  );

  c_mode15: cover property (en && mode15_word);
  c_mode16: cover property (en && !mode15_word);
  c_strobe: cover property (strobe);
  c_shift_strobe: cover property (shift_strobe);
  c_force16_L5: cover property (en && force16_word && L == 3'd5 && !mode15_word);
endmodule

bind spi_i_master spi_i_master_formal_checker #(.W(W)) u_spi_i_fchk (
  .clk(clk),
  .reset(reset),
  .en(en),
  .din(din),
  .L(L),
  .force16_word(force16_word),
  .word_out(word_out),
  .strobe(strobe),
  .shift_strobe(shift_strobe),
  .mode15_word(mode15_word),
  .count(count),
  .step_cnt(step_cnt),
  .en_d(en_d),
  .shreg(shreg)
);
