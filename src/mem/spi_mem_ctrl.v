/*
 * Copyright (c) 2026 quevedol
 * SPDX-License-Identifier: Apache-2.0
 *
 * Shared single-bit SPI mode-0 transaction engine for the QSPI Pmod.
 * Flash and PSRAM share SD0/SD1/SCK; their independent chip selects are
 * driven through cs_flash_n_o and cs_psram_n_o.
 */

`default_nettype none

module spi_mem_ctrl #(
    parameter integer CLK_DIV = 2
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        request_i,
    input  wire        write_i,
    input  wire        psram_i,
    input  wire [23:0] address_i,
    input  wire [31:0] wdata_i,
    output reg  [31:0] rdata_o,
    output reg         ack_o,
    output wire        busy_o,
    output reg         cs_flash_n_o,
    output reg         cs_psram_n_o,
    output reg         sck_o,
    output reg         mosi_o,
    input  wire        miso_i
);

  localparam [2:0] IDLE  = 3'd0;
  localparam [2:0] SEND  = 3'd1;
  localparam [2:0] READ  = 3'd2;
  localparam [2:0] WRITE = 3'd3;
  localparam [2:0] HOLD  = 3'd4;

  reg [2:0]  state_q;
  reg [15:0] divider_q;
  reg [5:0]  bit_count_q;
  reg [31:0] tx_shift_q;
  reg [31:0] rx_shift_q;
  reg        write_first_q;

  wire tick_w = divider_q == CLK_DIV - 1;

  assign busy_o = state_q != IDLE;

  always @(posedge clk) begin
    ack_o <= 1'b0;

    if (!rst_n) begin
      state_q      <= IDLE;
      divider_q    <= 16'd0;
      bit_count_q  <= 6'd0;
      tx_shift_q   <= 32'd0;
      rx_shift_q   <= 32'd0;
      write_first_q <= 1'b0;
      rdata_o      <= 32'd0;
      cs_flash_n_o <= 1'b1;
      cs_psram_n_o <= 1'b1;
      sck_o        <= 1'b0;
      mosi_o       <= 1'b0;
    end else if (state_q == IDLE) begin
      divider_q    <= 16'd0;
      cs_flash_n_o <= 1'b1;
      cs_psram_n_o <= 1'b1;
      sck_o        <= 1'b0;
      if (request_i) begin
        state_q      <= SEND;
        cs_flash_n_o <= psram_i;
        cs_psram_n_o <= !psram_i;
        tx_shift_q   <= {write_i ? 8'h02 : 8'h03, address_i};
        bit_count_q  <= 6'd31;
        mosi_o       <= 1'b0;
      end
    end else if (state_q == HOLD) begin
      if (sck_o) begin
        if (tick_w) begin
          divider_q    <= 16'd0;
          sck_o        <= 1'b0;
          cs_flash_n_o <= 1'b1;
          cs_psram_n_o <= 1'b1;
          ack_o        <= 1'b1;
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
        case (state_q)
          SEND: begin
            if (bit_count_q == 6'd0) begin
              if (write_i) begin
                state_q     <= WRITE;
                bit_count_q <= 6'd31;
                // Program bytes in increasing-address order, just as the
                // serial memories expect.  The bus word is little-endian.
                tx_shift_q  <= {wdata_i[7:0], wdata_i[15:8],
                                wdata_i[23:16], wdata_i[31:24]};
                write_first_q <= 1'b1;
              end else begin
                state_q     <= READ;
                bit_count_q <= 6'd31;
              end
            end
          end
          READ: begin
            rx_shift_q <= {rx_shift_q[30:0], miso_i};
            if (bit_count_q == 6'd0) begin
              // SPI sends the byte at the lowest address first.  SERV is
              // little-endian, so place that byte in rdata_o[7:0].
              rdata_o <= {rx_shift_q[6:0], miso_i, rx_shift_q[14:7],
                          rx_shift_q[22:15], rx_shift_q[30:23]};
              state_q <= HOLD;
            end else begin
              bit_count_q <= bit_count_q - 1'b1;
            end
          end
          WRITE: begin
            if (bit_count_q == 6'd0)
              state_q <= HOLD;
          end
          default: ;
        endcase
      end else begin
        sck_o <= 1'b0;
        if (state_q == SEND) begin
          if (bit_count_q != 6'd0) begin
            bit_count_q <= bit_count_q - 1'b1;
            mosi_o <= tx_shift_q[bit_count_q - 1'b1];
          end
        end else if (state_q == WRITE) begin
          if (write_first_q) begin
            mosi_o <= tx_shift_q[31];
            write_first_q <= 1'b0;
          end else if (bit_count_q != 6'd0) begin
            bit_count_q <= bit_count_q - 1'b1;
            mosi_o <= tx_shift_q[bit_count_q - 1'b1];
          end
        end
      end
    end else begin
      divider_q <= divider_q + 1'b1;
    end
  end

endmodule

`default_nettype wire
