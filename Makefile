# ------------------------------------------------------------------------------
# Copyright (c) 2019 Angel Terrones <angelterrones@gmail.com>
# ------------------------------------------------------------------------------
SHELL=/bin/bash

Color_Off='\033[0m'
# Bold colors
BBlack='\033[1;30m'
BRed='\033[1;31m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'
BBlue='\033[1;34m'
BPurple='\033[1;35m'
BCyan='\033[1;36m'
BWhite='\033[1;37m'

# ------------------------------------------------------------------------------
SUBMAKE  = $(MAKE) --no-print-directory
ROOT     = $(shell pwd)
BFOLDER  = $(ROOT)/build
VCOREDIR = $(ROOT)/simulator/verilator

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
	@echo -e $(BYellow)"Please, choose one target:"$(Color_Off)
	@echo -e $(BRed)"Setup:"$(Color_Off)
	@echo -e "- install-compliance:               Clone the riscv-compliance test."
	@echo -e "- install-zephyr:                   Clone the zephyr repo and chechout the v1.13 branch."
	@echo -e "- setup-environment:                Create a python3 virtualenv, and installs zephyr's requirements."
	@echo -e $(BBlue)"Build:"$(Color_Off)
	@echo -e "- build-core:                       Build C++ core model."
	@echo -e "- build-soc:                        Build C++ SoC model."
	@echo -e $(BGreen)"Execute tests:"$(Color_Off)
	@echo -e "- core-sim-compliance:              Execute the rv32i, rv32ui, rv32mi, rv32im, rv32Zicsr and rv32Zifencei tests."
	@echo -e "- core-sim-compliance-rv32i:        Execute the RV32I compliance tests."
	@echo -e "- core-sim-compliance-rv32mi:       Execute machine mode compliance tests."
	@echo -e "- core-sim-compliance-rv32ui:       Execute the RV32I compliance tests (redundant)."
	@echo -e "- core-sim-compliance-rv32Zicsr:    Execute the RV32Zicsr compliance tests."
	@echo -e "- core-sim-compliance-rv32Zifencei: Execute the RV32Zifencei compliance test."
	@echo -e "- core-sim-compliance-rv32im:        Execute the RV32M compliance tests."
	@echo -e "- core-sim-dhrystone:               Execute the Dhrystone benchmark"
	@echo -e "- soc-sim-compliance:               Execute the rv32i, rv32ui, rv32mi, rv32im, rv32Zicsr and rv32Zifencei tests."
	@echo -e "- soc-sim-compliance-rv32i:         Execute the RV32I compliance tests."
	@echo -e "- soc-sim-compliance-rv32mi:        Execute machine mode compliance tests."
	@echo -e "- soc-sim-compliance-rv32ui:        Execute the RV32I compliance tests (redundant)."
	@echo -e "- soc-sim-compliance-rv32Zicsr:     Execute the RV32Zicsr compliance tests."
	@echo -e "- soc-sim-compliance-rv32Zifencei:  Execute the RV32Zifencei compliance test."
	@echo -e "- soc-sim-compliance-rv32im:        Execute the RV32M compliance tests."
	@echo -e "- soc-sim-dhrystone:                Execute the Dhrystone benchmark"
	@echo -e "- soc-sim-zephyr-hello_world:       Execute the hello world example"
	@echo -e "- soc-sim-zephyr-philosophers:      Execute the philosophers example"
	@echo -e "- soc-sim-zephyr-synchronization:   Execute the synchronization example"
	@echo -e "--------------------------------------------------------------------------------"

# ------------------------------------------------------------------------------
# Install repo
# ------------------------------------------------------------------------------
install-compliance:
	@./scripts/install_compliance

install-zephyr:
	@./scripts/install_zephyr

# ------------------------------------------------------------------------------
# setup environment
# ------------------------------------------------------------------------------
setup-environment:
	@./scripts/setup_environment.sh

# ------------------------------------------------------------------------------
# verilator tests
# ------------------------------------------------------------------------------
# Core
core-sim-compliance: export TARGET_FOLDER=$(VCOREF)
core-sim-compliance: core-sim-compliance-rv32i core-sim-compliance-rv32ui core-sim-compliance-rv32Zicsr core-sim-compliance-rv32Zifencei core-sim-compliance-rv32mi core-sim-compliance-rv32im

core-sim-compliance-rv32i: export TARGET_FOLDER=$(VCOREF)
core-sim-compliance-rv32i: build-core
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algol RISCV_DEVICE=rv32i RISCV_ISA=rv32i

core-sim-compliance-rv32mi: export TARGET_FOLDER=$(VCOREF)
core-sim-compliance-rv32mi: build-core
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algol RISCV_DEVICE=rv32i RISCV_ISA=rv32mi

core-sim-compliance-rv32ui: export TARGET_FOLDER=$(VCOREF)
core-sim-compliance-rv32ui: build-core
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algol RISCV_DEVICE=rv32i RISCV_ISA=rv32ui

core-sim-compliance-rv32Zicsr: export TARGET_FOLDER=$(VCOREF)
core-sim-compliance-rv32Zicsr: build-core
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algol RISCV_DEVICE=rv32i RISCV_ISA=rv32Zicsr

core-sim-compliance-rv32Zifencei: export TARGET_FOLDER=$(VCOREF)
core-sim-compliance-rv32Zifencei: build-core
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algol RISCV_DEVICE=rv32i RISCV_ISA=rv32Zifencei

core-sim-compliance-rv32im: export TARGET_FOLDER=$(VCOREF)
core-sim-compliance-rv32im: build-core
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algol RISCV_DEVICE=rv32im RISCV_ISA=rv32im

# ----------------------------------------------------------
# SOC
soc-sim-compliance: export TARGET_FOLDER=$(VCOREF)
soc-sim-compliance: soc-sim-compliance-rv32i soc-sim-compliance-rv32ui soc-sim-compliance-rv32Zicsr soc-sim-compliance-rv32Zifencei soc-sim-compliance-rv32mi soc-sim-compliance-rv32im

soc-sim-compliance-rv32i: export TARGET_FOLDER=$(VSOCF)
soc-sim-compliance-rv32i: build-soc .bootloader
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algolsoc RISCV_DEVICE=rv32i RISCV_ISA=rv32i

soc-sim-compliance-rv32mi: export TARGET_FOLDER=$(VSOCF)
soc-sim-compliance-rv32mi: build-soc .bootloader
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algolsoc RISCV_DEVICE=rv32i RISCV_ISA=rv32mi

soc-sim-compliance-rv32ui: export TARGET_FOLDER=$(VSOCF)
soc-sim-compliance-rv32ui: build-soc .bootloader
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algolsoc RISCV_DEVICE=rv32i RISCV_ISA=rv32ui

soc-sim-compliance-rv32Zicsr: export TARGET_FOLDER=$(VSOCF)
soc-sim-compliance-rv32Zicsr: build-soc .bootloader
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algolsoc RISCV_DEVICE=rv32i RISCV_ISA=rv32Zicsr

soc-sim-compliance-rv32Zifencei: export TARGET_FOLDER=$(VSOCF)
soc-sim-compliance-rv32Zifencei: build-soc .bootloader
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algolsoc RISCV_DEVICE=rv32i RISCV_ISA=rv32Zifencei

soc-sim-compliance-rv32im: export TARGET_FOLDER=$(VSOCF)
soc-sim-compliance-rv32im: build-soc .bootloader
	@$(SUBMAKE) -C $(RVCOMPLIANCE) variant RISCV_TARGET=algolsoc RISCV_DEVICE=rv32im RISCV_ISA=rv32im

# ----------------------------------------------------------
# Dhrystone
core-sim-dhrystone: build-core .dhrystone-core
	@$(COREXE) $(ARGS) $(COREDHRY)

soc-sim-dhrystone: build-soc .bootloader .dhrystone-soc
	@$(SOCEXE) --use-uart $(ARGS) $(SOCDHRY)

# ----------------------------------------------------------
# zephyr
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
