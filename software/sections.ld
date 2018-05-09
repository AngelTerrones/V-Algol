/*
* Algol - A RISC-V (RV32I) Processor Core.
*
* Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
*
* Permission to use, copy, modify, and/or distribute this software for any
* purpose with or without fee is hereby granted, provided that the above
* copyright notice and this permission notice appear in all copies.
*
* THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
* WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
* ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
* WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
* ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
* OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*/

OUTPUT_ARCH( "riscv" )
ENTRY(_start)

/*----------------------------------------------------------------------*/
/* Sections                                                             */
/*----------------------------------------------------------------------*/
SECTIONS
{
    /*-----------------------------------------------------------------*/
    /* Machine region */
    . = 0x1C000000;
    .text.init : { *(.text.init) }
    . = ALIGN(0x1000);
    .text.mcode : { *(.text.mcode)}
    /* TOHOST/FROMHOST region inside the machine zone */
    . = 0x1FFF0000;
    .tohost : { *(.tohost) }
    /*-----------------------------------------------------------------*/
    /* User region */
    . = 0x20000000;
    .text : { *(.text) }
    /* data segment */
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
}
