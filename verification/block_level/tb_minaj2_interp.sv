`timescale 1ns/1ps

module tb_minaj2_interp;
  localparam real CLK_PERIOD = 1.0;

  logic clk;
  initial clk = 1'b0;
  always #(CLK_PERIOD/2.0) clk = ~clk;

  logic reset, en, strobe;
  logic [2:0] L_ctrl;
  logic signed [15:0] x_prev, x_c, x_n;
  logic signed [15:0] y0,y1,y2,y3,y4;

  minaj2_interp_3samp_internalSlope DUT (
	.clk(clk), .reset(reset), .en(en), .strobe(strobe), .L_ctrl(L_ctrl),
	.x_prev(x_prev), .x_c(x_c), .x_n(x_n),
	.y0(y0), .y1(y1), .y2(y2), .y3(y3), .y4(y4)
  );

  int pass_count, fail_count;
  logic checks_on;
  longint signed ref_mp;
  longint signed last_ref_mnew;

  task automatic wait_clk; begin @(posedge clk); #0.001; end endtask

  function automatic longint signed sra(input longint signed v, input int n);
	begin
	  sra = v >>> n;
	end
  endfunction

  function automatic longint signed sat16(input longint signed v);
	begin
	  if (v > 32767) sat16 = 32767;
	  else if (v < -32768) sat16 = -32768;
	  else sat16 = v;
	end
  endfunction

  function automatic longint signed wrap_n(input longint signed v, input int n);
	longint signed modv;
	longint signed base;
	begin
	  base = 64'sd1 <<< n;
	  modv = v % base;
	  if (modv < 0) modv = modv + base;
	  if (modv >= (64'sd1 <<< (n-1))) modv = modv - base;
	  wrap_n = modv;
	end
  endfunction

  function automatic logic signed [15:0] to_s16(input longint signed v);
	longint signed w;
	begin
	  w = wrap_n(v, 16);
	  to_s16 = $signed(w[15:0]);
	end
  endfunction

  function automatic longint signed calc_mnew(
	input longint signed xp,
	input longint signed xc,
	input longint signed xn,
	input longint signed mp
  );
	longint signed sum;
	longint signed raw;
	begin
	  sum = 8*xc + 3*xn - 11*xp - 4*mp;
	  raw = sra(sum * 1638 + 8192, 14);
	  calc_mnew = sat16(raw);
	end
  endfunction

  function automatic logic signed [15:0] eval_poly_ref(
	input longint signed c0,
	input longint signed c1,
	input longint signed c2,
	input longint signed c3,
	input longint signed U
  );
	longint signed t1, t2, t3;
	begin
	  t1 = sra(c3*U + 16384, 15) + c2;
	  t2 = sra(t1*U + 16384, 15) + c1;
	  t3 = sra(t2*U + 16384, 15) + c0;
	  eval_poly_ref = to_s16(t3);
	end
  endfunction

  task automatic expected_outputs(
	input logic [2:0] L,
	input longint signed xp,
	input longint signed xc,
	input longint signed xn,
	input longint signed mp,
	output logic signed [15:0] ey0,ey1,ey2,ey3,ey4,
	output longint signed mnew_out
  );
	longint signed mnew, delta, c0,c1,c2,c3;
	begin
	  mnew = calc_mnew(xp, xc, xn, mp);
	  mnew_out = mnew;
	  delta = xc - xp;
	  c0 = wrap_n(xp, 18);
	  c1 = wrap_n(mp, 18);
	  c2 = wrap_n(3*delta - 2*mp - mnew, 18);
	  c3 = wrap_n(mp + mnew - 2*delta, 18);

	  ey0 = to_s16(xp);
	  ey1 = 0; ey2 = 0; ey3 = 0; ey4 = 0;
	  case (L)
		3'd2: begin
		  ey1 = eval_poly_ref(c0,c1,c2,c3,16384);
		end
		3'd3: begin
		  ey1 = eval_poly_ref(c0,c1,c2,c3,10923);
		  ey2 = eval_poly_ref(c0,c1,c2,c3,21845);
		end
		3'd4: begin
		  ey1 = eval_poly_ref(c0,c1,c2,c3,8192);
		  ey2 = eval_poly_ref(c0,c1,c2,c3,16384);
		  ey3 = eval_poly_ref(c0,c1,c2,c3,24576);
		end
		default: begin
		  ey1 = eval_poly_ref(c0,c1,c2,c3,6554);
		  ey2 = eval_poly_ref(c0,c1,c2,c3,13107);
		  ey3 = eval_poly_ref(c0,c1,c2,c3,19661);
		  ey4 = eval_poly_ref(c0,c1,c2,c3,26214);
		end
	  endcase
	end
  endtask

  task automatic check_outputs(input string tag);
	logic signed [15:0] ey0,ey1,ey2,ey3,ey4;
	longint signed mn;
	int mm;
	begin
	  expected_outputs(L_ctrl, x_prev, x_c, x_n, ref_mp, ey0,ey1,ey2,ey3,ey4, mn);
	  last_ref_mnew = mn;
	  mm = 0;
	  if (y0 !== ey0) mm++;
	  if (y1 !== ey1) mm++;
	  if (y2 !== ey2) mm++;
	  if (y3 !== ey3) mm++;
	  if (y4 !== ey4) mm++;
	  if (mm == 0) begin
		$display("  PASS  [%s] y=%0d,%0d,%0d,%0d,%0d", tag, y0,y1,y2,y3,y4);
		pass_count++;
	  end else begin
		$display("  FAIL  [%s] got=%0d,%0d,%0d,%0d,%0d exp=%0d,%0d,%0d,%0d,%0d  <---",
				 tag, y0,y1,y2,y3,y4, ey0,ey1,ey2,ey3,ey4);
		fail_count++;
	  end
	end
  endtask

  task automatic do_reset;
	begin
	  reset <= 1; en <= 0; strobe <= 0; L_ctrl <= 3'd2;
	  x_prev <= 0; x_c <= 0; x_n <= 0;
	  ref_mp = 0; last_ref_mnew = 0;
	  repeat (3) wait_clk();
	  reset <= 0;
	  wait_clk();
	  if (DUT.m_p === 16'sd0) begin $display("  PASS  [reset/m_p]"); pass_count++; end
	  else begin $display("  FAIL  [reset/m_p]  <---"); fail_count++; end
	end
  endtask

  task automatic drive(input logic en_v, input logic strobe_v, input logic [2:0] L_v,
					   input logic signed [15:0] xp,xc,xn);
	longint signed old_mp;
	longint signed mnew_before;
	begin
	  old_mp = ref_mp;
	  mnew_before = calc_mnew(xp, xc, xn, old_mp);
	  en <= en_v; strobe <= strobe_v; L_ctrl <= L_v;
	  x_prev <= xp; x_c <= xc; x_n <= xn;
	  wait_clk();
	  if (en_v && strobe_v) ref_mp = mnew_before;
	  check_outputs($sformatf("en%0b_stb%0b_L%0d", en_v, strobe_v, L_v));
	  if ($signed(DUT.m_p) !== to_s16(ref_mp)) begin
		$display("  FAIL  [m_p_ref] got=%0d exp=%0d  <---", $signed(DUT.m_p), ref_mp);
		fail_count++;
	  end
	end
  endtask

  property p_no_x;
	@(posedge clk) disable iff (reset)
	  checks_on |-> !$isunknown({y0,y1,y2,y3,y4});
  endproperty
  a_no_x: assert property (p_no_x) else begin $error("interp output X/Z"); fail_count++; end

  property p_y0_eq_xprev;
	@(posedge clk) disable iff (reset)
	  checks_on |-> (y0 == x_prev);
  endproperty
  a_y0_eq_xprev: assert property (p_y0_eq_xprev) else begin $error("y0 != x_prev"); fail_count++; end

  property p_unused_zero;
	@(posedge clk) disable iff (reset)
	  checks_on |->
		((L_ctrl==3'd2) ? (y2==0 && y3==0 && y4==0) :
		 (L_ctrl==3'd3) ? (y3==0 && y4==0) :
		 (L_ctrl==3'd4) ? (y4==0) : 1'b1);
  endproperty
  a_unused_zero: assert property (p_unused_zero) else begin $error("unused output not zero"); fail_count++; end

  property p_mp_frozen;
	@(posedge clk) disable iff (reset)
	  checks_on && !(en && strobe) |=> $stable(DUT.m_p);
  endproperty
  a_mp_frozen: assert property (p_mp_frozen) else begin $error("m_p changed without en&&strobe"); fail_count++; end

  property p_mp_update;
	@(posedge clk) disable iff (reset)
	  checks_on && en && strobe |=> (DUT.m_p == $past(DUT.m_new));
  endproperty
  a_mp_update: assert property (p_mp_update) else begin $error("m_p did not update to m_new"); fail_count++; end

  covergroup cg @(posedge clk);
	cp_L: coverpoint L_ctrl {
	  bins L2={2}; bins L3={3}; bins L4={4}; bins L5={5};
	  bins illegal[] = {0,1,6,7};
	}
	cp_en: coverpoint en { bins b0={0}; bins b1={1}; }
	cp_strobe: coverpoint strobe { bins b0={0}; bins b1={1}; }
	x_en_strobe: cross cp_en, cp_strobe;
	cp_raw_m: coverpoint DUT.raw_m {
	  bins hi_sat = {[24'sd32768:24'sd8388607]};
	  bins lo_sat = {[-24'sd8388608:-24'sd32769]};
	  bins mid    = {[-24'sd32768:24'sd32767]};
	}
	cp_slope_sign: coverpoint DUT.m_new[15] { bins pos={0}; bins neg={1}; }
  endgroup
  cg cov_inst = new();

  initial begin
	pass_count=0; fail_count=0; checks_on=0;
	reset=1; en=0; strobe=0; L_ctrl=2; x_prev=0; x_c=0; x_n=0; ref_mp=0;
	repeat (4) wait_clk();
	checks_on=1;

	$display("=============================================================");
	$display(" TB: minaj2_interp clean bit-exact block testbench");
	$display("=============================================================");

	do_reset();

	$display("\n--- TEST 1: all L values active/unused outputs ---");
	for (int lv=2; lv<=5; lv++) begin
	  drive(1,1,lv[2:0],16'sd100,16'sd200,16'sd300);
	  drive(1,1,lv[2:0],16'sd200,16'sd300,16'sd400);
	end

	$display("\n--- TEST 2: DC and ramp ---");
	do_reset();
	repeat (5) drive(1,1,3'd5,16'sd1234,16'sd1234,16'sd1234);
	do_reset();
	for (int k=0; k<8; k++) drive(1,1,3'd4, k*100, (k+1)*100, (k+2)*100);

	$display("\n--- TEST 3: slope gating ---");
	drive(1,0,3'd5,16'sd0,16'sd1000,16'sd2000);
	drive(0,1,3'd5,16'sd0,16'sd2000,16'sd4000);
	drive(1,1,3'd5,16'sd0,16'sd3000,16'sd6000);

	$display("\n--- TEST 4: saturation and boundaries ---");
	drive(1,1,3'd5,-16'sd32768,16'sd32767,16'sd32767);
	drive(1,1,3'd5,16'sd32767,-16'sd32768,-16'sd32768);
	drive(1,1,3'd2,16'sd0,16'sd32767,-16'sd32768);

	$display("\n--- TEST 5: illegal L defaults to L5 output set ---");
	drive(1,1,3'd0,16'sd10,16'sd20,16'sd30);
	drive(1,1,3'd1,16'sd10,16'sd20,16'sd30);
	drive(1,1,3'd6,16'sd10,16'sd20,16'sd30);
	drive(1,1,3'd7,16'sd10,16'sd20,16'sd30);

	$display("\n--- TEST 6: constrained random bounded inputs ---");
	repeat (250) begin
	  logic signed [15:0] xp, xc, xn;
	  logic [2:0] lv;
	  xp = $urandom_range(16000,0) - 8000;
	  xc = $urandom_range(16000,0) - 8000;
	  xn = $urandom_range(16000,0) - 8000;
	  lv = $urandom_range(7,0);
	  drive($urandom_range(1,0), $urandom_range(1,0), lv, xp, xc, xn);
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
  initial begin $dumpfile("dump_minaj2_interp.vcd"); $dumpvars(0, tb_minaj2_interp); end
endmodule
