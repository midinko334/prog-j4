MAKEFLAGS += -s
AS      = nasm
CC      = cc
CFLAGS  = -O2 -fno-stack-protector
LOAD    = loader.c
LOADER  = $(basename $(LOAD))
SRCS    = $(filter %.asm,$(MAKECMDGOALS))
OBJS    = $(SRCS:.asm=.bin)

.PHONY: run gen

%.bin: %.asm
	$(AS) -f bin -o $@ $<

$(LOADER): $(LOAD)
	$(CC) $(CFLAGS) -o $@ $<

gen: $(LOADER) $(OBJS)

run:
	./$(basename $(LOAD)) $(OBJS) || true
