# Makefile

# Tool
NASM       = nasm
QEMU       = qemu-system-x86_64

# BuildOption
NFLAGS     = -f bin
QEMU_FLAGS = -monitor stdio

# OutputFile
BOOT       = boot.bin
IMG        = disk.img

# Default
all: $(BOOT)
	cat $(BOOT) > disk.img

# Assemble assembly to bin
%.bin: %.asm
	$(NASM) $(NFLAGS) $< -o $@

# Run
run:
	$(QEMU) $(QEMU_FLAGS) -fda $(IMG) -rtc base=localtime

# CleanUp
clean:
	rm -f $(IMG) $(BOOT)

# FakeTarget
.PHONY: all run clean
