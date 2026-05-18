AS = as
LD = ld
MSWP = mswp.s

all:

compile: $(MSWP)
	$(AS) -o $*.o $<
	$(LD) -o a.out $*.o
	rm $*.o

clean:
	rm -f *.o *.out
