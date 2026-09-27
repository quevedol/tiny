# SPDX-License-Identifier: Apache-2.0

import random
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "model"))
from int8_reference import dot_int8


async def write_reg(dut, offset, value):
    await FallingEdge(dut.clk)
    dut.bus_addr.value = offset
    dut.bus_wdata.value = value
    dut.bus_sel.value = 0xF
    dut.bus_we.value = 1
    dut.bus_cyc.value = 1
    for _ in range(16):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        if int(dut.bus_ack.value) == 1:
            break
    else:
        assert False, "MMIO write did not complete"
    await FallingEdge(dut.clk)
    dut.bus_cyc.value = 0
    dut.bus_we.value = 0


async def read_reg(dut, offset):
    await FallingEdge(dut.clk)
    dut.bus_addr.value = offset
    dut.bus_we.value = 0
    dut.bus_cyc.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    value = int(dut.bus_rdata.value)
    assert int(dut.bus_ack.value) == 1
    await FallingEdge(dut.clk)
    dut.bus_cyc.value = 0
    return value


@cocotb.test()
async def test_mac_mmio(dut):
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.bus_addr.value = 0
    dut.bus_wdata.value = 0
    dut.bus_sel.value = 0
    dut.bus_we.value = 0
    dut.bus_cyc.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1

    # Clear; 3*4 + (-2)*5 = 2.
    await write_reg(dut, 0x00, 0x1)
    await write_reg(dut, 0x04, 3)
    await write_reg(dut, 0x08, 4)
    await write_reg(dut, 0x00, 0x4)
    await write_reg(dut, 0x04, 0xFE)
    await write_reg(dut, 0x08, 5)
    await write_reg(dut, 0x00, 0x4)
    assert await read_reg(dut, 0x10) == 2
    assert await read_reg(dut, 0x14) == 2
    assert (await read_reg(dut, 0x18)) & 0x1

    # Bias and shift: 1024 >> 4 = 64.
    await write_reg(dut, 0x0C, 1024)
    await write_reg(dut, 0x00, 0x2)
    await write_reg(dut, 0x1C, 0x8)
    assert await read_reg(dut, 0x14) == 64

    # ReLU clamps a negative bias to zero.
    await write_reg(dut, 0x0C, 0xFFFFFFE0)
    await write_reg(dut, 0x00, 0x2)
    await write_reg(dut, 0x1C, 0x1)
    assert await read_reg(dut, 0x14) == 0

    # Explicit signed-accumulator overflow is sticky.
    await write_reg(dut, 0x0C, 0x7FFFFFFF)
    await write_reg(dut, 0x00, 0x2)
    await write_reg(dut, 0x1C, 0x0)
    await write_reg(dut, 0x04, 1)
    await write_reg(dut, 0x08, 1)
    await write_reg(dut, 0x00, 0x4)
    assert (await read_reg(dut, 0x18)) & 0x2


@cocotb.test()
async def test_mac_against_10000_random_int8_products(dut):
    """Compare 10,000 MMIO-driven products with the portable RTL reference."""
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.bus_addr.value = 0
    dut.bus_wdata.value = 0
    dut.bus_sel.value = 0
    dut.bus_we.value = 0
    dut.bus_cyc.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1

    generator = random.Random(0x51564D4C)
    products_per_batch = 100
    batches = 100

    for _ in range(batches):
        activations = [generator.randrange(-128, 128) for _ in range(products_per_batch)]
        weights = [generator.randrange(-128, 128) for _ in range(products_per_batch)]
        bias = generator.randrange(-(1 << 31), 1 << 31)
        shift = generator.randrange(0, 32)
        relu = bool(generator.getrandbits(1))
        expected_result, expected_accumulator, expected_overflow = dot_int8(
            activations, weights, bias, shift, relu
        )

        await write_reg(dut, 0x0C, bias & 0xFFFF_FFFF)
        await write_reg(dut, 0x00, 0x2)
        await write_reg(dut, 0x1C, (shift << 1) | int(relu))
        for activation, weight in zip(activations, weights):
            await write_reg(dut, 0x04, activation & 0xFF)
            await write_reg(dut, 0x08, weight & 0xFF)
            await write_reg(dut, 0x00, 0x4)

        assert await read_reg(dut, 0x10) == (expected_accumulator & 0xFFFF_FFFF)
        assert (await read_reg(dut, 0x14) & 0xFF) == (expected_result & 0xFF)
        status = await read_reg(dut, 0x18)
        assert status & 0x1
        assert bool(status & 0x2) == expected_overflow
