# TinyML model

The final target remains a quantized MNIST classifier using 16x16 inputs and a
`256 -> 16 -> 10` dense network. Before training that model, this directory
defines the arithmetic contract shared by the RTL, firmware and model tooling.

`int8_reference.py` is bit-exact with `src/accel/mac_int8.v`:

- activations and weights are signed INT8;
- each product is accumulated in a wrapping signed INT32 accumulator;
- overflow is detected per product and is sticky for a dot product;
- arithmetic right shift, optional ReLU and INT8 saturation happen only at the
  output.

`tinyml_smoke.json` is a deterministic 4 -> 3 dense layer that produces
`[32, 0, 19]` (class 0). It is deliberately tiny: it is the first executable
firmware/RTL integration vector, not a claimed MNIST model.

Run the portable reference checks with:

```sh
python model/int8_reference.py
python model/test_int8_reference.py
```

The next export stage will produce the 16x16 model's `weights.bin`,
`biases.bin`, `test_images.bin`, and expected bit-exact results in this same
format.
