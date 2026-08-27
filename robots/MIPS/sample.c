# include "mips.h"

/* メモリ */
# define MEMORY_SIZE	100
MEMORY Memory[MEMORY_SIZE];

/* レジスタ */
uint32_t PC;
uint32_t Reg[32];

IF_ID IfIdReg;
ID_EX IdExReg;
EX_MEM ExMemReg;
MEM_WB MemWbReg;

/* ステージ */
void IF(void) {
	/* body */
}

void ID(void) {
	/* body */
}

void MEM(void) {
	/* body */
}

void WB(void) {
	/* body */
}

int main(int argc, char *argv[]) {
	/* body */
}
