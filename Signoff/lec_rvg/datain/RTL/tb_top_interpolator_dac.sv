`timescale 1ns/1ps

module tb_top_interpolator_dac;

  localparam integer IN_W  = 16;
  localparam integer WL    = 16;
  localparam integer NTAPS = 10;
  localparam integer MAXS  = 200000;

  // DUT inputs
  reg clk;
  reg reset;
  reg serial_in_I;
  reg serial_in_Q;

  // DUT outputs
  wire signed [WL-1:0] dac_I;
  wire signed [WL-1:0] dac_Q;

  // file I/O
  integer fdi, fdo;
  reg [8*256-1:0] line;
  integer ti, tq, got;
  integer idx, nSamp, k;

  reg [15:0]        memCoeff [0:NTAPS-1];
  reg [IN_W-1:0]    memI     [0:MAXS-1];
  reg [IN_W-1:0]    memQ     [0:MAXS-1];

  reg signed [WL-1:0] last_dac_I;
  reg signed [WL-1:0] last_dac_Q;

  // header nibble from file line 1
  reg [3:0] hdr4;

  // ================= DUT =================
  top_interpolator_dac #(
	.WL    (WL),
	.FL    (12),
	.NTAPS (NTAPS)
  ) DUT (
	.clk         (clk),
	.reset       (reset),
	.serial_in_I (serial_in_I),
	.serial_in_Q (serial_in_Q),
	.dac_I       (dac_I),
	.dac_Q       (dac_Q)
  );

  // ================= VCD DUMP =================
  initial begin
	$dumpfile("top_interpolator_dac.vcd");
	$dumpvars(0, DUT);
  end

  // clock
  initial begin
	clk = 1'b0;
	forever #0.520833 clk = ~clk;
  end

  task write_hex_iq;
	input integer fd;
	input signed [WL-1:0] ri;
	input signed [WL-1:0] rq;
	begin
	  $fwrite(fd, "%04h %04h\n", ri[WL-1:0], rq[WL-1:0]);
	end
  endtask

  // MAIN
  initial begin
	// file format:
	// line 1           : 4-bit binary header nibble
	// next NTAPS lines : FIR coeffs, one 16-bit hex per line
	// remaining lines  : IQ hex pairs
	fdi = $fopen("iq_in_iq_16_12.txt", "r");
	if (fdi == 0) begin
	  $display("ERROR: cannot open input file iq_in_iq_16_12.txt");
	  $finish;
	end

	// header
	if ($fgets(line, fdi) == 0) begin
	  $display("ERROR: empty file");
	  $finish;
	end
	got = $sscanf(line, "%b", hdr4);
	if (got != 1) begin
	  $display("ERROR: first line must be 4-bit binary like 0111");
	  $finish;
	end

	// FIR coefficients
	for (k = 0; k < NTAPS; k = k + 1) begin
	  if ($fgets(line, fdi) == 0) begin
		$display("ERROR: file ended before reading %0d FIR coefficients", NTAPS);
		$finish;
	  end

	  got = $sscanf(line, "%h", ti);
	  if (got != 1) begin
		$display("ERROR: FIR coeff line %0d must contain one 16-bit hex number", k+1);
		$finish;
	  end
	  memCoeff[k] = ti[15:0];
	end

	// IQ data
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

	$display("HDR4 = %b (decimal %0d)", hdr4, hdr4);
	$display("FIR taps = %0d", NTAPS);
	$display("Read %0d IQ samples", nSamp);

	// output file
	fdo = $fopen("iq_out_hex.txt", "w");
	if (fdo == 0) begin
	  $display("ERROR: cannot open iq_out_hex.txt");
	  $finish;
	end

	// init
	reset       = 1'b1;
	serial_in_I = 1'b0;
	serial_in_Q = 1'b0;

	last_dac_I  = {WL{1'bx}};
	last_dac_Q  = {WL{1'bx}};

	repeat (3) @(posedge clk);
	reset <= 1'b0;
	@(posedge clk);

	// ==========================================================
	// SEND HEADER (LSB-first)
	// ==========================================================
	serial_in_Q <= 1'b0;

	serial_in_I <= hdr4[0]; @(posedge clk);
	serial_in_I <= hdr4[1]; @(posedge clk);
	serial_in_I <= hdr4[2]; @(posedge clk);
	serial_in_I <= hdr4[3]; @(posedge clk);

	// ==========================================================
	// SEND FIR COEFFICIENTS
	// - always 16-bit
	// - sent on I only
	// ==========================================================
	for (k = 0; k < NTAPS; k = k + 1) begin
	  for (int b = 0; b < 16; b = b + 1) begin
		serial_in_I <= memCoeff[k][15-b];
		serial_in_Q <= 1'b0;
		@(posedge clk);
	  end
	end

	// ==========================================================
	// START IQ DATA STREAM AFTER FIR COEFFS
	// ==========================================================
	if (nSamp > 0) begin
	  idx = 0;

	  serial_in_I <= memI[idx][IN_W-1];
	  serial_in_Q <= memQ[idx][IN_W-1];

	  for (int b = 1; b < IN_W; b = b + 1) begin
		@(posedge clk);
		serial_in_I <= memI[idx][IN_W-1-b];
		serial_in_Q <= memQ[idx][IN_W-1-b];
	  end

	  for (idx = 1; idx < nSamp; idx = idx + 1) begin
		for (int b = 0; b < IN_W; b = b + 1) begin
		  @(posedge clk);
		  serial_in_I <= memI[idx][IN_W-1-b];
		  serial_in_Q <= memQ[idx][IN_W-1-b];
		end
	  end
	end

	repeat (1000) @(posedge clk);

	$fclose(fdo);
	$display("✅ Simulation complete. Wrote iq_out_hex.txt");
	$finish;
  end

  // capture every valid FIR output sample
  always @(posedge clk) begin
	if (reset) begin
	  last_dac_I <= {WL{1'bx}};
	  last_dac_Q <= {WL{1'bx}};
	end else begin
	  if (DUT.coeff_done && DUT.shift_strobe_iq) begin
		$display("t=%0t  DAC_I=%04h (%0d)  DAC_Q=%04h (%0d)",
				 $time, dac_I[WL-1:0], $signed(dac_I),
						dac_Q[WL-1:0], $signed(dac_Q));
		if (fdo != 0)
		  write_hex_iq(fdo, dac_I, dac_Q);
	  end
	  last_dac_I <= dac_I;
	  last_dac_Q <= dac_Q;
	end
  end

endmodule
