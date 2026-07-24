# Makefile

# Tool
NASM       = nasm
QEMU       = qemu-system-x86_64

# Option
NFLAGS     = -f bin
QEMU_FLAGS = -monitor stdio

# Default
all:
	$(NASM) $(NFLAGS) boot.asm -o Bin/boot.bin

# Running
run:
	$(QEMU) $(QEMU_FLAGS) -fda Bin/boot.bin

# CleanUp
clean:
	rm -f Bin/boot.bin

# FakeTarget
.PHONY: all run clean
