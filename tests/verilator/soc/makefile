# ------------------------------------------------------------------------------
# Copyright (c) 2018 Angel Terrones <angelterrones@gmail.com>
# ------------------------------------------------------------------------------
include ../pprint.mk

# verilate
#--------------------------------------------------
EXE       := algolsoc
ROOT      ?= $(shell cd ../../..; pwd)
SOCDIR		:= $(ROOT)/soc
HWDIR			:= $(ROOT)/hardware
VSOURCES	:= $(shell find $(SOCDIR) $(HWDIR) -name "*.v")
VTOP			:= $(SOCDIR)/algolsoc.v
BOOTLOADER:= -GBOOTLOADER="\"$(ROOT)/build/bootloader/nouart.hex"\"
#--------------------------------------------------
OUT				:= $(ROOT)/build
VOBJ			:= $(ROOT)/build/obj_dir_$(EXE)
SUBMAKE		:= $(MAKE) --no-print-directory --directory=$(VOBJ) -f
VERILATE	:= verilator -O3 --trace -Wall -Wno-fatal --x-assign unique -cc -y $(SOCDIR) -y $(HWDIR) \
						-CFLAGS "-std=c++11 -O3 -DDPI_DLLISPEC= -DDPI_DLLESPEC=" -Mdir $(VOBJ) $(BOOTLOADER)

#--------------------------------------------------
# C++ build
CXX					:= g++
CFLAGS			:= -std=c++17 -Wall -O3 -DDPI_DLLISPEC= -DDPI_DLLESPEC= -MD -MP # -g # -DDEBUG # -Wno-sign-compare
CFLAGS_NEW	:= -faligned-new -Wno-attributes
CFLAGS_V		:= -Wno-sign-compare
VROOT				:= $(shell bash -c 'verilator -V|grep VERILATOR_ROOT | head -1 | sed -e " s/^.*=\s*//"')
VINCD				:= $(VROOT)/include
VINC				:= -I$(VINCD) -I$(VINCD)/vltstd -I$(VOBJ)

#--------------------------------------------------
ifeq ($(OS),Windows_NT)
	INCS := $(VINC) -I /mingw$(shell getconf LONG_BIT)/include/libelf
else
	INCS := $(VINC)
endif

#--------------------------------------------------
GCC7 = $(shell expr `gcc -dumpversion | cut -f1 -d.` = 7)
ifeq ($(GCC7), 1)
	CFLAGS += $(CFLAGS_NEW)
endif

#--------------------------------------------------
VOBJS	 := $(VOBJ)/verilated.o $(VOBJ)/verilated_vcd_c.o $(VOBJ)/verilated_dpi.o
SOURCES  := main.cpp coretb.cpp aelf.cpp
OBJS	 := $(addprefix $(VOBJ)/, $(subst .cpp,.o,$(SOURCES)))
DEPFILES := $(addprefix $(VOBJ)/, $(subst .cpp,.d,$(SOURCES)))

# ------------------------------------------------------------------------------
# targets
# ------------------------------------------------------------------------------
all: build-core

build-core: $(VSOURCES) $(VOBJ)/V$(EXE)__ALL.a $(OUT)/$(EXE).exe

run: build-core
	$(OUT)/$(EXE).exe $(ARGS)

clean:
	@rm -rf $(VOBJ) $(OUT)/$(EXE).exe

# ------------------------------------------------------------------------------
# aux targets
# ------------------------------------------------------------------------------
.SECONDARY: $(OBJS)

# Verilator
$(VOBJ)/V$(EXE)__ALL.a: $(VSOURCES)
	@mkdir -p $(OUT)
	@printf "%b" "$(.COM_COLOR)$(.VER_STRING)$(.OBJ_COLOR) $(VTOP) $(.NO_COLOR)\n"
	+@$(VERILATE) $(VTOP)
	@printf "%b" "$(.COM_COLOR)$(.COM_STRING)$(.OBJ_COLOR) $(@F)$(.NO_COLOR)\n"
	+@$(SUBMAKE) V$(EXE).mk

# C++
$(VOBJ)/%.o: cpp/%.cpp
	@printf "%b" "$(.COM_COLOR)$(.COM_STRING)$(.OBJ_COLOR) $(@F) $(.NO_COLOR)\n"
	@$(CXX) $(CFLAGS) -DEXE="\"$(EXE)\"" $(INCS) -c $< -o $@

$(VOBJS): $(VOBJ)/%.o: $(VINCD)/%.cpp
	@printf "%b" "$(.COM_COLOR)$(.COM_STRING)$(.OBJ_COLOR) $(@F) $(.NO_COLOR)\n"
	@$(CXX) $(CFLAGS) $(CFLAGS_V) $(INCS) -c $< -o $@

$(OUT)/$(EXE).exe: $(VOBJS) $(OBJS) $(VOBJ)/V$(EXE)__ALL.a
	@printf "%b" "$(.COM_COLOR)$(.COM_STRING)$(.OBJ_COLOR) $(@F)$(.NO_COLOR)\n"
	@$(CXX) $(INCS) -lelf $^ -o $@
	@printf "%b" "$(.MSJ_COLOR)Compilation $(.OK_COLOR)$(.OK_STRING)$(.NO_COLOR)\n"


-include $(DEPFILES)
