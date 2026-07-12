AS = nasm
LD = ld

SRCS = $(filter %.asm,$(MAKECMDGOALS))
OBJS = $(SRCS:.asm=.o)
LINK = link.ld
SSP  = sstrip.py

.PHONY: compile run

compile: $(OBJS)
	$(LD) -o $(basename $(OBJS)).ou $(OBJS) -T link.ld -nostdlib -N -s -no-pie
	python3 $(SSP) $(basename $(OBJS)).ou $(basename $(OBJS)).out
	chmod +x $(basename $(OBJS)).out

%.o: %.asm
	$(AS) -f elf64 $< -o $@

%:
	@:

run:
	./*.out
