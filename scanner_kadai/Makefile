CC = cc
INCLUDEDIR = -I. 
CFLAGS = -O2  -g ${INCLUDEDIR}

all: test_scanner

test_scanner: scanner.c scanner.h define.h test_scanner.c
	${CC} ${CFLAGS} scanner.c test_scanner.c -o test_scanner

clean:
	rm -rf *.o test_scanner
