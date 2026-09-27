CROSS ?= riscv64-unknown-elf-
CC := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump

CFLAGS := -march=rv32i -mabi=ilp32 -Os -ffreestanding \
	-ffunction-sections -fdata-sections -Wall -Wextra
LDFLAGS := -nostdlib -nostartfiles -Wl,--gc-sections \
	-Wl,-Map,build/serv_alive.map -T link.ld

BUILD := build
ELF := $(BUILD)/serv_alive.elf
BIN := $(BUILD)/serv_alive.bin
HEX := serv_alive.hex

.PHONY: all clean disasm

all: $(HEX)

$(BUILD):
	mkdir -p $(BUILD)

$(ELF): start.S main.c mac.c mac.h link.ld | $(BUILD)
	$(CC) $(CFLAGS) $(LDFLAGS) start.S main.c mac.c -o $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(HEX): $(BIN) bin2hex.py
	python3 bin2hex.py $(BIN) $(HEX)

disasm: $(ELF)
	$(OBJDUMP) -d -M no-aliases $(ELF)

clean:
	rm -rf $(BUILD) $(HEX)
