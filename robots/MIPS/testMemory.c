# include	<stdio.h>
# include	"MemoryModule.h"

MEMORY *Memory;

int main(void) {
	uint32_t data, w;
	uint32_t h1, h2;
	Memory = MMalloc(100);
	data = 0b11111111111011101101110111001100;
	MMwriteWord(Memory, 8, data);
	printf("write: %08x\n", data);
	w = MMreadWord(Memory, 8);
	printf("read: %08x\n", w);
	h1 = MMreadHalfWord(Memory, 8);
	h2 = MMreadHalfWord(Memory, 10);
	printf("read: %04x %04x\n", h1, h2);
}
