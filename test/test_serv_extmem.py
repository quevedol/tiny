import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer, with_timeout


@cocotb.test()
async def test_serv_executes_c_firmware_from_serial_memory(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    await with_timeout(RisingEdge(dut.status_valid), 150, timeout_unit="ms")
    assert int(dut.status_value.value) == 0x534D4C31
    # First .data word is the smoke-model input packed little-endian:
    # [12, -6, 8, 3]. The firmware subsequently reads it from PSRAM.
    assert int(dut.memory_model.psram_low[0].value) == 0x0308FA0C
    # The final smoke-model output is dot([12, -6, 8, 3], [2, 3, 4, -1])
    # plus bias 4, followed by ReLU: 19.  Checking it at the signature
    # proves that the external-memory boot path exercised the INT8 MAC.
    assert int(dut.mac_done.value) == 1
    assert int(dut.mac_result.value) == 19


@cocotb.test()
async def test_cpu_bus_waits_while_serial_memory_responds(dut):
    """SERV stalls on its Wishbone ack while the serial word is collected.

    SERV runs on the ungated system clock. The bridge holds off the ack while
    the SPI controller works, so SERV's request must stay stable, no ack may
    be issued early, and exactly one ack must follow the serial word.
    """
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    soc = dut.dut
    await with_timeout(RisingEdge(soc.cpu_wait), 50, timeout_unit="us")
    await FallingEdge(dut.clk)

    frozen_bus = (
        int(soc.ibus_addr.value),
        int(soc.ibus_cyc.value),
        int(soc.dbus_addr.value),
        int(soc.dbus_cyc.value),
        int(soc.dbus_we.value),
    )
    assert frozen_bus[1] or frozen_bus[3], "a bus request must be pending"
    saw_active_chip_select = False

    # A serial word takes far longer than these eight system cycles. During
    # that interval only the serial controller may make progress.
    for _ in range(8):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        assert int(soc.cpu_wait.value) == 1
        assert int(soc.ibus_ack.value) == 0 and int(soc.dbus_ack.value) == 0
        assert (
            int(soc.ibus_addr.value),
            int(soc.ibus_cyc.value),
            int(soc.dbus_addr.value),
            int(soc.dbus_cyc.value),
            int(soc.dbus_we.value),
        ) == frozen_bus
        saw_active_chip_select |= (
            int(dut.flash_cs_n.value) == 0 or int(dut.psram_cs_n.value) == 0
        )

    assert saw_active_chip_select

    # The ack is raised on the same clock edge that ends the wait.
    await with_timeout(FallingEdge(soc.cpu_wait), 50, timeout_unit="us")
    await Timer(1, unit="ns")
    acks = int(soc.ibus_ack.value) + int(soc.dbus_ack.value)
    for _ in range(3):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        acks += int(soc.ibus_ack.value) + int(soc.dbus_ack.value)
    assert acks == 1, f"expected exactly one ack after the word, saw {acks}"
