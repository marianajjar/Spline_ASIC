`timescale 1ns/1ps
// ============================================================================
// tb_sample_shift_Q.sv
// Block-level testbench for sample_shift_ntaps_Q (shift_30_Q.v)
//
// Q has no local phase counter.  It receives phase_in from the I shifter.
// Therefore this TB drives phase_in directly and verifies:
//   - reset clears the whole x delay line
//   - sample mux selects y0..y4 correctly for L=2,3,4,5
//   - illegal L values use the default/L5 mux behavior
//   - x[0] captures the sample selected by the OLD clock-edge inputs
//   - x[k] shifts from x[k-1]
//   - en=0 or shift_strobe=0 holds the delay line
// ============================================================================

module tb_sample_shift_Q;

  localparam int  WL         = 16;
  localparam int  NTAPS      = 10;
  localparam real CLK_PERIOD = 1.0;

  logic clk;
  initial clk = 1'b0;
  always #(CLK_PERIOD/2.0) clk = ~clk;

  logic                 reset;
  logic                 en;
  logic [2:0]           L_ctrl;
  logic                 shift_strobe;
  logic [2:0]           phase_in;
  logic signed [WL-1:0] y0_r, y1_r, y2_r, y3_r, y4_r;
  logic signed [WL-1:0] x [0:NTAPS-1];

  sample_shift_ntaps_Q #(.WL(WL), .NTAPS(NTAPS)) DUT (
	.clk(clk),
	.reset(reset),
	.en(en),
	.L_ctrl(L_ctrl),
	.shift_strobe(shift_strobe),
	.phase_in(phase_in),
	.y0_r(y0_r),
	.y1_r(y1_r),
	.y2_r(y2_r),
	.y3_r(y3_r),
	.y4_r(y4_r),
	.x(x)
  );

  int pass_count;
  int fail_count;
  logic checks_on;
  logic signed [WL-1:0] ref_x [0:NTAPS-1];
  logic signed [WL-1:0] sample_sel_tb;

  task automatic wait_clk;
	begin
	  @(posedge clk);
	  #0.001;
	end
  endtask

  function automatic logic signed [WL-1:0] sample_for_values(
	input logic [2:0] l,
	input logic [2:0] ph,
	input logic signed [WL-1:0] a,
	input logic signed [WL-1:0] b,
	input logic signed [WL-1:0] c,
	input logic signed [WL-1:0] d,
	input logic signed [WL-1:0] e
  );
	begin
	  case (l)
		3'd2: begin
		  if (ph == 3'd0) sample_for_values = a;
		  else            sample_for_values = b;
		end

		3'd3: begin
		  if      (ph == 3'd0) sample_for_values = a;
		  else if (ph == 3'd1) sample_for_values = b;
		  else                 sample_for_values = c;
		end

		3'd4: begin
		  if      (ph == 3'd0) sample_for_values = a;
		  else if (ph == 3'd1) sample_for_values = b;
		  else if (ph == 3'd2) sample_for_values = c;
		  else                 sample_for_values = d;
		end

		default: begin
		  if      (ph == 3'd0) sample_for_values = a;
		  else if (ph == 3'd1) sample_for_values = b;
		  else if (ph == 3'd2) sample_for_values = c;
		  else if (ph == 3'd3) sample_for_values = d;
		  else                 sample_for_values = e;
		end
	  endcase
	end
  endfunction

  always_comb begin
	sample_sel_tb = sample_for_values(L_ctrl, phase_in, y0_r, y1_r, y2_r, y3_r, y4_r);
  end

  task automatic chk_w(input string tag, input logic signed [WL-1:0] got, exp);
	begin
	  if (got === exp) begin
		$display("  PASS  [%s] got=0x%04h exp=0x%04h", tag, got, exp);
		pass_count++;
	  end else begin
		$display("  FAIL  [%s] got=0x%04h exp=0x%04h  <---", tag, got, exp);
		fail_count++;
	  end
	end
  endtask

  task automatic check_all(input string tag);
	int mism;
	begin
	  mism = 0;
	  for (int i = 0; i < NTAPS; i++) begin
		if (x[i] !== ref_x[i]) begin
		  mism++;
		end
	  end

	  if (mism == 0) begin
		$display("  PASS  [%s] x0=0x%04h x9=0x%04h", tag, x[0], x[NTAPS-1]);
		pass_count++;
	  end else begin
		$display("  FAIL  [%s] mismatches=%0d x0=0x%04h exp0=0x%04h  <---",
				 tag, mism, x[0], ref_x[0]);
		fail_count++;
	  end
	end
  endtask

  task automatic do_reset;
	begin
	  reset <= 1'b1;
	  en <= 1'b0;
	  L_ctrl <= 3'd5;
	  shift_strobe <= 1'b0;
	  phase_in <= 3'd0;
	  y0_r <= '0;
	  y1_r <= '0;
	  y2_r <= '0;
	  y3_r <= '0;
	  y4_r <= '0;
	  for (int i = 0; i < NTAPS; i++) ref_x[i] = '0;

	  repeat (3) wait_clk();
	  reset <= 1'b0;
	  wait_clk();

	  check_all("reset");
	end
  endtask

  task automatic drive(
	input logic en_v,
	input logic shift_v,
	input logic [2:0] l_v,
	input logic [2:0] ph_v,
	input logic signed [WL-1:0] a,
	input logic signed [WL-1:0] b,
	input logic signed [WL-1:0] c,
	input logic signed [WL-1:0] d,
	input logic signed [WL-1:0] e,
	input string tag
  );
	logic signed [WL-1:0] old_sample;
	begin
	  old_sample = sample_for_values(l_v, ph_v, a, b, c, d, e);

	  en <= en_v;
	  shift_strobe <= shift_v;
	  L_ctrl <= l_v;
	  phase_in <= ph_v;
	  y0_r <= a;
	  y1_r <= b;
	  y2_r <= c;
	  y3_r <= d;
	  y4_r <= e;

	  wait_clk();

	  if (en_v && shift_v) begin
		for (int i = NTAPS-1; i > 0; i--) ref_x[i] = ref_x[i-1];
		ref_x[0] = old_sample;
	  end

	  check_all(tag);
	end
  endtask

  property p_no_x;
	@(posedge clk) disable iff (reset)
	  checks_on |->
		!$isunknown({x[0],x[1],x[2],x[3],x[4],x[5],x[6],x[7],x[8],x[9]});
  endproperty
  a_no_x: assert property (p_no_x) else begin $error("Q shift output X/Z"); fail_count++; end

  property p_x_hold;
	@(posedge clk) disable iff (reset)
	  checks_on && !(en && shift_strobe) |=>
		($stable(x[0]) && $stable(x[1]) && $stable(x[2]) && $stable(x[3]) && $stable(x[4]) &&
		 $stable(x[5]) && $stable(x[6]) && $stable(x[7]) && $stable(x[8]) && $stable(x[9]));
  endproperty
  a_x_hold: assert property (p_x_hold) else begin $error("Q x changed without en&&shift_strobe"); fail_count++; end

  property p_x0_shift;
	@(posedge clk) disable iff (reset)
	  checks_on && en && shift_strobe |=> (x[0] == $past(sample_sel_tb));
  endproperty
  a_x0_shift: assert property (p_x0_shift) else begin $error("Q x[0] did not capture selected sample"); fail_count++; end

  genvar gi;
  generate
	for (gi = 1; gi < NTAPS; gi++) begin : g_shift
	  property p_x_shift;
		@(posedge clk) disable iff (reset)
		  checks_on && en && shift_strobe |=> (x[gi] == $past(x[gi-1]));
	  endproperty
	  assert property (p_x_shift) else begin $error("Q delay-line shift mismatch"); fail_count++; end
	end
  endgenerate

  covergroup cg @(posedge clk);
	cp_L: coverpoint L_ctrl {
	  bins L2 = {3'd2};
	  bins L3 = {3'd3};
	  bins L4 = {3'd4};
	  bins L5 = {3'd5};
	  bins bad[] = {3'd0,3'd1,3'd6,3'd7};
	}
	cp_phase: coverpoint phase_in { bins p[] = {[0:7]}; }
	cp_en: coverpoint en { bins lo={0}; bins hi={1}; }
	cp_shift: coverpoint shift_strobe { bins lo={0}; bins hi={1}; }
	x_en_shift: cross cp_en, cp_shift;
	x_L_phase: cross cp_L, cp_phase;
  endgroup
  cg cov_inst = new();

  initial begin
	pass_count = 0;
	fail_count = 0;
	checks_on = 0;
	reset = 1'b1;
	en = 1'b0;
	L_ctrl = 3'd5;
	shift_strobe = 1'b0;
	phase_in = 3'd0;
	y0_r = '0;
	y1_r = '0;
	y2_r = '0;
	y3_r = '0;
	y4_r = '0;
	for (int i = 0; i < NTAPS; i++) ref_x[i] = '0;

	repeat (4) wait_clk();
	checks_on = 1'b1;

	$display("=============================================================");
	$display(" TB: sample_shift_ntaps_Q block testbench");
	$display("=============================================================");

	$display("\n--- TEST 1: Reset state ---");
	do_reset();
	chk_w("rst/x[0]", x[0], '0);
	chk_w("rst/x[9]", x[9], '0);

	$display("\n--- TEST 2: Sample mux for legal L and phase ---");
	for (int Lv = 2; Lv <= 5; Lv++) begin
	  for (int ph = 0; ph < Lv; ph++) begin
		do_reset();
		drive(1'b1, 1'b1, Lv[2:0], ph[2:0],
			  16'sh1111, 16'sh2222, 16'sh3333, 16'sh4444, 16'sh5555,
			  $sformatf("mux_L%0d_ph%0d", Lv, ph));
		chk_w($sformatf("mux_L%0d_ph%0d/x0", Lv, ph),
			  x[0],
			  sample_for_values(Lv[2:0], ph[2:0],
								16'sh1111, 16'sh2222, 16'sh3333, 16'sh4444, 16'sh5555));
	  end
	end

	$display("\n--- TEST 3: Shift register propagation ---");
	do_reset();
	for (int i = 0; i < NTAPS; i++) begin
	  drive(1'b1, 1'b1, 3'd5, 3'd0,
			16'sh2000 + i, 16'sh3000 + i, 16'sh4000 + i, 16'sh5000 + i, 16'sh6000 + i,
			$sformatf("shift_%0d", i));
	end
	chk_w("shift/x[0]", x[0], 16'sh2000 + (NTAPS-1));
	chk_w("shift/x[9]", x[9], 16'sh2000);

	$display("\n--- TEST 4: Hold when en=0 or shift_strobe=0 ---");
	drive(1'b0, 1'b1, 3'd5, 3'd4, 1,2,3,4,5, "hold_en0");
	drive(1'b1, 1'b0, 3'd5, 3'd3, 5,4,3,2,1, "hold_shift0");

	$display("\n--- TEST 5: Illegal L uses default/L5 mux behavior ---");
	begin
	  logic [2:0] bad_L [0:3];
	  bad_L[0] = 3'd0;
	  bad_L[1] = 3'd1;
	  bad_L[2] = 3'd6;
	  bad_L[3] = 3'd7;

	  foreach (bad_L[idx]) begin
		for (int ph = 0; ph <= 4; ph++) begin
		  do_reset();
		  drive(1'b1, 1'b1, bad_L[idx], ph[2:0],
				16'sh1111, 16'sh2222, 16'sh3333, 16'sh4444, 16'sh5555,
				$sformatf("badL%0d_ph%0d", bad_L[idx], ph));
		  chk_w($sformatf("badL%0d_ph%0d/x0", bad_L[idx], ph),
				x[0],
				sample_for_values(bad_L[idx], ph[2:0],
								  16'sh1111, 16'sh2222, 16'sh3333, 16'sh4444, 16'sh5555));
		end
	  end
	end

	$display("\n--- TEST 6: Reset mid-operation ---");
	do_reset();
	repeat (5) begin
	  drive(1'b1, 1'b1, 3'd5, $urandom_range(4,0),
			$urandom(), $urandom(), $urandom(), $urandom(), $urandom(), "pre_mid_reset");
	end
	do_reset();
	chk_w("midrst/x[0]", x[0], '0);
	chk_w("midrst/x[9]", x[9], '0);

	$display("\n--- TEST 7: Constrained random ---");
	do_reset();
	repeat (200) begin
	  logic [2:0] lv;
	  logic [2:0] ph;
	  lv = $urandom_range(7,0);
	  ph = $urandom_range(7,0);
	  drive($urandom_range(1,0), $urandom_range(1,0), lv, ph,
			$urandom(), $urandom(), $urandom(), $urandom(), $urandom(),
			"rnd");
	end

	repeat (5) wait_clk();
	$display("\n=============================================================");
	$display(" RESULTS: %0d passed, %0d failed", pass_count, fail_count);
	$display(" Coverage: %.1f%%", cov_inst.get_coverage());
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
	$dumpfile("dump_sample_shift_Q.vcd");
	$dumpvars(0, tb_sample_shift_Q);
  end
endmodule
