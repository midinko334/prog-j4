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
CLOCK	   = clock.bin
IMG        = disk.img

# Default
all: $(IMG)

# ディスクイメージ作成
$(IMG): $(BOOT) $(KERNEL) $(CLOCK)
	cat Bin/$(BOOT) Bin/$(KERNEL) Bin/$(CLOCK) > Bin/$@

# アセンブリからバイナリへの変換ルール
%.bin: %.asm
	$(NASM) $(NFLAGS) $< -o Bin/$@

# Run
run: $(IMG)
	$(QEMU) $(QEMU_FLAGS) -fda Bin/$< -rtc base=localtime

# CleanUp
clean:
	rm -f Bin/$(IMG) Bin/$(BOOT) Bin/$(KERNEL) Bin/$(CLOCK)

# FakeTarget
.PHONY: all run clean
