/*
 * Copyright (c) 2026 quevedol
 * SPDX-License-Identifier: Apache-2.0
 *
 * SERV SoC with its instruction Flash and data PSRAM connected to the
 * single-bit compatibility mode of the Tiny Tapeout QSPI Pmod.
 */

`default_nettype none

module serv_extmem_soc #(
    parameter integer UART_CLKS_PER_BIT = 434,
    parameter integer SPI_CLK_DIV = 2
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        miso_i,
    output wire        flash_cs_n_o,
    output wire        psram_a_cs_n_o,
    output wire        sck_o,
    output wire        mosi_o,
    output wire        uart_tx_o,
    output wire        cpu_active_o,
    output wire [7:0]  mac_result_o,
    output wire        mac_done_o,
    output wire        mac_overflow_o,
    output wire [31:0] status_o,
    output wire        status_valid_o
);

  wire [31:0] ibus_addr;
  wire        ibus_cyc;
  wire [31:0] ibus_rdata;
  wire        ibus_ack;
  wire [31:0] dbus_addr;
  wire [31:0] dbus_wdata;
  wire [3:0]  dbus_sel;
  wire        dbus_we;
  wire        dbus_cyc;
  wire [31:0] dbus_rdata;
  wire        dbus_ack;
  wire        cpu_wait;
  wire        cpu_clk_enable = !cpu_wait || !rst_n;
  wire        cpu_clk;

  // Reset keeps the CPU clock enabled because SERV reset is synchronous. The
  // wrapper becomes a sky130_fd_sc_hd__dlclkp_4 instance during hardening.
  sky130_clock_gate cpu_clock_gate (
      .clk_i  (clk),
      .gate_i (cpu_clk_enable),
      .gclk_o (cpu_clk)
  );

  serv_soc #(
      .UART_CLKS_PER_BIT(UART_CLKS_PER_BIT)
  ) soc (
      .clk              (clk),
      .cpu_clk_i        (cpu_clk),
      .rst_n            (rst_n),
      .ibus_addr_o      (ibus_addr),
      .ibus_cyc_o       (ibus_cyc),
      .ibus_rdata_i     (ibus_rdata),
      .ibus_ack_i       (ibus_ack),
      .mem_dbus_addr_o  (dbus_addr),
      .mem_dbus_wdata_o (dbus_wdata),
      .mem_dbus_sel_o   (dbus_sel),
      .mem_dbus_we_o    (dbus_we),
      .mem_dbus_cyc_o   (dbus_cyc),
      .mem_dbus_rdata_i (dbus_rdata),
      .mem_dbus_ack_i   (dbus_ack),
      .uart_tx_o        (uart_tx_o),
      .cpu_active_o     (cpu_active_o),
      .mac_result_o     (mac_result_o),
      .mac_done_o       (mac_done_o),
      .mac_overflow_o   (mac_overflow_o),
      .status_o         (status_o),
      .status_valid_o   (status_valid_o)
  );

  spi_mem_bridge #(
      .CLK_DIV(SPI_CLK_DIV)
  ) bridge (
      .clk          (clk),
      .rst_n        (rst_n),
      .ibus_addr_i  (ibus_addr),
      .ibus_cyc_i   (ibus_cyc),
      .ibus_rdata_o (ibus_rdata),
      .ibus_ack_o   (ibus_ack),
      .dbus_addr_i  (dbus_addr),
      .dbus_wdata_i (dbus_wdata),
      .dbus_sel_i   (dbus_sel),
      .dbus_we_i    (dbus_we),
      .dbus_cyc_i   (dbus_cyc),
      .dbus_rdata_o (dbus_rdata),
      .dbus_ack_o   (dbus_ack),
      .cpu_wait_o   (cpu_wait),
      .cs_flash_n_o (flash_cs_n_o),
      .cs_psram_n_o (psram_a_cs_n_o),
      .sck_o        (sck_o),
      .mosi_o       (mosi_o),
      .miso_i       (miso_i)
  );

endmodule

`default_nettype wire
