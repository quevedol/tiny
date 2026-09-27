OUTPUT_ARCH("riscv")
ENTRY(_start)

PHDRS
{
    text PT_LOAD FLAGS(5);
    data PT_LOAD FLAGS(6);
}

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x00000000, LENGTH = 16M
    PSRAM (rwx) : ORIGIN = 0x10000000, LENGTH = 8M
}

SECTIONS
{
    .text :
    {
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
        *(.srodata*)
    } > FLASH :text

    /* start.S copies initialized data with lw/sw, so the Flash load address
       must remain word-aligned even when .text ends on an odd boundary. */
    .data : AT(ALIGN(LOADADDR(.text) + SIZEOF(.text), 4))
    {
        __data_start = .;
        *(.data*)
        *(.sdata*)
        __data_end = .;
    } > PSRAM :data
    __data_load_start = LOADADDR(.data);

    .bss (NOLOAD) :
    {
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        __bss_end = .;
    } > PSRAM :data

    _stack_top = ORIGIN(PSRAM) + LENGTH(PSRAM);
}
