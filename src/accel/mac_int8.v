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
    output reg                     overflow_o,
    output reg                     busy_o
);

  reg signed [31:0] accumulator_q;
  reg [15:0] partial_product_q;
  reg [15:0] multiplicand_q;
  reg [7:0] multiplier_q;
  reg       product_negative_q;
  reg [2:0] multiply_count_q;

  wire [7:0] activation_abs_w = activation_i[7] ? (~activation_i + 1'b1) : activation_i;
  wire [7:0] weight_abs_w = weight_i[7] ? (~weight_i + 1'b1) : weight_i;
  wire [15:0] partial_product_next_w = partial_product_q +
      (multiplier_q[0] ? multiplicand_q : 16'd0);
  wire signed [15:0] product_w = product_negative_q ?
      -$signed(partial_product_next_w) : $signed(partial_product_next_w);
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
      partial_product_q <= 16'd0;
      multiplicand_q <= 16'd0;
      multiplier_q <= 8'd0;
      product_negative_q <= 1'b0;
      multiply_count_q <= 3'd0;
      done_o        <= 1'b0;
      overflow_o    <= 1'b0;
      busy_o        <= 1'b0;
    end else begin
      done_o <= 1'b0;

      if (clear_i) begin
        accumulator_q <= 32'sd0;
        overflow_o    <= 1'b0;
        busy_o        <= 1'b0;
      end
      else if (load_bias_i) begin
        accumulator_q <= bias_i;
        overflow_o    <= 1'b0;
        busy_o        <= 1'b0;
      end else if (busy_o) begin
        partial_product_q <= partial_product_next_w;
        multiplicand_q <= multiplicand_q << 1;
        multiplier_q <= multiplier_q >> 1;

        if (multiply_count_q == 3'd7) begin
          accumulator_q <= sum_w;
          done_o        <= 1'b1;
          overflow_o    <= overflow_o | overflow_w;
          busy_o        <= 1'b0;
        end else begin
          multiply_count_q <= multiply_count_q + 1'b1;
        end
      end else if (mac_valid_i) begin
        partial_product_q <= 16'd0;
        multiplicand_q <= {8'd0, activation_abs_w};
        multiplier_q <= weight_abs_w;
        product_negative_q <= activation_i[7] ^ weight_i[7];
        multiply_count_q <= 3'd0;
        busy_o <= 1'b1;
      end
    end
  end

endmodule

`default_nettype wire
