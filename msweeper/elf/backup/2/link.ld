PHDRS { seg PT_LOAD FLAGS(7); }
SECTIONS
{
  . = 0x400078;
  .text : ALIGN(1) { *(.text) *(.data) } :seg
  .bss  : ALIGN(1) { *(.bss) } :seg
}
