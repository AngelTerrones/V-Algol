# ------------------------------------------------------------------------------
# Copyright (c) 2017 Angel Terrones <angelterrones@gmail.com>
# Project: V-Algol
# ------------------------------------------------------------------------------
include tests/verilator/pprint.mk
SHELL=bash

.SUBMAKE := $(MAKE) --no-print-directory
.PWD:=$(shell pwd)
.BFOLDER:=build
.RVTESTSF:=tests/riscv-tests
.RVBENCHMARKSF:=tests/benchmarks
.RTLMK_ALGOL:=tests/verilator/algol/build_rtl.mk
.VCOREMK_ALGOL:=tests/verilator/algol/build_verilated.mk
.RTLMK_PERSEUS:=tests/verilator/perseus/build_rtl.mk
.VCOREMK_PERSEUS:=tests/verilator/perseus/build_verilated.mk
.VALGOLCMD:=$(.BFOLDER)/algol.exe --frequency 10e6 --timeout 1000000000 --file
.PERSEUSCMD:=$(.BFOLDER)/Perseus.exe --frequency 10e6 --timeout 1000000000 --file
.PFILES=$(shell find Perseus -name "*.py")
.PYTHON=python3

define print_ok
	printf "%-50s %b" $(1) "$(OK_COLOR)$(OK_STRING)$(NO_COLOR)\n"
endef

define print_error
	printf "%-50s %b" $(1) "$(ERROR_COLOR)$(ERROR_STRING)$(NO_COLOR)\n"
endef

define run_bin_file
	$(1) $(2) > /dev/null && $(call print_ok, $(2)) || $(call print_error, $(2))
endef
# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------
help:
	@echo -e "--------------------------------------------------------------------------------"
	@echo -e "Please, choose one target:"
	@echo -e "- compile-tests:          Compile RISC-V assembler tests"
	@echo -e "- compile-benchmarks:     Compile RISC-V benchmarks"
	@echo -e "- verilate-algol:         Generate C++ core model (ALGOL)"
	@echo -e "- verilate-perseus:       Generate C++ core model (PERSEUS)"
	@echo -e "- build-algol:            Build C++ core model (ALGOL)"
	@echo -e "- build-perseus:          Build C++ core model (PERSEUS)"
	@echo -e "- run-algol-tests:        Execute assembler tests using the C++ testbench (ALGOL)"
	@echo -e "- run-perseus-tests:      Execute assembler tests using the C++ testbench (PERSEUS)"
	@echo -e "- run-algol-benchmarks:   Execute benchmarks using the C++ testbench (ALGOL)"
	@echo -e "- run-perseus-benchmarks: Execute benchmarks using the C++ testbench (PERSEUS)"
	@echo -e "--------------------------------------------------------------------------------"

compile-tests:
	+@$(.SUBMAKE) -C $(.RVTESTSF)

compile-benchmarks:
	+@$(.SUBMAKE) -C $(.RVBENCHMARKSF)

# ------------------------------------------------------------------------------
# verilate
verilate-algol:
	@printf "%b" "$(MSJ_COLOR)Building RTL (Modules) for Verilator$(NO_COLOR)\n"
	@mkdir -p $(.BFOLDER)
	+@$(.SUBMAKE) -f $(.RTLMK_ALGOL) core BUILD_DIR=$(.BFOLDER)

build-algol: verilate-algol
	+@$(.SUBMAKE) -f $(.VCOREMK_ALGOL) core BUILD_DIR=$(.BFOLDER)

# ----------------------------
$(.BFOLDER)/Perseus.v: algol.v $(.PFILES)
	@printf "%b" "$(MSJ_COLOR)myHDL to verilog$(NO_COLOR)\n"
	@mkdir -p $(.BFOLDER)
	@PYTHONPATH=$(PWD) $(.PYTHON) Perseus/perseus.py -c tests/settings/perseus_RV32I.ini -p $(.BFOLDER) -n Perseus

verilate-perseus: $(.BFOLDER)/Perseus.v
	@printf "%b" "$(MSJ_COLOR)Building RTL (Modules) for Verilator$(NO_COLOR)\n"
	+@$(.SUBMAKE) -f $(.RTLMK_PERSEUS) core BUILD_DIR=$(.BFOLDER)

build-perseus: verilate-perseus
	+@$(.SUBMAKE) -f $(.VCOREMK_PERSEUS) core BUILD_DIR=$(.BFOLDER)

# ------------------------------------------------------------------------------
# verilator tests
run-algol-tests: compile-tests build-algol
	@$(eval .RVTESTS:=$(shell find $(.RVTESTSF) -name "rv32ui*.bin" -o -name "rv32mi*.bin" ! -name "*breakpoint*.bin"))
	@$(foreach file, $(.RVTESTS), $(call run_bin_file,$(.VALGOLCMD),$(file)))

run-algol-benchmarks: compile-benchmarks build-algol
	@$(eval .RVBENCHMARKS:=$(shell find $(.RVBENCHMARKSF) -name "*.bin"))
	@$(foreach file, $(.RVBENCHMARKS), $(call run_bin_file,$(.VALGOLCMD),$(file)))

# ----------------------------
run-perseus-tests: compile-tests build-perseus
	@$(eval .RVTESTS:=$(shell find $(.RVTESTSF) -name "rv32ui*.bin" -o -name "rv32mi*.bin" ! -name "*breakpoint*.bin"))
	@$(foreach file, $(.RVTESTS), $(call run_bin_file,$(.PERSEUSCMD),$(file)))

run-perseus-benchmarks: compile-benchmarks build-perseus
	@$(eval .RVBENCHMARKS:=$(shell find $(.RVBENCHMARKSF) -name "*.bin"))
	@$(foreach file, $(.RVBENCHMARKS), $(call run_bin_file,$(.PERSEUSCMD),$(file)))

# ------------------------------------------------------------------------------
# clean
# ------------------------------------------------------------------------------
clean:
	@rm -rf $(.BFOLDER)

distclean: clean
	@find . | grep -E "(__pycache__|\.pyc|\.pyo|\.cache)" | xargs rm -rf
	@$(.SUBMAKE) -C $(.RVTESTSF) clean
	@$(.SUBMAKE) -C $(.RVBENCHMARKSF) clean

.PHONY: compile-tests compile-benchmarks run-tests run-benchmarks clean distclean
