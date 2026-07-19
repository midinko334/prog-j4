CC = cc
INCLUDEDIR = -I. 
CFLAGS = -O2 -g ${INCLUDEDIR}

EXP = expression_1 expression_1i expression_2 expression_3 expression_4 expression_4i expression_5id

CP = cp
RM = rm

HEADERS = define.h scanner.h parser.h error.h

.SUFFIXES: .c .o

all: ${EXP}

#.c.o:${HEADERS}
#	${CC} ${CFLAGS} -c $<
expression_%: expression.o parser_%.o scanner.o error.o
	${CC} ${CFLAGS} -o $@ expression.o parser_$*.o scanner.o error.o

expression_%i: expression_i.o parser_%i.o scanner.o error.o
	${CC} ${CFLAGS} -o $@ expression_i.o parser_$*i.o scanner.o error.o

expression_%id: expression_id.o parser_%id.o scanner_double.o error.o
	${CC} ${CFLAGS} -o $@ expression_id.o parser_$*id.o scanner_double.o error.o -lm

clean:
	${RM} -f *.o ${EXP}

tar: clean
	cd ..;tar cvzf `basename ${PWD}`.tgz `basename ${PWD}`
