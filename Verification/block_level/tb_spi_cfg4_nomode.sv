`timescale 1ns/1ps
// ============================================================================
// tb_spi_cfg4_nomode.sv
// Clean posedge-synchronous block-level testbench with SVA
// ============================================================================

module tb_spi_cfg4_nomode;

  localparam real CLK_PERIOD = 1.0;

  logic clk;
  initial clk = 1'b0;
  always #(CLK_PERIOD/2.0) clk = ~clk;

  logic       reset;
  logic       serial_in;
  logic [2:0] L_ctrl;
  logic       cfg_done;
  logic       cfg_ready_now;

  spi_cfg4_nomode DUT (
	.clk          (clk),
	.reset        (reset),
	.serial_in    (serial_in),
	.L_ctrl       (L_ctrl),
	.cfg_done     (cfg_done),
	.cfg_ready_now(cfg_ready_now)
  );

  int pass_count;
  int fail_count;
  logic checks_on;

  logic [2:0] L_values     [0:3];
  logic [2:0] bad_L_values [0:3];

  // ==========================================================================
  // Basic check tasks
  // ==========================================================================

  task automatic assert_eq3;
	input string tag;
	input logic [2:0] got;
	input logic [2:0] exp;
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

  task automatic assert_int;
	input string tag;
	input int got;
	input int exp;
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

  task automatic assert_bit;
	input string tag;
	input logic got;
	input logic exp;
	begin
	  if (got === exp) begin
		$display("  PASS  [%s] got=%0b exp=%0b", tag, got, exp);
		pass_count++;
	  end else begin
		$display("  FAIL  [%s] got=%0b exp=%0b  <---", tag, got, exp);
		fail_count++;
	  end
	end
  endtask

  // ==========================================================================
  // Posedge-synchronous driver helpers
  //
  // Important:
  //   drive_serial_bit() changes serial_in just AFTER a posedge.
  //   The DUT samples that value on the NEXT posedge.
  //   This models a real register-to-register signal and avoids races.
  // ==========================================================================

  task automatic wait_clk;
	begin
	  @(posedge clk);
	  #0.001;
	end
  endtask

  task automatic drive_serial_bit;
	input logic bit_val;
	begin
	  serial_in <= bit_val;
	  wait_clk();
	end
  endtask

  task automatic do_reset;
	begin
	  reset     <= 1'b1;
	  serial_in <= 1'b0;

	  repeat (3) wait_clk();

	  reset     <= 1'b0;
	  serial_in <= 1'b0;

	  wait_clk();
	end
  endtask

  task automatic send_header;
	input  logic [2:0] L_val;
	output logic [2:0] captured_L;
	logic [3:0] bits;
	begin
	  bits = {L_val, 1'b1};

	  drive_serial_bit(bits[0]);  // marker
	  drive_serial_bit(bits[1]);  // L[0]
	  drive_serial_bit(bits[2]);  // L[1]
	  drive_serial_bit(bits[3]);  // L[2]

	  // One extra clock so SVA that detects $rose(cfg_done) also sees it.
	  wait_clk();

	  captured_L = L_ctrl;
	end
  endtask

  // ==========================================================================
  // SVA assertions
  // ==========================================================================

  property p_reset_values;
	@(posedge clk)
	  checks_on && reset |->
		(L_ctrl == 3'd2 &&
		 cfg_done == 1'b0 &&
		 cfg_ready_now == 1'b0);
  endproperty

  a_reset_values: assert property (p_reset_values)
	else begin
	  $error("ASSERT FAIL: reset values are wrong");
	  fail_count++;
	end

  property p_no_x_inputs_outputs;
	@(posedge clk)
	  checks_on |->
		!$isunknown({reset, serial_in, L_ctrl, cfg_done, cfg_ready_now});
  endproperty

  a_no_x_inputs_outputs: assert property (p_no_x_inputs_outputs)
	else begin
	  $error("ASSERT FAIL: X/Z detected on input or output");
	  fail_count++;
	end

  property p_cfg_done_sticky;
	@(posedge clk) disable iff (reset)
	  checks_on && cfg_done |=> cfg_done;
  endproperty

  a_cfg_done_sticky: assert property (p_cfg_done_sticky)
	else begin
	  $error("ASSERT FAIL: cfg_done deasserted without reset");
	  fail_count++;
	end

  property p_lctrl_stable_after_done;
	@(posedge clk) disable iff (reset)
	  checks_on && cfg_done |=> $stable(L_ctrl);
  endproperty

  a_lctrl_stable_after_done: assert property (p_lctrl_stable_after_done)
	else begin
	  $error("ASSERT FAIL: L_ctrl changed after cfg_done");
	  fail_count++;
	end

  property p_fsm_frozen_after_done;
	@(posedge clk) disable iff (reset)
	  checks_on && cfg_done |=>
		($stable(DUT.cnt) && $stable(DUT.got_marker));
  endproperty

  a_fsm_frozen_after_done: assert property (p_fsm_frozen_after_done)
	else begin
	  $error("ASSERT FAIL: cfg FSM changed after cfg_done");
	  fail_count++;
	end

  property p_lctrl_default_before_done;
	@(posedge clk) disable iff (reset)
	  checks_on && !cfg_done |-> (L_ctrl == 3'd2);
  endproperty

  a_lctrl_default_before_done: assert property (p_lctrl_default_before_done)
	else begin
	  $error("ASSERT FAIL: L_ctrl changed before cfg_done");
	  fail_count++;
	end

  property p_lctrl_changes_only_when_done_rises;
	@(posedge clk) disable iff (reset)
	  checks_on && !$past(reset) && (L_ctrl !== $past(L_ctrl)) |->
		$rose(cfg_done);
  endproperty

  a_lctrl_changes_only_when_done_rises:
	assert property (p_lctrl_changes_only_when_done_rises)
	else begin
	  $error("ASSERT FAIL: L_ctrl changed without cfg_done rising");
	  fail_count++;
	end

  property p_marker_set_cause;
	@(posedge clk) disable iff (reset)
	  checks_on && !$past(reset) && $rose(DUT.got_marker) |->
		$past(serial_in);
  endproperty

  a_marker_set_cause: assert property (p_marker_set_cause)
	else begin
	  $error("ASSERT FAIL: got_marker rose without serial marker bit");
	  fail_count++;
	end

  property p_done_implies_marker;
	@(posedge clk) disable iff (reset)
	  checks_on && cfg_done |-> DUT.got_marker;
  endproperty

  a_done_implies_marker: assert property (p_done_implies_marker)
	else begin
	  $error("ASSERT FAIL: cfg_done high without got_marker");
	  fail_count++;
	end

  property p_cfg_done_rise_cause;
	@(posedge clk) disable iff (reset)
	  checks_on && !$past(reset) && $rose(cfg_done) |->
		($past(DUT.got_marker) && ($past(DUT.cnt) == 2'd2));
  endproperty

  a_cfg_done_rise_cause: assert property (p_cfg_done_rise_cause)
	else begin
	  $error("ASSERT FAIL: cfg_done rose at wrong time");
	  fail_count++;
	end

  property p_lctrl_load_value;
	@(posedge clk) disable iff (reset)
	  checks_on && !$past(reset) && $rose(cfg_done) |->
		(L_ctrl == {$past(serial_in), $past(DUT.l_tmp[1]), $past(DUT.l_tmp[0])});
  endproperty

  a_lctrl_load_value: assert property (p_lctrl_load_value)
	else begin
	  $error("ASSERT FAIL: L_ctrl loaded wrong value");
	  fail_count++;
	end

  property p_cfg_ready_equation;
	@(posedge clk) disable iff (reset)
	  checks_on |->
		(cfg_ready_now ==
		 (cfg_done || (!cfg_done && DUT.got_marker && (DUT.cnt == 2'd2))));
  endproperty

  a_cfg_ready_equation: assert property (p_cfg_ready_equation)
	else begin
	  $error("ASSERT FAIL: cfg_ready_now equation mismatch");
	  fail_count++;
	end

  property p_ready_before_done_then_done;
	@(posedge clk) disable iff (reset)
	  checks_on && cfg_ready_now && !cfg_done |=> cfg_done;
  endproperty

  a_ready_before_done_then_done: assert property (p_ready_before_done_then_done)
	else begin
	  $error("ASSERT FAIL: cfg_ready_now did not lead to cfg_done");
	  fail_count++;
	end

  property p_marker_sticky_until_done;
	@(posedge clk) disable iff (reset)
	  checks_on && DUT.got_marker && !cfg_done |=> (DUT.got_marker || cfg_done);
  endproperty

  a_marker_sticky_until_done: assert property (p_marker_sticky_until_done)
	else begin
	  $error("ASSERT FAIL: got_marker dropped before cfg_done");
	  fail_count++;
	end

  property p_cnt_range_before_done;
	@(posedge clk) disable iff (reset)
	  checks_on && !cfg_done && DUT.got_marker |->
		(DUT.cnt <= 2'd2);
  endproperty

  a_cnt_range_before_done: assert property (p_cnt_range_before_done)
	else begin
	  $error("ASSERT FAIL: cnt out of range before cfg_done");
	  fail_count++;
	end

  property p_cnt_increments;
	@(posedge clk) disable iff (reset)
	  checks_on &&
	  !$past(reset) &&
	  $past(DUT.got_marker) &&
	  !$past(cfg_done) &&
	  ($past(DUT.cnt) < 2'd2)
		|-> (DUT.cnt == ($past(DUT.cnt) + 2'd1));
  endproperty

  a_cnt_increments: assert property (p_cnt_increments)
	else begin
	  $error("ASSERT FAIL: cnt did not increment by 1");
	  fail_count++;
	end

  // ==========================================================================
  // Coverage
  // ==========================================================================

  covergroup cg_cfg @(posedge clk);
	cp_L_ctrl: coverpoint L_ctrl iff (!reset && cfg_done) {
	  bins L2 = {3'd2};
	  bins L3 = {3'd3};
	  bins L4 = {3'd4};
	  bins L5 = {3'd5};

	  bins unsupported_L0 = {3'd0};
	  bins unsupported_L1 = {3'd1};
	  bins unsupported_L6 = {3'd6};
	  bins unsupported_L7 = {3'd7};
	}

	cp_cfg_done: coverpoint cfg_done {
	  bins lo = {1'b0};
	  bins hi = {1'b1};
	}

	cp_cfg_ready_now: coverpoint cfg_ready_now {
	  bins lo = {1'b0};
	  bins hi = {1'b1};
	}

	cp_ready_before_done: coverpoint cfg_ready_now iff (!reset && !cfg_done) {
	  bins ready_early = {1'b1};
	}

	cp_marker: coverpoint DUT.got_marker iff (!reset) {
	  bins lo = {1'b0};
	  bins hi = {1'b1};
	}

	cp_cnt: coverpoint DUT.cnt iff (!reset && DUT.got_marker && !cfg_done) {
	  bins c0 = {2'd0};
	  bins c1 = {2'd1};
	  bins c2 = {2'd2};
	}
  endgroup

  cg_cfg cov_inst = new();

  logic [2:0] result_L;

  // ==========================================================================
  // Main test
  // ==========================================================================

  initial begin
	pass_count = 0;
	fail_count = 0;
	checks_on  = 1'b0;

	L_values[0] = 3'd2;
	L_values[1] = 3'd3;
	L_values[2] = 3'd4;
	L_values[3] = 3'd5;

	bad_L_values[0] = 3'd0;
	bad_L_values[1] = 3'd1;
	bad_L_values[2] = 3'd6;
	bad_L_values[3] = 3'd7;

	$display("=============================================================");
	$display(" TB: spi_cfg4_nomode - posedge-synchronous TB with SVA");
	$display("=============================================================");

	serial_in = 1'b0;
	reset     = 1'b1;

	repeat (4) wait_clk();

	checks_on = 1'b1;

	// TEST 1
	$display("\n--- TEST 1: Reset state ---");
	assert_eq3 ("reset/L_ctrl",    L_ctrl,        3'd2);
	assert_bit("reset/cfg_done",   cfg_done,      1'b0);
	assert_bit("reset/cfg_ready",  cfg_ready_now, 1'b0);

	// TEST 2
	$display("\n--- TEST 2: Valid L encodings ---");
	foreach (L_values[i]) begin
	  do_reset();
	  send_header(L_values[i], result_L);

	  assert_eq3 ($sformatf("L=%0d/L_ctrl", L_values[i]), result_L, L_values[i]);
	  assert_bit($sformatf("L=%0d/cfg_done", L_values[i]), cfg_done, 1'b1);
	  assert_bit($sformatf("L=%0d/cfg_ready", L_values[i]), cfg_ready_now, 1'b1);
	end

	// TEST 3
	$display("\n--- TEST 3: cfg_ready_now timing ---");
	do_reset();

	assert_bit("before_header/cfg_ready_now", cfg_ready_now, 1'b0);
	assert_bit("before_header/cfg_done",      cfg_done,      1'b0);

	drive_serial_bit(1'b1);
	assert_bit("after_marker/cfg_ready_now", cfg_ready_now, 1'b0);
	assert_bit("after_marker/cfg_done",      cfg_done,      1'b0);

	drive_serial_bit(1'b0);
	assert_bit("after_L0/cfg_ready_now", cfg_ready_now, 1'b0);
	assert_bit("after_L0/cfg_done",      cfg_done,      1'b0);

	drive_serial_bit(1'b1);
	assert_bit("after_L1/cfg_ready_now", cfg_ready_now, 1'b1);
	assert_bit("after_L1/cfg_done",      cfg_done,      1'b0);

	drive_serial_bit(1'b0);
	assert_bit("after_L2/cfg_ready_now", cfg_ready_now, 1'b1);
	assert_bit("after_L2/cfg_done",      cfg_done,      1'b1);
	assert_eq3 ("after_L2/L_ctrl",       L_ctrl,        3'd2);

	wait_clk();

	// TEST 4
	$display("\n--- TEST 4: Reconfig ignored without reset ---");
	drive_serial_bit(1'b1);
	drive_serial_bit(1'b1);
	drive_serial_bit(1'b1);
	drive_serial_bit(1'b1);

	assert_eq3 ("no_reset_reconfig/L_ctrl_still_2", L_ctrl, 3'd2);
	assert_bit("no_reset_reconfig/cfg_done",        cfg_done, 1'b1);

	// TEST 5
	$display("\n--- TEST 5: Leading zeros before marker ---");
	do_reset();

	repeat (5) begin
	  drive_serial_bit(1'b0);
	end

	assert_bit("leading_zeros/cfg_done_before_marker",  cfg_done, 1'b0);
	assert_bit("leading_zeros/cfg_ready_before_marker", cfg_ready_now, 1'b0);

	send_header(3'd5, result_L);

	assert_eq3 ("leading_zeros/L5",       result_L, 3'd5);
	assert_bit("leading_zeros/cfg_done",  cfg_done, 1'b1);
	assert_bit("leading_zeros/cfg_ready", cfg_ready_now, 1'b1);

	// TEST 6
	$display("\n--- TEST 6: Reset mid-sequence ---");
	do_reset();

	drive_serial_bit(1'b1);
	drive_serial_bit(1'b0);

	reset     <= 1'b1;
	serial_in <= 1'b0;

	repeat (3) wait_clk();

	reset <= 1'b0;

	wait_clk();

	assert_bit("mid_reset/cfg_done",  cfg_done, 1'b0);
	assert_bit("mid_reset/cfg_ready", cfg_ready_now, 1'b0);
	assert_eq3 ("mid_reset/L_ctrl",   L_ctrl,   3'd2);

	send_header(3'd3, result_L);
	assert_eq3 ("mid_reset/recovery_L3", result_L, 3'd3);
	assert_bit("mid_reset/recovery_done", cfg_done, 1'b1);

	// TEST 7
	$display("\n--- TEST 7: Multiple resets ---");

	repeat (3) begin
	  reset     <= 1'b1;
	  serial_in <= 1'b0;

	  repeat (2) wait_clk();

	  reset <= 1'b0;

	  wait_clk();
	end

	assert_bit("multi_reset/cfg_done",  cfg_done, 1'b0);
	assert_bit("multi_reset/cfg_ready", cfg_ready_now, 1'b0);
	assert_eq3 ("multi_reset/L_ctrl",   L_ctrl,   3'd2);

	send_header(3'd4, result_L);
	assert_eq3 ("multi_reset/L4_after", result_L, 3'd4);
	assert_bit("multi_reset/done_after", cfg_done, 1'b1);

	// TEST 8
	$display("\n--- TEST 8: Shuffled valid L order ---");
	begin
	  logic [2:0] rand_seq [0:19];
	  logic [2:0] tmp;
	  int hit_count [0:7];
	  int i;
	  int j;

	  for (i = 0; i < 8; i++) hit_count[i] = 0;

	  for (i = 0; i < 20; i++) begin
		rand_seq[i] = 3'd2 + (i % 4);
	  end

	  for (i = 19; i > 0; i--) begin
		j = $urandom_range(i, 0);
		tmp = rand_seq[i];
		rand_seq[i] = rand_seq[j];
		rand_seq[j] = tmp;
	  end

	  for (i = 0; i < 20; i++) begin
		do_reset();
		send_header(rand_seq[i], result_L);
		hit_count[rand_seq[i]]++;

		assert_eq3($sformatf("shuffle[%0d]/L=%0d", i, rand_seq[i]),
				   result_L, rand_seq[i]);
	  end

	  assert_int("shuffle/hit_L2", hit_count[2], 5);
	  assert_int("shuffle/hit_L3", hit_count[3], 5);
	  assert_int("shuffle/hit_L4", hit_count[4], 5);
	  assert_int("shuffle/hit_L5", hit_count[5], 5);
	end

	// TEST 9
	$display("\n--- TEST 9: Unsupported header codes are observed ---");
	foreach (bad_L_values[i]) begin
	  do_reset();
	  send_header(bad_L_values[i], result_L);

	  assert_eq3 ($sformatf("unsupported_L=%0d/L_ctrl", bad_L_values[i]),
				  result_L, bad_L_values[i]);
	  assert_bit($sformatf("unsupported_L=%0d/cfg_done", bad_L_values[i]),
				 cfg_done, 1'b1);
	end

	repeat (5) wait_clk();

	$display("\n=============================================================");
	$display(" RESULTS: %0d passed, %0d failed", pass_count, fail_count);
	$display(" Coverage: %.1f%%", cov_inst.get_coverage());
	$display("=============================================================");

	if (fail_count == 0)
	  $display(" ALL TESTS PASSED");
	else
	  $display(" FAILURES DETECTED - review above");

	$display("=============================================================");
	$finish;
  end

  initial begin
	#100000;
	$display("TIMEOUT - simulation hung");
	$finish;
  end

  initial begin
	$dumpfile("dump.vcd");
	$dumpvars(0, tb_spi_cfg4_nomode);
  end

endmodule
