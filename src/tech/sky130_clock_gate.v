/*
 * Copyright (c) 2026 quevedol
 * SPDX-License-Identifier: Apache-2.0
 *
 * Glitch-free clock gate for the SERV clock domain.
 *
 * RTL simulation uses an explicit transparent-low latch. Sky130 hardening
 * defines SKY130_CLOCK_GATE and instantiates the matching HD ICG cell, so CTS
 * sees a clock-gating point rather than an AND gate on a clock net.
 */

`default_nettype none

module sky130_clock_gate (
    input  wire clk_i,
    input  wire gate_i,
    output wire gclk_o
);

`ifdef SKY130_CLOCK_GATE
  sky130_fd_sc_hd__dlclkp gate_cell (
      .GCLK (gclk_o),
      .GATE (gate_i),
      .CLK  (clk_i)
  );
`else
  // Capture requests only while the source clock is low. Every generated high
  // phase therefore completes, matching the Sky130 ICG behavior.
  reg gate_latched_q;

  always @(clk_i or gate_i) begin
    if (!clk_i) begin
      gate_latched_q <= gate_i;
    end
  end

  assign gclk_o = clk_i & gate_latched_q;
`endif

endmodule

`default_nettype wire
