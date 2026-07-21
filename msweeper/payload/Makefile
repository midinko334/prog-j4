AS      = nasm
CC      = cc
CFLAGS  = -O2 -fno-stack-protector
LOAD    = loader.c
LOADER  = $(basename $(LOAD))
BIN     = $(filter %.bin,$(MAKECMDGOALS))

.PHONY: run clean

%.bin: %.asm
	$(AS) -f bin -o $@ $<

$(LOADER): $(LOAD)
	$(CC) $(CFLAGS) -o $@ $<

gen: $(LOADER) $(BIN)

run:
	./$(basename $(LOAD)) $(BIN)
