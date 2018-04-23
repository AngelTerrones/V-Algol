# ------------------------------------------------------------------------------
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>
# Project: V-Algol
# ------------------------------------------------------------------------------
include tests/verilator/pprint.mk

# verilate
.VOBJ := $(BUILD_DIR)/Algol_obj
.SUBMAKE := $(MAKE) --no-print-directory --directory=$(.VOBJ) -f
.VERILATE := verilator --trace -Wall -Wno-fatal -cc -CFLAGS "-std=c++11 -O3" -Mdir $(.VOBJ)

# C++ build
CXX := g++
CFLAGS := -std=c++17 -Wall -O3 #-Wno-sign-compare # -DDEBUG -g
CFLAGS_NEW := -faligned-new
VERILATOR_ROOT ?= $(shell bash -c 'verilator -V|grep VERILATOR_ROOT | head -1 | sed -e " s/^.*=\s*//"')
VROOT := $(VERILATOR_ROOT)
VINCD := $(VROOT)/include
VINC := -I$(VINCD) -I$(VINCD)/vltstd -I$(.VOBJ)

ifeq ($(OS),Windows_NT)
	INCS := $(VINC) -Itests/verilator -I /mingw$(shell getconf LONG_BIT)/include/libelf
else
	INCS := $(VINC) -Itests/verilator
endif

GCC7 = $(shell expr `gcc -dumpversion | cut -f1 -d.` = 7 )

ifeq ($(GCC7), 1)
	CFLAGS += $(CFLAGS_NEW)
endif

VOBJS := $(.VOBJ)/verilated.o $(.VOBJ)/verilated_vcd_c.o
SOURCES := algol_tb.cpp wbmemory.cpp aelf.cpp
OBJS := $(addprefix $(.VOBJ)/, $(subst .cpp,.o,$(SOURCES)))

# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------
build-vlib: $(.VOBJ)/VAlgol__ALL.a
build-core: $(BUILD_DIR)/Algol.exe

.SECONDARY: $(OBJS)

# Verilator
$(.VOBJ)/VAlgol__ALL.a: $(BUILD_DIR)/Algol.v
	@printf "%b" "$(.COM_COLOR)$(.VER_STRING)$(.OBJ_COLOR) $<$(.NO_COLOR)\n"
	+@$(.VERILATE) $<
	@printf "%b" "$(.COM_COLOR)$(.COM_STRING)$(.OBJ_COLOR) $(@F)$(.NO_COLOR)\n"
	+@$(.SUBMAKE) VAlgol.mk

# C++
$(.VOBJ)/%.o: tests/verilator/%.cpp
	@printf "%b" "$(.COM_COLOR)$(.COM_STRING)$(.OBJ_COLOR) $(@F) $(.NO_COLOR)\n"
	@$(CXX) $(CFLAGS) $(INCS) -c $< -o $@

$(VOBJS): $(.VOBJ)/%.o: $(VINCD)/%.cpp
	@printf "%b" "$(.COM_COLOR)$(.COM_STRING)$(.OBJ_COLOR) $(@F) $(.NO_COLOR)\n"
	@$(CXX) $(CFLAGS) $(INCS) -Wno-format -c $< -o $@

$(BUILD_DIR)/Algol.exe: $(VOBJS) $(OBJS) $(.VOBJ)/VAlgol__ALL.a
	@printf "%b" "$(.COM_COLOR)$(.COM_STRING)$(.OBJ_COLOR) $(@F)$(.NO_COLOR)\n"
	@$(CXX) $(INCS) $^ -lelf -o $@
	@printf "%b" "$(.MSJ_COLOR)Compilation $(.OK_COLOR)$(.OK_STRING)$(.NO_COLOR)\n"

.PHONY: build-vlib build-core
