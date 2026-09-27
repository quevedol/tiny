/*
 * Copyright (c) 2026 quevedol
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module mac_mmio (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [5:0]  bus_addr_i,
    input  wire [31:0] bus_wdata_i,
    input  wire [3:0]  bus_sel_i,
    input  wire        bus_we_i,
    input  wire        bus_cyc_i,
    output reg  [31:0] bus_rdata_o,
    output wire        bus_ack_o,
    output wire [7:0]  result_o,
    output wire        done_o,
    output wire        overflow_o
);

  localparam [3:0] CMD_REG          = 4'h0;
  localparam [3:0] ACTIVATION_REG   = 4'h1;
  localparam [3:0] WEIGHT_REG       = 4'h2;
  localparam [3:0] BIAS_REG         = 4'h3;
  localparam [3:0] ACCUMULATOR_REG  = 4'h4;
  localparam [3:0] RESULT_REG       = 4'h5;
  localparam [3:0] STATUS_REG       = 4'h6;
  localparam [3:0] CONFIG_REG       = 4'h7;

  reg signed [7:0]  activation_q;
  reg signed [7:0]  weight_q;
  reg signed [31:0] bias_q;
  reg               relu_q;
  reg [4:0]         shift_q;
  reg               done_q;
  reg               mac_command_active_q;
  reg               mac_command_complete_q;

  wire write_access = bus_cyc_i && bus_we_i;
  wire cmd_write = write_access && bus_addr_i[5:2] == CMD_REG;
  wire clear_w = cmd_write && bus_wdata_i[0];
  wire load_bias_w = cmd_write && bus_wdata_i[1];
  wire mac_valid_w = cmd_write && bus_wdata_i[2];
  wire signed [31:0] accumulator_w;
  wire signed [7:0] result_w;
  wire mac_done_w;
  wire overflow_w;
  wire mac_busy_w;
  wire mac_start_w = mac_valid_w && !mac_command_active_q;

  assign bus_ack_o = bus_cyc_i && (!mac_valid_w || mac_command_complete_q);
  assign result_o = result_w;
  assign done_o = done_q;
  assign overflow_o = overflow_w;

  always @(posedge clk) begin
    if (!rst_n) begin
      activation_q <= 8'sd0;
      weight_q     <= 8'sd0;
      bias_q       <= 32'sd0;
      relu_q       <= 1'b0;
      shift_q      <= 5'd0;
      done_q       <= 1'b0;
      mac_command_active_q <= 1'b0;
      mac_command_complete_q <= 1'b0;
    end else begin
      if (!bus_cyc_i || !mac_valid_w) begin
        mac_command_active_q <= 1'b0;
        mac_command_complete_q <= 1'b0;
      end else begin
        if (!mac_command_active_q)
          mac_command_active_q <= 1'b1;
        if (mac_done_w)
          mac_command_complete_q <= 1'b1;
      end

      if (write_access) begin
        case (bus_addr_i[5:2])
          ACTIVATION_REG: if (bus_sel_i[0]) activation_q <= bus_wdata_i[7:0];
          WEIGHT_REG:     if (bus_sel_i[0]) weight_q <= bus_wdata_i[7:0];
          BIAS_REG:       bias_q <= bus_wdata_i;
          CONFIG_REG: begin
            relu_q  <= bus_wdata_i[0];
            shift_q <= bus_wdata_i[5:1];
          end
          default: ;
        endcase
      end

      if (clear_w)
        done_q <= 1'b0;
      else if (mac_done_w)
        done_q <= 1'b1;
    end
  end

  always @(*) begin
    case (bus_addr_i[5:2])
      CMD_REG:         bus_rdata_o = 32'h0000_0000;
      ACTIVATION_REG:  bus_rdata_o = {{24{activation_q[7]}}, activation_q};
      WEIGHT_REG:      bus_rdata_o = {{24{weight_q[7]}}, weight_q};
      BIAS_REG:        bus_rdata_o = bias_q;
      ACCUMULATOR_REG: bus_rdata_o = accumulator_w;
      RESULT_REG:      bus_rdata_o = {{24{result_w[7]}}, result_w};
      STATUS_REG:      bus_rdata_o = {29'd0, mac_busy_w, overflow_w, done_q};
      CONFIG_REG:      bus_rdata_o = {26'd0, shift_q, relu_q};
      default:          bus_rdata_o = 32'h0000_0000;
    endcase
  end

  mac_int8 mac (
      .clk           (clk),
      .rst_n         (rst_n),
      .clear_i       (clear_w),
      .load_bias_i   (load_bias_w),
      .mac_valid_i   (mac_start_w),
      .relu_i        (relu_q),
      .shift_i       (shift_q),
      .activation_i  (activation_q),
      .weight_i      (weight_q),
      .bias_i        (bias_q),
      .accumulator_o (accumulator_w),
      .result_o      (result_w),
      .done_o        (mac_done_w),
      .overflow_o    (overflow_w),
      .busy_o        (mac_busy_w)
  );

endmodule

`default_nettype wire
