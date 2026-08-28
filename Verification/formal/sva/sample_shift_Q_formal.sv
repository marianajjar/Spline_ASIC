`timescale 1ns/1ps

module sample_shift_Q_formal_checker #(parameter int WL = 16, parameter int NTAPS = 10) (
  input logic                     clk,
  input logic                     reset,
  input logic                     en,
  input logic [2:0]               L_ctrl,
  input logic                     shift_strobe,
  input logic [2:0]               phase_in,
  input logic signed [WL-1:0]     sample_sel,
  input logic signed [WL-1:0]     x [0:NTAPS-1]
);
  default clocking cb @(posedge clk); endclocking
  default disable iff (reset);

  wire legal_L = (L_ctrl inside {3'd2,3'd3,3'd4,3'd5});

  am_legal_L_when_enabled: assume property (
    en |-> legal_L
  );

  am_phase_from_I_range: assume property (
    en |-> (phase_in <= (L_ctrl - 3'd1))
  );

  a_no_x_phase_in: assert property (
    !$isunknown(phase_in)
  );

  a_x0_shift: assert property (
    en && shift_strobe |=> (x[0] == $past(sample_sel))
  );

  genvar gi;
  generate
    for (gi = 0; gi < NTAPS; gi++) begin : g_x_nox
      property p_x_no_x;
        @(posedge clk) disable iff (reset)
          !$isunknown(x[gi]);
      endproperty
      assert property (p_x_no_x);
    end

    for (gi = 1; gi < NTAPS; gi++) begin : g_xshift
      property p_x_shift;
        @(posedge clk) disable iff (reset)
          en && shift_strobe |=> (x[gi] == $past(x[gi-1]));
      endproperty
      assert property (p_x_shift);
    end

    for (gi = 0; gi < NTAPS; gi++) begin : g_xhold
      property p_x_hold_without_shift;
        @(posedge clk) disable iff (reset)
          !(en && shift_strobe) |=> $stable(x[gi]);
      endproperty
      assert property (p_x_hold_without_shift);
    end
  endgenerate

  c_L2: cover property (en && L_ctrl == 3'd2 && shift_strobe);
  c_L3: cover property (en && L_ctrl == 3'd3 && shift_strobe);
  c_L4: cover property (en && L_ctrl == 3'd4 && shift_strobe);
  c_L5: cover property (en && L_ctrl == 3'd5 && shift_strobe);
endmodule

bind sample_shift_ntaps_Q sample_shift_Q_formal_checker #(.WL(WL), .NTAPS(NTAPS)) u_shift_Q_fchk (
  .clk(clk),
  .reset(reset),
  .en(en),
  .L_ctrl(L_ctrl),
  .shift_strobe(shift_strobe),
  .phase_in(phase_in),
  .sample_sel(sample_sel),
  .x(x)
);
