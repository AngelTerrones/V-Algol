/*
 * Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
 */

OUTPUT_ARCH( "riscv" )
ENTRY(_start)

/*----------------------------------------------------------------------*/
/* Sections                                                             */
/*----------------------------------------------------------------------*/
SECTIONS
{
    /*-----------------------------------------------------------------*/
    . = 0x10000000;
    .text.init : { *(.text.init) }
    . = ALIGN(0x1000);
    .text : { *(.text) }
    /*-----------------------------------------------------------------*/
    /* data segment */
    . = ALIGN(0x1000);
    .data : { *(.data) }
    .sdata : {
    __global_pointer$ = . + 0x800;
    *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2) *(.srodata*)
    *(.sdata .sdata.* .gnu.linkonce.s.*)
    }
    /* bss segment */
    .sbss : {
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.scommon)
    }
    .bss : { *(.bss) }
    /* End of uninitalized data segment */
    _end = .;
    . = ALIGN(0x1000);
    . = . + 0x1000;  /*4K stack*/
    _sp = .;
}
