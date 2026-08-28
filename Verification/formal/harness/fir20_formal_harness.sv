`timescale 1ns/1ps

module fir20_formal_harness #(
  parameter int WL = 16,
  parameter int FL = 12,
  parameter int NTAPS = 10
) (
  input  logic                     clk,
  input  logic                     reset,
  input  logic                     en,
  input  logic signed [WL-1:0]     x [0:NTAPS-1],
  input  logic                     coeff_load_en,
  input  logic                     coeff_strobe,
  input  logic signed [WL-1:0]     coeff_word,
  output logic signed [WL-1:0]     y
);

  fir20_q16_fromx #(.WL(WL), .FL(FL), .NTAPS(NTAPS)) DUT (
    .clk(clk),
    .reset(reset),
    .en(en),
    .x(x),
    .coeff_load_en(coeff_load_en),
    .coeff_strobe(coeff_strobe),
    .coeff_word(coeff_word),
    .y(y)
  );
endmodule
