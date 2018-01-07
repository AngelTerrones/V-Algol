# ------------------------------------------------------------------------------
# Copyright (c) 2017 Angel Terrones <angelterrones@gmail.com>
# Project: V-Algol
# ------------------------------------------------------------------------------
include tests/verilator/pprint.mk
SHELL=bash

.SUBMAKE := $(MAKE) --no-print-directory
.PWD=$(shell pwd)
.BFOLDER=build
.PYTHON=python3
.PYTEST=pytest
.PYTHONTB=tests/python/test_core.py
.RVTESTS=tests/riscv-tests
.RVBENCHMARKS=tests/benchmarks
.RTLMK=tests/verilator/build_rtl.mk
.VCOREMK=tests/verilator/build_verilated.mk

# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------
help:
	@echo -e "--------------------------------------------------------------------------------"
	@echo -e "Please, choose one target:"
	@echo -e "- compile-tests:      Compile RISC-V assembler tests"
	@echo -e "- compile-benchmarks: Compile RISC-V benchmarks"
	@echo -e "- run-tests-p:        Execute assembler tests using the python testbench"
	@echo -e "- run-benchmarks-p:   Execute benchmarks using the python testbench"
	@echo -e "- run-tests-v:        Execute assembler tests using the C++ testbench"
	@echo -e "- run-benchmarks-v:   Execute benchmarks using the C++ testbench"
	@echo -e "--------------------------------------------------------------------------------"

compile-tests:
	+@$(.SUBMAKE) -C $(.RVTESTS)

compile-benchmarks:
	+@$(.SUBMAKE) -C $(.RVBENCHMARKS)

# verilate
rtl: verilate-core
verilate-core:
	@printf "%b" "$(MSJ_COLOR)Building RTL (Modules) for Verilator$(NO_COLOR)\n"
	@mkdir -p $(.BFOLDER)
	+@$(.SUBMAKE) -f $(.RTLMK) core .BUILD_DIR=$(.BFOLDER)

build-vcore: verilate-core
	+@$(.SUBMAKE) -f $(.VCOREMK) core .BUILD_DIR=$(.BFOLDER)

# myhdl tests
run-tests-p: compile-tests
	@$(.PYTEST) -v --tb=short tests/python/

run-benchmarks-p: compile-benchmarks
	@$(.PYTEST) -v --tb=short --slow tests/python/

# verilator tests
run-tests-v: compile-tests

run-benchmarks-v: compile-benchmarks

# ------------------------------------------------------------------------------
# clean
# ------------------------------------------------------------------------------
clean:
	@rm -rf $(.BFOLDER)

distclean: clean
	@find . | grep -E "(__pycache__|\.pyc|\.pyo|\.cache)" | xargs rm -rf
	@@$(.SUBMAKE) -C $(.RVTESTS) clean
	@$(.SUBMAKE) -C $(.RVBENCHMARKS) clean

.PHONY: compile-tests compile-benchmarks run-tests-p run-benchmarks-p run-tests-v run-benchmarks-v clean distclean
