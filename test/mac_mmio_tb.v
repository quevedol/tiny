`default_nettype none
`timescale 1ns / 1ps

module mac_mmio_tb ();

  reg        clk;
  reg        rst_n;
  reg [5:0]  bus_addr;
  reg [31:0] bus_wdata;
  reg [3:0]  bus_sel;
  reg        bus_we;
  reg        bus_cyc;
  wire [31:0] bus_rdata;
  wire        bus_ack;
  wire [7:0]  result;
  wire        done;
  wire        overflow;

  mac_mmio dut (
      .clk         (clk),
      .rst_n       (rst_n),
      .bus_addr_i  (bus_addr),
      .bus_wdata_i (bus_wdata),
      .bus_sel_i   (bus_sel),
      .bus_we_i    (bus_we),
      .bus_cyc_i   (bus_cyc),
      .bus_rdata_o (bus_rdata),
      .bus_ack_o   (bus_ack),
      .result_o    (result),
      .done_o      (done),
      .overflow_o  (overflow)
  );

endmodule

`default_nettype wire
