# ------------------------------------------------------------------------------
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>
# ------------------------------------------------------------------------------
include tests/verilator/pprint.mk
SHELL=/bin/bash

# ------------------------------------------------------------------------------
.SUBMAKE        = $(MAKE) --no-print-directory
ROOT            = $(shell pwd)
.BFOLDER        = build
.RVCOMPLIANCE   = $(ROOT)/tests/riscv-compliance
.RVXTRASF       = $(ROOT)/tests/extra-tests

.VCOREF = tests/verilator/core
.VSOCF  = tests/verilator/soc
.ARGS   = --timeout 50000000 --file

.COREXE = $(.BFOLDER)/algol.exe
.SOCEXE = $(.BFOLDER)/algolsoc.exe

.COREDHRY = $(ROOT)/$(.BFOLDER)/dhrystone/dhrystone-core.elf
.SOCDHRY  = $(ROOT)/$(.BFOLDER)/dhrystone/dhrystone-soc.elf

# use custom compiler for compliance and dhrystone...
export RISCV_PREFIX ?= riscv-none-embed-
export ROOT

# zephyr
export ZEPHYR                   = $(ROOT)/software/zephyr
export ZEPHYR_TOOLCHAIN_VARIANT = zephyr
export ZEPHYR_SDK_INSTALL_DIR   = /opt/zephyr-sdk

# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------
help:
	@echo -e "--------------------------------------------------------------------------------"
	@echo -e "Please, choose one target:"
	@echo -e "- install-compliance:             Clone the riscv-compliance test."
	@echo -e "- install-zephyt:                 Clone the zephyr repo and chechout the v1.13 branch."
	@echo -e "- core-sim-compliance-rv32i:      Execute the RV32I compliance tests."
	@echo -e "- core-sim-dhrystone:             Execute the Dhrystone benchmark"
	@echo -e "- soc-sim-compliance-rv32i:       Execute the RV32I compliance tests."
	@echo -e "- soc-sim-dhrystone:              Execute the Dhrystone benchmark"
	@echo -e "- soc-sim-zephyr-hello_world:     Execute the hello world example"
	@echo -e "- soc-sim-zephyr-philosophers:    Execute the philosophers example"
	@echo -e "- soc-sim-zephyr-synchronization: Execute the synchronization example"
	@echo -e "--------------------------------------------------------------------------------"

# ------------------------------------------------------------------------------
# Install repo
# ------------------------------------------------------------------------------
install-compliance:
	@./scripts/install_compliance

install-zephyr:
	@./scripts/install_zephyr

# ------------------------------------------------------------------------------
# verilator tests
# ------------------------------------------------------------------------------
core-sim-compliance-rv32i: .core
	@$(.SUBMAKE) -C $(.RVCOMPLIANCE) clean
	@$(.SUBMAKE) -C $(.RVCOMPLIANCE) variant RISCV_TARGET=algol RISCV_DEVICE=rv32i RISCV_ISA=rv32i

soc-sim-compliance-rv32i: .soc .bootloader
	@$(.SUBMAKE) -C $(.RVCOMPLIANCE) clean
	@$(.SUBMAKE) -C $(.RVCOMPLIANCE) variant RISCV_TARGET=algolsoc RISCV_DEVICE=rv32i RISCV_ISA=rv32i

core-sim-dhrystone: .core .dhrystone-core
	@./$(.COREXE) $(.ARGS) $(.COREDHRY)

soc-sim-dhrystone: .soc .bootloader .dhrystone-soc
	@./$(.SOCEXE) --use-uart $(.ARGS) $(.SOCDHRY)

soc-sim-zephyr-hello_world: .soc .bootloader .zephyr-hello_world
	./$(.SOCEXE) --file $(.BFOLDER)/zephyr-hello_world/zephyr/zephyr.elf --use-uart

soc-sim-zephyr-philosophers: .soc .bootloader .zephyr-philosophers
	./$(.SOCEXE) --file $(.BFOLDER)/zephyr-philosophers/zephyr/zephyr.elf --use-uart

soc-sim-zephyr-synchronization: .soc .bootloader .zephyr-synchronization
	./$(.SOCEXE) --file $(.BFOLDER)/zephyr-synchronization/zephyr/zephyr.elf --use-uart

# extras
.bootloader:
	+@$(.SUBMAKE) -C software/bootloader all

.dhrystone-core:
	+@$(.SUBMAKE) -C software/dhrystone/core all

.dhrystone-soc:
	+@$(.SUBMAKE) -C software/dhrystone/soc all

.core:
	+@$(.SUBMAKE) -C $(.VCOREF)

.soc:
	+@$(.SUBMAKE) -C $(.VSOCF)

.zephyr-%:
	@./scripts/compile_zephyr_example $*

# ------------------------------------------------------------------------------
# Formal verification
# ------------------------------------------------------------------------------
formal: hardware/algol.v
	@mkdir -p $(.BFOLDER)
	@sby -d $(.BFOLDER)/fv_algol -f scripts/formal/algol_prove.sby

# ------------------------------------------------------------------------------
# clean
# ------------------------------------------------------------------------------
clean:
	@rm -rf vcd
	@$(.SUBMAKE) -C $(.VCOREF) clean
	@$(.SUBMAKE) -C $(.VSOCF) clean

distclean: clean
	@find . | grep -E "(__pycache__|\.pyc|\.pyo|\.cache)" | xargs rm -rf
	@$(.SUBMAKE) -C $(.RVCOMPLIANCE) clean
	@rm -rf $(.BFOLDER)

.PHONY: verilate build-model clean distclean
