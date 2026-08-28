`timescale 1ns/1ps

// ============================================================================
// I master
// - During FIR loading: forced 16-bit word mode
// - After FIR loading: normal 15/16-bit mode from L_ctrl
// ============================================================================

module spi_i_master #(
  parameter int W = 16
)(
  input  logic         clk,
  input  logic         reset,
  input  logic         en,
  input  logic         din,
  input  logic [2:0]   L,
  input  logic         force16_word,   // NEW

  output logic [W-1:0] word_out,
  output logic         strobe,
  output logic         shift_strobe,
  output logic         mode15_word
);

  wire mode15_now_raw = (L == 3'd3) || (L == 3'd5);
  wire mode15_now     = force16_word ? 1'b0 : mode15_now_raw;

  logic en_d;
  wire  en_rise = en & ~en_d;

  always_ff @(posedge clk or posedge reset) begin
	if (reset) en_d <= 1'b0;
	else       en_d <= en;
  end

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

  localparam int CW = 4;
  logic [CW-1:0] count;

  wire [CW-1:0] term = mode15_word ? 4'd14 : 4'd15;

  always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
	  count       <= '0;
	  mode15_word <= 1'b0;
	end else if (en_rise) begin
	  count       <= '0;
	  mode15_word <= mode15_now;
	end else if (!en) begin
	  count       <= count;
	  mode15_word <= mode15_word;
	end else begin
	  if (count == 0)
		mode15_word <= mode15_now;

	  if (count == term)
		count <= '0;
	  else
		count <= count + 1'b1;
	end
  end

  always_comb strobe = en && (count == term);

  logic [3:0] step_cnt, div_val;

  always_comb begin
	case (L)
	  3'd2: div_val = 4'd8;
	  3'd3: div_val = 4'd5;
	  3'd4: div_val = 4'd4;
	  3'd5: div_val = 4'd3;
	  default: div_val = 4'd8;
	endcase
  end

  always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
	  step_cnt     <= 4'd0;
	  shift_strobe <= 1'b0;
	end else if (en_rise) begin
	  step_cnt     <= 4'd0;
	  shift_strobe <= 1'b0;
	end else if (!en) begin
	  step_cnt     <= step_cnt;
	  shift_strobe <= 1'b0;
	end else begin
	  shift_strobe <= 1'b0;
	  if (step_cnt == (div_val - 1)) begin
		step_cnt     <= 4'd0;
		shift_strobe <= 1'b1;
	  end else begin
		step_cnt <= step_cnt + 1'b1;
	  end
	end
  end

endmodule
