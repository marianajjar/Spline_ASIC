`timescale 1ns/1ps

module spi_q_slave_formal_checker #(parameter int W = 16) (
  input logic         clk,
  input logic         reset,
  input logic         en,
  input logic         din,
  input logic         mode15_word,
  input logic [W-1:0] word_out,
  input logic [W-2:0] shreg
);
  default clocking cb @(posedge clk); endclocking
  default disable iff (reset);

  a_word15_signext: assert property (
    mode15_word |-> (word_out[15] == word_out[14])
  );

  a_shreg_loads_when_enabled: assert property (
    en |=> (shreg == $past(word_out[14:0]))
  );

  a_shreg_holds_when_disabled: assert property (
    !en |=> $stable(shreg)
  );

  a_no_x_word: assert property (
    !$isunknown(word_out)
  );

  c_mode15: cover property (en && mode15_word);
  c_mode16: cover property (en && !mode15_word);
endmodule

bind spi_q_slave spi_q_slave_formal_checker #(.W(W)) u_spi_q_fchk (
  .clk(clk),
  .reset(reset),
  .en(en),
  .din(din),
  .mode15_word(mode15_word),
  .word_out(word_out),
  .shreg(shreg)
);
