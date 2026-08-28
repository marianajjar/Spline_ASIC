`timescale 1ns/1ps
module spi_cfg4_nomode (
  input  wire       clk,
  input  wire       reset,
  input  wire       serial_in,
  output reg  [2:0] L_ctrl,
  output reg        cfg_done,
  output wire       cfg_ready_now
);

  reg [1:0] cnt;
  reg       got_marker;
  reg [2:0] l_tmp;

  assign cfg_ready_now = cfg_done || (!cfg_done && got_marker && (cnt == 2'd2));

  always @(posedge clk or posedge reset) begin
	if (reset) begin
	  L_ctrl     <= 3'd2;
	  cfg_done   <= 1'b0;
	  got_marker <= 1'b0;
	  cnt        <= 2'd0;
	  l_tmp      <= 3'd0;

	end else if (!cfg_done) begin
	  if (!got_marker) begin
		if (serial_in) begin
		  got_marker <= 1'b1;
		  cnt        <= 2'd0;
		end
	  end else begin
		l_tmp[cnt] <= serial_in;

		if (cnt == 2'd2) begin
		  L_ctrl   <= {serial_in, l_tmp[1:0]};
		  cfg_done <= 1'b1;
		end else begin
		  cnt <= cnt + 2'd1;
		end
	  end
	end
  end

endmodule
