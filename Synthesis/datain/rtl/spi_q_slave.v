`timescale 1ns/1ps

module spi_q_slave #(
  parameter int W = 16
)(
  input  logic         clk,
  input  logic         reset,
  input  logic         en,
  input  logic         din,
  input  logic         mode15_word,

  output logic [W-1:0] word_out
);

  // CHANGED: shreg is now internal and only [W-2:0] (15 bits). Bit 15 of
  //          the old 16-bit shreg was written but never read back, so DC
  //          deleted it (OPT-1207 shreg_reg[15]). word_out stays 16-bit.
  logic [W-2:0] shreg;
  logic [W-1:0] next_shift;

  always_comb begin
	if (mode15_word) begin
	  next_shift[14:0] = {shreg[13:0], din};
	  next_shift[15]   = next_shift[14];
	end else begin
	  next_shift = {shreg[14:0], din};
	end
  end

  always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
	  shreg <= '0;
	end else if (en) begin
	  shreg <= next_shift[W-2:0];
	end
  end

  always_comb word_out = next_shift;

endmodule
