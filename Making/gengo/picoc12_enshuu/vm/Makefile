CC = cc
INCLUDEDIR = -I. -I..
CFLAGS = -O2  -g ${INCLUDEDIR}

CP = cp
RM = rm

HEADERS = ../define.h label_table.h vm.h

OBJECTS = label_table.o vm.o

BINDIR = ${HOME}/bin

#.SUFFIXES: .c .o

.c.o:${HEADERS}
	${CC} ${CFLAGS} -c $<

all: picoc_vm

picoc_vm: ${OBJECTS} picoc_vm.o
	${CC} ${CFLAGS} picoc_vm.o ${OBJECTS} -o picoc_vm

install:
	mkdir -p ${BINDIR}
	cp picoc_vm ${BINDIR}

clean:
	${RM} -f *.o

hardclean:
	${RM} -f *.o Makefile~ *.*~ picoc_vm

tar: clean
	cd ..;tar cvzf `basename ${PWD}`.tgz `basename ${PWD}`
