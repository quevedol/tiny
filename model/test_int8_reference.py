#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0

import unittest

from int8_reference import as_int32, dot_int8, mac_step, quantize_int8, smoke_inference


class Int8ReferenceTest(unittest.TestCase):
    def test_smoke_model(self):
        self.assertEqual(smoke_inference(), [32, 0, 19])

    def test_signed_inputs_and_relu(self):
        result, accumulator, overflow = dot_int8([3, 0xFE], [4, 5], 0, 0, False)
        self.assertEqual((result, accumulator, overflow), (2, 2, False))
        self.assertEqual(quantize_int8(-32, 0, True), 0)

    def test_wrapping_accumulator_and_sticky_overflow(self):
        accumulator, overflow = mac_step(0x7FFF_FFFF, 1, 1)
        self.assertEqual(accumulator, -0x8000_0000)
        self.assertTrue(overflow)
        self.assertEqual(as_int32(0xFFFF_FFFF), -1)


if __name__ == "__main__":
    unittest.main()
