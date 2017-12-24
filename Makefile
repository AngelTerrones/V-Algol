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

# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------
compile-tests:
	$(MAKE) -C $(.RVTESTS)

run-riscv-tests-all: compile-tests
	$(.PYTEST) -v --tb=short

# ------------------------------------------------------------------------------
# clean
# ------------------------------------------------------------------------------
clean:
	rm -rf $(.BFOLDER)

distclean: clean
	find . | grep -E "(__pycache__|\.pyc|\.pyo|\.cache)" | xargs rm -rf

.PHONY: compile-tests run-riscv-tests-all clean distclean
