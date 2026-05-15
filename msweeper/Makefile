AS = as
LD = ld

all:

%: %.s
	$(AS) -o $*.o $<
	$(LD) -o $@ $*.o
	rm $*.o

clean:
	rm -f *.o *.out
