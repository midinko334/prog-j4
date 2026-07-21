AS = nasm
LD = ld

#SRCS = $(filter %.asm,$(MAKECMDGOALS))
SRCS = mswp.asm
OBJS = $(SRCS:.asm=.o)
LINK = link.ld
SSP  = sstrip.py
OVP  = overlap.py

.PHONY: all run clean

all: $(OBJS)
	$(LD) -o $(basename $(OBJS)).lout $(OBJS) -T link.ld -nostdlib -N -s -no-pie
	python3 $(SSP) $(basename $(OBJS)).lout $(basename $(OBJS)).sout
	python3 $(OVP) $(basename $(OBJS)).sout $(basename $(OBJS)).out
	chmod +x $(basename $(OBJS)).out

%.o: %.asm
	$(AS) -f elf64 $< -o $@

%:
	@:

run:
	./*.out

clean:
	rm *.o *.lout *.sout
