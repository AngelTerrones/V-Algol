# UART bootloader
# Jump to RAM code

#define ramStart       0x10000000
#define UART_CFG       0x20010000
#define UART_TX        0x20010004
#define UART_RX        0x20010008
#define UART_TX_STATUS 0x2001000C

  .global bootStart

bootStart:
  li a0, UART_CFG
  li a1, 100
  sw a1, (a0)
wait:
  addi a1, a1, -1
  bne  a1, zero, wait

bootloader:
  // send 0xff
  li a0, 0xff
  call tx
  // load 2 bytes with the size
  call rx
  call tx
  mv   s0, a0
  call rx
  call tx
  slli s0, s0, 8
  or   s0, s0, a0
  li   a0, 0xffff
  beq  s0, a0, boot
  // receive data
  li s1, ramStart
download:
  call rx
  call tx
  sb   a0, (s1)
  addi s0, s0, -1
  addi s1, s1, 1
  bne  s0, zero, download

  // boot
boot:
  li a0, 'o'
  call tx
  li a0, 'k'
  call tx
  li a0, '\n'
  call tx
  call ramStart

tx:
  li t0, UART_TX
  li t1, UART_TX_STATUS
1:
  lw t2, (t1)
  andi t2, t2, 0x1
  beq  t2, zero, 1b
  sw a0, (t0)
  ret

rx:
  li t0, UART_RX
  li t1, UART_TX_STATUS
1:
  lw t2, (t1)
  andi t2, t2, 0x2
  beq  t2, zero, 1b
  sw zero, (t1)
  lw a0, (t0)
  ret
