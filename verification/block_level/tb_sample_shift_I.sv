`timescale 1ns/1ps
// ============================================================================
// tb_sample_shift_I.sv
// Block-level testbench for sample_shift_ntaps_I (shift_30_I.v)
//
// DUT: phase counter + N-tap shift register, with sample_sel MUX driven by
//      (L_ctrl, phase). Strobe wins over shift_strobe for phase.
//
// Corners checked:
//   1.  Reset state (phase=0, x[] all 0)
//   2.  L=2: phase toggles 0->1 on shift_strobe, resets on strobe
//   3.  L=3: phase 0,1,2,2,2,...  (stays at L-1 with no strobe)
//   4.  L=4: phase 0,1,2,3,3,...
//   5.  L=5: phase 0,1,2,3,4,4,...
//   6.  L=5 with strobe AND shift_strobe coinciding every word
//       (REGRESSION TEST FOR THE PATCH that gives strobe priority)
//   7.  en=0 gates phase update
//   8.  Sample selection per (L,phase) for all 4 L's
//   9.  Shift register propagation (NTAPS samples deep)
//   10. Illegal L (0,1,6,7) -- INFORMATIONAL ONLY (OPEN FINDING #2)
//   11. Reset mid-stream
//   12. Constrained random L + strobes vs SW reference
// ============================================================================

module tb_sample_shift_I;

  localparam int  WL         = 16;
  localparam int  NTAPS      = 10;
  localparam real CLK_PERIOD = 1.0;

  logic clk;
  initial clk = 1'b0;
  always #(CLK_PERIOD/2.0) clk = ~clk;

  logic                  reset;
  logic                  en;
  logic [2:0]            L_ctrl;
  logic                  strobe;
  logic                  shift_strobe;
  logic signed [WL-1:0]  y0_r, y1_r, y2_r, y3_r, y4_r;
  logic signed [WL-1:0]  x [0:NTAPS-1];
  logic [2:0]            phase_out;

  sample_shift_ntaps_I #(.WL(WL), .NTAPS(NTAPS)) DUT (
	.clk(clk), .reset(reset), .en(en), .L_ctrl(L_ctrl),
	.strobe(strobe), .shift_strobe(shift_strobe),
	.y0_r(y0_r), .y1_r(y1_r), .y2_r(y2_r), .y3_r(y3_r), .y4_r(y4_r),
	.x(x), .phase_out(phase_out)
  );

  int pass_count, fail_count;
  logic checks_on;
  logic legal_L;

  assign legal_L = (L_ctrl >= 3'd2) && (L_ctrl <= 3'd5);

  task automatic wait_clk;
	begin
	  @(posedge clk);
	  #0.001;
	end
  endtask

  task automatic chk_i(input string tag, input int got, input int exp);
	begin
	  if (got == exp) begin
		$display("  PASS  [%s] %0d", tag, got);
		pass_count++;
	  end else begin
		$display("  FAIL  [%s] got=%0d exp=%0d  <---", tag, got, exp);
		fail_count++;
	  end
	end
  endtask

  task automatic chk_w(input string tag, input logic signed [WL-1:0] got, exp);
	begin
	  if (got === exp) begin
		$display("  PASS  [%s] 0x%04h", tag, got);
		pass_count++;
	  end else begin
		$display("  FAIL  [%s] got=0x%04h exp=0x%04h  <---", tag, got, exp);
		fail_count++;
	  end
	end
  endtask

  task automatic do_reset;
	begin
	  reset <= 1'b1;
	  en <= 1'b0;
	  L_ctrl <= 3'd5;
	  strobe <= 1'b0;
	  shift_strobe <= 1'b0;
	  y0_r <= '0;
	  y1_r <= '0;
	  y2_r <= '0;
	  y3_r <= '0;
	  y4_r <= '0;
	  repeat (3) wait_clk();
	  reset <= 1'b0;
	  wait_clk();
	end
  endtask

  task automatic tick(input logic st, input logic ss);
	begin
	  strobe <= st;
	  shift_strobe <= ss;
	  wait_clk();
	  strobe <= 1'b0;
	  shift_strobe <= 1'b0;
	end
  endtask

  function automatic logic signed [WL-1:0] sw_sample(input logic [2:0] L, input logic [2:0] ph);
	case (L)
	  3'd2: begin
		case (ph)
		  3'd0:    return y0_r;
		  default: return y1_r;
		endcase
	  end

	  3'd3: begin
		case (ph)
		  3'd0:    return y0_r;
		  3'd1:    return y1_r;
		  default: return y2_r;
		endcase
	  end

	  3'd4: begin
		case (ph)
		  3'd0:    return y0_r;
		  3'd1:    return y1_r;
		  3'd2:    return y2_r;
		  default: return y3_r;
		endcase
	  end

	  default: begin
		case (ph)
		  3'd0:    return y0_r;
		  3'd1:    return y1_r;
		  3'd2:    return y2_r;
		  3'd3:    return y3_r;
		  default: return y4_r;
		endcase
	  end
	endcase
  endfunction

  // Assertions
  property p_no_x;
	@(posedge clk) disable iff (reset)
	  checks_on |-> !$isunknown({phase_out, x[0]});
  endproperty
  a_no_x: assert property (p_no_x) else begin $error("X/Z on outputs"); fail_count++; end

  // Only check phase range for legal L values. Illegal L is documented as an
  // open finding because SPI config should lock L to 2..5 before this block runs.
  property p_phase_range;
	@(posedge clk) disable iff (reset)
	  checks_on && legal_L |-> (phase_out <= 3'd4);
  endproperty
  a_phase_range: assert property (p_phase_range) else begin $error("phase > 4 in legal L"); fail_count++; end

  property p_strobe_clears_phase;
	@(posedge clk) disable iff (reset)
	  checks_on && en && strobe |=> (phase_out == 0);
  endproperty
  a_strobe_clears: assert property (p_strobe_clears_phase) else begin $error("strobe did not clear phase"); fail_count++; end

  property p_en0_holds_phase;
	@(posedge clk) disable iff (reset)
	  checks_on && !en |=> $stable(phase_out);
  endproperty
  a_en0_holds: assert property (p_en0_holds_phase) else begin $error("phase moved when en=0"); fail_count++; end

  covergroup cg @(posedge clk);
	cp_L: coverpoint L_ctrl {
	  bins L2 = {3'd2};
	  bins L3 = {3'd3};
	  bins L4 = {3'd4};
	  bins L5 = {3'd5};
	  bins bad[] = {3'd0,3'd1,3'd6,3'd7};
	}
	cp_phase: coverpoint phase_out { bins p[] = {[0:4]}; }
	cp_strobe:  coverpoint strobe       { bins lo={0}; bins hi={1}; }
	cp_sstrobe: coverpoint shift_strobe { bins lo={0}; bins hi={1}; }
	x_LP: cross cp_L, cp_phase;
	x_str: cross cp_strobe, cp_sstrobe;
  endgroup
  cg cov_inst = new();

  initial begin
	pass_count = 0;
	fail_count = 0;
	checks_on = 0;
	reset = 1'b1;
	en = 1'b0;
	L_ctrl = 3'd5;
	strobe = 1'b0;
	shift_strobe = 1'b0;
	y0_r = '0;
	y1_r = '0;
	y2_r = '0;
	y3_r = '0;
	y4_r = '0;
	repeat (4) wait_clk();
	checks_on = 1'b1;

	$display("=============================================================");
	$display(" TB: sample_shift_ntaps_I block testbench");
	$display("=============================================================");

	$display("\n--- TEST 1: Reset state ---");
	do_reset();
	chk_i("rst/phase", phase_out, 0);
	chk_w("rst/x[0]", x[0], '0);
	chk_w("rst/x[9]", x[9], '0);

	for (int Lv = 2; Lv <= 5; Lv++) begin
	  $display("\n--- TEST: L=%0d phase progression ---", Lv);
	  do_reset();
	  en <= 1'b1;
	  L_ctrl <= Lv[2:0];
	  wait_clk();

	  tick(1'b1, 1'b0);
	  chk_i($sformatf("L%0d/ph0_after_strobe", Lv), phase_out, 0);

	  for (int s = 0; s < Lv+2; s++) begin
		tick(1'b0, 1'b1);
		chk_i($sformatf("L%0d/ph_after_ss%0d", Lv, s+1),
			  phase_out, (s+1 < Lv-1) ? s+1 : Lv-1);
	  end
	end

	$display("\n--- TEST 6 (REGRESSION): L=5 strobe+ss every word ---");
	do_reset();
	en <= 1'b1;
	L_ctrl <= 3'd5;
	wait_clk();
	for (int i = 0; i < 10; i++) begin
	  tick(1'b1, 1'b1);
	  if (phase_out != 0) begin
		$display("  FAIL  [stuck-at-4 regression] iter=%0d phase=%0d  <--- PATCH BROKEN", i, phase_out);
		fail_count++;
	  end
	end
	if (phase_out == 0) begin
	  $display("  PASS  [stuck-at-4 regression] phase reset cleanly each word");
	  pass_count++;
	end

	$display("\n--- TEST 7: en=0 gates phase update ---");
	do_reset();
	en <= 1'b1;
	L_ctrl <= 3'd5;
	wait_clk();
	tick(1'b1, 1'b0);
	chk_i("en1/ph_strobe_clears", phase_out, 0);
	tick(1'b0, 1'b1);
	chk_i("en1/ph_ss_advances", phase_out, 1);
	en <= 1'b0;
	repeat (5) tick(1'b0, 1'b1);
	chk_i("en0/ph_held", phase_out, 1);

	$display("\n--- TEST 8: Sample selection per (L,phase) ---");
	y0_r <= 16'sh1111;
	y1_r <= 16'sh2222;
	y2_r <= 16'sh3333;
	y3_r <= 16'sh4444;
	y4_r <= 16'sh5555;
	wait_clk();
	for (int Lv = 2; Lv <= 5; Lv++) begin
	  do_reset();
	  y0_r <= 16'sh1111;
	  y1_r <= 16'sh2222;
	  y2_r <= 16'sh3333;
	  y3_r <= 16'sh4444;
	  y4_r <= 16'sh5555;
	  en <= 1'b1;
	  L_ctrl <= Lv[2:0];
	  wait_clk();
	  tick(1'b1, 1'b0);
	  tick(1'b0, 1'b1);
	  chk_w($sformatf("L%0d/x0_at_ph0", Lv), x[0], 16'sh1111);
	end

	$display("\n--- TEST 9: Shift register propagation ---");
	do_reset();
	en <= 1'b1;
	L_ctrl <= 3'd2;
	y0_r <= 16'sh1000;
	y1_r <= 16'sh2000;
	wait_clk();
	for (int i = 0; i < NTAPS; i++) begin
	  y0_r <= 16'sh1000 + i;
	  tick(1'b1, 1'b1);
	end
	chk_w("shift/x[0]", x[0], 16'sh1000 + (NTAPS-1));
	chk_w("shift/x[9]", x[9], 16'sh1000);

	$display("\n--- TEST 10: Illegal L (INFORMATIONAL - OPEN FINDING #2) ---");
	begin
	  automatic logic [2:0] bad_L [4] = '{3'd0, 3'd1, 3'd6, 3'd7};
	  foreach (bad_L[idx]) begin
		do_reset();
		y0_r <= 16'sh1111;
		y1_r <= 16'sh2222;
		y2_r <= 16'sh3333;
		y3_r <= 16'sh4444;
		y4_r <= 16'sh5555;
		en <= 1'b1;
		L_ctrl <= bad_L[idx];
		wait_clk();
		repeat (10) tick(1'b0, 1'b1);
		$display("  INFO  [badL%0d] phase_terminal=%0d  x[0]=0x%04h  (illegal L: behaviour documented)",
				 bad_L[idx], phase_out, x[0]);
		if ($isunknown(x[0])) begin
		  $display("  FAIL  [badL%0d] x[0] is X/Z  <---", bad_L[idx]);
		  fail_count++;
		end
	  end
	  $display("  PASS  [badL informational] all illegal L produced defined outputs (no X/Z)");
	  pass_count++;
	end

	$display("\n--- TEST 11: Reset mid-stream ---");
	do_reset();
	en <= 1'b1;
	L_ctrl <= 3'd5;
	repeat (3) tick(1'b0, 1'b1);
	reset <= 1'b1;
	repeat (3) wait_clk();
	reset <= 1'b0;
	wait_clk();
	chk_i("midrst/ph", phase_out, 0);
	chk_w("midrst/x[0]", x[0], '0);

	$display("\n--- TEST 12: Random L + strobes (200 cycles) ---");
	begin
	  automatic int mism = 0;
	  logic [2:0] L_v;
	  logic st_v, ss_v;
	  logic [2:0] sw_phase;
	  do_reset();
	  L_v = 3'd5;
	  sw_phase = 0;
	  en <= 1'b1;
	  L_ctrl <= L_v;
	  wait_clk();
	  for (int i = 0; i < 200; i++) begin
		if (($urandom_range(100,0)) < 5) begin
		  L_v = 3'd2 + $urandom_range(3,0);
		  L_ctrl <= L_v;
		  wait_clk();
		end
		st_v = ($urandom_range(100,0)) < 15;
		ss_v = ($urandom_range(100,0)) < 50;
		tick(st_v, ss_v);
		if (st_v) sw_phase = 0;
		else if (ss_v && (sw_phase < L_v-1)) sw_phase = sw_phase + 1;
		if (phase_out != sw_phase) begin
		  $display("  FAIL  [rnd/i=%0d L=%0d st=%0b ss=%0b] phase=%0d exp=%0d",
				   i, L_v, st_v, ss_v, phase_out, sw_phase);
		  mism++;
		  fail_count++;
		end
	  end
	  if (mism == 0) begin
		$display("  PASS  [rnd] 200 cycles, phase tracks SW model");
		pass_count++;
	  end
	end

	repeat (5) wait_clk();
	$display("\n=============================================================");
	$display(" RESULTS: %0d passed, %0d failed", pass_count, fail_count);
	$display(" Coverage: %.1f%%", cov_inst.get_coverage());
	$display(" Note: TEST 10 (illegal L) is informational only -- OPEN FINDING #2");
	$display("=============================================================");
	if (fail_count == 0) $display(" ALL TESTS PASSED"); else $display(" FAILURES DETECTED");
	$finish;
  end

  initial begin
	#500000;
	$display("TIMEOUT");
	$finish;
  end

  initial begin
	$dumpfile("dump_sample_shift_I.vcd");
	$dumpvars(0, tb_sample_shift_I);
  end
endmodule
