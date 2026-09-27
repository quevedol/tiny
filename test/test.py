# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # 50 MHz project clock.
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Check the external-memory pin ownership")
    await Timer(1, unit="ns")
    assert int(dut.uio_oe.value) == 0xCB
    assert int(dut.uio_out.value) & 0xC1 == 0xC1

    # ena holds the SoC in reset, so no serial transaction may be initiated.
    dut.ena.value = 0
    await ClockCycles(dut.clk, 2)
    assert int(dut.uio_out.value) & 0xC1 == 0xC1
