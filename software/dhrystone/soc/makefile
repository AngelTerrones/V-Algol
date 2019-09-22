# ------------------------------------------------------------------------------
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>
# ------------------------------------------------------------------------------
RISCV_PREFIX  ?= riscv-none-embed-
RISCV_GCC     := ${RISCV_PREFIX}gcc
RISCV_OBJCOPY := ${RISCV_PREFIX}objcopy
RISCV_OBJDUMP := ${RISCV_PREFIX}objdump
ROOT          ?= $(shell cd ../../..; pwd)
OUT           := $(ROOT)/build/dhrystone

ELFNAME  = dhrystone-soc
LDSCRIPT = sections.ld
CFLAGS   = -g -O3 -march=rv32i -mabi=ilp32 -fno-inline -fno-common -DTIME -DSOC_HZ=100000000ll
LDFLAGS  = -nostdlib -lgcc -lc -nostartfiles -ffreestanding -Wl,-Bstatic,-T,$(LDSCRIPT)
INC      = -I src
SRCS     = src/dhrystone_main.c src/dhrystone.c  src/syscalls.c src/start.S

all: $(OUT)/$(ELFNAME).elf

%.elf: $(SRCS)
	@mkdir -p $(OUT)
	@$(RISCV_GCC) $(INC) $(CFLAGS) $(LFLAGS) -o $@ $(SRCS) $(LDFLAGS)
	@$(RISCV_OBJDUMP) -dS $@ > $*.dump

clean:
	@rm -rf $(OUT)/$(ELFNAME).*
