# ------------------------------------------------------------------------------
# Copyright (c) 2019 Angel Terrones <angelterrones@gmail.com>
# ------------------------------------------------------------------------------
SHELL=/bin/bash

# ------------------------------------------------------------------------------
SUBMAKE        = $(MAKE) --no-print-directory
ROOT            = $(shell pwd)
BFOLDER        = $(ROOT)/build
VCOREDIR		= $(ROOT)/simulator/verilator

VCOREF = $(VCOREDIR)/core
VSOCF  = $(VCOREDIR)/soc
ARGS   = --timeout 50000000 --file

COREXE = $(BFOLDER)/core.exe
SOCEXE = $(BFOLDER)/soc.exe

COREDHRY = $(BFOLDER)/dhrystone/dhrystone-core.elf
SOCDHRY  = $(BFOLDER)/dhrystone/dhrystone-soc.elf

# compliance tests and external interrupts test
RVCOMPLIANCE = $(ROOT)/tests/riscv-compliance
RVXTRASF     = $(ROOT)/tests/extra-tests

# Export variables
export ROOT
export RISCV_PREFIX ?= $(RVGCC_PATH)/riscv64-unknown-elf-

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
	@echo -e "- install-zephyr:                 Clone the zephyr repo and chechout the v1.13 branch."
	@echo -e "- build-core:                     Build C++ core model."
	@echo -e "- build-soc:                      Build C++ SoC model."
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
core-sim-compliance-rv32i: export TARGET_FOLDER=$(VCOREF)
core-sim-compliance-rv32i: build-core
	@$(SUBMAKE) -C $(RVCOMPLIANCE) clean
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algol RISCV_DEVICE=rv32i RISCV_ISA=rv32i

soc-sim-compliance-rv32i: export TARGET_FOLDER=$(VSOCF)
soc-sim-compliance-rv32i: build-soc .bootloader
	@$(SUBMAKE) -C $(RVCOMPLIANCE) clean
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algolsoc RISCV_DEVICE=rv32i RISCV_ISA=rv32i

core-sim-dhrystone: build-core .dhrystone-core
	@$(COREXE) $(ARGS) $(COREDHRY)

soc-sim-dhrystone: build-soc .bootloader .dhrystone-soc
	@$(SOCEXE) --use-uart $(ARGS) $(SOCDHRY)

soc-sim-zephyr-hello_world: build-soc .bootloader .zephyr-hello_world
	@$(SOCEXE) --file $(BFOLDER)/zephyr-hello_world/zephyr/zephyr.elf --use-uart

soc-sim-zephyr-philosophers: build-soc .bootloader .zephyr-philosophers
	@$(SOCEXE) --file $(BFOLDER)/zephyr-philosophers/zephyr/zephyr.elf --use-uart

soc-sim-zephyr-synchronization: build-soc .bootloader .zephyr-synchronization
	@$(SOCEXE) --file $(BFOLDER)/zephyr-synchronization/zephyr/zephyr.elf --use-uart
# ------------------------------------------------------------------------------
# verilate and build
# ------------------------------------------------------------------------------
build-core:
	@mkdir -p $(BFOLDER)
	+@$(SUBMAKE) -C $(VCOREF)

build-soc:
	@mkdir -p $(BFOLDER)
	+@$(SUBMAKE) -C $(VSOCF)

# ------------------------------------------------------------------------------
# External interrupts test
# ------------------------------------------------------------------------------
extra:
	+@$(SUBMAKE) -C tests/extra-tests

# ------------------------------------------------------------------------------
# extra targes (hidden)
# ------------------------------------------------------------------------------
.bootloader:
	+@$(SUBMAKE) -C software/bootloader all

.dhrystone-core:
	+@$(SUBMAKE) -C software/dhrystone/core all

.dhrystone-soc:
	+@$(SUBMAKE) -C software/dhrystone/soc all

.zephyr-%:
	@./scripts/compile_zephyr_example $*

# ------------------------------------------------------------------------------
# Formal verification
# ------------------------------------------------------------------------------
formal: hardware/algol.v
	@mkdir -p $(BFOLDER)
	@sby -d $(BFOLDER)/fv_algol -f scripts/formal/algol_prove.sby

# ------------------------------------------------------------------------------
# clean
# ------------------------------------------------------------------------------
clean:
	@rm -rf vcd
	@$(SUBMAKE) -C $(VCOREF) clean
	@$(SUBMAKE) -C $(VSOCF) clean

distclean: clean
	@$(SUBMAKE) -C $(RVCOMPLIANCE) clean
	@rm -rf $(BFOLDER)

.PHONY: verilate build-model clean distclean
