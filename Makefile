# ------------------------------------------------------------------------------
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>
# ------------------------------------------------------------------------------
include tests/verilator/pprint.mk
SHELL=bash

# ------------------------------------------------------------------------------
.PROJECTNAME = Algol
# ------------------------------------------------------------------------------
.SUBMAKE		= $(MAKE) --no-print-directory
.PWD			= $(shell pwd)
.BFOLDER		= build
.RVTESTSF		= tests/riscv-tests
.RVBENCHMARKSF	= tests/benchmarks
.RVXTRATESTSF	= tests/extra-tests
.MKTB			= tests/verilator/build.mk
.TBEXE			= $(.BFOLDER)/$(.PROJECTNAME).exe --frequency 10e6 --timeout 1000000000 --file

# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------
help:
	@echo -e "--------------------------------------------------------------------------------"
	@echo -e "Please, choose one target:"
	@echo -e "- compile-tests: Compile RISC-V assembler tests, benchmarks and extra tests."
	@echo -e "- verilate:      Generate C++ core model."
	@echo -e "- build-model:   Build C++ core model."
	@echo -e "- run-tests:     Execute assembler tests, benchmarks and extra tests."
	@echo -e "--------------------------------------------------------------------------------"

compile-tests:
	+@$(.SUBMAKE) -C $(.RVTESTSF)
	+@$(.SUBMAKE) -C $(.RVBENCHMARKSF)
	+@$(.SUBMAKE) -C $(.RVXTRATESTSF)

# ------------------------------------------------------------------------------
# verilate and build
verilate:
	@printf "%b" "$(.MSJ_COLOR)Building RTL (Modules) for Verilator$(.NO_COLOR)\n"
	@mkdir -p $(.BFOLDER)
	+@$(.SUBMAKE) -f $(.MKTB) build-vlib BUILD_DIR=$(.BFOLDER)

build-model: verilate
	+@$(.SUBMAKE) -f $(.MKTB) build-core BUILD_DIR=$(.BFOLDER)

# ------------------------------------------------------------------------------
# verilator tests
run-tests: compile-tests build-model
	$(eval .RVTESTS:=$(shell find $(.RVTESTSF) -name "rv32ui*.elf" -o -name "rv32mi*.elf" ! -name "*breakpoint*.elf"))
	$(eval .RVBENCHMARKS:=$(shell find $(.RVBENCHMARKSF) -name "*.riscv"))
	@$(eval .RVXTRATESTS:=$(shell find $(.RVXTRATESTSF) -name "*.riscv"))
	@for file in $(.RVTESTS) $(.RVBENCHMARKS) $(.RVXTRATESTS); do \
		$(.TBEXE) $$file > /dev/null; \
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
	@$(.SUBMAKE) -C $(.RVXTRATESTSF) clean

.PHONY: compile-tests compile-benchmarks run-tests clean distclean
