`timescale 1ns/1ps
// ============================================================================
// tb_minaj2_window_latch.sv
// Block-level testbench for minaj2_window_latch (spline_reg_out.v)
//
// DUT: 5-word capture register.  On posedge clk:
//        reset      -> all y*_r = 0
//        !en        -> hold
//        en && strobe -> y*_r <= y*
//        en && !strobe -> hold
//
// Corners checked:
//   1.  Reset state
//   2.  Single capture
//   3.  Sequential captures (each pushes new vector)
//   4.  Hold when en=0
//   5.  Hold when en=1, strobe=0
//   6.  Reset mid-stream
//   7.  Reset-release while en && strobe high (priority race)
//   8.  Boundary values (±FS, 0, alternating bits)
//   9.  Constrained-random capture vs SW reference (300 vectors)
// ============================================================================

module tb_minaj2_window_latch;

  localparam int  WL         = 16;
  localparam real CLK_PERIOD = 1.0;

  logic clk;
  initial clk = 1'b0;
  always #(CLK_PERIOD/2.0) clk = ~clk;

  logic                  reset;
  logic                  en;
  logic                  strobe;
  logic signed [WL-1:0]  y0, y1, y2, y3, y4;
  logic signed [WL-1:0]  y0_r, y1_r, y2_r, y3_r, y4_r;

  minaj2_window_latch #(.WL(WL)) DUT (
    .clk(clk), .reset(reset), .en(en), .strobe(strobe),
    .y0(y0), .y1(y1), .y2(y2), .y3(y3), .y4(y4),
    .y0_r(y0_r), .y1_r(y1_r), .y2_r(y2_r), .y3_r(y3_r), .y4_r(y4_r)
  );

  int pass_count, fail_count;
  logic checks_on;

  task automatic wait_clk; begin @(posedge clk); #0.001; end endtask

  task automatic chk_v(input string tag,
                       input logic signed [WL-1:0] g0, e0,
                       input logic signed [WL-1:0] g1, e1,
                       input logic signed [WL-1:0] g2, e2,
                       input logic signed [WL-1:0] g3, e3,
                       input logic signed [WL-1:0] g4, e4);
    begin
      if ((g0===e0)&&(g1===e1)&&(g2===e2)&&(g3===e3)&&(g4===e4)) begin
        $display("  PASS  [%s]", tag);
        pass_count++;
      end else begin
        $display("  FAIL  [%s] got=(%h %h %h %h %h) exp=(%h %h %h %h %h)  <---",
                 tag, g0,g1,g2,g3,g4, e0,e1,e2,e3,e4);
        fail_count++;
      end
    end
  endtask

  task automatic do_reset;
    begin
      reset<=1; en<=0; strobe<=0; y0<=0; y1<=0; y2<=0; y3<=0; y4<=0;
      repeat (3) wait_clk();
      reset<=0; wait_clk();
    end
  endtask

  task automatic drive_vec(input signed [WL-1:0] v0, v1, v2, v3, v4);
    begin y0<=v0; y1<=v1; y2<=v2; y3<=v3; y4<=v4; end
  endtask

  task automatic capture_vec(input signed [WL-1:0] v0, v1, v2, v3, v4);
    begin
      drive_vec(v0,v1,v2,v3,v4);
      en<=1; strobe<=1; wait_clk();
      en<=0; strobe<=0;
    end
  endtask

  property p_no_x;
    @(posedge clk) disable iff (reset)
      checks_on |-> !$isunknown({y0_r,y1_r,y2_r,y3_r,y4_r});
  endproperty
  a_no_x: assert property (p_no_x) else begin $error("X/Z on outputs"); fail_count++; end

  property p_hold_en0;
    @(posedge clk) disable iff (reset)
      checks_on && !en |=> $stable(y0_r) && $stable(y1_r) && $stable(y2_r) && $stable(y3_r) && $stable(y4_r);
  endproperty
  a_hold_en0: assert property (p_hold_en0) else begin $error("held wrong when en=0"); fail_count++; end

  property p_hold_strobe0;
    @(posedge clk) disable iff (reset)
      checks_on && en && !strobe |=> $stable(y0_r) && $stable(y1_r) && $stable(y2_r) && $stable(y3_r) && $stable(y4_r);
  endproperty
  a_hold_st0: assert property (p_hold_strobe0) else begin $error("held wrong when strobe=0"); fail_count++; end

  property p_capture;
    @(posedge clk) disable iff (reset)
      checks_on && en && strobe |=>
        (y0_r==$past(y0)) && (y1_r==$past(y1)) && (y2_r==$past(y2)) && (y3_r==$past(y3)) && (y4_r==$past(y4));
  endproperty
  a_capture: assert property (p_capture) else begin $error("capture mismatch"); fail_count++; end

  covergroup cg @(posedge clk);
    cp_en:     coverpoint en     { bins lo={0}; bins hi={1}; }
    cp_strobe: coverpoint strobe { bins lo={0}; bins hi={1}; }
    cp_x:      cross cp_en, cp_strobe;
    cp_y0_sign: coverpoint y0_r[WL-1] { bins neg={1}; bins pos={0}; }
  endgroup
  cg cov_inst = new();

  initial begin
    pass_count=0; fail_count=0; checks_on=0;
    reset=1; en=0; strobe=0; y0=0; y1=0; y2=0; y3=0; y4=0;
    repeat (4) wait_clk();
    checks_on=1;

    $display("=============================================================");
    $display(" TB: minaj2_window_latch block testbench");
    $display("=============================================================");

    // TEST 1
    $display("\n--- TEST 1: Reset state ---");
    do_reset();
    chk_v("rst", y0_r,0, y1_r,0, y2_r,0, y3_r,0, y4_r,0);

    // TEST 2
    $display("\n--- TEST 2: Single capture ---");
    do_reset();
    capture_vec(16'sd100,16'sd200,16'sd300,16'sd400,16'sd500);
    wait_clk();
    chk_v("cap1", y0_r,100, y1_r,200, y2_r,300, y3_r,400, y4_r,500);

    // TEST 3
    $display("\n--- TEST 3: Sequential captures ---");
    do_reset();
    capture_vec(16'sd1,16'sd2,16'sd3,16'sd4,16'sd5);
    capture_vec(16'sd10,16'sd20,16'sd30,16'sd40,16'sd50);
    capture_vec(16'sd100,16'sd200,16'sd300,16'sd400,16'sd500);
    chk_v("cap3", y0_r,100, y1_r,200, y2_r,300, y3_r,400, y4_r,500);

    // TEST 4: hold when en=0
    $display("\n--- TEST 4: Hold when en=0 ---");
    do_reset();
    capture_vec(16'sd7,16'sd8,16'sd9,16'sd10,16'sd11);
    drive_vec(16'sd999,16'sd999,16'sd999,16'sd999,16'sd999);
    en<=0; strobe<=1;
    repeat (5) wait_clk();
    chk_v("hold_en0", y0_r,7, y1_r,8, y2_r,9, y3_r,10, y4_r,11);
    strobe<=0;

    // TEST 5: hold when strobe=0
    $display("\n--- TEST 5: Hold when strobe=0 ---");
    do_reset();
    capture_vec(16'sd21,16'sd22,16'sd23,16'sd24,16'sd25);
    drive_vec(16'sd999,16'sd999,16'sd999,16'sd999,16'sd999);
    en<=1; strobe<=0;
    repeat (5) wait_clk();
    chk_v("hold_st0", y0_r,21, y1_r,22, y2_r,23, y3_r,24, y4_r,25);
    en<=0;

    // TEST 6: Reset mid-stream
    $display("\n--- TEST 6: Reset mid-stream ---");
    do_reset();
    capture_vec(16'sd111,16'sd112,16'sd113,16'sd114,16'sd115);
    reset<=1; repeat (3) wait_clk(); reset<=0; wait_clk();
    chk_v("midrst", y0_r,0, y1_r,0, y2_r,0, y3_r,0, y4_r,0);

    // TEST 7: Reset release while en && strobe HIGH
    $display("\n--- TEST 7: reset-release race ---");
    reset<=1; en<=1; strobe<=1;
    drive_vec(16'sd1,16'sd2,16'sd3,16'sd4,16'sd5);
    repeat (3) wait_clk();
    reset<=0;
    wait_clk();
    chk_v("rstrel", y0_r,1, y1_r,2, y2_r,3, y3_r,4, y4_r,5);
    en<=0; strobe<=0;

    // TEST 8: Boundary values
    $display("\n--- TEST 8: Boundary values ---");
    do_reset();
    capture_vec(16'sh7FFF,16'sh8000,16'sh0000,16'shFFFF,16'sh5555);
    chk_v("bd", y0_r,16'sh7FFF, y1_r,16'sh8000, y2_r,16'sh0000, y3_r,16'shFFFF, y4_r,16'sh5555);

    // TEST 9: Constrained random
    $display("\n--- TEST 9: Random capture vs reference (300 vectors) ---");
    begin
      automatic int mism = 0;
      logic signed [WL-1:0] r0,r1,r2,r3,r4;
      logic signed [WL-1:0] sw0,sw1,sw2,sw3,sw4;
      logic e_v, s_v;
      do_reset();
      sw0=0; sw1=0; sw2=0; sw3=0; sw4=0;
      for (int i = 0; i < 300; i++) begin
        r0 = $urandom(); r1 = $urandom(); r2 = $urandom();
        r3 = $urandom(); r4 = $urandom();
        e_v = $urandom_range(1,0);
        s_v = $urandom_range(1,0);
        drive_vec(r0,r1,r2,r3,r4);
        en <= e_v; strobe <= s_v;
        wait_clk();
        if (e_v && s_v) begin sw0=r0; sw1=r1; sw2=r2; sw3=r3; sw4=r4; end
        if (y0_r!==sw0 || y1_r!==sw1 || y2_r!==sw2 || y3_r!==sw3 || y4_r!==sw4) begin
          $display("  FAIL  [rnd/i=%0d en=%0b st=%0b] got=(%h %h %h %h %h) exp=(%h %h %h %h %h)",
                   i, e_v, s_v, y0_r,y1_r,y2_r,y3_r,y4_r, sw0,sw1,sw2,sw3,sw4);
          mism++; fail_count++;
        end
      end
      if (mism == 0) begin $display("  PASS  [rnd] 300 vectors"); pass_count++; end
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
  initial begin $dumpfile("dump_window_latch.vcd"); $dumpvars(0, tb_minaj2_window_latch); end
endmodule
