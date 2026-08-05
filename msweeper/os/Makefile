# Makefile

# Tool
NASM       = nasm
QEMU       = qemu-system-x86_64

# BuildOption
NFLAGS     = -f bin
QEMU_FLAGS = -monitor stdio

# OutputFile
BOOT       = mswp.bin
IMG        = mswp.img

# Default
all: $(BOOT)
	cat ${BOOT} > ${IMG}

# Assemble assembly to bin
%.bin: %.asm
	$(NASM) $(NFLAGS) $< -o $@

# Run
run:
	$(QEMU) $(QEMU_FLAGS) -drive file=$(filter %.img,$(MAKECMDGOALS)),format=raw,if=floppy -boot order=a -rtc base=localtime

# CleanUp
clean:
	rm -f $(BOOT)

# FakeTarget
.PHONY: all run clean
