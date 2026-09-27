#!/usr/bin/env python3
"""Convert a little-endian RISC-V binary to readmemh 32-bit words."""

from pathlib import Path
import sys


def main() -> None:
    source = Path(sys.argv[1])
    destination = Path(sys.argv[2])
    data = source.read_bytes()
    data += bytes((-len(data)) % 4)
    words = [
        int.from_bytes(data[index:index + 4], "little")
        for index in range(0, len(data), 4)
    ]
    if len(words) > 1024:
        raise ValueError("firmware exceeds the 4 KiB ideal-memory test image")
    words.extend([0x00000013] * (1024 - len(words)))
    destination.write_text(
        "".join(f"{word:08x}\n" for word in words),
        encoding="ascii",
    )


if __name__ == "__main__":
    main()
