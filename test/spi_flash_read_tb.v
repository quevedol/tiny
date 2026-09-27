`default_nettype none
`timescale 1ns / 1ps

module spi_flash_model (
    input  wire sck_i,
    input  wire cs_n_i,
    input  wire mosi_i,
    output reg  miso_o,
    output reg [7:0] command_o,
    output reg [23:0] address_o
);

  reg [6:0] bit_count_q;
  reg [31:0] request_q;
  // Bytes on the wire: be ba fe ca. The controller returns ca fe ba be.
  localparam [31:0] RESPONSE = 32'hbe_ba_fe_ca;

  always @(negedge cs_n_i) begin
    bit_count_q <= 7'd0;
    request_q <= 32'd0;
    miso_o <= 1'b0;
  end

  always @(posedge sck_i) begin
    if (!cs_n_i && bit_count_q < 7'd32) begin
      request_q <= {request_q[30:0], mosi_i};
      bit_count_q <= bit_count_q + 1'b1;
      if (bit_count_q == 7'd31) begin
        command_o <= request_q[30:23];
        address_o <= {request_q[22:0], mosi_i};
      end
    end
  end

  always @(negedge sck_i) begin
    if (!cs_n_i && bit_count_q >= 7'd32 && bit_count_q < 7'd64) begin
      miso_o <= RESPONSE[7'd63 - bit_count_q];
      bit_count_q <= bit_count_q + 1'b1;
    end
  end

endmodule

module spi_flash_read_tb ();

  reg clk;
  reg rst_n;
  reg request;
  reg [23:0] address;
  wire [31:0] rdata;
  wire ack;
  wire busy;
  wire cs_n;
  wire sck;
  wire mosi;
  wire miso;
  wire [7:0] command;
  wire [23:0] captured_address;

  spi_flash_read #(.CLK_DIV(1)) dut (
      .clk       (clk),
      .rst_n     (rst_n),
      .request_i (request),
      .address_i (address),
      .rdata_o   (rdata),
      .ack_o     (ack),
      .busy_o    (busy),
      .cs_n_o    (cs_n),
      .sck_o     (sck),
      .mosi_o    (mosi),
      .miso_i    (miso)
  );

  spi_flash_model flash_model (
      .sck_i     (sck),
      .cs_n_i    (cs_n),
      .mosi_i    (mosi),
      .miso_o    (miso),
      .command_o (command),
      .address_o (captured_address)
  );

endmodule

`default_nettype wire
