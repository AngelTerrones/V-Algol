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
.RTLMK:=tests/verilator/build_rtl.mk
.VCOREMK:=tests/verilator/build_verilated.mk
.RVTESTS:=$(shell find $(.RVTESTSF) -name "rv32ui*.bin" -o -name "rv32mi*.bin" ! -name "*breakpoint*.bin")
.RVBENCHMARKS:=$(shell find $(.RVBENCHMARKSF) -name "*.bin")
.VALGOLCMDTST:=$(.BFOLDER)/algol.exe --frequency 10e6 --timeout 1000000 --file
.VALGOLCMDBMK:=$(.BFOLDER)/algol.exe --frequency 10e6 --timeout 1000000000 --file

define print_ok
	printf "%-50s %b" $(1) "$(OK_COLOR)$(OK_STRING)$(NO_COLOR)\n"
endef

define print_error
	printf "%-50s %b" $(1) "$(ERROR_COLOR)$(ERROR_STRING)$(NO_COLOR)\n"
endef
# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------
help:
	@echo -e "--------------------------------------------------------------------------------"
	@echo -e "Please, choose one target:"
	@echo -e "- compile-tests:      Compile RISC-V assembler tests"
	@echo -e "- compile-benchmarks: Compile RISC-V benchmarks"
	@echo -e "- verilate-core:      Generate C++ core model"
	@echo -e "- build-code:         Build C++ core model"
	@echo -e "- run-tests:          Execute assembler tests using the C++ testbench"
	@echo -e "- run-benchmarks:     Execute benchmarks using the C++ testbench"
	@echo -e "--------------------------------------------------------------------------------"

compile-tests:
	+@$(.SUBMAKE) -C $(.RVTESTSF)

compile-benchmarks:
	+@$(.SUBMAKE) -C $(.RVBENCHMARKSF)

# verilate
rtl: verilate-core
verilate-core:
	@printf "%b" "$(MSJ_COLOR)Building RTL (Modules) for Verilator$(NO_COLOR)\n"
	@mkdir -p $(.BFOLDER)
	+@$(.SUBMAKE) -f $(.RTLMK) core BUILD_DIR=$(.BFOLDER)

build-vcore: verilate-core
	+@$(.SUBMAKE) -f $(.VCOREMK) core BUILD_DIR=$(.BFOLDER)

# verilator tests
run-tests: compile-tests build-vcore
	@$(foreach f, $(.RVTESTS), $(.VALGOLCMDTST) $(f) > /dev/null && $(call print_ok,$(f)) || $(call print_error,$(f));)

run-benchmarks: compile-benchmarks build-vcore
	@$(foreach f, $(.RVBENCHMARKS), $(.VALGOLCMDBMK) $(f) > /dev/null && $(call print_ok,$(f)) || $(call print_error,$(f));)

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
