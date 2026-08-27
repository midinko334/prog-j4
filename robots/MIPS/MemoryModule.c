# include	"MemoryModule.h"

static void myerror(char *msg, MADDR addr) {
	fprintf(stderr, "%s: %ud\n", *msg, addr);
	exit(EXIT_FAILURE);
}

static void checkAlignment(MADDR addr, int size) {
	if ( addr % size != 0 )
		myerror("illeagl word access", addr); 
}

MEMORY *MMalloc(size_t size) {
	MEMORY *new;
	if ((new = (MEMORY *)malloc(size)) == NULL )
		myerror("no more memry", size);
	return new;
}

void MMwriteByte(MEMORY *mem, MADDR addr, uint8_t data) {
	mem[addr] = (MEMORY)data;
}

uint8_t MMreadByte(MEMORY *mem, MADDR addr) {
	return (uint8_t) mem[addr];
}

void MMwriteHalfWord(MEMORY *mem, MADDR addr, uint16_t data) {
	checkAlignment(addr, 2);
	MMwriteByte(mem, addr, (uint8_t)(data >> 8));
	MMwriteByte(mem, addr+1, (char)data);
}

uint16_t MMreadHalfWord(MEMORY *mem, MADDR addr) {
	uint16_t data;
	checkAlignment(addr, 2);
	data = (uint16_t)MMreadByte(mem, addr);
	data = (data << 8) + (uint16_t)MMreadByte(mem, addr+1);
	return data;
}

void MMwriteWord(MEMORY *mem, MADDR addr, uint32_t data) {
	checkAlignment(addr, 4);
	MMwriteHalfWord(mem, addr, (uint16_t)(data >> 16));
	MMwriteHalfWord(mem, addr+2, (uint16_t)data);
}

uint32_t MMreadWord(MEMORY *mem, MADDR addr) {
	uint32_t data;
	checkAlignment(addr, 4);
	data = (uint32_t)MMreadHalfWord(mem, addr);
	data = (data << 16) + (uint32_t)MMreadHalfWord(mem, addr+2);
	return data;
}

void MMloadProgram(MEMORY *mem, MADDR addr, uint32_t code[], size_t len) {
	for ( int i = 0; i < len; i ++ ) {
		MMwriteWord(mem, addr, code[i]);
		addr += 4;
	}
}
		
