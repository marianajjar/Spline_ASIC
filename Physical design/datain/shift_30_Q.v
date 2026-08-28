`timescale 1ns/1ps
module sample_shift_ntaps_Q #(
  parameter int WL = 16,
  parameter int NTAPS = 10
)(
  input  logic                     clk,
  input  logic                     reset,
  input  logic                     en,
  input  logic [2:0]               L_ctrl,
  input  logic                     shift_strobe,

  input  logic [2:0]               phase_in,

  input  logic signed [WL-1:0]     y0_r,
  input  logic signed [WL-1:0]     y1_r,
  input  logic signed [WL-1:0]     y2_r,
  input  logic signed [WL-1:0]     y3_r,
  input  logic signed [WL-1:0]     y4_r,

  output logic signed [WL-1:0]     x [0:NTAPS-1]
);

  // CHANGED: removed dac_out and sample_en outputs. They were debug-only
  //          duplicates of the shift register and were left unconnected at
  //          the top level, so DC deleted them (OPT-1207). The FIR reads the
  //          x[] delay line directly.
  logic signed [WL-1:0] sample_sel;
  integer i;

  always_comb begin
	unique case (L_ctrl)
	  3'd2: begin
		case (phase_in)
		  3'd0:    sample_sel = y0_r;
		  default: sample_sel = y1_r;
		endcase
	  end

	  3'd3: begin
		case (phase_in)
		  3'd0:    sample_sel = y0_r;
		  3'd1:    sample_sel = y1_r;
		  default: sample_sel = y2_r;
		endcase
	  end

	  3'd4: begin
		case (phase_in)
		  3'd0:    sample_sel = y0_r;
		  3'd1:    sample_sel = y1_r;
		  3'd2:    sample_sel = y2_r;
		  default: sample_sel = y3_r;
		endcase
	  end

	  default: begin
		case (phase_in)
		  3'd0:    sample_sel = y0_r;
		  3'd1:    sample_sel = y1_r;
		  3'd2:    sample_sel = y2_r;
		  3'd3:    sample_sel = y3_r;
		  default: sample_sel = y4_r;
		endcase
	  end
	endcase
  end

  always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
	  for (i = 0; i < NTAPS; i = i + 1)
		x[i] <= '0;

	end else begin
	  if (en && shift_strobe) begin
		for (i = NTAPS-1; i > 0; i = i - 1)
		  x[i] <= x[i-1];
		x[0] <= sample_sel;
	  end
	end
  end

endmodule
