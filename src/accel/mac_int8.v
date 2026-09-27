/*
 * Copyright (c) 2026 quevedol
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module mac_int8 (
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    clear_i,
    input  wire                    load_bias_i,
    input  wire                    mac_valid_i,
    input  wire                    relu_i,
    input  wire [4:0]              shift_i,
    input  wire signed [7:0]       activation_i,
    input  wire signed [7:0]       weight_i,
    input  wire signed [31:0]      bias_i,
    output wire signed [31:0]      accumulator_o,
    output reg  signed [7:0]       result_o,
    output reg                     done_o,
    output reg                     overflow_o
);

  reg signed [31:0] accumulator_q;

  wire signed [15:0] product_w = activation_i * weight_i;
  wire signed [31:0] product_extended_w = {{16{product_w[15]}}, product_w};
  wire signed [31:0] sum_w = accumulator_q + product_extended_w;
  wire signed [31:0] shifted_w = accumulator_q >>> shift_i;
  wire overflow_w = (accumulator_q[31] == product_extended_w[31]) &&
                    (sum_w[31] != accumulator_q[31]);

  assign accumulator_o = accumulator_q;

  always @(*) begin
    if (relu_i && shifted_w < 0)
      result_o = 8'sd0;
    else if (shifted_w > 32'sd127)
      result_o = 8'sd127;
    else if (shifted_w < -32'sd128)
      result_o = -8'sd128;
    else
      result_o = shifted_w[7:0];
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      accumulator_q <= 32'sd0;
      done_o        <= 1'b0;
      overflow_o    <= 1'b0;
    end else begin
      done_o <= 1'b0;

      if (clear_i)
        begin
          accumulator_q <= 32'sd0;
          overflow_o    <= 1'b0;
        end
      else if (load_bias_i) begin
        accumulator_q <= bias_i;
        overflow_o    <= 1'b0;
      end
      else if (mac_valid_i) begin
        accumulator_q <= sum_w;
        done_o        <= 1'b1;
        overflow_o    <= overflow_o | overflow_w;
      end
    end
  end

endmodule

`default_nettype wire
