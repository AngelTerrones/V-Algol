RISCV_PREFIX  ?= riscv-none-embed-
RISCV_GCC     := $(RISCV_PREFIX)gcc
RISCV_OBJCOPY := $(RISCV_PREFIX)objcopy
RISCV_OBJDUMP := $(RISCV_PREFIX)objdump
ROOT          ?= $(shell cd ../..; pwd)
OUT           := $(ROOT)/build/bootloader
B2H           := $(ROOT)/software/bin2hex.py
BOOTSIZE      := 64

CFLAGS = -march=rv32i -mabi=ilp32 -O3 -Wl,--no-relax
LFLAGS = -nostdlib -nostartfiles -mcmodel=medany -T sections.ld

$(OUT)/%.elf: %.S
	@mkdir -p $(OUT)
	@$(RISCV_GCC) $(CFLAGS) $(LFLAGS) -o $@ $^
	@$(RISCV_OBJDUMP) --disassemble-all --disassemble-zeroes $@ > $(OUT)/$*.dump

$(OUT)/%.bin: $(OUT)/%.elf
	@$(RISCV_OBJCOPY) -O binary $^ $@

$(OUT)/%.hex: $(OUT)/%.bin
	@python3 $(B2H) $^ $(BOOTSIZE) > $(OUT)/$*.hex

all: $(OUT)/nouart.hex $(OUT)/bootloader.hex

clean:
	@rm -rf $(OUT)

.PRECIOUS: $(OUT)/%.elf $(OUT)/%.bin
