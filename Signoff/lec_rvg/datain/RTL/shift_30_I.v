`timescale 1ns/1ps
module sample_shift_ntaps_I #(
  parameter int WL = 16,
  parameter int NTAPS = 10
)(
  input  logic                     clk,
  input  logic                     reset,
  input  logic                     en,
  input  logic [2:0]               L_ctrl,
  input  logic                     strobe,
  input  logic                     shift_strobe,

  input  logic signed [WL-1:0]     y0_r,
  input  logic signed [WL-1:0]     y1_r,
  input  logic signed [WL-1:0]     y2_r,
  input  logic signed [WL-1:0]     y3_r,
  input  logic signed [WL-1:0]     y4_r,

  output logic signed [WL-1:0]     x [0:NTAPS-1],

  output logic [2:0]               phase_out
);

  logic [2:0]           phase;
  logic signed [WL-1:0] sample_sel;
  integer i;

  assign phase_out = phase;

  // ------------------------------------------------------------
  // Combinational phase -> sample selector
  // ------------------------------------------------------------
  always_comb begin
	unique case (L_ctrl)
	  3'd2: begin
		case (phase)
		  3'd0:    sample_sel = y0_r;
		  default: sample_sel = y1_r;
		endcase
	  end

	  3'd3: begin
		case (phase)
		  3'd0:    sample_sel = y0_r;
		  3'd1:    sample_sel = y1_r;
		  default: sample_sel = y2_r;
		endcase
	  end

	  3'd4: begin
		case (phase)
		  3'd0:    sample_sel = y0_r;
		  3'd1:    sample_sel = y1_r;
		  3'd2:    sample_sel = y2_r;
		  default: sample_sel = y3_r;
		endcase
	  end

	  default: begin   // L = 5
		case (phase)
		  3'd0:    sample_sel = y0_r;
		  3'd1:    sample_sel = y1_r;
		  3'd2:    sample_sel = y2_r;
		  3'd3:    sample_sel = y3_r;
		  default: sample_sel = y4_r;
		endcase
	  end
	endcase
  end

  // ------------------------------------------------------------
  // Registered datapath
  // PATCH: strobe takes priority over shift_strobe for phase.
  //        Fixes phase-stuck-at-(L-1) bug for L=5 (mode15)
  //        where strobe and shift_strobe collide every word
  //        because GCD(15,3) = 3.
  // ------------------------------------------------------------
  always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
	  phase     <= 3'd0;
	  for (i = 0; i < NTAPS; i = i + 1)
		x[i] <= '0;

	end else begin
	  if (!en) begin
		phase <= phase;
	  end else begin
		// shift_strobe processes the shift register
		if (shift_strobe) begin
		  for (i = NTAPS-1; i > 0; i = i - 1)
			x[i] <= x[i-1];
		  x[0] <= sample_sel;
		end

		// phase update: strobe wins over shift_strobe
		if (strobe)
		  phase <= 3'd0;
		else if (shift_strobe && (phase < (L_ctrl - 1)))
		  phase <= phase + 3'd1;
		// else: no NBA -> phase keeps its value
	  end
	end
  end

endmodule
