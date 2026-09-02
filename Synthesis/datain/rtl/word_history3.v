`timescale 1ns/1ps

module word_history3 #(
  parameter int WL = 16
)(
  input  logic          clk,
  input  logic          reset,
  input  logic          shift_en,
  input  logic          strobe,
  input  logic [WL-1:0] word_in,
  output logic [WL-1:0] w0, w1, w2
);

  always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
	  w0 <= '0; w1 <= '0; w2 <= '0;
	end else if (!shift_en) begin
	  w0 <= w0; w1 <= w1; w2 <= w2;
	end else if (strobe) begin
	  w2 <= w1;
	  w1 <= w0;
	  w0 <= word_in;
	end
  end

endmodule
