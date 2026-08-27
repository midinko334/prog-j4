# ifndef MEMORYMODULE_H
# define MEMORYMODULE_H

# include <stdint.h>
# include <stdlib.h>
# include <stdio.h>

typedef size_t	MADDR;
typedef uint8_t	MEMORY;

MEMORY *MMalloc(size_t size);

void MMwriteWord(MEMORY *mem, MADDR addr, uint32_t data);
uint32_t MMreadWord(MEMORY *mem, MADDR addr);

void MMwriteHalfWord(MEMORY *mem, MADDR addr, uint16_t data);
uint16_t MMreadHalfWord(MEMORY *mem, MADDR addr);

void MMwriteByte(MEMORY *mem, MADDR addr, uint8_t data);
uint8_t MMreadByte(MEMORY *mem, MADDR addr);

void MMloadProgram(MEMORY *mem, MADDR addr, uint32_t code[], size_t len);

# endif
