`default_nettype none
`timescale 1ns / 1ps

module serv_tb ();

  reg clk;
  reg rst_n;

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
  wire        cpu_active;

  reg [31:0] flash_memory [0:1023];
  reg [31:0] psram_low [0:1023];
  reg [31:0] psram_high [0:1023];
  wire [31:0] status_value;
  wire        status_valid;
  wire        uart_tx;
  integer index;

  initial begin
    $dumpfile("serv_tb.fst");
    $dumpvars(0, serv_tb);
    for (index = 0; index < 1024; index = index + 1) begin
      flash_memory[index] = 32'h0000_0013;
      psram_low[index] = 32'd0;
      psram_high[index] = 32'd0;
    end
    $readmemh("../firmware/serv_alive.hex", flash_memory);
  end

  assign ibus_rdata = (ibus_addr[31:12] == 20'h00000)
                    ? flash_memory[ibus_addr[11:2]] : 32'h0000_0013;
  assign ibus_ack = ibus_cyc;

  assign dbus_rdata = (dbus_addr[31:24] == 8'h00)
                    ? flash_memory[dbus_addr[11:2]] :
                    (dbus_addr[31:24] == 8'h10)
                    ? (dbus_addr[23] ? psram_high[dbus_addr[11:2]] :
                                        psram_low[dbus_addr[11:2]]) :
                      32'h0000_0000;
  assign dbus_ack = dbus_cyc;

  always @(posedge clk) begin
    if (rst_n && dbus_cyc && dbus_ack && dbus_we) begin
      if (dbus_addr[31:24] == 8'h10) begin
        if (dbus_addr[23]) begin
          if (dbus_sel[0]) psram_high[dbus_addr[11:2]][7:0]   <= dbus_wdata[7:0];
          if (dbus_sel[1]) psram_high[dbus_addr[11:2]][15:8]  <= dbus_wdata[15:8];
          if (dbus_sel[2]) psram_high[dbus_addr[11:2]][23:16] <= dbus_wdata[23:16];
          if (dbus_sel[3]) psram_high[dbus_addr[11:2]][31:24] <= dbus_wdata[31:24];
        end else begin
          if (dbus_sel[0]) psram_low[dbus_addr[11:2]][7:0]   <= dbus_wdata[7:0];
          if (dbus_sel[1]) psram_low[dbus_addr[11:2]][15:8]  <= dbus_wdata[15:8];
          if (dbus_sel[2]) psram_low[dbus_addr[11:2]][23:16] <= dbus_wdata[23:16];
          if (dbus_sel[3]) psram_low[dbus_addr[11:2]][31:24] <= dbus_wdata[31:24];
        end
      end
    end
  end

  serv_soc #(
      .UART_CLKS_PER_BIT(4)
  ) dut (
      .clk          (clk),
      .cpu_clk_i    (clk),
      .rst_n        (rst_n),
      .ibus_addr_o  (ibus_addr),
      .ibus_cyc_o   (ibus_cyc),
      .ibus_rdata_i (ibus_rdata),
      .ibus_ack_i   (ibus_ack),
      .mem_dbus_addr_o  (dbus_addr),
      .mem_dbus_wdata_o (dbus_wdata),
      .mem_dbus_sel_o   (dbus_sel),
      .mem_dbus_we_o    (dbus_we),
      .mem_dbus_cyc_o   (dbus_cyc),
      .mem_dbus_rdata_i (dbus_rdata),
      .mem_dbus_ack_i   (dbus_ack),
      .uart_tx_o        (uart_tx),
      .cpu_active_o     (cpu_active),
      .status_o         (status_value),
      .status_valid_o   (status_valid)
  );

  wire _unused = &{cpu_active, 1'b0};

endmodule

`default_nettype wire
