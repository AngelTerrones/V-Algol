# ------------------------------------------------------------------------------
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>
# Project: V-Algol
# ------------------------------------------------------------------------------

XLEN = 32

default: all

RISCV_PREFIX ?= riscv-none-embed-
RISCV_GCC ?= $(RISCV_PREFIX)gcc
RISCV_GCC_OPTS ?= -DPREALLOCATE=1 -mcmodel=medany -static -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf -march=rv32i -mabi=ilp32 -Wl,--no-relax
RISCV_LINK_OPTS ?= -static -nostdlib -nostartfiles -lm -lgcc -T section.ld
RISCV_OBJDUMP ?= $(RISCV_PREFIX)objdump --disassemble-all --disassemble-zeroes

ELF = bootstrap.elf
DUMP = bootstrap.dump

$(ELF): boot.s section.ld
	$(RISCV_GCC) $(RISCV_GCC_OPTS) $(RISCV_LINK_OPTS) $< -o $@

$(DUMP): bootstrap.elf
	$(RISCV_OBJDUMP) $< > $@

all: $(DUMP)

clean:
	rm -rf $(ELF) $(DUMP)
