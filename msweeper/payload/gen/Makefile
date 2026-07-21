AS = nasm

BIN = $(filter %.bin,$(MAKECMDGOALS))
#SRCS = $(filter %.asm,$(MAKECMDGOALS))
SRCS = mswp.asm
LOAD = loader.c

.PHONY: all run

all: $(SRCS)
	$(AS) -f bin -o $(basename $(SRCS)).bin $(SRCS)
	cc -O2 -fno-stack-protector -o $(basename $(LOAD)) $(LOAD)

%:
	@:

run:
	./$(basename $(LOAD)) $(BIN)
