AS = as
LD = ld

SRCS = $(filter %.s,$(MAKECMDGOALS))
OBJS = $(SRCS:.s=.o)
.PHONY: all run

all: $(OBJS)
	$(LD) -o a.out $(OBJS)
	rm *.o

%.o: %.s
	$(AS) -o $@ $<

%:
	@:

run:
	./a.out
