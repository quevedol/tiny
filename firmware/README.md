# Firmware

This directory contains the initial SERV bare-metal startup code, linker
script and C smoke-test firmware. The current program checks representative
RV32I ALU, branch, load and store operations, sends `SML1` over the MMIO UART
and writes a completion signature. The integer-only inference runtime will be
added here as the SoC grows.

Planned compiler baseline:

```text
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -Os
```

Run `make` with a RISC-V GNU toolchain in `PATH` to regenerate
`serv_alive.hex`. The checked-in hex file lets RTL CI run without installing
the cross compiler.
