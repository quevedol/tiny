/*
 * Copyright (c) 2026 quevedol
 * SPDX-License-Identifier: Apache-2.0
 *
 * Read-only SPI mode-0 controller for the QSPI Pmod flash. It uses the
 * universally supported 0x03 command and can later be replaced by a quad
 * fast-read engine without changing the memory-bus side of the SoC.
 */

`default_nettype none

module spi_flash_read #(
    parameter integer CLK_DIV = 2
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        request_i,
    input  wire [23:0] address_i,
    output reg  [31:0] rdata_o,
    output reg         ack_o,
    output wire        busy_o,
    output reg         cs_n_o,
    output reg         sck_o,
    output reg         mosi_o,
    input  wire        miso_i
);

  localparam [1:0] IDLE = 2'd0;
  localparam [1:0] SEND = 2'd1;
  localparam [1:0] READ = 2'd2;
  localparam [1:0] HOLD = 2'd3;

  reg [1:0]  state_q;
  reg [15:0] divider_q;
  reg [5:0]  bit_count_q;
  reg [31:0] tx_shift_q;
  reg [31:0] rx_shift_q;

  wire tick_w = divider_q == CLK_DIV - 1;

  assign busy_o = state_q != IDLE;

  always @(posedge clk) begin
    ack_o <= 1'b0;

    if (!rst_n) begin
      state_q     <= IDLE;
      divider_q   <= 16'd0;
      bit_count_q <= 6'd0;
      tx_shift_q  <= 32'd0;
      rx_shift_q  <= 32'd0;
      rdata_o     <= 32'd0;
      cs_n_o      <= 1'b1;
      sck_o       <= 1'b0;
      mosi_o      <= 1'b0;
    end else begin
      if (state_q == IDLE) begin
        divider_q <= 16'd0;
        cs_n_o    <= 1'b1;
        sck_o     <= 1'b0;
        if (request_i) begin
          state_q     <= SEND;
          cs_n_o      <= 1'b0;
          tx_shift_q  <= {8'h03, address_i};
          bit_count_q <= 6'd31;
          mosi_o      <= 1'b0;
        end
      end else if (state_q == HOLD) begin
        if (sck_o) begin
          if (tick_w) begin
            divider_q <= 16'd0;
            sck_o     <= 1'b0;
            cs_n_o    <= 1'b1;
            ack_o     <= 1'b1;
          end else begin
            divider_q <= divider_q + 1'b1;
          end
        end else if (!request_i) begin
          state_q <= IDLE;
        end
      end else if (tick_w) begin
        divider_q <= 16'd0;
        if (!sck_o) begin
          sck_o <= 1'b1;
          if (state_q == SEND) begin
            if (bit_count_q == 6'd0) begin
              state_q     <= READ;
              bit_count_q <= 6'd31;
            end
          end else begin
            rx_shift_q <= {rx_shift_q[30:0], miso_i};
            if (bit_count_q == 6'd0) begin
              // The serial Flash supplies the lowest-addressed byte first;
              // expose it in the RV32I little-endian byte lane.
              rdata_o <= {rx_shift_q[6:0], miso_i, rx_shift_q[14:7],
                          rx_shift_q[22:15], rx_shift_q[30:23]};
              state_q <= HOLD;
            end else begin
              bit_count_q <= bit_count_q - 1'b1;
            end
          end
        end else begin
          sck_o <= 1'b0;
          if (state_q == SEND) begin
            if (bit_count_q != 6'd0) begin
              bit_count_q <= bit_count_q - 1'b1;
              mosi_o <= tx_shift_q[bit_count_q - 1'b1];
            end
          end else if (state_q == HOLD) begin
            cs_n_o <= 1'b1;
            ack_o  <= 1'b1;
          end
        end
      end else begin
        divider_q <= divider_q + 1'b1;
      end
    end
  end

endmodule

`default_nettype wire
