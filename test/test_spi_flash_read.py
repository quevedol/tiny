# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer


@cocotb.test()
async def test_spi_flash_word_read(dut):
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.request.value = 0
    dut.address.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1

    dut.address.value = 0x123456
    dut.request.value = 1
    for _ in range(300):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        if int(dut.ack.value):
            assert int(dut.rdata.value) == 0xCAFEBABE
            assert int(dut.flash_model.command_o.value) == 0x03
            assert int(dut.flash_model.address_o.value) == 0x123456
            dut.request.value = 0
            return

    raise AssertionError("SPI flash controller did not acknowledge the read")
