# No UART bootloader
# Jump to RAM code

#define ramStart 0x10000000

  .global bootStart

bootStart:
  call ramStart
