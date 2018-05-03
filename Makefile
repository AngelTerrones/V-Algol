# ------------------------------------------------------------------------------
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>
# Project: V-Algol
# ------------------------------------------------------------------------------
include tests/verilator/pprint.mk
SHELL=bash

.SUBMAKE := $(MAKE) --no-print-directory
.PWD:=$(shell pwd)
.BFOLDER:=build
.RVTESTSF:=tests/riscv-tests
.RVBENCHMARKSF:=tests/benchmarks
.MK_ALGOL:=tests/verilator/build.mk
.ALGOLCMD:=$(.BFOLDER)/Algol.exe --frequency 10e6 --timeout 1000000000 --file
.PFILES=$(shell find Algol -name "*.py")
.PYTHON=python3

# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------
help:
	@echo -e "--------------------------------------------------------------------------------"
	@echo -e "Please, choose one target:"
	@echo -e "- compile-tests:          Compile RISC-V assembler tests"
	@echo -e "- compile-benchmarks:     Compile RISC-V benchmarks"
	@echo -e "- verilate-algol:         Generate C++ core model (ALGOL)"
	@echo -e "- build-algol:            Build C++ core model (ALGOL)"
	@echo -e "- run-algol-tests:        Execute assembler tests using the C++ testbench (ALGOL)"
	@echo -e "- run-algol-benchmarks:   Execute benchmarks using the C++ testbench (ALGOL)"
	@echo -e "--------------------------------------------------------------------------------"

compile-tests:
	+@$(.SUBMAKE) -C $(.RVTESTSF)

compile-benchmarks:
	+@$(.SUBMAKE) -C $(.RVBENCHMARKSF)

# ------------------------------------------------------------------------------
# verilate
$(.BFOLDER)/Algol.v: Algol/core.v $(.PFILES)
	@printf "%b" "$(.MSJ_COLOR)myHDL to verilog$(.NO_COLOR)\n"
	@mkdir -p $(.BFOLDER)
	@PYTHONPATH=$(PWD) $(.PYTHON) Algol/algol.py -c tests/settings/algol_RV32I.ini -p $(.BFOLDER) -n Algol

verilate-algol: $(.BFOLDER)/Algol.v
	@printf "%b" "$(.MSJ_COLOR)Building RTL (Modules) for Verilator$(.NO_COLOR)\n"
	+@$(.SUBMAKE) -f $(.MK_ALGOL) build-vlib BUILD_DIR=$(.BFOLDER)

build-algol: verilate-algol
	+@$(.SUBMAKE) -f $(.MK_ALGOL) build-core BUILD_DIR=$(.BFOLDER)

# ------------------------------------------------------------------------------
# verilator tests
run-algol-tests: compile-tests build-algol
	@$(eval .RVTESTS:=$(shell find $(.RVTESTSF) -name "rv32ui*.elf" -o -name "rv32mi*.elf" ! -name "*breakpoint*.elf"))
	@for file in $(.RVTESTS); do \
		$(.ALGOLCMD) $$file > /dev/null; \
		if [ $$? -eq 0 ]; then \
			printf "%-50b %b\n" $$file "$(.OK_COLOR)$(.OK_STRING)$(.NO_COLOR)"; \
		else \
			printf "%-50s %b" $$file "$(.ERROR_COLOR)$(.ERROR_STRING)$(.NO_COLOR)\n"; \
		fi; \
	done

run-algol-benchmarks: compile-benchmarks build-algol
	@$(eval .RVBENCHMARKS:=$(shell find $(.RVBENCHMARKSF) -name "*.riscv"))
	@for file in $(.RVBENCHMARKS); do \
		$(.ALGOLCMD) $$file --benchmark > /dev/null; \
		if [ $$? -eq 0 ]; then \
			printf "%-50b %b\n" $$file "$(.OK_COLOR)$(.OK_STRING)$(.NO_COLOR)"; \
		else \
			printf "%-50s %b" $$file "$(.ERROR_COLOR)$(.ERROR_STRING)$(.NO_COLOR)\n"; \
		fi; \
	done

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
