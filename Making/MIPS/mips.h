# include "MemoryModule.h"

/* 型 */
typedef struct {
	/*  members */
} IF_ID;

typedef struct {
	/*  members */
} ID_EX;

typedef struct {
	/*  members */
} EX_MEM;

typedef struct {
	/*  members */
} MEM_WB;

/* 大域変数 */
extern MEMORY Memory[];

extern uint32_t PC;
extern uint32_t Reg[32];


extern IF_ID IfIdReg;
extern ID_EX IdExReg;
extern EX_MEM ExMemReg;
extern MEM_WB MemWbReg;

/* 関数 */
void IF(void);
void ID(void);
void EX(void);
void MEM(void);
void WB(void);
