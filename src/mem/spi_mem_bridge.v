/*
 * Copyright (c) 2026 quevedol
 * SPDX-License-Identifier: Apache-2.0
 *
 * Bridges SERV's separate instruction/data buses to one serial memory engine.
 * Address range 0x0000_0000..0x00ff_ffff is Flash (read-only). Range
 * 0x1000_0000..0x10ff_ffff is PSRAM A. Data requests win arbitration because
 * SERV waits on them before issuing its next instruction fetch.
 */

`default_nettype none

module spi_mem_bridge #(
    parameter integer CLK_DIV = 2
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] ibus_addr_i,
    input  wire        ibus_cyc_i,
    output wire [31:0] ibus_rdata_o,
    output wire        ibus_ack_o,
    input  wire [31:0] dbus_addr_i,
    input  wire [31:0] dbus_wdata_i,
    input  wire [3:0]  dbus_sel_i,
    input  wire        dbus_we_i,
    input  wire        dbus_cyc_i,
    output wire [31:0] dbus_rdata_o,
    output wire        dbus_ack_o,
    output wire        cpu_wait_o,
    output wire        cs_flash_n_o,
    output wire        cs_psram_n_o,
    output wire        sck_o,
    output wire        mosi_o,
    input  wire        miso_i
);

  localparam [1:0] IDLE  = 2'd0;
  localparam [1:0] WAIT  = 2'd1;
  localparam [1:0] REPLY = 2'd2;

  reg [1:0]  state_q;
  reg        selected_dbus_q;
  reg        selected_psram_q;
  reg        selected_write_q;
  reg [23:0] selected_addr_q;
  reg [31:0] selected_wdata_q;
  reg [31:0] response_q;
  reg        reply_acked_q;

  wire dbus_flash_w = dbus_addr_i[31:24] == 8'h00;
  wire dbus_psram_w = dbus_addr_i[31:24] == 8'h10;
  wire dbus_valid_w = dbus_cyc_i &&
                      (dbus_psram_w || (dbus_flash_w && !dbus_we_i));
  wire ctrl_request_w = state_q == WAIT;
  wire ctrl_ack_w;
  wire [31:0] ctrl_rdata_w;

  // High while the serial engine collects a word. SERV is stalled simply by
  // withholding its ack until REPLY; the signal is exported for observation.
  assign cpu_wait_o = state_q == WAIT;
  assign ibus_ack_o = state_q == REPLY && !reply_acked_q && !selected_dbus_q;
  assign dbus_ack_o = state_q == REPLY && !reply_acked_q && selected_dbus_q;
  assign ibus_rdata_o = response_q;
  assign dbus_rdata_o = response_q;

  always @(posedge clk) begin
    if (!rst_n) begin
      state_q           <= IDLE;
      selected_dbus_q   <= 1'b0;
      selected_psram_q  <= 1'b0;
      selected_write_q  <= 1'b0;
      selected_addr_q   <= 24'd0;
      selected_wdata_q  <= 32'd0;
      response_q        <= 32'd0;
      reply_acked_q     <= 1'b0;
    end else begin
      case (state_q)
        IDLE: begin
          if (dbus_valid_w) begin
            selected_dbus_q  <= 1'b1;
            selected_psram_q <= dbus_psram_w;
            selected_write_q <= dbus_we_i;
            selected_addr_q  <= {dbus_addr_i[23:2], 2'b00};
            selected_wdata_q <= dbus_wdata_i;
            reply_acked_q    <= 1'b0;
            state_q          <= WAIT;
          end else if (ibus_cyc_i) begin
            selected_dbus_q  <= 1'b0;
            selected_psram_q <= 1'b0;
            selected_write_q <= 1'b0;
            selected_addr_q  <= {ibus_addr_i[23:2], 2'b00};
            selected_wdata_q <= 32'd0;
            reply_acked_q    <= 1'b0;
            state_q          <= WAIT;
          end
        end
        WAIT: begin
          if (ctrl_ack_w) begin
            response_q <= ctrl_rdata_w;
            state_q <= REPLY;
            reply_acked_q <= 1'b0;
          end
        end
        REPLY: begin
          if (!reply_acked_q) begin
            reply_acked_q <= 1'b1;
          end else if ((selected_dbus_q && !dbus_cyc_i) ||
                       (!selected_dbus_q && !ibus_cyc_i)) begin
            state_q <= IDLE;
          end
        end
        default: state_q <= IDLE;
      endcase
    end
  end

  spi_mem_ctrl #(
      .CLK_DIV(CLK_DIV)
  ) ctrl (
      .clk          (clk),
      .rst_n        (rst_n),
      .request_i    (ctrl_request_w),
      .write_i      (selected_write_q),
      .psram_i      (selected_psram_q),
      .address_i    (selected_addr_q),
      .wdata_i      (selected_wdata_q),
      .rdata_o      (ctrl_rdata_w),
      .ack_o        (ctrl_ack_w),
      .busy_o       (),
      .cs_flash_n_o (cs_flash_n_o),
      .cs_psram_n_o (cs_psram_n_o),
      .sck_o        (sck_o),
      .mosi_o       (mosi_o),
      .miso_i       (miso_i)
  );

endmodule

`default_nettype wire
