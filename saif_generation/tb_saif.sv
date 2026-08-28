`timescale 1ns/1ps

module tb_top_interpolator_dac;

  localparam integer STORE_W = 16;
  localparam integer WL      = 16;
  localparam integer NTAPS   = 10;
  localparam integer MAXS    = 200000;

  // Runtime mode selected with +L=2/3/4/5.
  integer L_VALUE;
  integer WORD_BITS;
  real    CLK_HALF_NS;
  integer mode_ready;

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
  reg [STORE_W-1:0] memI     [0:MAXS-1];
  reg [STORE_W-1:0] memQ     [0:MAXS-1];

  reg signed [WL-1:0] last_dac_I;
  reg signed [WL-1:0] last_dac_Q;

  // Header nibble from file line 1.
  // Encoding used by the project files:
  //   bit[0]   = synchronization marker = 1
  //   bit[3:1] = interpolation factor L
  reg [3:0] hdr4;

  // ================= MODE / CLOCK CONFIGURATION =================
  //
  // L=2,4 : 960 MHz, 16-bit serial input words
  // L=3,5 : 900 MHz, 15-bit serial input words
  //
  initial begin : mode_configuration
    mode_ready = 0;

    if (!$value$plusargs("L=%d", L_VALUE))
      L_VALUE = 2;

    case (L_VALUE)
      2, 4: begin
        WORD_BITS   = 16;
        CLK_HALF_NS = 0.520833333;  // 960 MHz
      end

      3, 5: begin
        WORD_BITS   = 15;
        CLK_HALF_NS = 0.555555556;  // 900 MHz
      end

      default: begin
        $display("ERROR: unsupported +L=%0d. Expected 2, 3, 4, or 5.", L_VALUE);
        $finish;
      end
    endcase

    $display("SAIF mode: L=%0d, serial word=%0d bits, clock=%0.3f MHz",
             L_VALUE, WORD_BITS,
             (1.0 / (2.0 * CLK_HALF_NS)) * 1000.0);

    mode_ready = 1;
  end

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

  // ================= OPTIONAL VCD =================
  // SAIF runs do not need a VCD. Add +VCD only when waveform debug is wanted.
  initial begin
    if ($test$plusargs("VCD")) begin
      $dumpfile("top_interpolator_dac.vcd");
      $dumpvars(0, DUT);
    end
  end

  // ================= CLOCK =================
  initial begin
    wait (mode_ready == 1);
    clk = 1'b0;
    forever #(CLK_HALF_NS) clk = ~clk;
  end

  task write_hex_iq;
    input integer fd;
    input signed [WL-1:0] ri;
    input signed [WL-1:0] rq;
    begin
      $fwrite(fd, "%04h %04h\n", ri[WL-1:0], rq[WL-1:0]);
    end
  endtask

  // ================= MAIN =================
  initial begin
    wait (mode_ready == 1);

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
      $display("ERROR: first line must be 4-bit binary like 0101");
      $finish;
    end

    // Make sure the selected +L mode matches the vector-file header.
    if ((hdr4[0] !== 1'b1) || (hdr4[3:1] !== L_VALUE[2:0])) begin
      $display("ERROR: input header %b does not match +L=%0d", hdr4, L_VALUE);
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
          memI[nSamp] = ti[STORE_W-1:0];
          memQ[nSamp] = tq[STORE_W-1:0];
          nSamp = nSamp + 1;
        end
      end
    end

    $fclose(fdi);

    $display("HDR4       = %b (decimal %0d)", hdr4, hdr4);
    $display("L           = %0d", L_VALUE);
    $display("WORD_BITS   = %0d", WORD_BITS);
    $display("FIR taps    = %0d", NTAPS);
    $display("IQ samples  = %0d", nSamp);

    // Output file is mainly useful for debug; SAIF generation itself
    // does not depend on this file.
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
    // START IQ DATA STREAM AFTER FIR COEFFICIENTS
    //
    // L=2,4 : transmit bits [15:0]
    // L=3,5 : transmit bits [14:0]
    //
    // This matches the actual serial-word cadence of each mode.
    // ==========================================================
    if (nSamp > 0) begin
      idx = 0;

      // First sample
      serial_in_I <= memI[idx][WORD_BITS-1];
      serial_in_Q <= memQ[idx][WORD_BITS-1];

      for (int b = 1; b < WORD_BITS; b = b + 1) begin
        @(posedge clk);
        serial_in_I <= memI[idx][WORD_BITS-1-b];
        serial_in_Q <= memQ[idx][WORD_BITS-1-b];
      end

      // Remaining samples
      for (idx = 1; idx < nSamp; idx = idx + 1) begin
        for (int b = 0; b < WORD_BITS; b = b + 1) begin
          @(posedge clk);
          serial_in_I <= memI[idx][WORD_BITS-1-b];
          serial_in_Q <= memQ[idx][WORD_BITS-1-b];
        end
      end
    end

    repeat (1000) @(posedge clk);

    $fclose(fdo);
    $display("Simulation complete. Wrote iq_out_hex.txt");
    $finish;
  end

  // Capture every valid FIR output sample.
  // The synthesized core netlist does not expose the original RTL valid
  // hierarchy used by the functional testbench, so this remains disabled
  // for the SAIF-only run.
  always @(posedge clk) begin
    if (reset) begin
      last_dac_I <= {WL{1'bx}};
      last_dac_Q <= {WL{1'bx}};
    end
    else begin
      if (1'b0) begin
        $display("t=%0t DAC_I=%04h (%0d) DAC_Q=%04h (%0d)",
                 $time,
                 dac_I[WL-1:0], $signed(dac_I),
                 dac_Q[WL-1:0], $signed(dac_Q));

        if (fdo != 0)
          write_hex_iq(fdo, dac_I, dac_Q);
      end

      last_dac_I <= dac_I;
      last_dac_Q <= dac_Q;
    end
  end

  // ================= SAIF TOGGLE CAPTURE =================
  //
  // Skip reset/configuration, then measure a steady-state processing window.
  //
  initial begin : saif_capture
    string _sf;

    wait (mode_ready == 1);

    if ($test$plusargs("SAIF")) begin
      if (!$value$plusargs("SAIFFILE=%s", _sf))
        _sf = "core.saif";

      $set_gate_level_monitoring("on");
      $set_toggle_region(DUT);

      repeat (300) @(posedge clk);    // skip reset/header/FIR configuration

      $display("SAIF_PROBE L=%0d WORD_BITS=%0d START t=%0t",
               L_VALUE, WORD_BITS, $time);

      $toggle_start;
      repeat (40000) @(posedge clk);  // steady-state IQ-processing window
      $toggle_stop;

      $toggle_report(_sf, 1.0e-9, "DUT");

      $display("SAIF_WRITTEN %s", _sf);
      $display("DONE L=%0d", L_VALUE);
      $finish;
    end
  end

endmodule
