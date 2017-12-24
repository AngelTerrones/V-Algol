#=======================================================================
# Makefile for riscv-tests/isa
#-----------------------------------------------------------------------

XLEN ?= 32

src_dir := ./isa

include $(src_dir)/rv32ui/Makefrag
include $(src_dir)/rv32uc/Makefrag
include $(src_dir)/rv32um/Makefrag
include $(src_dir)/rv32ua/Makefrag
include $(src_dir)/rv32mi/Makefrag

default: all

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

#RISCV_PREFIX ?= riscv64-unknown-elf-
RISCV_PREFIX ?= riscv-none-embed-
RISCV_GCC ?= $(RISCV_PREFIX)gcc
RISCV_GCC_OPTS ?= -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles
RISCV_OBJDUMP ?= $(RISCV_PREFIX)objdump --disassemble-all --disassemble-zeroes --section=.text --section=.text.startup --section=.text.init --section=.data
RISCV_SIM ?= spike

vpath %.S $(src_dir)

#------------------------------------------------------------
# Build assembly tests

%.dump: %.elf
	$(RISCV_OBJDUMP) $< > $@

%.out: %
	$(RISCV_SIM) --isa=rv64gc $< 2> $@

%.out32: %
	$(RISCV_SIM) --isa=rv32gc $< 2> $@

define compile_template

$(1)_p_tests_elf = $$(addsuffix .elf, $$($(1)_p_tests))

$$($(1)_p_tests_elf): $(1)-p-%.elf: $(1)/%.S
	$$(RISCV_GCC) $(2) $$(RISCV_GCC_OPTS) -I$(src_dir)/../env/p -I$(src_dir)/macros/scalar -T$(src_dir)/../env/p/link.ld $$< -o $$@
$(1)_tests += $$($(1)_p_tests)

# $(1)_tests_dump = $$(addsuffix .dump, $$($(1)_tests))
#
# $(1): $$($(1)_tests_dump)
#
# .PHONY: $(1)

tests += $$($(1)_tests)
tests_elf += $$($(1)_p_tests_elf)

endef

$(eval $(call compile_template,rv32ui,-march=rv32i -mabi=ilp32))
$(eval $(call compile_template,rv32uc,-march=rv32i -mabi=ilp32))
$(eval $(call compile_template,rv32um,-march=rv32im -mabi=ilp32))
$(eval $(call compile_template,rv32ua,-march=rv32ia -mabi=ilp32))
$(eval $(call compile_template,rv32mi,-march=rv32i -mabi=ilp32))

tests_dump = $(addsuffix .dump, $(tests))
tests_hex = $(addsuffix .hex, $(tests))
tests_out = $(addsuffix .out, $(spike_tests))
tests32_out = $(addsuffix .out32, $(spike32_tests))

run: $(tests_out) $(tests32_out)

junk += $(tests) $(tests_dump) $(tests_hex) $(tests_out) $(tests32_out) $(tests_elf)

#------------------------------------------------------------
# Default

all: $(tests_dump)

#------------------------------------------------------------
# Clean up

clean:
	@rm -rf $(junk)
