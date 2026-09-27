# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer


async def receive_uart_byte(dut, clocks_per_bit=4):
    bit_period_ns = clocks_per_bit * 20
    await FallingEdge(dut.uart_tx)
    await Timer(bit_period_ns // 2, unit="ns")
    assert int(dut.uart_tx.value) == 0

    value = 0
    for bit in range(8):
        await Timer(bit_period_ns, unit="ns")
        value |= int(dut.uart_tx.value) << bit

    await Timer(bit_period_ns, unit="ns")
    assert int(dut.uart_tx.value) == 1
    return value


async def receive_uart_message(dut, length):
    return bytes([await receive_uart_byte(dut) for _ in range(length)])


@cocotb.test()
async def test_serv_executes_c_firmware(dut):
    """SERV must execute C and write the SML1 signature through its data bus."""

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    uart_message = cocotb.start_soon(receive_uart_message(dut, 5))

    # The firmware now runs the 4 -> 3 INT8 smoke inference after its ALU,
    # store and basic MAC checks, so allow the additional MMIO transactions.
    for cycle in range(60000):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        if int(dut.status_valid.value):
            assert int(dut.status_value.value) == 0x534D4C31
            assert await uart_message == b"SML1\n"
            dut._log.info("SERV alive signature observed after %d cycles", cycle + 1)
            return

    raise AssertionError("SERV did not write the SML1 signature within 60000 cycles")
