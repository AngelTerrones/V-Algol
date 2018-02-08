# ------------------------------------------------------------------------------
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>
# Project: V-Algol
# ------------------------------------------------------------------------------
include tests/verilator/pprint.mk

CXX := g++
CFLAGS := -std=c++11 -Wall -O3 #-DDEBUG -g
RTL_OBJ := $(BUILD_DIR)/algol_obj
VERILATOR_ROOT ?= $(shell bash -c 'verilator -V|grep VERILATOR_ROOT | head -1 | sed -e " s/^.*=\s*//"')
VROOT := $(VERILATOR_ROOT)
VINCD := $(VROOT)/include
VINC := -I$(VINCD) -I$(VINCD)/vltstd -I$(RTL_OBJ)
INCS := $(VINC) -Itests/verilator
VOBJS := $(RTL_OBJ)/verilated.o $(RTL_OBJ)/verilated_vcd_c.o

SOURCES := algol_tb.cpp memory.cpp
HEADERS := memory.h testbench.h

OBJS := $(addprefix $(RTL_OBJ)/, $(subst .cpp,.o,$(SOURCES)))
# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------
core: $(BUILD_DIR)/algol.exe

.SECONDARY: $(OBJS)

$(RTL_OBJ)/%.o: tests/verilator/%.cpp
	@printf "%b" "$(COM_COLOR)$(COM_STRING)$(OBJ_COLOR) $(@F) $(NO_COLOR)\n"
	@$(CXX) $(CFLAGS) $(INCS) -c $< -o $@

$(RTL_OBJ)/%.o: tests/verilator/algol/%.cpp
	@printf "%b" "$(COM_COLOR)$(COM_STRING)$(OBJ_COLOR) $(@F) $(NO_COLOR)\n"
	@$(CXX) $(CFLAGS) $(INCS) -c $< -o $@

$(VOBJS): $(RTL_OBJ)/%.o: $(VINCD)/%.cpp
	@printf "%b" "$(COM_COLOR)$(COM_STRING)$(OBJ_COLOR) $(@F) $(NO_COLOR)\n"
	@$(CXX) $(CFLAGS) $(INCS) -c $< -o $@

$(BUILD_DIR)/%.exe: $(VOBJS) $(OBJS) $(RTL_OBJ)/V%__ALL.a
	@printf "%b" "$(COM_COLOR)$(COM_STRING)$(OBJ_COLOR) $(@F)$(NO_COLOR)\n"
	@$(CXX) $(INCS) $^ -o $@
	@printf "%b" "$(MSJ_COLOR)Compilation $(OK_COLOR)$(OK_STRING)$(NO_COLOR)\n"

.PHONY: default clean distclean all core
