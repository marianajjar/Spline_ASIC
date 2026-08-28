`timescale 1ns/1ps
// ============================================================================
// tb_fir.sv
// Block-level testbench for fir20_q16_fromx (filter4tweny.v)
//
// Real chip parameters:
//   WL    = 16
//   FL    = 12
//   NTAPS = 10
//
// Important:
//   The current RTL uses:
//      RND = {{(ACC_W-FL){1'b0}}, (1'sb1 <<< (FL-1))}
//   Because 1'sb1 is a 1-bit literal, the shift overflows to 0.
//   So the current RTL behavior is TRUNC/FLOOR:
//      y = sat(fir_acc >>> FL)
//
// This TB checks the CURRENT RTL behavior bit-exactly.
// It also prints an INFO message for vectors where ideal rounding would differ.
// ============================================================================

module tb_fir;

  localparam int WL         = 16;
  localparam int FL         = 12;
  localparam int NTAPS      = 10;
  localparam int ACC_W      = 48;
  localparam real CLK_PERIOD = 1.0;
  localparam logic signed [WL-1:0] MAXQ = {1'b0, {(WL-1){1'b1}}};
  localparam logic signed [WL-1:0] MINQ = {1'b1, {(WL-1){1'b0}}};

  logic clk;
  initial clk = 1'b0;
  always #(CLK_PERIOD/2.0) clk = ~clk;

  logic                         reset;
  logic                         en;
  logic signed [WL-1:0]         x [0:NTAPS-1];
  logic                         coeff_load_en;
  logic                         coeff_strobe;
  logic signed [WL-1:0]         coeff_word;
  logic signed [WL-1:0]         y;

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

  int pass_count;
  int fail_count;
  logic checks_on;
  logic trunc_corner_hit;
  logic pos_sat_hit;
  logic neg_sat_hit;

  logic signed [WL-1:0] ref_coeffs [0:NTAPS-1];
  int ref_load_idx;
  logic signed [WL-1:0] ref_check;
  logic signed [WL-1:0] last_exp_trunc;

  task automatic wait_clk;
	begin
	  @(posedge clk);
	  #0.001;
	end
  endtask

  function automatic longint signed sat16(input longint signed v);
	begin
	  if (v > 32767) sat16 = 32767;
	  else if (v < -32768) sat16 = -32768;
	  else sat16 = v;
	end
  endfunction

  function automatic longint signed s16_to_long(input logic signed [WL-1:0] v);
	begin
	  s16_to_long = v;
	end
  endfunction

  function automatic longint signed fir_acc_ref;
	longint signed acc;
	begin
	  acc = 0;
	  for (int k = 0; k < NTAPS; k++) begin
		acc = acc + (s16_to_long(x[k]) * s16_to_long(ref_coeffs[k]));
	  end
	  fir_acc_ref = acc;
	end
  endfunction

  function automatic logic signed [WL-1:0] fir_ref(input bit use_rounding);
	longint signed acc;
	longint signed shifted;
	longint signed bias;
	longint signed satv;
	logic signed [WL-1:0] sat_bits;
	begin
	  acc = fir_acc_ref();
	  bias = use_rounding ? (64'sd1 <<< (FL-1)) : 64'sd0;
	  shifted = (acc + bias) >>> FL;
	  satv = sat16(shifted);
	  sat_bits = satv;
	  fir_ref = sat_bits;
	end
  endfunction

  task automatic chk_w(input string tag, input logic signed [WL-1:0] got, exp);
	begin
	  if (got === exp) begin
		$display("  PASS  [%s] got=%0d exp=%0d", tag, got, exp);
		pass_count++;
	  end else begin
		$display("  FAIL  [%s] got=%0d exp=%0d  <---", tag, got, exp);
		fail_count++;
	  end
	end
  endtask

  task automatic chk_i(input string tag, input int got, exp);
	begin
	  if (got == exp) begin
		$display("  PASS  [%s] got=%0d exp=%0d", tag, got, exp);
		pass_count++;
	  end else begin
		$display("  FAIL  [%s] got=%0d exp=%0d  <---", tag, got, exp);
		fail_count++;
	  end
	end
  endtask

  task automatic clear_x;
	begin
	  for (int k = 0; k < NTAPS; k++) x[k] = '0;
	end
  endtask

  task automatic clear_ref;
	begin
	  for (int k = 0; k < NTAPS; k++) ref_coeffs[k] = '0;
	  ref_load_idx = 0;
	  ref_check = '0;
	  last_exp_trunc = '0;
	  trunc_corner_hit = 1'b0;
	  pos_sat_hit = 1'b0;
	  neg_sat_hit = 1'b0;
	end
  endtask

  task automatic do_reset;
	begin
	  reset = 1'b1;
	  en = 1'b0;
	  coeff_load_en = 1'b0;
	  coeff_strobe = 1'b0;
	  coeff_word = '0;
	  clear_x();
	  clear_ref();

	  repeat (3) wait_clk();
	  reset = 1'b0;
	  wait_clk();

	  chk_w("reset/y", y, '0);
	  chk_i("reset/load_idx", DUT.load_idx, 0);
	  chk_w("reset/check", DUT.check, '0);
	end
  endtask

  task automatic load_coeff(input logic signed [WL-1:0] cw);
	begin
	  coeff_load_en = 1'b1;
	  coeff_strobe = 1'b1;
	  coeff_word = cw;
	  en = 1'b0;

	  wait_clk();

	  ref_coeffs[ref_load_idx] = cw;
	  ref_check = cw;
	  if (ref_load_idx < NTAPS-1) ref_load_idx++;

	  coeff_strobe = 1'b0;
	  coeff_load_en = 1'b0;
	  coeff_word = '0;
	end
  endtask

  task automatic load_all_zero;
	begin
	  do_reset();
	  for (int k = 0; k < NTAPS; k++) load_coeff(16'sd0);
	end
  endtask

  task automatic load_unity_tap0;
	begin
	  do_reset();
	  load_coeff(16'sd4096);
	  for (int k = 1; k < NTAPS; k++) load_coeff(16'sd0);
	end
  endtask

  task automatic compute_and_check(input string tag);
	logic signed [WL-1:0] exp_trunc;
	logic signed [WL-1:0] exp_round;
	longint signed acc;
	begin
	  exp_trunc = fir_ref(1'b0);
	  exp_round = fir_ref(1'b1);
	  acc = fir_acc_ref();
	  last_exp_trunc = exp_trunc;

	  if ((acc < 0) && ((acc & ((64'sd1 <<< FL)-1)) != 0)) begin
		trunc_corner_hit = 1'b1;
	  end
	  if (exp_trunc == MAXQ) pos_sat_hit = 1'b1;
	  if (exp_trunc == MINQ) neg_sat_hit = 1'b1;

	  en = 1'b1;
	  coeff_load_en = 1'b0;
	  coeff_strobe = 1'b0;
	  wait_clk();
	  en = 1'b0;

	  chk_w(tag, y, exp_trunc);

	  if (exp_trunc !== exp_round) begin
		$display("  INFO  [%s] trunc=%0d ideal_round=%0d acc=%0d", tag, exp_trunc, exp_round, acc);
	  end
	end
  endtask

  property p_no_x;
	@(posedge clk) disable iff (reset)
	  checks_on |-> !$isunknown(y);
  endproperty
  a_no_x: assert property (p_no_x) else begin $error("FIR y has X/Z"); fail_count++; end

  property p_y_frozen;
	@(posedge clk) disable iff (reset)
	  checks_on && !en |=> $stable(y);
  endproperty
  a_y_frozen: assert property (p_y_frozen) else begin $error("FIR y changed while en=0"); fail_count++; end

  property p_loadidx_sat;
	@(posedge clk) disable iff (reset)
	  checks_on && coeff_load_en && coeff_strobe && (DUT.load_idx == NTAPS-1) |=> (DUT.load_idx == NTAPS-1);
  endproperty
  a_loadidx_sat: assert property (p_loadidx_sat) else begin $error("load_idx did not saturate"); fail_count++; end

  property p_check_loads;
	@(posedge clk) disable iff (reset)
	  checks_on && coeff_load_en && coeff_strobe |=> (DUT.check == $past(coeff_word));
  endproperty
  a_check_loads: assert property (p_check_loads) else begin $error("check did not load coeff_word"); fail_count++; end

  property p_check_holds;
	@(posedge clk) disable iff (reset)
	  checks_on && !coeff_load_en |=> $stable(DUT.check);
  endproperty
  a_check_holds: assert property (p_check_holds) else begin $error("check changed when coeff_load_en=0"); fail_count++; end

  covergroup cg @(posedge clk);
	cp_en: coverpoint en { bins lo={0}; bins hi={1}; }
	cp_coeff_load_en: coverpoint coeff_load_en { bins lo={0}; bins hi={1}; }
	cp_load_idx: coverpoint DUT.load_idx { bins idx[] = {[0:NTAPS-1]}; }
	cp_y_sat: coverpoint y {
	  bins pos_clamp = {MAXQ};
	  bins neg_clamp = {MINQ};
	  bins mid       = {[-16'sd32767:16'sd32766]};
	}
	cp_trunc_corner: coverpoint trunc_corner_hit { bins hit={1}; bins no={0}; }
	cp_pos_sat: coverpoint pos_sat_hit { bins hit={1}; bins no={0}; }
	cp_neg_sat: coverpoint neg_sat_hit { bins hit={1}; bins no={0}; }
	x_en_load: cross cp_en, cp_coeff_load_en;
  endgroup
  cg cov_inst = new();

  initial begin
	pass_count = 0;
	fail_count = 0;
	checks_on = 0;
	reset = 1'b1;
	en = 1'b0;
	coeff_load_en = 1'b0;
	coeff_strobe = 1'b0;
	coeff_word = '0;
	clear_x();
	clear_ref();

	repeat (4) wait_clk();
	checks_on = 1'b1;

	$display("=============================================================");
	$display(" TB: fir20_q16_fromx block testbench");
	$display(" Current RTL behavior checked: TRUNC/FLOOR, not ideal rounding");
	$display("=============================================================");

	$display("\n--- TEST 1: Reset ---");
	do_reset();

	$display("\n--- TEST 2: Coefficient load sequence ---");
	do_reset();
	for (int k = 0; k < NTAPS; k++) begin
	  load_coeff(16'sd100 + k);
	  chk_i($sformatf("load_idx_after_%0d", k), DUT.load_idx, (k == NTAPS-1) ? NTAPS-1 : k+1);
	  chk_w($sformatf("check_after_%0d", k), DUT.check, 16'sd100 + k);
	end

	load_coeff(16'sd999);
	chk_i("load_idx_saturated", DUT.load_idx, NTAPS-1);
	chk_w("check_after_extra_load", DUT.check, 16'sd999);

	$display("\n--- TEST 3: coeff_load_en=0 blocks coeff/check update ---");
	coeff_load_en = 1'b0;
	coeff_strobe = 1'b1;
	coeff_word = 16'sd777;
	wait_clk();
	coeff_strobe = 1'b0;
	chk_w("check_hold_when_load_disabled", DUT.check, 16'sd999);

	$display("\n--- TEST 4: Unity tap and zero cases ---");
	load_unity_tap0();
	clear_x();
	x[0] = 16'sd1234;
	compute_and_check("unity_x1234");

	load_all_zero();
	clear_x();
	for (int k = 0; k < NTAPS; k++) x[k] = 16'sd3000;
	compute_and_check("zero_coeffs");

	load_unity_tap0();
	clear_x();
	compute_and_check("zero_x");

	$display("\n--- TEST 5: Saturation ---");
	do_reset();
	for (int k = 0; k < NTAPS; k++) load_coeff(16'sd32767);
	for (int k = 0; k < NTAPS; k++) x[k] = 16'sd32767;
	compute_and_check("positive_saturation");

	do_reset();
	for (int k = 0; k < NTAPS; k++) load_coeff(-16'sd32768);
	for (int k = 0; k < NTAPS; k++) x[k] = 16'sd32767;
	compute_and_check("negative_saturation");

	$display("\n--- TEST 6: en gating ---");
	load_unity_tap0();
	clear_x();
	x[0] = 16'sd1000;
	compute_and_check("pre_hold_y1000");
	x[0] = 16'sd2000;
	en = 1'b0;
	wait_clk();
	chk_w("y_hold_when_en0", y, 16'sd1000);

	$display("\n--- TEST 7: truncation / rounding finding ---");
	do_reset();
	load_coeff(16'sd1);
	for (int k = 1; k < NTAPS; k++) load_coeff(16'sd0);

	clear_x();
	x[0] = -16'sd1;
	compute_and_check("negative_fraction_floor");
	$display("  INFO  [rounding finding] coeff=1, x=-1 gives RTL/trunc y=-1; ideal rounding would be 0");

	clear_x();
	x[0] = 16'sd2048;
	compute_and_check("positive_half_lsb_floor");
	$display("  INFO  [rounding finding] coeff=1, x=2048 gives RTL/trunc y=0; ideal rounding would be 1");

	$display("\n--- TEST 8: constrained random truncating reference ---");
	do_reset();
	for (int k = 0; k < NTAPS; k++) begin
	  logic signed [15:0] cw;
	  cw = $urandom_range(4096,0) - 2048;
	  load_coeff(cw);
	end

	repeat (200) begin
	  for (int k = 0; k < NTAPS; k++) begin
		x[k] = $urandom_range(16000,0) - 8000;
	  end
	  compute_and_check("random");
	end

	repeat (5) wait_clk();

	$display("\n=============================================================");
	$display(" RESULTS: %0d passed, %0d failed", pass_count, fail_count);
	$display(" Coverage: %.1f%%", cov_inst.get_coverage());
	$display(" Note: FIR currently truncates/floors because RND is effectively zero.");
	$display("       If you want ideal rounding, fix RND in filter4tweny.v and rerun.");
	$display("=============================================================");

	if (fail_count == 0) $display(" ALL TESTS PASSED"); else $display(" FAILURES DETECTED");
	$finish;
  end

  initial begin
	#1000000;
	$display("TIMEOUT");
	$finish;
  end

  initial begin
	$dumpfile("dump_fir20.vcd");
	$dumpvars(0, tb_fir);
  end

endmodule
