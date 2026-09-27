<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

SERV TinyML is a fully digital RV32I system-on-chip targeting the SkyWater SKY130 process. A bit-serial SERV CPU executes bare-metal firmware from external SPI Flash and uses external SPI PSRAM for data. A memory-mapped signed INT8 multiply-accumulate unit accelerates dense neural-network layers.

The first demonstration target is an MNIST classifier using 16x16 input images and a quantized `256 -> 16 -> 10` network. Weights and test images reside in Flash; activations and intermediate results reside in PSRAM.

The project is under active development. The current RTL contains a signed INT8 MAC with a C driver, a fixed upstream revision of SERV configured for RV32I/ILP32, an MMIO fabric, a UART transmitter and a single-bit SPI external-memory path. A smoke test boots C firmware from serial Flash/PSRAM RTL models, checks core RV32I operations, executes a 4 -> 3 INT8 classifier, transmits `SML1` through UART and observes the completion signature. Sky130 physical hardening and clock-gating validation are the next milestones.

## How to test

The repository includes RTL regressions for the Tiny Tapeout wrapper, MAC MMIO, SPI, memory bridge, SERV firmware boot and external serial-memory boot.

## External hardware

The prototype uses the Tiny Tapeout QSPI Pmod interface with one Flash device and one PSRAM device. UART access from the Tiny Tapeout demoboard will be used for status and test output.
