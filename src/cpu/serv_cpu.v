/*
 * Copyright (c) 2026 quevedol
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module serv_cpu (
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] ibus_addr_o,
    output wire        ibus_cyc_o,
    input  wire [31:0] ibus_rdata_i,
    input  wire        ibus_ack_i,
    output wire [31:0] dbus_addr_o,
    output wire [31:0] dbus_wdata_o,
    output wire [3:0]  dbus_sel_o,
    output wire        dbus_we_o,
    output wire        dbus_cyc_o,
    input  wire [31:0] dbus_rdata_i,
    input  wire        dbus_ack_i,
    output wire        active_o
);

  wire [31:0] ext_rs1_unused;
  wire [31:0] ext_rs2_unused;
  wire [2:0]  ext_funct3_unused;
  wire        mdu_valid_unused;

  /*
   * Minimal area-preserving RV32I configuration:
   * - W=1: original bit-serial SERV datapath.
   * - 32 GPRs are retained for the standard ilp32 ABI.
   * - CSR, debug, M, C and misaligned-fetch support are initially disabled.
   */
  serv_rf_top #(
      .RESET_PC      (32'h0000_0000),
      .COMPRESSED    (1'b0),
      .ALIGN         (1'b0),
      .MDU           (1'b0),
      .PRE_REGISTER  (1),
      .RESET_STRATEGY("MINI"),
      .DEBUG         (1'b0),
      .WITH_CSR      (0),
      .W             (1),
      .RF_WIDTH      (2)
  ) core (
      .clk          (clk),
      .i_rst        (!rst_n),
      .i_timer_irq  (1'b0),
      .o_ibus_adr   (ibus_addr_o),
      .o_ibus_cyc   (ibus_cyc_o),
      .i_ibus_rdt   (ibus_rdata_i),
      .i_ibus_ack   (ibus_ack_i),
      .o_dbus_adr   (dbus_addr_o),
      .o_dbus_dat   (dbus_wdata_o),
      .o_dbus_sel   (dbus_sel_o),
      .o_dbus_we    (dbus_we_o),
      .o_dbus_cyc   (dbus_cyc_o),
      .i_dbus_rdt   (dbus_rdata_i),
      .i_dbus_ack   (dbus_ack_i),
      .o_ext_rs1    (ext_rs1_unused),
      .o_ext_rs2    (ext_rs2_unused),
      .o_ext_funct3 (ext_funct3_unused),
      .i_ext_rd     (32'h0000_0000),
      .i_ext_ready  (1'b0),
      .o_mdu_valid  (mdu_valid_unused)
  );

  assign active_o = ibus_cyc_o | dbus_cyc_o;

endmodule

`default_nettype wire
