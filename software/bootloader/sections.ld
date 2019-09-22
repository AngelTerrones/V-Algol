/*
  Copyright: Angel Terrones <angelterrones@gmail.com>
*/

OUTPUT_ARCH(riscv)
ENTRY(bootStart)

MEMORY {
       mem : ORIGIN = 0x00000000, LENGTH = 0x00000100
}

SECTIONS {
         .text : {
               *(.text)
               } > mem
}
