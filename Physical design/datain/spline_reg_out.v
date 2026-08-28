`timescale 1ns/1ps
// ============================================================================
// minaj2_window_latch
// - Holds y0..y4 stable between word strobes
// - enable-based style: synthesis can infer clock gating
// ============================================================================

module minaj2_window_latch #(
  parameter int WL = 16
)(
  input  logic                 clk,
  input  logic                 reset,
  input  logic                 en,
  input  logic                 strobe,

  input  logic signed [WL-1:0] y0,
  input  logic signed [WL-1:0] y1,
  input  logic signed [WL-1:0] y2,
  input  logic signed [WL-1:0] y3,
  input  logic signed [WL-1:0] y4,

  output logic signed [WL-1:0] y0_r,
  output logic signed [WL-1:0] y1_r,
  output logic signed [WL-1:0] y2_r,
  output logic signed [WL-1:0] y3_r,
  output logic signed [WL-1:0] y4_r
);

  always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
	  y0_r <= '0; y1_r <= '0; y2_r <= '0; y3_r <= '0; y4_r <= '0;
	end else if (!en) begin
	  // hold (lets synthesis infer clock gating)
	  y0_r <= y0_r; y1_r <= y1_r; y2_r <= y2_r; y3_r <= y3_r; y4_r <= y4_r;
	end else if (strobe) begin
	  y0_r <= y0;
	  y1_r <= y1;
	  y2_r <= y2;
	  y3_r <= y3;
	  y4_r <= y4;
	end
  end

endmodule
