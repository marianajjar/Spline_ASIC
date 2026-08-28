`timescale 1ns/1ps

module tb_spi_i_master;
  localparam int W = 16;
  localparam real CLK_PERIOD = 1.0;

  logic clk;
  initial clk = 1'b0;
  always #(CLK_PERIOD/2.0) clk = ~clk;

  logic         reset;
  logic         en;
  logic         din;
  logic [2:0]   L;
  logic         force16_word;
  logic [W-1:0] word_out;
  logic         strobe;
  logic         shift_strobe;
  logic         mode15_word;

  spi_i_master #(.W(W)) DUT (
	.clk(clk), .reset(reset), .en(en), .din(din), .L(L),
	.force16_word(force16_word),
	.word_out(word_out), .strobe(strobe),
	.shift_strobe(shift_strobe), .mode15_word(mode15_word)
  );

  int pass_count, fail_count;
  logic checks_on;

  function automatic logic mode15_now(input logic [2:0] lv, input logic f16);
	return f16 ? 1'b0 : ((lv == 3'd3) || (lv == 3'd5));
  endfunction

  function automatic int term_now(input logic m15);
	return m15 ? 14 : 15;
  endfunction

  function automatic int div_now(input logic [2:0] lv);
	case (lv)
	  3'd2: return 8;
	  3'd3: return 5;
	  3'd4: return 4;
	  3'd5: return 3;
	  default: return 8;
	endcase
  endfunction

  task automatic wait_clk; begin @(posedge clk); #0.001; end endtask

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

  task automatic check_int(input string tag, input int got, input int exp);
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

  task automatic check_word(input string tag, input logic [15:0] got, input logic [15:0] exp);
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

  task automatic do_reset;
	begin
	  reset <= 1'b1; en <= 1'b0; din <= 1'b0; L <= 3'd2; force16_word <= 1'b0;
	  repeat (3) wait_clk();
	  reset <= 1'b0;
	  wait_clk();
	end
  endtask

  task automatic drive(input logic en_v, input logic din_v, input logic [2:0] l_v, input logic force_v);
	begin
	  en <= en_v; din <= din_v; L <= l_v; force16_word <= force_v;
	  wait_clk();
	end
  endtask

  task automatic start_stream(input logic [2:0] l_v, input logic force_v);
	begin
	  drive(1'b0, 1'b0, l_v, force_v);
	  drive(1'b1, 1'b0, l_v, force_v);
	end
  endtask

  task automatic run_bits(input int nbits, input logic [31:0] data,
						  input logic [2:0] l_v, input logic force_v,
						  output int strobe_count, output int shift_count);
	begin
	  strobe_count = 0;
	  shift_count = 0;
	  for (int b = nbits-1; b >= 0; b--) begin
		drive(1'b1, data[b], l_v, force_v);
		if (strobe) strobe_count++;
		if (shift_strobe) shift_count++;
	  end
	end
  endtask

  task automatic check_word_mode(input logic [2:0] l_v, input int nbits, input logic force_v);
	int sc, ssc;
	begin
	  do_reset();
	  start_stream(l_v, force_v);
	  run_bits(nbits, 32'h0000_A5C3, l_v, force_v, sc, ssc);
	  check_int($sformatf("L%0d_force%0b/strobe_count", l_v, force_v), sc, 1);
	  check_bit($sformatf("L%0d_force%0b/mode15", l_v, force_v), mode15_word, mode15_now(l_v, force_v));
	end
  endtask

  task automatic check_word_value(input logic [2:0] l_v,
								  input logic force_v,
								  input logic [15:0] data);
	int nbits;
	logic m15;
	logic [15:0] exp;
	begin
	  m15   = mode15_now(l_v, force_v);
	  nbits = m15 ? 15 : 16;
	  exp   = m15 ? {data[14], data[14:0]} : data;

	  do_reset();
	  start_stream(l_v, force_v);

	  for (int b = nbits-1; b >= 0; b--) begin
		en <= 1'b1;
		din <= data[b];
		L <= l_v;
		force16_word <= force_v;

		@(posedge clk);
		if (b == 0) begin
		  check_bit($sformatf("L%0d_force%0b/word_strobe", l_v, force_v),
					strobe, 1'b1);
		  check_word($sformatf("L%0d_force%0b/word_out", l_v, force_v),
					 word_out, exp);
		end else if (strobe) begin
		  $display("  FAIL  [L%0d_force%0b/early_strobe bit=%0d]  <---",
				   l_v, force_v, b);
		  fail_count++;
		end
		#0.001;
	  end
	end
  endtask

  property p_no_x;
	@(posedge clk) disable iff (reset)
	  checks_on && en |-> !$isunknown({word_out, strobe, shift_strobe, mode15_word});
  endproperty
  a_no_x: assert property (p_no_x) else begin $error("SPI-I output X/Z"); fail_count++; end

  property p_strobe_eq;
	@(posedge clk) disable iff (reset)
	  checks_on |-> (strobe == (en && (DUT.count == term_now(mode15_word))));
  endproperty
  a_strobe_eq: assert property (p_strobe_eq) else begin $error("strobe equation mismatch"); fail_count++; end

  property p_strobe_pulse;
	@(posedge clk) disable iff (reset)
	  checks_on && strobe |=> !strobe;
  endproperty
  a_strobe_pulse: assert property (p_strobe_pulse) else begin $error("strobe wider than one cycle"); fail_count++; end

  property p_shift_strobe_pulse;
	@(posedge clk) disable iff (reset)
	  checks_on && shift_strobe |=> !shift_strobe;
  endproperty
  a_shift_strobe_pulse: assert property (p_shift_strobe_pulse) else begin $error("shift_strobe wider than one cycle"); fail_count++; end

  property p_count_range;
	@(posedge clk) disable iff (reset)
	  checks_on && en |-> (DUT.count <= term_now(mode15_word));
  endproperty
  a_count_range: assert property (p_count_range) else begin $error("count out of range"); fail_count++; end

  property p_mode15_change_legal;
	@(posedge clk) disable iff (reset)
	  checks_on && !$past(reset) && (mode15_word != $past(mode15_word)) |->
		($past(en && !DUT.en_d) || ($past(DUT.count) == 0));
  endproperty
  a_mode15_change_legal: assert property (p_mode15_change_legal) else begin $error("mode15 changed mid-word"); fail_count++; end

  // strobe is combinational with en, so it must be quiet in the same cycle.
  // shift_strobe is registered, so a pulse generated on the previous enabled
  // edge may still be visible until this clock edge updates it low.
  property p_no_strobe_when_disabled;
	@(posedge clk) disable iff (reset)
	  checks_on && !en |-> !strobe;
  endproperty
  a_no_strobe_when_disabled: assert property (p_no_strobe_when_disabled) else begin $error("strobe high while en=0"); fail_count++; end

  property p_shift_strobe_clears_when_disabled;
	@(posedge clk) disable iff (reset)
	  checks_on && !en |=> !shift_strobe;
  endproperty
  a_shift_strobe_clears_when_disabled: assert property (p_shift_strobe_clears_when_disabled) else begin $error("shift_strobe did not clear after en=0"); fail_count++; end

  property p_enrise_clears_count;
	@(posedge clk) disable iff (reset)
	  checks_on && $rose(en) |=> (DUT.count == 0);
  endproperty
  a_enrise_clears_count: assert property (p_enrise_clears_count) else begin $error("en rise did not clear count"); fail_count++; end

  property p_word15_signext;
	@(posedge clk) disable iff (reset)
	  checks_on && mode15_word |-> (word_out[15] == word_out[14]);
  endproperty
  a_word15_signext: assert property (p_word15_signext) else begin $error("15-bit sign extension failed"); fail_count++; end

  property p_stepcnt_range;
	@(posedge clk) disable iff (reset)
	  checks_on && en && $past(en) && (L == $past(L)) |-> (DUT.step_cnt < div_now(L));
  endproperty
  a_stepcnt_range: assert property (p_stepcnt_range) else begin $error("step_cnt out of range"); fail_count++; end

  covergroup cg @(posedge clk);
	cp_L: coverpoint L {
	  bins L2={3'd2}; bins L3={3'd3}; bins L4={3'd4}; bins L5={3'd5};
	  bins unsupported[] = {3'd0,3'd1,3'd6,3'd7};
	}
	cp_mode15: coverpoint mode15_word { bins b0={0}; bins b1={1}; }
	cp_force16: coverpoint force16_word { bins b0={0}; bins b1={1}; }
	cp_strobe: coverpoint strobe { bins b0={0}; bins b1={1}; }
	cp_shift_strobe: coverpoint shift_strobe { bins b0={0}; bins b1={1}; }
	cp_en: coverpoint en { bins b0={0}; bins b1={1}; }
	cp_count: coverpoint DUT.count { bins c[] = {[0:15]}; }
	cp_div: coverpoint div_now(L) { bins d3={3}; bins d4={4}; bins d5={5}; bins d8={8}; }
	x_en_strobe: cross cp_en, cp_strobe {
	  illegal_bins strobe_when_off = binsof(cp_en.b0) && binsof(cp_strobe.b1);
	}
  endgroup
  cg cov_inst = new();

  initial begin
	int sc, ssc;
	pass_count=0; fail_count=0; checks_on=0;
	reset=1; en=0; din=0; L=2; force16_word=0;
	repeat (4) wait_clk();
	checks_on=1;

	$display("=============================================================");
	$display(" TB: spi_i_master clean block testbench");
	$display("=============================================================");

	$display("\n--- TEST 1: Reset and en gating ---");
	do_reset();
	check_bit("reset/strobe", strobe, 1'b0);
	check_bit("reset/shift_strobe", shift_strobe, 1'b0);
	repeat (10) drive(1'b0, $urandom(), 3'd2, 1'b0);

	$display("\n--- TEST 2: 16-bit and 15-bit word strobes ---");
	check_word_mode(3'd2, 16, 1'b0);
	check_word_mode(3'd4, 16, 1'b0);
	check_word_mode(3'd3, 15, 1'b0);
	check_word_mode(3'd5, 15, 1'b0);

	$display("\n--- TEST 2b: word_out value correctness ---");
	begin
	  logic [15:0] pats [0:4];
	  pats[0] = 16'h0000;
	  pats[1] = 16'hffff;
	  pats[2] = 16'ha5c3;
	  pats[3] = 16'h8001;
	  pats[4] = 16'h4002;

	  foreach (pats[i]) begin
		check_word_value(3'd2, 1'b0, pats[i]);
		check_word_value(3'd3, 1'b0, pats[i]);
		check_word_value(3'd5, 1'b1, pats[i]);
	  end
	end

	$display("\n--- TEST 3: force16 during coefficient load ---");
	check_word_mode(3'd3, 16, 1'b1);
	check_word_mode(3'd5, 16, 1'b1);

	$display("\n--- TEST 4: shift_strobe divider per L ---");
	for (int lv = 2; lv <= 5; lv++) begin
	  do_reset();
	  start_stream(lv[2:0], 1'b0);
	  sc=0; ssc=0;
	  repeat (80) begin
		drive(1'b1, $urandom(), lv[2:0], 1'b0);
		if (shift_strobe) ssc++;
	  end
	  check_int($sformatf("L%0d/shift_strobe_count", lv), ssc, 80 / div_now(lv[2:0]));
	end

	$display("\n--- TEST 5: illegal L defaults ---");
	for (int idx = 0; idx < 4; idx++) begin
	  logic [2:0] bad;
	  case (idx) 0: bad=0; 1: bad=1; 2: bad=6; default: bad=7; endcase
	  do_reset();
	  start_stream(bad, 1'b0);
	  repeat (20) drive(1'b1, $urandom(), bad, 1'b0);
	  check_bit($sformatf("badL%0d/mode15_zero", bad), mode15_word, 1'b0);
	end

	$display("\n--- TEST 6: en falling mid-word restarts ---");
	do_reset();
	start_stream(3'd5, 1'b0);
	repeat (6) drive(1'b1, $urandom(), 3'd5, 1'b0);
	repeat (3) drive(1'b0, $urandom(), 3'd5, 1'b0);
	drive(1'b1, $urandom(), 3'd5, 1'b0);
	check_int("restart/count_zero", DUT.count, 0);

	$display("\n--- TEST 7: constrained random stream ---");
	repeat (50) begin
	  logic [2:0] lv;
	  logic force_v;
	  logic [15:0] data;
	  lv = 3'd2 + $urandom_range(3,0);
	  force_v = $urandom_range(1,0);
	  data = $urandom();
	  check_word_value(lv, force_v, data);
	end

	repeat (5) wait_clk();
	$display("\n=============================================================");
	$display(" RESULTS: %0d passed, %0d failed", pass_count, fail_count);
	$display(" Coverage: %.1f%%", cov_inst.get_coverage());
	$display("=============================================================");
	if (fail_count == 0) $display(" ALL TESTS PASSED"); else $display(" FAILURES DETECTED");
	$finish;
  end

  initial begin #100000; $display("TIMEOUT"); $finish; end
  initial begin $dumpfile("dump_spi_i.vcd"); $dumpvars(0, tb_spi_i_master); end
endmodule
