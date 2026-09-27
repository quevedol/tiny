/*
 * Copyright (c) 2026 quevedol
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module serv_soc #(
    parameter integer UART_CLKS_PER_BIT = 434
) (
    input  wire        clk,
    input  wire        cpu_clk_i,
    input  wire        rst_n,
    output wire [31:0] ibus_addr_o,
    output wire        ibus_cyc_o,
    input  wire [31:0] ibus_rdata_i,
    input  wire        ibus_ack_i,
    output wire [31:0] mem_dbus_addr_o,
    output wire [31:0] mem_dbus_wdata_o,
    output wire [3:0]  mem_dbus_sel_o,
    output wire        mem_dbus_we_o,
    output wire        mem_dbus_cyc_o,
    input  wire [31:0] mem_dbus_rdata_i,
    input  wire        mem_dbus_ack_i,
    output wire        uart_tx_o,
    output wire        cpu_active_o,
    output wire [7:0]  mac_result_o,
    output wire        mac_done_o,
    output wire        mac_overflow_o,
    output reg  [31:0] status_o,
    output reg         status_valid_o
);

  localparam [31:0] UART_DATA_ADDR   = 32'h2000_0100;
  localparam [31:0] UART_STATUS_ADDR = 32'h2000_0104;
  localparam [31:0] SOC_STATUS_ADDR  = 32'h2000_0200;

  wire [31:0] cpu_dbus_addr;
  wire [31:0] cpu_dbus_wdata;
  wire [3:0]  cpu_dbus_sel;
  wire        cpu_dbus_we;
  wire        cpu_dbus_cyc;
  wire [31:0] cpu_dbus_rdata;
  wire        cpu_dbus_ack;
  wire        uart_ready;
  wire [31:0] mac_rdata;
  wire        mac_ack;

  wire uart_data_access = cpu_dbus_cyc &&
                          cpu_dbus_addr == UART_DATA_ADDR;
  wire uart_status_access = cpu_dbus_cyc &&
                            cpu_dbus_addr == UART_STATUS_ADDR;
  wire soc_status_access = cpu_dbus_cyc &&
                           cpu_dbus_addr == SOC_STATUS_ADDR;
  wire mac_access = cpu_dbus_cyc &&
                    cpu_dbus_addr[31:6] == 26'h0800000;
  wire mmio_access = uart_data_access || uart_status_access ||
                     soc_status_access || mac_access;
  wire uart_write = uart_data_access && cpu_dbus_we &&
                    cpu_dbus_sel[0] && uart_ready;

  assign mem_dbus_addr_o  = cpu_dbus_addr;
  assign mem_dbus_wdata_o = cpu_dbus_wdata;
  assign mem_dbus_sel_o   = cpu_dbus_sel;
  assign mem_dbus_we_o    = cpu_dbus_we;
  assign mem_dbus_cyc_o   = cpu_dbus_cyc && !mmio_access;

  assign cpu_dbus_ack = uart_data_access ? (!cpu_dbus_we || uart_ready) :
                         (uart_status_access || soc_status_access) ? 1'b1 :
                         mac_access ? mac_ack :
                         mem_dbus_ack_i;
  assign cpu_dbus_rdata = uart_status_access ? {31'd0, uart_ready} :
                          soc_status_access  ? status_o :
                          mac_access         ? mac_rdata :
                          mem_dbus_rdata_i;

  always @(posedge clk) begin
    if (!rst_n) begin
      status_o       <= 32'h0000_0000;
      status_valid_o <= 1'b0;
    end else if (soc_status_access && cpu_dbus_we && cpu_dbus_ack) begin
      status_o       <= cpu_dbus_wdata;
      status_valid_o <= 1'b1;
    end
  end

  uart_tx #(
      .CLKS_PER_BIT(UART_CLKS_PER_BIT)
  ) uart (
      .clk     (clk),
      .rst_n   (rst_n),
      .valid_i (uart_write),
      .data_i  (cpu_dbus_wdata[7:0]),
      .ready_o (uart_ready),
      .tx_o    (uart_tx_o)
  );

  mac_mmio mac (
      .clk         (clk),
      .rst_n       (rst_n),
      .bus_addr_i  (cpu_dbus_addr[5:0]),
      .bus_wdata_i (cpu_dbus_wdata),
      .bus_sel_i   (cpu_dbus_sel),
      .bus_we_i    (cpu_dbus_we),
      .bus_cyc_i   (mac_access),
      .bus_rdata_o (mac_rdata),
      .bus_ack_o   (mac_ack),
      .result_o    (mac_result_o),
      .done_o      (mac_done_o),
      .overflow_o  (mac_overflow_o)
  );

  serv_cpu cpu (
      .clk          (cpu_clk_i),
      .rst_n        (rst_n),
      .ibus_addr_o  (ibus_addr_o),
      .ibus_cyc_o   (ibus_cyc_o),
      .ibus_rdata_i (ibus_rdata_i),
      .ibus_ack_i   (ibus_ack_i),
      .dbus_addr_o  (cpu_dbus_addr),
      .dbus_wdata_o (cpu_dbus_wdata),
      .dbus_sel_o   (cpu_dbus_sel),
      .dbus_we_o    (cpu_dbus_we),
      .dbus_cyc_o   (cpu_dbus_cyc),
      .dbus_rdata_i (cpu_dbus_rdata),
      .dbus_ack_i   (cpu_dbus_ack),
      .active_o     (cpu_active_o)
  );

endmodule

`default_nettype wire
