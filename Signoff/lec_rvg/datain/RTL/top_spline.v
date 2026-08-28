`timescale 1ns/1ps
module top_interpolator_dac #(
  parameter int WL    = 16,
  parameter int FL    = 12,
  parameter int NTAPS = 10
)(
  input  wire                 clk,
  input  wire                 reset,
  input  wire                 serial_in_I,
  input  wire                 serial_in_Q,
  output wire signed [WL-1:0] dac_I,
  output wire signed [WL-1:0] dac_Q
);

  localparam int CFW = (NTAPS <= 1) ? 1 : $clog2(NTAPS+1);

  // ============================
  // 0) Auto config capture
  // ============================
  wire [2:0] L_ctrl_int;
  wire       cfg_ready_now;

  spi_cfg4_nomode cfg_u (
	.clk          (clk),
	.reset        (reset),
	.serial_in    (serial_in_I),
	.L_ctrl       (L_ctrl_int),
	.cfg_done     (),
	.cfg_ready_now(cfg_ready_now)
  );

  wire en_stream = cfg_ready_now;

  // ============================
  // 1) SPI signals
  // ============================
  wire [WL-1:0] word_I, word_Q;
  wire          strobe_common;
  wire          shift_strobe_common;
  wire          mode15_word;

  // ============================
  // 1.5) FIR coefficient loading control
  // - after config, load NTAPS words (16-bit each)
  // - only after that IQ path starts
  // ============================
  reg [CFW-1:0] coeff_count;
  reg           coeff_done;

  wire coeff_load_mode = en_stream && !coeff_done;
  wire en_iq           = en_stream && coeff_done;

  always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
	  coeff_count <= '0;
	  coeff_done  <= 1'b0;
	end else if (!en_stream) begin
	  coeff_count <= coeff_count;
	  coeff_done  <= coeff_done;
	end else if (!coeff_done && strobe_common) begin
	  if (coeff_count == NTAPS-1) begin
		coeff_done  <= 1'b1;
		coeff_count <= coeff_count;
	  end else begin
		coeff_count <= coeff_count + 1'b1;
	  end
	end
  end

  // ============================
  // 2) SPI: I master + Q slave
  // - During coeff load: I master is forced to 16-bit words
  // ============================
  spi_i_master #(.W(WL)) spi_I (
	.clk          (clk),
	.reset        (reset),
	.en           (en_stream),
	.din          (serial_in_I),
	.L            (L_ctrl_int),
	.force16_word (coeff_load_mode),
	.word_out     (word_I),
	.strobe       (strobe_common),
	.shift_strobe (shift_strobe_common),
	.mode15_word  (mode15_word)
  );

  spi_q_slave #(.W(WL)) spi_Q (
	.clk         (clk),
	.reset       (reset),
	.en          (en_stream),
	.din         (serial_in_Q),
	.mode15_word (mode15_word),
	.word_out    (word_Q)
  );

  wire strobe_iq       = strobe_common       && coeff_done;
  wire shift_strobe_iq = shift_strobe_common && coeff_done;

  // ============================
  // 3) 4-word history
  // ============================
  wire [WL-1:0] w0_I, w1_I, w2_I;
  wire [WL-1:0] w0_Q, w1_Q, w2_Q;

  word_history3 #(.WL(WL)) hist_I (
	.clk      (clk),
	.reset    (reset),
	.shift_en (en_iq),
	.strobe   (strobe_iq),
	.word_in  (word_I),
	.w0       (w0_I),
	.w1       (w1_I),
	.w2       (w2_I)
  );

  word_history3 #(.WL(WL)) hist_Q (
	.clk      (clk),
	.reset    (reset),
	.shift_en (en_iq),
	.strobe   (strobe_iq),
	.word_in  (word_Q),
	.w0       (w0_Q),
	.w1       (w1_Q),
	.w2       (w2_Q)
  );

  // ============================
  // 4) MinAJ2 interpolation
  // ============================
  wire signed [WL-1:0] xprev_I = $signed(w2_I);
  wire signed [WL-1:0] xc_I    = $signed(w1_I);
  wire signed [WL-1:0] xn_I    = $signed(w0_I);

  wire signed [WL-1:0] xprev_Q = $signed(w2_Q);
  wire signed [WL-1:0] xc_Q    = $signed(w1_Q);
  wire signed [WL-1:0] xn_Q    = $signed(w0_Q);

  wire signed [WL-1:0] y0_I, y1_I, y2_I, y3_I, y4_I;
  wire signed [WL-1:0] y0_Q, y1_Q, y2_Q, y3_Q, y4_Q;

  minaj2_interp_3samp_internalSlope minaj2_I (
	.clk    (clk),
	.reset  (reset),
	.en     (en_iq),
	.strobe (strobe_iq),
	.L_ctrl (L_ctrl_int),
	.x_prev (xprev_I),
	.x_c    (xc_I),
	.x_n    (xn_I),
	.y0     (y0_I),
	.y1     (y1_I),
	.y2     (y2_I),
	.y3     (y3_I),
	.y4     (y4_I)
  );

  minaj2_interp_3samp_internalSlope minaj2_Q (
	.clk    (clk),
	.reset  (reset),
	.en     (en_iq),
	.strobe (strobe_iq),
	.L_ctrl (L_ctrl_int),
	.x_prev (xprev_Q),
	.x_c    (xc_Q),
	.x_n    (xn_Q),
	.y0     (y0_Q),
	.y1     (y1_Q),
	.y2     (y2_Q),
	.y3     (y3_Q),
	.y4     (y4_Q)
  );

  // ============================
  // 5) Latch output window
  // ============================
  wire signed [WL-1:0] y0_I_lat, y1_I_lat, y2_I_lat, y3_I_lat, y4_I_lat;
  wire signed [WL-1:0] y0_Q_lat, y1_Q_lat, y2_Q_lat, y3_Q_lat, y4_Q_lat;

  minaj2_window_latch #(.WL(WL)) latch_I (
	.clk    (clk),
	.reset  (reset),
	.en     (en_iq),
	.strobe (strobe_iq),
	.y0     (y0_I),
	.y1     (y1_I),
	.y2     (y2_I),
	.y3     (y3_I),
	.y4     (y4_I),
	.y0_r   (y0_I_lat),
	.y1_r   (y1_I_lat),
	.y2_r   (y2_I_lat),
	.y3_r   (y3_I_lat),
	.y4_r   (y4_I_lat)
  );

  minaj2_window_latch #(.WL(WL)) latch_Q (
	.clk    (clk),
	.reset  (reset),
	.en     (en_iq),
	.strobe (strobe_iq),
	.y0     (y0_Q),
	.y1     (y1_Q),
	.y2     (y2_Q),
	.y3     (y3_Q),
	.y4     (y4_Q),
	.y0_r   (y0_Q_lat),
	.y1_r   (y1_Q_lat),
	.y2_r   (y2_Q_lat),
	.y3_r   (y3_Q_lat),
	.y4_r   (y4_Q_lat)
  );

  // ============================
  // 6) Shift / phase
  // ============================
  wire signed [WL-1:0] sr_I [0:NTAPS-1];
  wire signed [WL-1:0] sr_Q [0:NTAPS-1];

  wire [2:0] phase_shared;

  sample_shift_ntaps_I #(.WL(WL), .NTAPS(NTAPS)) shift_I (
	.clk          (clk),
	.reset        (reset),
	.en           (en_iq),
	.L_ctrl       (L_ctrl_int),
	.strobe       (strobe_iq),
	.shift_strobe (shift_strobe_iq),
	.y0_r         (y0_I_lat),
	.y1_r         (y1_I_lat),
	.y2_r         (y2_I_lat),
	.y3_r         (y3_I_lat),
	.y4_r         (y4_I_lat),
	.x            (sr_I),
	.phase_out    (phase_shared)
  );

  sample_shift_ntaps_Q #(.WL(WL), .NTAPS(NTAPS)) shift_Q (
	.clk          (clk),
	.reset        (reset),
	.en           (en_iq),
	.L_ctrl       (L_ctrl_int),
	.shift_strobe (shift_strobe_iq),
	.phase_in     (phase_shared),
	.y0_r         (y0_Q_lat),
	.y1_r         (y1_Q_lat),
	.y2_r         (y2_Q_lat),
	.y3_r         (y3_Q_lat),
	.y4_r         (y4_Q_lat),
	.x            (sr_Q)
  );

  // ============================
  // 7) FIR
  // - load coeffs from word_I during coeff_load_mode
  // ============================
  wire signed [WL-1:0] fir_I, fir_Q;

  fir20_q16_fromx #(.WL(WL), .FL(FL), .NTAPS(NTAPS)) fir_I_u (
	.clk           (clk),
	.reset         (reset),
	.en            (shift_strobe_iq),
	.x             (sr_I),
	.coeff_load_en (coeff_load_mode),
	.coeff_strobe  (strobe_common),
	.coeff_word    ($signed(word_I)),
	.y             (fir_I)
  );

  fir20_q16_fromx #(.WL(WL), .FL(FL), .NTAPS(NTAPS)) fir_Q_u (
	.clk           (clk),
	.reset         (reset),
	.en            (shift_strobe_iq),
	.x             (sr_Q),
	.coeff_load_en (coeff_load_mode),
	.coeff_strobe  (strobe_common),
	.coeff_word    ($signed(word_I)),
	.y             (fir_Q)
  );

  assign dac_I = fir_I;
  assign dac_Q = fir_Q;

endmodule
