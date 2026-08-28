`timescale 1ns/1ps

// ============================================================================
// tb_corner_top.sv
//
// Gate-level testbench for the PAD-level netlist in top.v.
//
// Run ONE interpolation factor per simulation:
// Default files selected by +L:
//   L=2 : input_L2.txt -> output_L2.txt, gate_L2.vcd
//   L=3 : input_L3.txt -> output_L3.txt, gate_L3.vcd
//   L=4 : input_L4.txt -> output_L4.txt, gate_L4.vcd
//   L=5 : input_L5.txt -> output_L5.txt, gate_L5.vcd
//
// Optional overrides:
//   +INPUT=<input_file> +OUTPUT=<output_file> +VCD=<vcd_file>
//
// Important hierarchy in top.v:
//   dut       = PAD-level module top
//   dut.I0    = synthesized top_interpolator_dac core
//   dut.I0.n167 = valid DAC-output pulse surviving synthesis
// ============================================================================
module tb_GLS;

	localparam integer IN_W  = 16;
	localparam integer WL    = 16;
	localparam integer NTAPS = 10;
	localparam integer MAXS  = 200000;
	localparam integer L_VALUE = 5;
	// 960 MHz clock, matching the existing corner testbench.
	localparam realtime HALF_CLK_PERIOD = 0.520833;
	localparam integer  RESET_CYCLES    = 5;
	localparam integer  DRAIN_CYCLES    = 1000;

	reg clk;
	reg reset;
	reg serial_in_I;
	reg serial_in_Q;

	wire [WL-1:0] dac_I;
	wire [WL-1:0] dac_Q;

	integer L_value;
	integer fdi;
	integer fdo;
	integer ti;
	integer tq;
	integer got;
	integer idx;
	integer nSamp;
	integer k;
	integer kb;
	integer iq_bits;
	integer ndac;

	reg [8*256-1:0] line;
	reg [15:0]       memCoeff [0:NTAPS-1];
	reg [IN_W-1:0]   memI     [0:MAXS-1];
	reg [IN_W-1:0]   memQ     [0:MAXS-1];
	reg [3:0]         hdr4;

	reg capture_enable;
	reg streaming_active;

	string in_file;
	string out_file;
	string vcd_file;

	// ------------------------------------------------------------------------
	// PAD-level DUT from top.v.
	// ------------------------------------------------------------------------
	top dut (
		.clk         (clk),
		.reset       (reset),
		.serial_in_I (serial_in_I),
		.serial_in_Q (serial_in_Q),
		.dac_I       (dac_I),
		.dac_Q       (dac_Q)
	);

	// Synthesized internal status nets that still exist in top.v.
	wire coeff_done;
	wire output_valid;
	assign coeff_done   = dut.I0.coeff_done;
	assign output_valid = dut.I0.n167;

	// ------------------------------------------------------------------------
	// Clock generation.
	// ------------------------------------------------------------------------
	initial begin
		clk = 1'b0;
		forever #HALF_CLK_PERIOD clk = ~clk;
	end

	// ------------------------------------------------------------------------
	// Choose the exact input/output/VCD names for this independent run.
	// ------------------------------------------------------------------------
	task automatic select_files;
		begin
			case (L_value)

				2: begin
					in_file  = "GLSP/input_L2.txt";
					out_file = "GLSP/output_L2.txt";
					vcd_file = "GLSP/gate_L2.vcd";
				end

				3: begin
					in_file  = "GLSP/input_L3.txt";
					out_file = "GLSP/output_L3.txt";
					vcd_file = "GLSP/gate_L3.vcd";
				end

				4: begin
					in_file  = "GLSP/input_L4.txt";
					out_file = "GLSP/output_L4.txt";
					vcd_file = "GLSP/gate_L4.vcd";
				end

				5: begin
					in_file  = "GLSP/input_L5.txt";
					out_file = "GLSP/output_L5.txt";
					vcd_file = "GLSP/gate_L5.vcd";
				end

				default: begin
					$fatal(
						1,
						"Unsupported L_VALUE=%0d. Use 2, 3, 4, or 5.",
						L_value
					);
				end

			endcase
		end
		endtask
	task automatic decode_iq_bits;
		begin
			case (hdr4)
				4'b0101: begin iq_bits = 16; if (L_value != 2) $fatal(1, "Header %b is L=2, but +L=%0d", hdr4, L_value); end
				4'b0111: begin iq_bits = 15; if (L_value != 3) $fatal(1, "Header %b is L=3, but +L=%0d", hdr4, L_value); end
				4'b1001: begin iq_bits = 16; if (L_value != 4) $fatal(1, "Header %b is L=4, but +L=%0d", hdr4, L_value); end
				4'b1011: begin iq_bits = 15; if (L_value != 5) $fatal(1, "Header %b is L=5, but +L=%0d", hdr4, L_value); end
				default: $fatal(1, "Illegal 4-bit header %b in %s", hdr4, in_file);
			endcase
		end
	endtask

	task automatic read_stimulus;
		begin
			fdi = $fopen(in_file, "r");
			if (fdi == 0)
				$fatal(1, "Cannot open input file: %s", in_file);

			if ($fgets(line, fdi) == 0)
				$fatal(1, "Input file is empty: %s", in_file);

			got = $sscanf(line, "%b", hdr4);
			if (got != 1)
				$fatal(1, "Cannot read the 4-bit header from %s", in_file);

			for (k = 0; k < NTAPS; k = k + 1) begin
				if ($fgets(line, fdi) == 0)
					$fatal(1, "Missing coefficient %0d in %s", k, in_file);

				got = $sscanf(line, "%h", ti);
				if (got != 1)
					$fatal(1, "Malformed coefficient %0d in %s", k, in_file);

				memCoeff[k] = ti[15:0];
			end

			nSamp = 0;
			while (!$feof(fdi)) begin
				if ($fgets(line, fdi) != 0) begin
					got = $sscanf(line, "%h %h", ti, tq);
					if (got == 2) begin
						if (nSamp >= MAXS)
							$fatal(1, "Too many samples in %s; increase MAXS", in_file);

						memI[nSamp] = ti[IN_W-1:0];
						memQ[nSamp] = tq[IN_W-1:0];
						nSamp = nSamp + 1;
					end
					else if (got != 0) begin
						$fatal(1, "Malformed I/Q line after sample %0d in %s", nSamp, in_file);
					end
				end
			end

			$fclose(fdi);
			decode_iq_bits();
		end
	endtask

	task automatic apply_reset;
		begin
			@(negedge clk);
			reset       = 1'b1;
			serial_in_I = 1'b0;
			serial_in_Q = 1'b0;

			repeat (RESET_CYCLES) @(posedge clk);

			@(negedge clk);
			reset = 1'b0;

			// Intentional idle zeros. The control logic must wait for Sync=1.
			repeat (5) @(posedge clk);
		end
	endtask

	// Header is serialized LSB-first, matching the original tb_corner.sv.
	task automatic send_header;
		begin
			serial_in_Q = 1'b0;
			for (kb = 0; kb < 4; kb = kb + 1) begin
				@(negedge clk);
				serial_in_I = hdr4[kb];
			end
			@(posedge clk);
		end
	endtask

	// Coefficients are sent MSB-first on serial_in_I.
	task automatic send_coeffs;
		begin
			for (k = 0; k < NTAPS; k = k + 1) begin
				for (kb = 15; kb >= 0; kb = kb - 1) begin
					@(negedge clk);
					serial_in_I = memCoeff[k][kb];
					serial_in_Q = 1'b0;
				end
			end
			@(posedge clk);
		end
	endtask

	// I and Q samples are sent together, MSB-first.
	// Odd L values use the lower 15-bit serial word, as in the original TB.
	task automatic send_iq;
		begin
			for (idx = 0; idx < nSamp; idx = idx + 1) begin
				if (iq_bits == 16) begin
					for (kb = 15; kb >= 0; kb = kb - 1) begin
						@(negedge clk);
						serial_in_I = memI[idx][kb];
						serial_in_Q = memQ[idx][kb];
					end
				end
				else begin
					for (kb = 14; kb >= 0; kb = kb - 1) begin
						@(negedge clk);
						serial_in_I = memI[idx][kb];
						serial_in_Q = memQ[idx][kb];
					end
				end

				if (((idx + 1) % 1000) == 0)
					$display("Sent %0d/%0d source samples", idx + 1, nSamp);
			end

			@(negedge clk);
			serial_in_I = 1'b0;
			serial_in_Q = 1'b0;
		end
	endtask

	task automatic write_hex_iq;
		input integer fd;
		input [WL-1:0] ri;
		input [WL-1:0] rq;
		begin
			$fwrite(fd, "%04h %04h\n", ri, rq);
		end
	endtask

	// ------------------------------------------------------------------------
	// Main: exactly one L/input file per simulation.
	// ------------------------------------------------------------------------
	initial begin
		reset            = 1'b1;
		serial_in_I      = 1'b0;
		serial_in_Q      = 1'b0;
		capture_enable   = 1'b0;
		streaming_active = 1'b0;
		fdo              = 0;
		ndac             = 0;
		L_value = L_VALUE;

		
		select_files();
		read_stimulus();

		// Dump only the complete PAD-level DUT hierarchy.
		// Activity is disabled during reset, idle, header, and coefficient load.
		$dumpfile(vcd_file);
		$dumpvars(0, dut);
		$dumpoff;

		fdo = $fopen(out_file, "w");
		if (fdo == 0)
			$fatal(1, "Cannot open output file: %s", out_file);

		$display("============================================================");
		$display("PAD-level gate simulation: L=%0d", L_value);
		$display("Input file : %s", in_file);
		$display("Output file: %s", out_file);
		$display("VCD file   : %s", vcd_file);
		$display("Header     : %b", hdr4);
		$display("IQ bits    : %0d", iq_bits);
		$display("Samples    : %0d", nSamp);
		$display("DUT scope  : tb_corner/dut");
		$display("Core scope : tb_corner/dut/I0");
		$display("============================================================");

		apply_reset();
		send_header();
		send_coeffs();

		// Let gate-level combinational paths settle without adding any extra
		// serial clock cycles between the last coefficient and the first IQ bit.
		#0.01;
		$display("[%0t] coeff_done=%b", $time, coeff_done);

		// Match the earlier power-VCD method: record only real streaming and
		// pipeline drain activity, not reset/configuration activity.
		streaming_active = 1'b1;
		capture_enable   = 1'b1;
		$display("[VCD] Starting activity dump for L=%0d", L_value);
		$dumpon;

		send_iq();
		repeat (DRAIN_CYCLES) @(posedge clk);

		@(negedge clk);
		capture_enable   = 1'b0;
		streaming_active = 1'b0;
		$dumpoff;
		$display("[VCD] Stopped activity dump for L=%0d", L_value);

		$fclose(fdo);
		fdo = 0;

		$display("============================================================");
		$display("Simulation completed for L=%0d", L_value);
		$display("Source samples : %0d", nSamp);
		$display("DAC samples    : %0d", ndac);
		$display("Output written : %s", out_file);
		$display("VCD written    : %s", vcd_file);
		$display("============================================================");

		$finish;
	end

	// ------------------------------------------------------------------------
	// Capture one DAC pair for every synthesized valid-output pulse.
	// Sampling on negedge avoids racing the gate-level sequential logic.
	// ------------------------------------------------------------------------
	always @(negedge clk) begin
		if (!reset && capture_enable && output_valid && (fdo != 0)) begin
			write_hex_iq(fdo, dac_I, dac_Q);
			ndac = ndac + 1;
		end
	end

endmodule