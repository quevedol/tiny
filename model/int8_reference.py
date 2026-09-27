#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Bit-exact software model of the on-chip INT8 MAC post-processing path."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable, Sequence

INT32_MIN = -(1 << 31)
INT32_MAX = (1 << 31) - 1


def as_int8(value: int) -> int:
    """Interpret the low byte of *value* as a signed two's-complement INT8."""
    value &= 0xFF
    return value - 0x100 if value & 0x80 else value


def as_int32(value: int) -> int:
    """Wrap *value* to the signed 32-bit accumulator representation."""
    value &= 0xFFFF_FFFF
    return value - (1 << 32) if value & (1 << 31) else value


def mac_step(accumulator: int, activation: int, weight: int) -> tuple[int, bool]:
    """Perform one RTL-equivalent MAC step, returning (new_accumulator, overflow)."""
    accumulator = as_int32(accumulator)
    product = as_int8(activation) * as_int8(weight)
    unwrapped_sum = accumulator + product
    overflow = unwrapped_sum < INT32_MIN or unwrapped_sum > INT32_MAX
    return as_int32(unwrapped_sum), overflow


def quantize_int8(accumulator: int, shift: int, relu: bool) -> int:
    """Apply the MAC output shift, optional ReLU, and signed INT8 saturation."""
    if not 0 <= shift <= 31:
        raise ValueError("shift must be in [0, 31]")
    value = as_int32(accumulator) >> shift
    if relu and value < 0:
        return 0
    return max(-128, min(127, value))


def dot_int8(
    activations: Iterable[int], weights: Iterable[int], bias: int, shift: int, relu: bool
) -> tuple[int, int, bool]:
    """Return (INT8 result, accumulator, sticky overflow) for one dense output."""
    activations = list(activations)
    weights = list(weights)
    if len(activations) != len(weights):
        raise ValueError("activations and weights must have the same length")
    accumulator = as_int32(bias)
    overflow = False
    for activation, weight in zip(activations, weights):
        accumulator, step_overflow = mac_step(accumulator, activation, weight)
        overflow |= step_overflow
    return quantize_int8(accumulator, shift, relu), accumulator, overflow


def dense_int8(
    activations: Sequence[int], weights: Sequence[Sequence[int]], biases: Sequence[int], shift: int, relu: bool
) -> list[int]:
    """Evaluate a row-major dense layer using the hardware arithmetic contract."""
    if len(weights) != len(biases):
        raise ValueError("one bias is required for each output row")
    return [dot_int8(activations, row, bias, shift, relu)[0] for row, bias in zip(weights, biases)]


def load_smoke_model() -> dict:
    """Load the deterministic 4-input/3-output bring-up model."""
    path = Path(__file__).with_name("tinyml_smoke.json")
    return json.loads(path.read_text(encoding="utf-8"))


def smoke_inference() -> list[int]:
    model = load_smoke_model()
    return dense_int8(
        model["input"], model["weights"], model["biases"], model["shift"], model["relu"]
    )


if __name__ == "__main__":
    model = load_smoke_model()
    outputs = smoke_inference()
    assert outputs == model["expected_output"], (outputs, model["expected_output"])
    print(f"TinyML INT8 smoke output: {outputs}; class={outputs.index(max(outputs))}")
