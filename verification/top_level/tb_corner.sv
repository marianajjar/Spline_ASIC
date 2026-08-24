`timescale 1ns/1ps
// ============================================================================
// tb_corner.sv  -  RTL
//
// Correct for this structure:
//
//   /project/verif/users/marianajjar/ws/spline_opt/
//   |
//   |-- InputSignal/
//   |    |-- manifest.txt
//   |    |-- seg01_L2.txt
//   |    |-- seg02_L3.txt
//   |    |-- ...
//   |
//   |-- RTL/
//        |-- tb_corner.sv
//        |-- top_interpolator_dac.v
//        |-- SignalOutput/
//             |-- seg01_L2.txt.out
//             |-- seg02_L3.txt.out
//
// Run simulation from:
//   /project/verif/users/marianajjar/ws/spline_opt
//
// Default manifest:
//   ./InputSignal/manifest.txt
//
// Default input files:
//   ./InputSignal/<stimfile>
//
// Default output files:
//   ./RTL/SignalOutput/<stimfile>.out
//
// Manifest lines:  <stimfile> [mode] [param]
//   <file>                      -> full run
//   <file> full                 -> full run
//   <file> abort_coeff K        -> reset, send header + K coeffs, RESET
//   <file> abort_iq    M        -> reset, send header + 10 coeffs + M IQ, RESET
//   <file> badhdr               -> reset, send illegal header + coeffs + IQ
//   <file> rst2_full            -> reset TWICE, then full run
//
// No VCD or FSDB generation is included.
// ============================================================================

module tb_corner;

  localparam integer IN_W  = 16;
  localparam integer WL    = 16;
  localparam integer NTAPS = 10;
  localparam integer MAXS  = 200000;

  reg clk;
  reg reset;
  reg serial_in_I;
  reg serial_in_Q;

  wire signed [WL-1:0] dac_I;
  wire signed [WL-1:0] dac_Q;

  integer fdi;
  integer fdo;
  integer mf;
  integer ti;
  integer tq;
  integer got;
  integer idx;
  integer nSamp;
  integer k;
  integer kb;
  integer iq_bits;
  integer nseg;
  integer param;
  integer ndac;

  reg [8*256-1:0] line;
  reg [8*256-1:0] mline;

  reg [15:0] memCoeff [0:NTAPS-1];
  reg [IN_W-1:0] memI [0:MAXS-1];
  reg [IN_W-1:0] memQ [0:MAXS-1];

  reg [3:0] hdr4;
  reg capture_enable;

  string manifest;
  string input_dir;
  string output_dir;
  string in_file;
  string stim_path;
  string mode_str;
  string out_file;

  // -------------------------------------------------------------------------
  // RTL DUT
  // -------------------------------------------------------------------------
  top_interpolator_dac DUT (
	.clk         (clk),
	.reset       (reset),
	.serial_in_I (serial_in_I),
	.serial_in_Q (serial_in_Q),
	.dac_I       (dac_I),
	.dac_Q       (dac_Q)
  );

  // -------------------------------------------------------------------------
  // Clock generation: approximately 960 MHz
  // -------------------------------------------------------------------------
  initial begin
	clk = 1'b0;
	forever #0.520833 clk = ~clk;
  end

  // -------------------------------------------------------------------------
  // Write one I/Q output pair
  // -------------------------------------------------------------------------
  task write_hex_iq;

	input integer fd;
	input signed [WL-1:0] ri;
	input signed [WL-1:0] rq;

	begin
	  $fwrite(fd, "%04h %04h\n", ri[WL-1:0], rq[WL-1:0]);
	end

  endtask

  // -------------------------------------------------------------------------
  // Normal reset
  // -------------------------------------------------------------------------
  task apply_reset;

	begin
	  reset       <= 1'b1;
	  serial_in_I <= 1'b0;
	  serial_in_Q <= 1'b0;

	  repeat (5) @(posedge clk);

	  reset <= 1'b0;

	  @(posedge clk);
	end

  endtask

  // -------------------------------------------------------------------------
  // Mid-stream reset
  // -------------------------------------------------------------------------
  task inject_reset;

	begin
	  reset       <= 1'b1;
	  serial_in_I <= 1'b0;
	  serial_in_Q <= 1'b0;

	  repeat (3) @(posedge clk);

	  reset <= 1'b0;

	  @(posedge clk);
	end

  endtask

  // -------------------------------------------------------------------------
  // Decode the number of bits per I/Q sample
  // -------------------------------------------------------------------------
  task decode_iq_bits;

	begin
	  case (hdr4)

		4'b0101: iq_bits = 16;
		4'b1001: iq_bits = 16;

		4'b0111: iq_bits = 15;
		4'b1011: iq_bits = 15;

		default: begin
		  iq_bits = 16;
		  $display("  NOTE: illegal header %b (treating IQ as 16-bit)", hdr4);
		end

	  endcase
	end

  endtask

  // -------------------------------------------------------------------------
  // Read one stimulus file
  // -------------------------------------------------------------------------
  task read_stimulus;

	input string fname;

	begin
	  fdi = $fopen(fname, "r");

	  if (fdi == 0) begin
		$display("ERROR: cannot open stimulus file %s", fname);
		$finish;
	  end

	  // Read header.
	  if ($fgets(line, fdi) == 0) begin
		$display("ERROR: missing header in %s", fname);
		$fclose(fdi);
		$finish;
	  end

	  got = $sscanf(line, "%b", hdr4);

	  if (got != 1) begin
		$display("ERROR: invalid header in %s", fname);
		$fclose(fdi);
		$finish;
	  end

	  // Read coefficients.
	  for (k = 0; k < NTAPS; k = k + 1) begin

		if ($fgets(line, fdi) == 0) begin
		  $display("ERROR: missing coefficient %0d in %s", k, fname);
		  $fclose(fdi);
		  $finish;
		end

		got = $sscanf(line, "%h", ti);

		if (got != 1) begin
		  $display("ERROR: invalid coefficient %0d in %s", k, fname);
		  $fclose(fdi);
		  $finish;
		end

		memCoeff[k] = ti[15:0];
	  end

	  // Read I/Q samples.
	  nSamp = 0;

	  while (!$feof(fdi) && nSamp < MAXS) begin

		if ($fgets(line, fdi) != 0) begin
		  got = $sscanf(line, "%h %h", ti, tq);

		  if (got == 2) begin
			memI[nSamp] = ti[IN_W-1:0];
			memQ[nSamp] = tq[IN_W-1:0];

			nSamp = nSamp + 1;
		  end
		end

	  end

	  $fclose(fdi);

	  decode_iq_bits();
	end

  endtask

  // -------------------------------------------------------------------------
  // Send header LSB first
  // -------------------------------------------------------------------------
  task send_header;

	begin
	  serial_in_Q <= 1'b0;

	  serial_in_I <= hdr4[0];
	  @(posedge clk);

	  serial_in_I <= hdr4[1];
	  @(posedge clk);

	  serial_in_I <= hdr4[2];
	  @(posedge clk);

	  serial_in_I <= hdr4[3];
	  @(posedge clk);
	end

  endtask

  // -------------------------------------------------------------------------
  // Send coefficients MSB first
  // -------------------------------------------------------------------------
  task send_coeffs;

	input integer ncoeff;

	begin
	  for (k = 0; k < ncoeff; k = k + 1) begin

		for (kb = 0; kb < 16; kb = kb + 1) begin
		  serial_in_I <= memCoeff[k][15-kb];
		  serial_in_Q <= 1'b0;

		  @(posedge clk);
		end

	  end
	end

  endtask

  // -------------------------------------------------------------------------
  // Send serialized I/Q samples
  // -------------------------------------------------------------------------
  task send_iq;

	input integer niq;

	begin
	  for (idx = 0; idx < niq; idx = idx + 1) begin

		if (iq_bits == 16) begin

		  serial_in_I <= memI[idx][15];
		  serial_in_Q <= memQ[idx][15];

		  for (kb = 1; kb < 16; kb = kb + 1) begin
			@(posedge clk);

			serial_in_I <= memI[idx][15-kb];
			serial_in_Q <= memQ[idx][15-kb];
		  end

		  @(posedge clk);

		end
		else begin

		  serial_in_I <= memI[idx][14];
		  serial_in_Q <= memQ[idx][14];

		  for (kb = 1; kb < 15; kb = kb + 1) begin
			@(posedge clk);

			serial_in_I <= memI[idx][14-kb];
			serial_in_Q <= memQ[idx][14-kb];
		  end

		  @(posedge clk);

		end

	  end
	end

  endtask

  // -------------------------------------------------------------------------
  // Main test sequence
  // -------------------------------------------------------------------------
  initial begin

	// These defaults are correct when running from:
	// /project/verif/users/marianajjar/ws/spline_opt
	input_dir  = "./InputSignal";
	output_dir = "./RTL/SignalOut";

	manifest = {input_dir, "/manifest.txt"};

	// Optional overrides:
	//
	//   ./simv +INPUT_DIR=./InputSignal
	//   ./simv +OUTPUT_DIR=./RTL/SignalOutput
	//   ./simv +MANIFEST=./InputSignal/manifest.txt
	//
	void'($value$plusargs("INPUT_DIR=%s", input_dir));
	void'($value$plusargs("OUTPUT_DIR=%s", output_dir));

	manifest = {input_dir, "/manifest.txt"};
	void'($value$plusargs("MANIFEST=%s", manifest));

	reset          = 1'b1;
	serial_in_I    = 1'b0;
	serial_in_Q    = 1'b0;
	capture_enable = 1'b0;

	fdo  = 0;
	ndac = 0;
	nseg = 0;

	repeat (3) @(posedge clk);

	mf = $fopen(manifest, "r");

	if (mf == 0) begin
	  $display("ERROR: cannot open manifest %s", manifest);
	  $finish;
	end

	$display("============================================================");
	$display("tb_corner RTL: directed reset/corner tests");
	$display("Manifest     : %s", manifest);
	$display("Input folder : %s", input_dir);
	$display("Output folder: %s", output_dir);
	$display("============================================================");

	while ($fgets(mline, mf) != 0) begin

	  in_file  = "";
	  mode_str = "full";
	  param    = 0;

	  got = $sscanf(mline, "%s %s %d", in_file, mode_str, param);

	  if (got >= 1) begin

		nseg = nseg + 1;

		// Input:
		// ./InputSignal/seg01_L2.txt
		stim_path = {input_dir, "/", in_file};

		// Output:
		// ./RTL/SignalOutput/seg01_L2.txt.out
		out_file = {output_dir, "/", in_file, ".out"};

		// --------------------------------------------------------------------
		// Reset before all coefficients are loaded
		// --------------------------------------------------------------------
		if (mode_str == "abort_coeff") begin

		  apply_reset();
		  read_stimulus(stim_path);

		  $display(
			"[%0d] %-16s abort_coeff %0d (illegal-early load)",
			nseg,
			in_file,
			param
		  );

		  send_header();
		  send_coeffs(param);

		  if (DUT.coeff_done) begin
			$display(
			  "      *** FAIL: coeff_done asserted after only %0d coeffs",
			  param
			);
		  end
		  else begin
			$display(
			  "      OK: coeff_done still low after %0d coeffs (no premature output)",
			  param
			);
		  end

		  inject_reset();

		end

		// --------------------------------------------------------------------
		// Reset during I/Q input transmission
		// --------------------------------------------------------------------
		else if (mode_str == "abort_iq") begin

		  apply_reset();
		  read_stimulus(stim_path);

		  $display(
			"[%0d] %-16s abort_iq %0d  (reset mid-stream)",
			nseg,
			in_file,
			param
		  );

		  send_header();
		  send_coeffs(NTAPS);
		  send_iq(param);

		  inject_reset();

		end

		// --------------------------------------------------------------------
		// Illegal header
		// --------------------------------------------------------------------
		else if (mode_str == "badhdr") begin

		  apply_reset();
		  read_stimulus(stim_path);

		  $display(
			"[%0d] %-16s badhdr %b   (illegal header)",
			nseg,
			in_file,
			hdr4
		  );

		  ndac = 0;

		  fdo = $fopen(out_file, "w");

		  if (fdo == 0) begin
			$display("ERROR: cannot open output file %s", out_file);
			$display("Make sure the directory %s exists.", output_dir);
			$finish;
		  end

		  capture_enable = 1'b1;

		  send_header();
		  send_coeffs(NTAPS);

		  if (nSamp < 32) begin
			send_iq(nSamp);
		  end
		  else begin
			send_iq(32);
		  end

		  repeat (400) @(posedge clk);

		  capture_enable = 1'b0;

		  $fclose(fdo);
		  fdo = 0;

		  $display(
			"      coeff_done=%b  (captured %0d DAC samples; not hang)",
			DUT.coeff_done,
			ndac
		  );

		  $display("      -> wrote %s", out_file);

		end

		// --------------------------------------------------------------------
		// Full run or reset-twice full run
		// --------------------------------------------------------------------
		else begin

		  apply_reset();

		  if (mode_str == "rst2_full") begin
			apply_reset();
		  end

		  read_stimulus(stim_path);

		  $display(
			"[%0d] %-16s %-10s HDR=%b L-bits=%0d nSamp=%0d",
			nseg,
			in_file,
			mode_str,
			hdr4,
			iq_bits,
			nSamp
		  );

		  ndac = 0;

		  fdo = $fopen(out_file, "w");

		  if (fdo == 0) begin
			$display("ERROR: cannot open output file %s", out_file);
			$display("Make sure the directory %s exists.", output_dir);
			$finish;
		  end

		  capture_enable = 1'b1;

		  send_header();
		  send_coeffs(NTAPS);
		  send_iq(nSamp);

		  repeat (1000) @(posedge clk);

		  capture_enable = 1'b0;

		  $fclose(fdo);
		  fdo = 0;

		  $display("      -> wrote %s", out_file);

		end
	  end
	end

	$fclose(mf);

	$display("============================================================");
	$display("tb_corner RTL: DONE, %0d lines", nseg);
	$display("============================================================");

	$finish;
  end

  // -------------------------------------------------------------------------
  // Output capture: sample dac_I/dac_Q on each DAC strobe while coeff_done.
  // -------------------------------------------------------------------------
  always @(posedge clk) begin

	if (!reset) begin

	  if (capture_enable && DUT.coeff_done && DUT.shift_strobe_iq) begin

		if (fdo != 0) begin
		  write_hex_iq(fdo, dac_I, dac_Q);
		  ndac = ndac + 1;
		end

	  end
	end

  end

endmodule