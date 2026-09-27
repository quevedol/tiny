/*
 * Copyright (c) 2026 quevedol
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module uart_tx #(
    parameter integer CLKS_PER_BIT = 434
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       valid_i,
    input  wire [7:0] data_i,
    output wire       ready_o,
    output wire       tx_o
);

  reg [9:0]  shift_q;
  reg [15:0] clock_count_q;
  reg [3:0]  bit_count_q;
  reg        busy_q;

  assign ready_o = !busy_q;
  assign tx_o = busy_q ? shift_q[0] : 1'b1;

  always @(posedge clk) begin
    if (!rst_n) begin
      shift_q      <= 10'h3ff;
      clock_count_q <= 16'd0;
      bit_count_q   <= 4'd0;
      busy_q        <= 1'b0;
    end else if (!busy_q) begin
      clock_count_q <= 16'd0;
      bit_count_q   <= 4'd0;
      if (valid_i) begin
        shift_q <= {1'b1, data_i, 1'b0};
        busy_q   <= 1'b1;
      end
    end else if (clock_count_q == CLKS_PER_BIT - 1) begin
      clock_count_q <= 16'd0;
      if (bit_count_q == 4'd9) begin
        busy_q <= 1'b0;
      end else begin
        shift_q    <= {1'b1, shift_q[9:1]};
        bit_count_q <= bit_count_q + 1'b1;
      end
    end else begin
      clock_count_q <= clock_count_q + 1'b1;
    end
  end

endmodule

`default_nettype wire
