`default_nettype none
`timescale 1ns / 1ps

/* A compact serial-memory model: the selected chip returns its own marker. */
module spi_dual_memory_model (
    input  wire       sck_i,
    input  wire       cs_flash_n_i,
    input  wire       cs_psram_n_i,
    input  wire       mosi_i,
    output reg        miso_o,
    output reg [7:0]  command_o,
    output reg [23:0] address_o,
    output reg [31:0] write_data_o,
    output reg        psram_selected_o
);

  reg [6:0] bit_count_q;
  reg [5:0] response_count_q;
  reg [31:0] request_q;
  reg selected_q;
  reg write_mode_q;
  reg [31:0] data_shift_q;
  // These are serial byte streams; the controller byte-swaps for RV32I.
  localparam [31:0] FLASH_RESPONSE = 32'h5a_00_a5_f1;
  localparam [31:0] PSRAM_RESPONSE = 32'hdf_9b_57_13;

  always @(negedge cs_flash_n_i or negedge cs_psram_n_i) begin
    selected_q        <= !cs_psram_n_i;
    psram_selected_o  <= !cs_psram_n_i;
    bit_count_q       <= 7'd0;
    response_count_q  <= 6'd0;
    request_q         <= 32'd0;
    data_shift_q      <= 32'd0;
    write_mode_q      <= 1'b0;
    miso_o            <= 1'b0;
  end

  always @(posedge sck_i) begin
    if (!cs_flash_n_i || !cs_psram_n_i) begin
      if (bit_count_q < 7'd32) begin
        request_q <= {request_q[30:0], mosi_i};
        bit_count_q <= bit_count_q + 1'b1;
        if (bit_count_q == 7'd31) begin
          command_o <= request_q[30:23];
          address_o <= {request_q[22:0], mosi_i};
          write_mode_q <= request_q[30:23] == 8'h02;
        end
      end else if (write_mode_q && bit_count_q < 7'd64) begin
        data_shift_q <= {data_shift_q[30:0], mosi_i};
        bit_count_q <= bit_count_q + 1'b1;
        if (bit_count_q == 7'd63)
          write_data_o <= {data_shift_q[30:0], mosi_i};
      end
    end
  end

  always @(negedge sck_i) begin
    if ((!cs_flash_n_i || !cs_psram_n_i) && !write_mode_q && bit_count_q >= 7'd32 &&
        response_count_q < 6'd32) begin
      if (selected_q)
        miso_o <= PSRAM_RESPONSE[6'd31 - response_count_q];
      else
        miso_o <= FLASH_RESPONSE[6'd31 - response_count_q];
      response_count_q <= response_count_q + 1'b1;
    end
  end

endmodule

module spi_mem_bridge_tb ();

  reg clk;
  reg rst_n;
  reg [31:0] ibus_addr;
  reg ibus_cyc;
  wire [31:0] ibus_rdata;
  wire ibus_ack;
  reg [31:0] dbus_addr;
  reg [31:0] dbus_wdata;
  reg [3:0] dbus_sel;
  reg dbus_we;
  reg dbus_cyc;
  wire [31:0] dbus_rdata;
  wire dbus_ack;
  wire cs_flash_n;
  wire cs_psram_n;
  wire sck;
  wire mosi;
  wire miso;
  wire [7:0] command;
  wire [23:0] captured_address;
  wire [31:0] captured_write_data;
  wire psram_selected;

  spi_mem_bridge dut (
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
      .cs_flash_n_o (cs_flash_n),
      .cs_psram_n_o (cs_psram_n),
      .sck_o        (sck),
      .mosi_o       (mosi),
      .miso_i       (miso)
  );

  spi_dual_memory_model memory_model (
      .sck_i            (sck),
      .cs_flash_n_i     (cs_flash_n),
      .cs_psram_n_i     (cs_psram_n),
      .mosi_i           (mosi),
      .miso_o           (miso),
      .command_o        (command),
      .address_o        (captured_address),
      .write_data_o     (captured_write_data),
      .psram_selected_o (psram_selected)
  );

endmodule

`default_nettype wire
