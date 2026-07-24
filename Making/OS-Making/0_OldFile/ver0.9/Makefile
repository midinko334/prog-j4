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
MSWP       = mswp.bin
IMG        = disk.img

# Default
all: $(IMG)

# ディスクイメージ作成
$(IMG): $(BOOT) $(KERNEL)
	cat Bin/$(BOOT) Bin/$(KERNEL) > Bin/$@

$(KERNEL): $(MSWP) clock.bin

# アセンブリからバイナリへの変換ルール
%.bin: %.asm
	$(NASM) $(NFLAGS) $< -o Bin/$@

# Run
run: $(IMG)
	$(QEMU) $(QEMU_FLAGS) -fda Bin/$< -rtc base=localtime

# CleanUp
clean:
	rm -f Bin/$(IMG) Bin/$(BOOT) Bin/$(KERNEL) Bin/$(MSWP) Bin/clock.bin

# FakeTarget
.PHONY: all run clean
