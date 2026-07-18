# Makefile

# Tool
NASM       = nasm
QEMU       = qemu-system-x86_64

# BuildOption
NFLAGS     = -f bin
QEMU_FLAGS = -monitor stdio

# OutputFile
BOOT       = boot.bin
KERNEL     = kernel.bin
IMG        = disk.img

# Default
all: $(IMG)

# Create Disk Image
$(KERNEL): clock.bin mswp.bin

# Assemble assembly to bin
%.bin: %.asm
	$(NASM) $(NFLAGS) $< -o Bin/$@

# Compile
compile: $(BOOT) $(KERNEL)
	cat Bin/$(BOOT) Bin/$(KERNEL) > Bin/disk.img

# Run
run:
	$(QEMU) $(QEMU_FLAGS) -fda Bin/$(IMG) -rtc base=localtime

# CleanUp
clean:
	rm -f Bin/$(IMG) Bin/$(BOOT) Bin/$(KERNEL) Bin/clock.bin Bin/mswp.bin

# FakeTarget
.PHONY: all run clean
