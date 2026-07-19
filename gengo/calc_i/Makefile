CC = cc
INCLUDEDIR = -I. 
CFLAGS = -O2 -g ${INCLUDEDIR}

CP = cp
RM = rm

HEADERS = define.h scanner.h parser.h error.h

.SUFFIXES: .c .o

all: expression_1 expression_1i

#.c.o:${HEADERS}
#	${CC} ${CFLAGS} -c $<

expression_1: expression.o parser_1.o scanner.o error.o
	${CC} ${CFLAGS} -o $@ expression.o parser_1.o scanner.o error.o

expression_1i: expression_i.o parser_1i.o scanner.o error.o
	${CC} ${CFLAGS} -o $@ expression_i.o parser_1i.o scanner.o error.o

clean:
	${RM} -f *.o expression_1 expression_1i

tar: clean
	cd ..;tar cvzf `basename ${PWD}`.tgz `basename ${PWD}`
