# ------------------------------------------------------------------------------
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>
# Project: V-Algol
# ------------------------------------------------------------------------------

XLEN = 32

default: riscv

SWFOLDER = ../../software
RISCV_PREFIX ?= riscv-none-embed-
RISCV_GCC ?= $(RISCV_PREFIX)gcc
RISCV_GCC_OPTS ?= -Wall -mcmodel=medany -static -std=gnu99 -O2 -ffast-math -fno-common  -march=rv32i -mabi=ilp32 -Wl,--no-relax
RISCV_LINK_OPTS ?= -static -nostartfiles -lm -lgcc -T $(SWFOLDER)/sections.ld
RISCV_OBJDUMP ?= $(RISCV_PREFIX)objdump --disassemble-all --disassemble-zeroes

INC = -I$(SWFOLDER)
SWSRC = $(wildcard $(SWFOLDER)/*.c) $(wildcard $(SWFOLDER)/*.S)
tests = interrupts testlib

#------------------------------------------------------------
# template to compile the tests.
define compile_template
$(1).riscv: $(1).c $(wildcard $(SWFOLDER)/*)
	$(RISCV_GCC) $(INC) $(RISCV_GCC_OPTS) $(RISCV_LINK_OPTS) $(SWSRC) $$< -o $$@
endef

$(foreach test,$(tests),$(eval $(call compile_template,$(test))))

#------------------------------------------------------------
# add targets
tests_riscv = $(addsuffix .riscv,$(tests))
tests_dump  = $(addsuffix .dump,$(tests))

$(tests_dump): %.dump: %.riscv
	$(RISCV_OBJDUMP) $< > $@

riscv: $(tests_dump)

junk = $(tests_riscv) $(tests_dump)

clean:
	rm -rf $(junk)
