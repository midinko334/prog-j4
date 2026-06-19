AS = as
LD = ld
MSWP = mswp.s

all:

compile: $(MSWP)
	$(AS) -o $*.o $<
	$(LD) -o a.out $*.o
	rm $*.o

run:
	./a.out

clean:
	rm -f *.o *.out
