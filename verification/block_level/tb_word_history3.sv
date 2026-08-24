`timescale 1ns/1ps
// ============================================================================
// tb_word_history3.sv
// Block-level testbench for word_history3 (spi_register.v)
//
// DUT: 3-deep word history. On posedge clk, if shift_en=1 AND strobe=1:
//          w2 <= w1; w1 <= w0; w0 <= word_in
//      Otherwise hold. Reset clears all three.
//
// Corners checked:
//   1.  Reset state (all three = 0)
//   2.  Single push
//   3.  Two consecutive pushes
//   4.  Three pushes — pipeline full
//   5.  Fourth push — oldest drops
//   6.  shift_en=0 inhibit (with strobe=1)
//   7.  strobe=0 inhibit (with shift_en=1)
//   8.  Both inhibit
//   9.  Reset mid-stream
//   10. Reset-release at the same edge where shift_en && strobe are HIGH
//       (priority race — important for the pipeline that drives this block)
//   11. Boundary values (0, all-1, 0x8000, 0x7FFF, 0x5555, 0xAAAA)
//   12. Constrained-random sliding-window check vs SW reference (200 words)
// ============================================================================

module tb_word_history3;

  localparam int  WL         = 16;
  localparam real CLK_PERIOD = 1.0;

  logic clk;
  initial clk = 1'b0;
  always #(CLK_PERIOD/2.0) clk = ~clk;

  logic          reset;
  logic          shift_en;
  logic          strobe;
  logic [WL-1:0] word_in;
  logic [WL-1:0] w0, w1, w2;

  word_history3 #(.WL(WL)) DUT (
    .clk     (clk),
    .reset   (reset),
    .shift_en(shift_en),
    .strobe  (strobe),
    .word_in (word_in),
    .w0      (w0),
    .w1      (w1),
    .w2      (w2)
  );

  int pass_count, fail_count;
  logic checks_on;

  task automatic wait_clk; begin @(posedge clk); #0.001; end endtask

  task automatic chk(input string tag, input logic [WL-1:0] got, input logic [WL-1:0] exp);
    begin
      if (got === exp) begin
        $display("  PASS  [%s] val=0x%04h", tag, got);
        pass_count++;
      end else begin
        $display("  FAIL  [%s] got=0x%04h exp=0x%04h  <---", tag, got, exp);
        fail_count++;
      end
    end
  endtask

  task automatic do_reset;
    begin
      reset    <= 1'b1;
      shift_en <= 1'b0;
      strobe   <= 1'b0;
      word_in  <= '0;
      repeat (3) wait_clk();
      reset    <= 1'b0;
      wait_clk();
    end
  endtask

  task automatic push(input logic [WL-1:0] d);
    begin
      word_in  <= d;
      shift_en <= 1'b1;
      strobe   <= 1'b1;
      wait_clk();
      shift_en <= 1'b0;
      strobe   <= 1'b0;
    end
  endtask

  // ------ Assertions ------
  property p_no_x;
    @(posedge clk) disable iff (reset)
      checks_on |-> !$isunknown({w0,w1,w2});
  endproperty
  a_no_x: assert property (p_no_x) else begin $error("X/Z on outputs"); fail_count++; end

  property p_hold_when_dis;
    @(posedge clk) disable iff (reset)
      checks_on && (!shift_en || !strobe) |=>
        (w0 == $past(w0)) && (w1 == $past(w1)) && (w2 == $past(w2));
  endproperty
  a_hold: assert property (p_hold_when_dis) else begin $error("history changed while disabled"); fail_count++; end

  property p_shift_when_en;
    @(posedge clk) disable iff (reset)
      checks_on && shift_en && strobe |=>
        (w0 == $past(word_in)) && (w1 == $past(w0)) && (w2 == $past(w1));
  endproperty
  a_shift: assert property (p_shift_when_en) else begin $error("shift function incorrect"); fail_count++; end

  // ------ Coverage ------
  covergroup cg @(posedge clk);
    cp_en:     coverpoint shift_en { bins lo={0}; bins hi={1}; }
    cp_strobe: coverpoint strobe   { bins lo={0}; bins hi={1}; }
    cp_x:      cross cp_en, cp_strobe;
    cp_w0_msb: coverpoint w0[WL-1] { bins lo={0}; bins hi={1}; }
    cp_zero:   coverpoint (w0=='0 && w1=='0 && w2=='0) { bins all_zero={1}; bins not_zero={0}; }
  endgroup
  cg cov_inst = new();

  initial begin
    pass_count=0; fail_count=0; checks_on=0;
    reset=1; shift_en=0; strobe=0; word_in='0;
    repeat (4) wait_clk();
    checks_on=1;

    $display("=============================================================");
    $display(" TB: word_history3 block testbench");
    $display("=============================================================");

    // TEST 1: Reset state
    $display("\n--- TEST 1: Reset state ---");
    do_reset();
    chk("rst/w0", w0, '0);
    chk("rst/w1", w1, '0);
    chk("rst/w2", w2, '0);

    // TEST 2-5: 1..4 pushes
    $display("\n--- TEST 2-5: 1..4 sequential pushes ---");
    do_reset();
    push(16'hAAAA);                    chk("p1/w0", w0, 16'hAAAA); chk("p1/w1", w1, '0); chk("p1/w2", w2, '0);
    push(16'hBBBB);                    chk("p2/w0", w0, 16'hBBBB); chk("p2/w1", w1, 16'hAAAA); chk("p2/w2", w2, '0);
    push(16'hCCCC);                    chk("p3/w0", w0, 16'hCCCC); chk("p3/w1", w1, 16'hBBBB); chk("p3/w2", w2, 16'hAAAA);
    push(16'hDDDD);                    chk("p4/w0", w0, 16'hDDDD); chk("p4/w1", w1, 16'hCCCC); chk("p4/w2", w2, 16'hBBBB);

    // TEST 6: shift_en=0 inhibit while strobe pulses
    $display("\n--- TEST 6: shift_en=0 inhibit ---");
    do_reset();
    push(16'h1111); push(16'h2222); push(16'h3333);
    word_in <= 16'hFFFF; shift_en <= 1'b0; strobe <= 1'b1;
    repeat (5) wait_clk();
    chk("en0/w0", w0, 16'h3333); chk("en0/w1", w1, 16'h2222); chk("en0/w2", w2, 16'h1111);
    strobe <= 1'b0;

    // TEST 7: strobe=0 inhibit while shift_en=1
    $display("\n--- TEST 7: strobe=0 inhibit ---");
    do_reset();
    push(16'h1234); push(16'h5678); push(16'h9ABC);
    word_in <= 16'hFFFF; shift_en <= 1'b1; strobe <= 1'b0;
    repeat (5) wait_clk();
    chk("st0/w0", w0, 16'h9ABC); chk("st0/w1", w1, 16'h5678); chk("st0/w2", w2, 16'h1234);
    shift_en <= 1'b0;

    // TEST 8: Both off
    $display("\n--- TEST 8: Both off ---");
    do_reset();
    push(16'hF0F0);
    word_in <= 16'hFFFF; shift_en <= 1'b0; strobe <= 1'b0;
    repeat (10) wait_clk();
    chk("both0/w0", w0, 16'hF0F0); chk("both0/w1", w1, '0); chk("both0/w2", w2, '0);

    // TEST 9: Reset mid-pipeline
    $display("\n--- TEST 9: Reset mid-pipeline ---");
    do_reset();
    push(16'hAAAA); push(16'hBBBB); push(16'hCCCC);
    reset <= 1'b1;
    repeat (3) wait_clk();
    reset <= 1'b0;
    wait_clk();
    chk("midrst/w0", w0, '0); chk("midrst/w1", w1, '0); chk("midrst/w2", w2, '0);

    // TEST 10: Reset release on same edge as shift_en && strobe
    $display("\n--- TEST 10: Reset release while shift_en && strobe HIGH ---");
    reset <= 1'b1; word_in <= 16'hDEAD; shift_en <= 1'b1; strobe <= 1'b1;
    repeat (3) wait_clk();
    reset <= 1'b0;        // async release on next edge: the rest must hold
    wait_clk();
    // Async release model: reset wins on the edge it falls, but inputs are
    // already at the proper hold value. After ONE clk we expect first shift.
    chk("rstrel/w0", w0, 16'hDEAD);
    shift_en <= 1'b0; strobe <= 1'b0;

    // TEST 11: Boundary values
    $display("\n--- TEST 11: Boundary values ---");
    do_reset();
    push(16'h0000); push(16'hFFFF); push(16'h8000);
    chk("bd1/w0", w0, 16'h8000); chk("bd1/w1", w1, 16'hFFFF); chk("bd1/w2", w2, 16'h0000);
    do_reset();
    push(16'h7FFF); push(16'h5555); push(16'hAAAA);
    chk("bd2/w0", w0, 16'hAAAA); chk("bd2/w1", w1, 16'h5555); chk("bd2/w2", w2, 16'h7FFF);

    // TEST 12: Constrained-random sliding-window check
    $display("\n--- TEST 12: Random sliding window (200 words) ---");
    begin
      localparam int N = 200;
      logic [WL-1:0] hist [N];
	  automatic int mism = 0;
	  do_reset();
      for (int i = 0; i < N; i++) begin
        hist[i] = $urandom();
        push(hist[i]);
        begin
          logic [WL-1:0] e0, e1, e2;
          e0 = hist[i];
          e1 = (i>=1) ? hist[i-1] : '0;
          e2 = (i>=2) ? hist[i-2] : '0;
          if (w0 !== e0 || w1 !== e1 || w2 !== e2) begin
            $display("  FAIL  [rnd/i=%0d] w=%04h%04h%04h  exp=%04h%04h%04h", i, w0,w1,w2, e0,e1,e2);
            mism++; fail_count++;
          end
        end
      end
      if (mism == 0) begin $display("  PASS  [rnd] %0d words", N); pass_count++; end
    end

    repeat (5) wait_clk();
    $display("\n=============================================================");
    $display(" RESULTS: %0d passed, %0d failed", pass_count, fail_count);
    $display(" Coverage: %.1f%%", cov_inst.get_coverage());
    $display("=============================================================");
    if (fail_count == 0) $display(" ALL TESTS PASSED"); else $display(" FAILURES DETECTED");
    $finish;
  end

  initial begin #200000; $display("TIMEOUT"); $finish; end
  initial begin $dumpfile("dump_word_history3.vcd"); $dumpvars(0,tb_word_history3); end
endmodule
