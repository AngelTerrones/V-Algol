# ------------------------------------------------------------------------------
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>
# Project: V-Algol
# ------------------------------------------------------------------------------
include tests/verilator/pprint.mk

.VOBJ := $(BUILD_DIR)/Algol_obj
.SUBMAKE := $(MAKE) --no-print-directory --directory=$(.VOBJ) -f
.VERILATE := verilator --trace -Wall -Wno-fatal -cc -CFLAGS "-std=c++11 -O3" -Mdir $(.VOBJ)

# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------
core: $(.VOBJ)/VAlgol__ALL.a

$(.VOBJ)/VAlgol__ALL.a: $(BUILD_DIR)/Algol.v
	@printf "%b" "$(COM_COLOR)$(VER_STRING)$(OBJ_COLOR) $<$(NO_COLOR)\n"
	+@$(.VERILATE) $<
	@printf "%b" "$(COM_COLOR)$(COM_STRING)$(OBJ_COLOR) $(@F)$(NO_COLOR)\n"
	+@$(.SUBMAKE) VAlgol.mk

.PHONY: default clean distclean core
