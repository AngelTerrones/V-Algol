# ------------------------------------------------------------------------------
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>
# Project: V-Algol
# ------------------------------------------------------------------------------
include tests/verilator/pprint.mk

CXX := g++
CFLAGS := -pedantic -std=c++11 -Wall -O3 -DDEBUG -g

VTBDIR := tests/verilator
BDIR := $(.BUILD_DIR)/algol_obj
RTL_OBJ := $(.BUILD_DIR)/algol_obj

## Verilator data
VERILATOR_ROOT ?= $(shell bash -c 'verilator -V|grep VERILATOR_ROOT | head -1 | sed -e " s/^.*=\s*//"')
VROOT := $(VERILATOR_ROOT)
VINC := -I$(VROOT)/include -I$(VROOT)/include/vltstd
TBINC := -Itests/verilator
INC := -I$(RTL_OBJ) $(VINC) $(TBINC)
#VLSRCS	:= verilated.cpp verilated_vcd_c.cpp
VLOBJS := $(BDIR)/verilated.o $(BDIR)/verilated_vcd_c.o
#VLIB	:= $(addprefix $(VROOT)/include/,$(VLSRCS))
TBOBJS := $(BDIR)/memory.o
-include $(BDIR)/algol.d

# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------

core: $(BDIR)/algol.exe

$(TBOBJS): $(BDIR)/%.o: tests/verilator/%.cpp
	@printf "%b" "$(COM_COLOR)$(COM_STRING)$(OBJ_COLOR) $(@F) $(NO_COLOR)\n"
	$(CXX) $(CFLAGS) $(INC) -c $< -o $@

$(VLOBJS): $(BDIR)/%.o: $(VROOT)/include/%.cpp
	@printf "%b" "$(COM_COLOR)$(COM_STRING)$(OBJ_COLOR) $(@F) $(NO_COLOR)\n"
	$(CXX) $(CFLAGS) $(INCS) -c $< -o $@

$(BDIR)/%.exe: $(VTBDIR)/%_tb.cpp $(VLOBJS) $(RTL_OBJ)/V%__ALL.a $(TBOBJS)
	@printf "%b" "$(COM_COLOR)$(COM_STRING)$(OBJ_COLOR) $(@F)$(NO_COLOR)\n"
	$(CXX) $(CFLAGS) $(INC) $(VTBDIR)/$*_tb.cpp $(VLOBJS) $(TBOBJS) $(RTL_OBJ)/V$*__ALL.a -MMD -o $@

.PHONY: default clean distclean all core
