# SPDX-License-Identifier: Apache-2.0
"""Board-level checks of the Tiny Tapeout top module through its pins only.

The design runs with its production parameters: 50 MHz project clock,
115200 baud UART (434 clocks per bit) and SPI_CLK_DIV=2 (12.5 MHz SCK).
Event times are written to board_events.json for the waveform plots.
"""

import json
import os
import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer, with_timeout
from cocotb.utils import get_sim_time

CLK_NS = 20
UART_CLKS_PER_BIT = 434
EVENTS_FILE = os.environ.get("BOARD_EVENTS", "board_events.json")
GATE_LEVEL = os.environ.get("GATES") == "yes"


def record(name, **values):
    try:
        with open(EVENTS_FILE) as handle:
            events = json.load(handle)
    except (OSError, ValueError):
        events = {}
    events[name] = values
    with open(EVENTS_FILE, "w") as handle:
        json.dump(events, handle, indent=2)


def now_ns():
    return get_sim_time(unit="ns")


def bit(signal):
    """Return 0/1, or None for X/Z (gate-level unknowns)."""
    text = str(signal.value)
    return int(text) if text in ("0", "1") else None


async def power_on(dut, reset_cycles=10):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, unit="ns").start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in_extra.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, reset_cycles)


async def receive_uart_byte(dut):
    """Sample uo[0] like a 115200 8N1 receiver: centre of each bit."""
    while bit(dut.uart_tx) != 0:
        await FallingEdge(dut.uart_tx)
    start = now_ns()
    await ClockCycles(dut.clk, UART_CLKS_PER_BIT // 2)
    assert bit(dut.uart_tx) == 0, "start bit glitch"
    value = 0
    for index in range(8):
        await ClockCycles(dut.clk, UART_CLKS_PER_BIT)
        value |= (bit(dut.uart_tx) or 0) << index
    await ClockCycles(dut.clk, UART_CLKS_PER_BIT)
    assert bit(dut.uart_tx) == 1, "missing stop bit"
    return value, start


async def watch_mac_done(dut, stats):
    """Log every edge of uo[5] (MAC done) to see how the pin behaves."""
    while True:
        await RisingEdge(dut.mac_done)
        stats["rises"] += 1
        if stats["first_rise_ns"] is None:
            stats["first_rise_ns"] = now_ns()
        await FallingEdge(dut.mac_done)
        stats["falls"] += 1
        stats["last_fall_ns"] = now_ns()


async def wiggle_unused_inputs(dut, seed):
    """Drive random values on ui_in and the unused uio inputs."""
    rng = random.Random(seed)
    while True:
        dut.ui_in.value = rng.randrange(256)
        dut.uio_in_extra.value = rng.randrange(256)
        await ClockCycles(dut.clk, 997)


@cocotb.test()
async def pins_are_safe_during_reset(dut):
    """1. While rst_n=0: pin directions, both memories deselected, SCK idle."""
    await power_on(dut)
    await Timer(5, unit="ns")
    samples = []
    for _ in range(5):
        await ClockCycles(dut.clk, 1)
        await Timer(5, unit="ns")
        samples.append({
            "uio_oe": str(dut.uio_oe.value),
            "flash_cs_n": bit(dut.flash_cs_n),
            "psram_cs_n": bit(dut.psram_cs_n),
            "psram_b_cs_n": bit(dut.psram_b_cs_n),
            "sck": bit(dut.sck),
            "mosi": bit(dut.mosi),
            "uart_tx": bit(dut.uart_tx),
        })
    record("reset_pins", time_ns=now_ns(), samples=samples)
    for sample in samples:
        assert sample["uio_oe"] == "11001011"
        assert sample["flash_cs_n"] == 1
        assert sample["psram_cs_n"] == 1
        assert sample["psram_b_cs_n"] == 1
        assert sample["sck"] == 0
        assert sample["mosi"] == 0


@cocotb.test()
async def first_flash_read_on_the_pins(dut):
    """2. After reset the chip reads address 0 of the Flash: command 0x03."""
    await power_on(dut)
    dut.rst_n.value = 1
    release = now_ns()
    await with_timeout(FallingEdge(dut.flash_cs_n), 20, timeout_unit="us")
    cs_low = now_ns()
    command = 0
    rises = []
    for _ in range(32):
        await RisingEdge(dut.sck)
        rises.append(now_ns())
        command = (command << 1) | (bit(dut.mosi) or 0)
    word = 0
    for _ in range(32):
        await FallingEdge(dut.sck)
        await RisingEdge(dut.sck)
        word = (word << 1) | (bit(dut.miso) or 0)
    period = (rises[-1] - rises[0]) / (len(rises) - 1)
    record("first_flash_read", release_ns=release, cs_low_ns=cs_low,
           command=f"0x{command:08x}", word=f"0x{word:08x}",
           sck_period_ns=period, sck_mhz=1000.0 / period,
           psram_cs_n=bit(dut.psram_cs_n))
    assert command >> 24 == 0x03, f"expected READ (0x03), got {command:#010x}"
    assert command & 0xFFFFFF == 0, "first fetch must be address 0"
    assert abs(period - 80.0) < 0.5, f"SCK period {period} ns, expected 80 ns"
    assert bit(dut.psram_cs_n) == 1, "PSRAM must stay deselected"


@cocotb.test()
async def boots_and_prints_sml1_on_uart(dut):
    """3. Full boot from the Flash model; decode the UART on uo[0].

    Unused inputs (ui_in, uio[7:3], uio[1:0]) are driven with random values
    the whole time to show they cannot disturb the design.
    """
    await power_on(dut)
    dut.rst_n.value = 1
    start = now_ns()
    stats = {"rises": 0, "falls": 0, "first_rise_ns": None, "last_fall_ns": None}
    cocotb.start_soon(watch_mac_done(dut, stats))
    cocotb.start_soon(wiggle_unused_inputs(dut, seed=1806))

    text = ""
    char_times = []
    while not text.endswith("\n"):
        value, when = await with_timeout(receive_uart_byte(dut), 40, timeout_unit="ms")
        text += chr(value)
        char_times.append(when)
        assert len(text) <= 8, f"unexpected UART output {text!r}"

    await ClockCycles(dut.clk, 20)
    mac_low = int(dut.mac_low.value)
    record("boot", start_ns=start, text=text, char_times_ns=char_times,
           boot_ms=(char_times[0] - start) / 1e6,
           mac_done=stats, mac_done_final=bit(dut.mac_done), mac_low_final=mac_low,
           cpu_active_final=bit(dut.cpu_active),
           mac_overflow_final=bit(dut.mac_overflow))
    assert text == "SML1\n"
    # Final classifier output is 19 = 0b0001_0011; only the low nibble is
    # visible on uo[4:1].
    assert mac_low == 19 & 0xF
    # uo[5] is the sticky MMIO done bit: it rises with the first product and
    # is only cleared by the CLEAR command, which the firmware issues once
    # before its self-test. It therefore stays high until the end.
    assert stats["rises"] >= 1
    assert bit(dut.mac_done) == 1


@cocotb.test()
async def ena_low_freezes_memory_pins(dut):
    """4. ena=0 in the middle of activity: memories deselected, SCK stops."""
    await power_on(dut)
    dut.rst_n.value = 1
    await with_timeout(FallingEdge(dut.flash_cs_n), 20, timeout_unit="us")
    await ClockCycles(dut.clk, 3000)
    dut.ena.value = 0
    ena_low = now_ns()
    await ClockCycles(dut.clk, 2)
    edges = {"flash_cs_low": 0, "psram_cs_low": 0, "sck_high": 0}
    for _ in range(5000):
        await ClockCycles(dut.clk, 1)
        edges["flash_cs_low"] += bit(dut.flash_cs_n) == 0
        edges["psram_cs_low"] += bit(dut.psram_cs_n) == 0
        edges["sck_high"] += bit(dut.sck) == 1
    dut.ena.value = 1
    record("ena_low", ena_low_ns=ena_low, cycles=5000, counts=edges)
    assert edges == {"flash_cs_low": 0, "psram_cs_low": 0, "sck_high": 0}


@cocotb.test()
async def reset_during_boot_restarts_cleanly(dut):
    """5. Pull rst_n low in the middle of the boot; the chip must start over."""
    await power_on(dut)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 50_000)  # 1 ms into the boot
    dut.rst_n.value = 0
    reset_at = now_ns()
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    released = now_ns()
    await with_timeout(FallingEdge(dut.flash_cs_n), 20, timeout_unit="us")
    command = 0
    for _ in range(32):
        await RisingEdge(dut.sck)
        command = (command << 1) | (bit(dut.mosi) or 0)
    text = ""
    while not text.endswith("\n"):
        value, _ = await with_timeout(receive_uart_byte(dut), 40, timeout_unit="ms")
        text += chr(value)
        assert len(text) <= 8
    record("reset_mid_boot", reset_ns=reset_at, release_ns=released,
           first_command=f"0x{command:08x}", text=text, done_ns=now_ns())
    assert command == 0x03000000, "fetch must restart at address 0"
    assert text == "SML1\n"
