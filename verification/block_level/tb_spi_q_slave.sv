`timescale 1ns/1ps

module tb_spi_q_slave;
  localparam int W = 16;
  localparam real CLK_PERIOD = 1.0;

  logic clk;
  initial clk = 1'b0;
  always #(CLK_PERIOD/2.0) clk = ~clk;

  logic         reset;
  logic         en;
  logic         din;
  logic         mode15_word;
  logic [W-1:0] word_out;

  spi_q_slave #(.W(W)) DUT (
	.clk(clk),
	.reset(reset),
	.en(en),
	.din(din),
	.mode15_word(mode15_word),
	.word_out(word_out)
  );

  int pass_count, fail_count;
  logic checks_on;
  logic [W-2:0] ref_shreg;

  function automatic logic [W-1:0] ref_word(input logic [W-2:0] sh,
											input logic din_v,
											input logic m15_v);
	logic [W-1:0] tmp;
	begin
	  if (m15_v) begin
		tmp[14:0] = {sh[13:0], din_v};
		tmp[15]   = tmp[14];
	  end else begin
		tmp = {sh[14:0], din_v};
	  end
	  return tmp;
	end
  endfunction

  function automatic logic [W-1:0] exp_word15(input logic [15:0] data);
	return {data[14], data[14:0]};
  endfunction

  task automatic wait_clk;
	begin
	  @(posedge clk);
	  #0.001;
	end
  endtask

  task automatic check_bit(input string tag, input logic got, input logic exp);
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

  task automatic check_word(input string tag, input logic [W-1:0] got, input logic [W-1:0] exp);
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

  task automatic check_shreg(input string tag, input logic [W-2:0] exp);
	begin
	  if (DUT.shreg === exp) begin
		$display("  PASS  [%s] shreg=0x%04h", tag, DUT.shreg);
		pass_count++;
	  end else begin
		$display("  FAIL  [%s] shreg=0x%04h exp=0x%04h  <---", tag, DUT.shreg, exp);
		fail_count++;
	  end
	end
  endtask

  task automatic do_reset;
	begin
	  reset <= 1'b1;
	  en <= 1'b0;
	  din <= 1'b0;
	  mode15_word <= 1'b0;
	  ref_shreg = '0;

	  repeat (3) wait_clk();
	  reset <= 1'b0;
	  wait_clk();
	end
  endtask

  task automatic drive_bit(input logic en_v,
						   input logic din_v,
						   input logic m15_v,
						   input logic do_final_check,
						   input string tag,
						   input logic [W-1:0] final_exp);
	logic [W-1:0] sample_exp;
	begin
	  en <= en_v;
	  din <= din_v;
	  mode15_word <= m15_v;

	  @(posedge clk);

	  sample_exp = ref_word(ref_shreg, din_v, m15_v);
	  if (do_final_check) begin
		check_word(tag, word_out, final_exp);
	  end

	  #0.001;

	  if (en_v) begin
		ref_shreg = sample_exp[14:0];
	  end
	end
  endtask

  task automatic check_current_word(input string tag);
	logic [W-1:0] exp;
	begin
	  exp = ref_word(ref_shreg, din, mode15_word);
	  check_word(tag, word_out, exp);
	end
  endtask

  task automatic shift_word16(input logic [15:0] data, input string tag);
	begin
	  for (int b = 15; b >= 0; b--) begin
		drive_bit(1'b1, data[b], 1'b0, (b == 0), tag, data);
	  end
	end
  endtask

  task automatic shift_word15(input logic [15:0] data, input string tag);
	logic [15:0] exp;
	begin
	  exp = exp_word15(data);
	  for (int b = 14; b >= 0; b--) begin
		drive_bit(1'b1, data[b], 1'b1, (b == 0), tag, exp);
	  end
	end
  endtask

  property p_no_x;
	@(posedge clk) disable iff (reset)
	  checks_on |-> !$isunknown(word_out);
  endproperty
  a_no_x: assert property (p_no_x) else begin $error("word_out has X/Z"); fail_count++; end

  property p_word15_signext;
	@(posedge clk) disable iff (reset)
	  checks_on && mode15_word |-> (word_out[15] == word_out[14]);
  endproperty
  a_word15_signext: assert property (p_word15_signext) else begin $error("15-bit sign extension failed"); fail_count++; end

  property p_shreg_frozen;
	@(posedge clk) disable iff (reset)
	  checks_on && !en |=> $stable(DUT.shreg);
  endproperty
  a_shreg_frozen: assert property (p_shreg_frozen) else begin $error("shreg changed while en=0"); fail_count++; end

  property p_shift_when_en;
	@(posedge clk) disable iff (reset)
	  checks_on && en |=> (DUT.shreg == $past(word_out[14:0]));
  endproperty
  a_shift_when_en: assert property (p_shift_when_en) else begin $error("shreg did not load sampled word_out[14:0]"); fail_count++; end

  property p_reset;
	@(posedge clk)
	  checks_on && reset |-> (DUT.shreg == '0);
  endproperty
  a_reset: assert property (p_reset) else begin $error("shreg not zero during reset"); fail_count++; end

  covergroup cg @(posedge clk);
	cp_mode15: coverpoint mode15_word { bins b0={0}; bins b1={1}; }
	cp_en:     coverpoint en          { bins b0={0}; bins b1={1}; }
	cp_din:    coverpoint din         { bins b0={0}; bins b1={1}; }
	cp_sign15: coverpoint word_out[15] iff (mode15_word) { bins pos={0}; bins neg={1}; }
	x_mode_din: cross cp_mode15, cp_din;
  endgroup
  cg cov_inst = new();

  initial begin
	logic [15:0] pats [0:4];
	logic [14:0] held_ref;

	pass_count = 0;
	fail_count = 0;
	checks_on = 0;
	reset = 1'b1;
	en = 1'b0;
	din = 1'b0;
	mode15_word = 1'b0;
	ref_shreg = '0;

	pats[0] = 16'h0000;
	pats[1] = 16'hffff;
	pats[2] = 16'ha5c3;
	pats[3] = 16'h8001;
	pats[4] = 16'h4002;

	repeat (4) wait_clk();
	checks_on = 1'b1;

	$display("=============================================================");
	$display(" TB: spi_q_slave clean block testbench");
	$display("=============================================================");

	$display("\n--- TEST 1: Reset ---");
	do_reset();
	check_word("reset/word_out", word_out, 16'h0000);
	check_shreg("reset/shreg", 15'h0000);

	$display("\n--- TEST 2: 16-bit word value correctness ---");
	foreach (pats[i]) begin
	  do_reset();
	  shift_word16(pats[i], $sformatf("word16_0x%04h", pats[i]));
	end

	$display("\n--- TEST 3: 15-bit sign extension and value correctness ---");
	foreach (pats[i]) begin
	  do_reset();
	  shift_word15(pats[i], $sformatf("word15_0x%04h", exp_word15(pats[i])));
	  check_bit($sformatf("word15_0x%04h/signext", exp_word15(pats[i])),
				word_out[15], word_out[14]);
	end

	$display("\n--- TEST 4: en gating keeps shreg frozen ---");
	do_reset();
	shift_word16(16'h1234, "gate/preload_1234");
	held_ref = ref_shreg;

	drive_bit(1'b0, 1'b1, 1'b0, 1'b0, "unused", 16'h0000);
	check_shreg("en0_hold_after_din1_mode16", held_ref);
	check_current_word("en0_comb_word_mode16");

	drive_bit(1'b0, 1'b0, 1'b1, 1'b0, "unused", 16'h0000);
	check_shreg("en0_hold_after_mode15", held_ref);
	check_current_word("en0_comb_word_mode15");

	$display("\n--- TEST 5: Back-to-back words without idle ---");
	do_reset();
	shift_word16(16'h1111, "back_to_back_1111");
	shift_word16(16'h2222, "back_to_back_2222");
	shift_word15(16'h4002, "back_to_back_c002_15bit");

	$display("\n--- TEST 6: Reset mid receive ---");
	do_reset();
	for (int b = 15; b >= 8; b--) begin
	  drive_bit(1'b1, 1'b1, 1'b0, 1'b0, "unused", 16'h0000);
	end
	do_reset();
	check_word("mid_reset/word_out", word_out, 16'h0000);
	check_shreg("mid_reset/shreg", 15'h0000);

	$display("\n--- TEST 7: Constrained random value checks ---");
	repeat (30) begin
	  logic [15:0] data;
	  data = $urandom();
	  do_reset();
	  shift_word16(data, $sformatf("rand16_0x%04h", data));
	end
	repeat (30) begin
	  logic [15:0] data;
	  data = $urandom();
	  do_reset();
	  shift_word15(data, $sformatf("rand15_0x%04h", exp_word15(data)));
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
	#100000;
	$display("TIMEOUT");
	$finish;
  end

  initial begin
	$dumpfile("dump_spi_q.vcd");
	$dumpvars(0, tb_spi_q_slave);
  end
endmodule
