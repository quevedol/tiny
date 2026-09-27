# Vendored SERV RTL

- Upstream: `https://github.com/olofk/serv`
- Revision: `41e8aeedfd1e9ad5f95902c5b0dfc83d1c99e5d2`
- Core metadata version: `1.4.0`
- Imported files: the 18 Verilog files listed by the upstream `serv.core` core fileset.
- License: ISC; see `LICENSE` in this directory.

The upstream RTL files are preserved verbatim. Project-specific parameters and signal adaptation live one directory above in `serv_cpu.v`.

Initial configuration: `W=1`, 32 GPRs, `RF_WIDTH=2`, `WITH_CSR=0`, `DEBUG=0`, `MDU=0`, `COMPRESSED=0`, `ALIGN=0` and reset strategy `MINI`. This implements the RV32I base ISA for an `rv32i/ilp32` bare-metal toolchain while omitting optional extensions.
