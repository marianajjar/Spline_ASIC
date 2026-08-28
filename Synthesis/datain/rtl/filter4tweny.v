`timescale 1ns/1ps
// ============================================================================
// Runtime-loaded FIR, Q16.12
// - Coefficients are loaded serially through word_I before IQ data starts
// - Same loaded coefficients are used for I and Q FIRs
// - Added simple checker register: check <= coeff_word
// ============================================================================

module fir20_q16_fromx #(
  parameter int WL    = 16,
  parameter int FL    = 14,
  parameter int NTAPS = 20
)(
  input  logic                        clk,
  input  logic                        reset,
  input  logic                        en,
  input  logic signed [WL-1:0]        x [0:NTAPS-1],

  // runtime coefficient loading
  input  logic                        coeff_load_en,
  input  logic                        coeff_strobe,
  input  logic signed [WL-1:0]        coeff_word,

  output logic signed [WL-1:0]        y
);

  localparam int ACC_W = 48;
  localparam int CW    = (NTAPS <= 1) ? 1 : $clog2(NTAPS);

  logic signed [WL-1:0] coeffs [0:NTAPS-1];
  logic [CW-1:0]        load_idx;

  logic signed [ACC_W-1:0] fir_acc;
  logic signed [ACC_W-1:0] fir_shift;
  logic signed [WL-1:0]    y_next;

  // ============================
  // NEW: checker register
  // ============================
  logic signed [WL-1:0] check;

  localparam logic signed [ACC_W-1:0] RND =
	(FL == 0) ? '0 : ({{(ACC_W-FL){1'b0}}, (1'sb1 <<< (FL-1))});

  // CHANGED: written as explicit bit patterns to avoid the signed/unsigned
  //          mix in (1 <<< (WL-1)) which triggered VER-318. Same values:
  //          MAXQ = 0x7FFF (+32767), MINQ = 0x8000 (-32768).
  localparam logic signed [WL-1:0] MAXQ = {1'b0, {(WL-1){1'b1}}};
  localparam logic signed [WL-1:0] MINQ = {1'b1, {(WL-1){1'b0}}};

  integer k, i;

  // ----------------------------
  // Load coefficients serially as 16-bit words
  // ----------------------------
  always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
	  load_idx <= '0;
	  check    <= '0;
	  for (i = 0; i < NTAPS; i = i + 1)
		coeffs[i] <= '0;
	  y <= '0;

	end else begin
	  if (!coeff_load_en) begin
		check <= check;
	  end else if (coeff_strobe) begin
		coeffs[load_idx] <= coeff_word;

		// ============================
		// checker: last loaded coefficient
		// ============================
		check <= coeff_word;

		if (load_idx == $unsigned(NTAPS-1))
		  load_idx <= load_idx;
		else
		  load_idx <= load_idx + 1'b1;
	  end

	  if (en)
		y <= y_next;
	end
  end

  // ----------------------------
  // FIR MAC
  // ----------------------------
  always_comb begin
	fir_acc = '0;
	for (k = 0; k < NTAPS; k = k + 1)
	  fir_acc += $signed(x[k]) * $signed(coeffs[k]);

	fir_shift = (fir_acc + RND) >>> FL;

	if      (fir_shift > MAXQ) y_next = MAXQ;
	else if (fir_shift < MINQ) y_next = MINQ;
	else                       y_next = $signed(fir_shift[WL-1:0]);
  end

endmodule
