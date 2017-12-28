# ------------------------------------------------------------------------------
# Copyright (c) 2017 Angel Terrones <angelterrones@gmail.com>
# Project: V-Algol
# ------------------------------------------------------------------------------
SHELL=bash

.PWD=$(shell pwd)
.BFOLDER=build
.PYTHON=python3
.PYTEST=pytest
.PYTHONTB=tests/python/test_core.py
.RVTESTS=tests/riscv-tests
.RVBENCHMARKS=tests/benchmarks

# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------
compile-tests:
	$(MAKE) -C $(.RVTESTS)

compile-benchmarks:
	$(MAKE) -C $(.RVBENCHMARKS)

run-riscv-tests: compile-tests
	$(.PYTEST) -v --tb=short tests/python/

run-riscv-benchmarks: compile-benchmarks
	$(.PYTEST) -v --tb=short --slow tests/python/

# ------------------------------------------------------------------------------
# clean
# ------------------------------------------------------------------------------
clean:
	rm -rf $(.BFOLDER)

distclean: clean
	find . | grep -E "(__pycache__|\.pyc|\.pyo|\.cache)" | xargs rm -rf
	$(MAKE) -C $(.RVTESTS) clean
	$(MAKE) -C $(.RVBENCHMARKS) clean

.PHONY: compile-tests run-riscv-tests-all clean distclean
