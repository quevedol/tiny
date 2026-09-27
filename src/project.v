/*
 * Copyright (c) 2026 quevedol
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_quevedol_serv_tinyml (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire flash_cs_n;
  wire psram_a_cs_n;
  wire sck;
  wire mosi;
  wire uart_tx;
  wire cpu_active;
  wire [7:0] mac_result;
  wire mac_done;
  wire mac_overflow;
  wire [31:0] status;
  wire status_valid;
  wire soc_rst_n = rst_n && ena;

  serv_extmem_soc extmem_soc (
      .clk             (clk),
      .rst_n           (soc_rst_n),
      .miso_i          (uio_in[2]),
      .flash_cs_n_o    (flash_cs_n),
      .psram_a_cs_n_o  (psram_a_cs_n),
      .sck_o           (sck),
      .mosi_o          (mosi),
      .uart_tx_o       (uart_tx),
      .cpu_active_o    (cpu_active),
      .mac_result_o    (mac_result),
      .mac_done_o      (mac_done),
      .mac_overflow_o  (mac_overflow),
      .status_o        (status),
      .status_valid_o  (status_valid)
  );

  assign uo_out = {cpu_active, mac_overflow, mac_done, mac_result[3:0], uart_tx};

  // uio[2] is the only input in the initial SPI-compatible memory path.
  // SD2/SD3 remain tri-stated until the Quad transfer engine is introduced.
  assign uio_out = {1'b1, psram_a_cs_n, 1'b0, 1'b0,
                    sck, 1'b0, mosi, flash_cs_n};
  assign uio_oe  = 8'b1100_1011;

  wire _unused = &{ui_in, status, status_valid, 1'b0};

endmodule

`default_nettype wire
