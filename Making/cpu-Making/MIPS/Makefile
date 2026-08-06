all: MemoryModule.o
	cc -std=c11 -Wall -o mips mips.c MemoryModule.o

clean:
	rm -f MemoryModule.o

MemoryModule.o: MemoryModule.c MemoryModule.h
	cc -c MemoryModule.c
