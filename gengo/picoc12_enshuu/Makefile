CC = cc
INCLUDEDIR = -I. 
CFLAGS = -O2  -g ${INCLUDEDIR} -DVERBOSE_COMMENT

# x64 のネイティブコードか picovm かを選択
#ARCH = x64
ARCH = vm

CP = cp
RM = rm

HEADERS = define.h scanner.h parser.h id_table.h \
		id_table_stack.h id_info.h

OBJECTS = scanner.o parser_${ARCH}.o id_table.o id_table_stack.o

BINDIR = ${HOME}/bin
LIBDIR = ${HOME}/lib

#.SUFFIXES: .c .o

all: pcc_${ARCH} picoc_vm

.c.o:${HEADERS}
	${CC} ${CFLAGS} -c $<

test_scanner: ${OBJECTS} test_scanner.o
	${CC} ${CFLAGS} test_scanner.o ${OBJECTS} -o test_scanner

pcc_vm: ${OBJECTS} pcc.o
	${CC} ${CFLAGS} pcc.o ${OBJECTS} -o pcc_vm

pcc_x64: ${OBJECTS} pcc.o
	${CC} ${CFLAGS} pcc.o ${OBJECTS} -o pcc_x64

picoc_vm:
	cd vm; make picoc_vm

install:
	mkdir -p ${BINDIR}
	cp pcc_${ARCH} picocc_${ARCH} ${BINDIR} 
	mkdir -p ${LIBDIR}
	cp picoc_lib.c ${LIBDIR}
	cd vm; make install

clean:
	${RM} -f *.o pcc_${ARCH}
	cd vm;make clean

hardclean:
	${RM} -f *.o Makefile~ *.*~ test_scanner pcc_vm pcc_x64
	cd vm;make hardclean

tar: clean
	cd ..;tar cvzf `basename ${PWD}`.tgz `basename ${PWD}`
