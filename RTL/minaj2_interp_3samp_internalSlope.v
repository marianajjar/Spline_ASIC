`timescale 1ns/1ps
// ============================================================================
// minaj2_interp_3samp_internalSlope  (COMBINED: core + wrapper)
// - Uses 3 samples: x_prev, x_c, x_n
// - Stores previous slope m_p internally
// - Updates m_p at each strobe (new word)
// - Computes m_new and polynomial coeffs c0..c3 internally
// - Outputs y0..y4 (y0 = x_prev)
// ============================================================================
module minaj2_interp_3samp_internalSlope (
  input  logic               clk,
  input  logic               reset,
  input  logic               en,
  input  logic               strobe,     // update m_p once per new input word
  input  logic [2:0]         L_ctrl,     // 2..5
  input  logic signed [15:0] x_prev,
  input  logic signed [15:0] x_c,
  input  logic signed [15:0] x_n,
  output logic signed [15:0] y0, y1, y2, y3, y4
);

  // -------------------------
  // Internal slope register
  // -------------------------
  logic signed [15:0] m_p;
  logic signed [15:0] m_new;

  // Polynomial coefficients
  logic signed [17:0] c0, c1, c2, c3;

  // ========================================================
  // (A) MinAJ2 CORE MATH (combinational)
  // Sum = -11*x_prev - 4*m_p + 8*x_c + 3*x_n
  // m_new ~ Sum/10 via *1638 >> 14   (now WITH rounding)
  // coeffs for Hermite cubic segment x_prev -> x_c
  // ========================================================
  logic signed [21:0] term_11_xp;
  logic signed [21:0] term_4_mp;
  logic signed [21:0] term_8_xc;
  logic signed [21:0] term_3_xn;
  logic signed [21:0] Sum;

  logic signed [36:0] mult_res;
  logic signed [23:0] raw_m;

  logic signed [16:0] delta;
  logic signed [18:0] term_3delta;
  logic signed [18:0] term_2m0;
  logic signed [18:0] term_2delta;

  // half-LSB rounding constant for >>> 14  (2^13)
  localparam logic signed [36:0] RND14 = 37'sh00_0000_2000;

  always_comb begin
	term_11_xp = (x_prev <<< 3) + (x_prev <<< 1) + x_prev; // 11=8+2+1
	term_4_mp  = (m_p   <<< 2);                             // 4*m_p
	term_8_xc  = (x_c   <<< 3);                             // 8*x_c
	term_3_xn  = (x_n   <<< 1) + x_n;                       // 3*x_n

	Sum      = term_8_xc + term_3_xn - term_11_xp - term_4_mp;
	mult_res = $signed(Sum) * 16'sd1638;

	// PATCH: add half-LSB bias so >>> 14 rounds to nearest instead of floors
	raw_m    = (mult_res + RND14) >>> 14;

	if (raw_m > 24'sd32767)
	  m_new = 16'sd32767;
	else if (raw_m < -24'sd32768)
	  m_new = $signed({1'b1, 15'd0}); // -32768
	else
	  m_new = $signed(raw_m[15:0]);

	// coeffs (segment P0=x_prev -> P1=x_c, M0=m_p, M1=m_new)
	c0 = x_prev;
	c1 = m_p;

	delta       = x_c - x_prev;
	term_3delta = (delta <<< 1) + delta;
	term_2m0    = m_p <<< 1;
	c2          = term_3delta - term_2m0 - m_new;

	term_2delta = delta <<< 1;
	c3          = m_p + m_new - term_2delta;
  end

  // ========================================================
  // (B) Update slope once per word
  // ========================================================
  always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
	  m_p <= 16'sd0;
	end else if (!en) begin
	  m_p <= m_p;
	end else if (strobe) begin
	  m_p <= m_new;
	end
  end

  // ========================================================
  // (C) U values (Q1.15)
  // ========================================================
  localparam signed [15:0] U_0_20 = 16'sd6554;
  localparam signed [15:0] U_0_25 = 16'sd8192;
  localparam signed [15:0] U_0_33 = 16'sd10923;
  localparam signed [15:0] U_0_40 = 16'sd13107;
  localparam signed [15:0] U_0_50 = 16'sd16384;
  localparam signed [15:0] U_0_60 = 16'sd19661;
  localparam signed [15:0] U_0_66 = 16'sd21845;
  localparam signed [15:0] U_0_75 = 16'sd24576;
  localparam signed [15:0] U_0_80 = 16'sd26214;

  // ========================================================
  // (D) Horner eval  (PATCHED: rounding bias before each >>> 15)
  // ========================================================
  function automatic signed [15:0] eval_poly;
	input signed [17:0] C0i, C1i, C2i, C3i;
	input signed [15:0] U_VAL;
	reg signed [35:0] t1, t2, t3;
	// half-LSB rounding constant for >>> 15  (2^14)
	localparam signed [35:0] RND15 = 36'sh0_0000_4000;
	begin
	  // PATCH: add RND15 before each shift so we round-to-nearest
	  // instead of flooring (which created -1.5 LSB DC bias).
	  t1 = ( $signed(C3i) * $signed(U_VAL) + RND15 ) >>> 15;
	  t1 = t1 + $signed(C2i);
	  t2 = ( $signed(t1)  * $signed(U_VAL) + RND15 ) >>> 15;
	  t2 = t2 + $signed(C1i);
	  t3 = ( $signed(t2)  * $signed(U_VAL) + RND15 ) >>> 15;
	  t3 = t3 + $signed(C0i);
	  eval_poly = $signed(t3[15:0]);
	end
  endfunction

  // ========================================================
  // (E) Outputs
  // ========================================================
  always_comb begin
	y0 = x_prev;
	y1 = 16'sd0; y2 = 16'sd0; y3 = 16'sd0; y4 = 16'sd0;
	unique case (L_ctrl)
	  3'd2: begin
		y1 = eval_poly(c0,c1,c2,c3, U_0_50);
	  end
	  3'd3: begin
		y1 = eval_poly(c0,c1,c2,c3, U_0_33);
		y2 = eval_poly(c0,c1,c2,c3, U_0_66);
	  end
	  3'd4: begin
		y1 = eval_poly(c0,c1,c2,c3, U_0_25);
		y2 = eval_poly(c0,c1,c2,c3, U_0_50);
		y3 = eval_poly(c0,c1,c2,c3, U_0_75);
	  end
	  default: begin
		y1 = eval_poly(c0,c1,c2,c3, U_0_20);
		y2 = eval_poly(c0,c1,c2,c3, U_0_40);
		y3 = eval_poly(c0,c1,c2,c3, U_0_60);
		y4 = eval_poly(c0,c1,c2,c3, U_0_80);
	  end
	endcase
  end
endmodule
