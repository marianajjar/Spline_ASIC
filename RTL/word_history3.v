`timescale 1ns/1ps
// ============================================================================
// SPI split #2: 3-word history
// CHANGED: was word_history4 (w0..w3). The spline interpolator only uses
//          3 samples (w0=x_n, w1=x_c, w2=x_prev), so w3 was always dead and
//          DC deleted it (OPT-1207). Removed w3 entirely for a clean LEC.
// ============================================================================

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
