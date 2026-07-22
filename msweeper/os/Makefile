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
	cat ${BOOT} > ${IMG}
#	dd if=/dev/zero of=$(IMG) bs=512 count=2880 2>/dev/null
#	dd if=$(BOOT) of=$(IMG) conv=notrunc 2>/dev/null

# Assemble assembly to bin
%.bin: %.asm
	$(NASM) $(NFLAGS) $< -o $@

# Run
run:
	$(QEMU) $(QEMU_FLAGS) -drive file=$(IMG),format=raw,if=floppy -boot order=a -rtc base=localtime

# CleanUp
clean:
	rm -f $(IMG) $(BOOT)

# FakeTarget
.PHONY: all run clean
