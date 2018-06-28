# ------------------------------------------------------------------------------
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>
# ------------------------------------------------------------------------------
include tests/verilator/pprint.mk

# verilate
#--------------------------------------------------
.RTLDIR		:= hardware
.TBDIR		:= tests/verilator
VSOURCES	:= $(shell find . -name "*.v")
VTOP		:= $(.TBDIR)/top.v
#--------------------------------------------------
.VOBJ 		:= $(BUILD_DIR)/obj_dir
.SUBMAKE 	:= $(MAKE) --no-print-directory --directory=$(.VOBJ) -f
.VERILATE 	:= verilator -O3 --trace -Wall -Wno-fatal --x-assign 1 -cc -y $(.RTLDIR) -y $(.TBDIR) -CFLAGS "-std=c++11 -O3 -DDPI_DLLISPEC= -DDPI_DLLESPEC=" -Mdir $(.VOBJ)

#--------------------------------------------------
# C++ build
CXX			:= g++
CFLAGS		:= -std=c++17 -Wall -O3 -DDPI_DLLISPEC= -DDPI_DLLESPEC= -MD -MP # -g # -DDEBUG # -Wno-sign-compare
CFLAGS_NEW	:= -faligned-new -Wno-attributes
VROOT		:= $(shell bash -c 'verilator -V|grep VERILATOR_ROOT | head -1 | sed -e " s/^.*=\s*//"')
VINCD		:= $(VROOT)/include
VINC		:= -I$(VINCD) -I$(VINCD)/vltstd -I$(.VOBJ)

#--------------------------------------------------
ifeq ($(OS),Windows_NT)
	INCS := $(VINC) -Itests/verilator -I /mingw$(shell getconf LONG_BIT)/include/libelf
else
	INCS := $(VINC) -Itests/verilator
endif

#--------------------------------------------------
GCC7 = $(shell expr `gcc -dumpversion | cut -f1 -d.` = 7)
ifeq ($(GCC7), 1)
	CFLAGS += $(CFLAGS_NEW)
endif

#--------------------------------------------------
VOBJS	 := $(.VOBJ)/verilated.o $(.VOBJ)/verilated_vcd_c.o $(.VOBJ)/verilated_dpi.o
SOURCES  := testbench.cpp aelf.cpp
OBJS	 := $(addprefix $(.VOBJ)/, $(subst .cpp,.o,$(SOURCES)))
DEPFILES := $(addprefix $(.VOBJ)/, $(subst .cpp,.d,$(SOURCES)))

# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------
build-vlib: $(.VOBJ)/Vtop__ALL.a
build-core: $(BUILD_DIR)/$(EXE).exe

.SECONDARY: $(OBJS)

# Verilator
$(.VOBJ)/Vtop__ALL.a: $(VSOURCES)
	@printf "%b" "$(.COM_COLOR)$(.VER_STRING)$(.OBJ_COLOR) $(VTOP) $(.NO_COLOR)\n"
	+@$(.VERILATE) $(VTOP)
	@printf "%b" "$(.COM_COLOR)$(.COM_STRING)$(.OBJ_COLOR) $(@F)$(.NO_COLOR)\n"
	+@$(.SUBMAKE) Vtop.mk

# C++
$(.VOBJ)/%.o: tests/verilator/%.cpp
	@printf "%b" "$(.COM_COLOR)$(.COM_STRING)$(.OBJ_COLOR) $(@F) $(.NO_COLOR)\n"
	@$(CXX) $(CFLAGS) -DEXE="\"$(EXE)\"" $(INCS) -c $< -o $@

$(VOBJS): $(.VOBJ)/%.o: $(VINCD)/%.cpp
	@printf "%b" "$(.COM_COLOR)$(.COM_STRING)$(.OBJ_COLOR) $(@F) $(.NO_COLOR)\n"
	@$(CXX) $(CFLAGS) $(INCS) -Wno-format -c $< -o $@

$(BUILD_DIR)/$(EXE).exe: $(VOBJS) $(OBJS) $(.VOBJ)/Vtop__ALL.a
	@printf "%b" "$(.COM_COLOR)$(.COM_STRING)$(.OBJ_COLOR) $(@F)$(.NO_COLOR)\n"
	@$(CXX) $(INCS) $^ -lelf -o $@
	@printf "%b" "$(.MSJ_COLOR)Compilation $(.OK_COLOR)$(.OK_STRING)$(.NO_COLOR)\n"

-include $(DEPFILES)

.PHONY: build-vlib build-core
