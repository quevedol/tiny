`default_nettype none
`timescale 1ns / 1ps

/* Board-level testbench: the Tiny Tapeout top module with its real
 * parameters (50 MHz clock, 115200 baud UART, SPI_CLK_DIV=2) wired through
 * its uio pins to the serial Flash/PSRAM model, as on the QSPI Pmod.
 * The named wires below exist so the cocotb tests and waveform plots can
 * refer to individual pins by function.
 */
module tb_board ();

  initial begin
`ifdef GL_TEST
    $dumpfile("tb_board_gl.vcd");
`else
    $dumpfile("tb_board.vcd");
`endif
    $dumpvars(1, tb_board);
    #1;
  end

  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in_extra;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  wire miso;

  // Pin names as they appear on the QSPI Pmod and in info.yaml.
  wire flash_cs_n = uio_out[0];
  wire mosi       = uio_out[1];
  wire sck        = uio_out[3];
  wire psram_cs_n = uio_out[6];
  wire psram_b_cs_n = uio_out[7];
  wire uart_tx    = uo_out[0];
  wire [3:0] mac_low = uo_out[4:1];
  wire mac_done   = uo_out[5];
  wire mac_overflow = uo_out[6];
  wire cpu_active = uo_out[7];

  // uio[2] is MISO; the remaining input bits are driven by the test to
  // prove the design ignores them.
  wire [7:0] uio_in = {uio_in_extra[7:3], miso, uio_in_extra[1:0]};

`ifdef USE_POWER_PINS
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  tt_um_quevedol_serv_tinyml user_project (
`ifdef USE_POWER_PINS
      .VPWR   (VPWR),
      .VGND   (VGND),
`endif
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

`ifndef GL_TEST
  // Internal probes, only available before synthesis.
  wire cpu_clk  = user_project.extmem_soc.cpu_clk;
  wire cpu_wait = user_project.extmem_soc.cpu_wait;
`endif

  serial_flash_psram_model memory_model (
      .sck_i        (sck),
      .flash_cs_n_i (flash_cs_n),
      .psram_cs_n_i (psram_cs_n),
      .mosi_i       (mosi),
      .miso_o       (miso)
  );

endmodule

`default_nettype wire
