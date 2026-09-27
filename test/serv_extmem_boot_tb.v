`default_nettype none
`timescale 1ns / 1ps

/* SPI-mode-0 model for an external Flash plus the two address windows SERV
 * uses in PSRAM A: .bss at the bottom and stack at the top. */
module serial_flash_psram_model (
    input  wire sck_i,
    input  wire flash_cs_n_i,
    input  wire psram_cs_n_i,
    input  wire mosi_i,
    output reg  miso_o
);

  reg [31:0] flash_memory [0:1023];
  reg [31:0] psram_low [0:1023];
  reg [31:0] psram_high [0:1023];
  reg [6:0] bit_count_q;
  reg [5:0] response_count_q;
  reg [31:0] request_q;
  reg [31:0] data_shift_q;
  reg [31:0] response_q;
  reg [23:0] address_q;
  reg psram_q;
  reg write_q;
  integer index;

  initial begin
    for (index = 0; index < 1024; index = index + 1) begin
      flash_memory[index] = 32'h0000_0013;
      psram_low[index] = 32'd0;
      psram_high[index] = 32'd0;
    end
    $readmemh("../firmware/serv_alive.hex", flash_memory);
  end

  always @(negedge flash_cs_n_i or negedge psram_cs_n_i) begin
    bit_count_q      <= 7'd0;
    response_count_q <= 6'd0;
    request_q        <= 32'd0;
    data_shift_q     <= 32'd0;
    response_q       <= 32'd0;
    address_q        <= 24'd0;
    psram_q          <= !psram_cs_n_i;
    write_q          <= 1'b0;
    miso_o           <= 1'b0;
  end

  always @(posedge sck_i) begin
    if (!flash_cs_n_i || !psram_cs_n_i) begin
      if (bit_count_q < 7'd32) begin
        request_q <= {request_q[30:0], mosi_i};
        bit_count_q <= bit_count_q + 1'b1;
        if (bit_count_q == 7'd31) begin
          address_q <= {request_q[22:0], mosi_i};
          write_q <= request_q[30:23] == 8'h02;
          if (request_q[30:23] == 8'h03) begin
            if (psram_q) begin
              if (request_q[22])
                response_q <= {psram_high[request_q[10:1]][7:0],
                               psram_high[request_q[10:1]][15:8],
                               psram_high[request_q[10:1]][23:16],
                               psram_high[request_q[10:1]][31:24]};
              else
                response_q <= {psram_low[request_q[10:1]][7:0],
                               psram_low[request_q[10:1]][15:8],
                               psram_low[request_q[10:1]][23:16],
                               psram_low[request_q[10:1]][31:24]};
            end else begin
              response_q <= {flash_memory[request_q[10:1]][7:0],
                             flash_memory[request_q[10:1]][15:8],
                             flash_memory[request_q[10:1]][23:16],
                             flash_memory[request_q[10:1]][31:24]};
            end
          end
        end
      end else if (write_q && bit_count_q < 7'd64) begin
        data_shift_q <= {data_shift_q[30:0], mosi_i};
        bit_count_q <= bit_count_q + 1'b1;
        if (bit_count_q == 7'd63) begin
          if (address_q[23])
            psram_high[address_q[11:2]] <= {data_shift_q[6:0], mosi_i,
                                              data_shift_q[14:7],
                                              data_shift_q[22:15],
                                              data_shift_q[30:23]};
          else
            psram_low[address_q[11:2]] <= {data_shift_q[6:0], mosi_i,
                                             data_shift_q[14:7],
                                             data_shift_q[22:15],
                                             data_shift_q[30:23]};
        end
      end
    end
  end

  always @(negedge sck_i) begin
    if ((!flash_cs_n_i || !psram_cs_n_i) && !write_q && bit_count_q >= 7'd32 &&
        response_count_q < 6'd32) begin
      miso_o <= response_q[6'd31 - response_count_q];
      response_count_q <= response_count_q + 1'b1;
    end
  end

endmodule

module serv_extmem_boot_tb ();
  reg clk;
  reg rst_n;
  wire flash_cs_n;
  wire psram_cs_n;
  wire sck;
  wire mosi;
  wire miso;
  wire uart_tx;
  wire cpu_active;
  wire [7:0] mac_result;
  wire mac_done;
  wire mac_overflow;
  wire [31:0] status_value;
  wire status_valid;

  serv_extmem_soc #(
      .UART_CLKS_PER_BIT(4),
      .SPI_CLK_DIV(1)
  ) dut (
      .clk            (clk),
      .rst_n          (rst_n),
      .miso_i         (miso),
      .flash_cs_n_o   (flash_cs_n),
      .psram_a_cs_n_o (psram_cs_n),
      .sck_o          (sck),
      .mosi_o         (mosi),
      .uart_tx_o      (uart_tx),
      .cpu_active_o   (cpu_active),
      .mac_result_o   (mac_result),
      .mac_done_o     (mac_done),
      .mac_overflow_o (mac_overflow),
      .status_o       (status_value),
      .status_valid_o (status_valid)
  );

  serial_flash_psram_model memory_model (
      .sck_i        (sck),
      .flash_cs_n_i (flash_cs_n),
      .psram_cs_n_i (psram_cs_n),
      .mosi_i       (mosi),
      .miso_o       (miso)
  );
endmodule

`default_nettype wire
