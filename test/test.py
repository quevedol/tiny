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
    # The gate-level netlist contains real Sky130 output stages with unit
    # delays.  Allow those stages to settle after reset before sampling pins.
    await Timer(20, unit="ns")
    assert str(dut.uio_oe.value) == "11001011"
    # Check the two chip selects directly. Other serial signals can still
    # carry gate-level unknowns before the first memory transaction settles.
    assert str(dut.uio_out.value[0]) == "1"
    assert str(dut.uio_out.value[6]) == "1"

    # ena holds the SoC in reset, so no serial transaction may be initiated.
    dut.ena.value = 0
    await ClockCycles(dut.clk, 2)
    await Timer(20, unit="ns")
    # In a gate-level simulation, unrelated pad paths can retain X values
    # while the design is held reset.  The externally relevant safety
    # requirement is that neither memory device is selected.
    assert str(dut.uio_out.value[0]) == "1"
    assert str(dut.uio_out.value[6]) == "1"
