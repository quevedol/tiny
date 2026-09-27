import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


FLASH_RESPONSE = 0xF1A5005A
PSRAM_RESPONSE = 0x13579BDF


async def reset(dut):
    dut.rst_n.value = 0
    dut.ibus_cyc.value = 0
    dut.ibus_addr.value = 0
    dut.dbus_cyc.value = 0
    dut.dbus_addr.value = 0
    dut.dbus_wdata.value = 0
    dut.dbus_sel.value = 0xF
    dut.dbus_we.value = 0
    for _ in range(4):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def wait_for_ack(dut, signal, limit=1000):
    for _ in range(limit):
        await RisingEdge(dut.clk)
        if int(signal.value):
            return
    raise AssertionError("SPI memory request timed out")


@cocotb.test()
async def flash_and_psram_reads_are_routed_to_the_right_chip(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    dut.ibus_addr.value = 0x00123456
    dut.ibus_cyc.value = 1
    await wait_for_ack(dut, dut.ibus_ack)
    assert int(dut.ibus_rdata.value) == FLASH_RESPONSE
    assert int(dut.command.value) == 0x03
    assert int(dut.captured_address.value) == 0x123454
    assert int(dut.psram_selected.value) == 0
    dut.ibus_cyc.value = 0
    await RisingEdge(dut.clk)

    dut.dbus_addr.value = 0x1000ABCD
    dut.dbus_cyc.value = 1
    await wait_for_ack(dut, dut.dbus_ack)
    assert int(dut.dbus_rdata.value) == PSRAM_RESPONSE
    assert int(dut.command.value) == 0x03
    assert int(dut.captured_address.value) == 0x00ABCC
    assert int(dut.psram_selected.value) == 1
    dut.dbus_cyc.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def data_bus_has_priority_over_an_instruction_fetch(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    dut.ibus_addr.value = 0x00001111
    dut.ibus_cyc.value = 1
    dut.dbus_addr.value = 0x10002222
    dut.dbus_cyc.value = 1
    await wait_for_ack(dut, dut.dbus_ack)
    assert int(dut.dbus_rdata.value) == PSRAM_RESPONSE
    assert int(dut.ibus_ack.value) == 0
    dut.dbus_cyc.value = 0

    await wait_for_ack(dut, dut.ibus_ack)
    assert int(dut.ibus_rdata.value) == FLASH_RESPONSE
    dut.ibus_cyc.value = 0


@cocotb.test()
async def psram_word_write_uses_the_spi_program_command(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    dut.dbus_addr.value = 0x100055AA
    dut.dbus_wdata.value = 0xDEADBEEF
    dut.dbus_we.value = 1
    dut.dbus_cyc.value = 1
    await wait_for_ack(dut, dut.dbus_ack)
    assert int(dut.command.value) == 0x02
    assert int(dut.captured_address.value) == 0x0055A8
    assert int(dut.captured_write_data.value) == 0xEFBEADDE
    assert int(dut.psram_selected.value) == 1
    dut.dbus_cyc.value = 0

