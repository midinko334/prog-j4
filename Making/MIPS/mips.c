/* ============================================================================
 *
 * MIPS命令セット・シミュレータ（最終統合版）
 *
 * MemoryModule.c/h（バイトアドレッシングのメモリモジュール）と組み合わせて
 * 使用する。IF/ID/EX/MEM/WBの5つのステージ関数を1命令ごとに順番に呼び出す
 * マルチサイクル方式で命令を実行する（分岐・ジャンプは MEM ステージで PC に
 * 反映されるため、次の IF は必ず正しいアドレスを取得できる）。
 *
 * AllInstructions.txt に列挙されている全命令（整数演算・分岐・ジャンプ・
 * メモリアクセス・単精度/倍精度浮動小数点演算・LL/SC・MFC0・BREAK）を
 * サポートする。
 *
 * コンパイル:
 *   cc -std=c11 -Wall -o mips mips.c MemoryModule.c
 *
 * 実行:
 *   ./mips              ... 内蔵のサンプルプログラム(SampleCode.txt相当)を実行
 *   ./mips <machcode>   ... 16進数の機械語を1行1語で記述したファイルを読み込んで実行
 * ==========================================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <ctype.h>

#include "MemoryModule.h"

/* ------------------------------------------------------------------------
 * レジスタ数・コプロセッサ0レジスタ番号
 * ----------------------------------------------------------------------*/
#define NUM_GPR 32
#define NUM_FPR 32
#define NUM_CR  32

#define CR_CAUSE 13   /* MIPS CP0 Cause レジスタ番号 */
#define CR_EPC   14   /* MIPS CP0 EPC レジスタ番号   */

#define CAUSE_OVERFLOW (12 << 2)  /* ExcCode=12(Ov) を Cause の ExcCode フィールドへ */

/* ------------------------------------------------------------------------
 * 命令の内部表現
 * ----------------------------------------------------------------------*/
typedef enum {
    OP_UNKNOWN = 0,
    OP_BREAK,
    /* 整数R形式 */
    OP_ADD, OP_ADDU, OP_SUB, OP_SUBU,
    OP_AND, OP_OR, OP_NOR,
    OP_SLL, OP_SRL, OP_SRA,
    OP_SLT, OP_SLTU,
    OP_JR,
    OP_MULT, OP_MULTU, OP_DIV, OP_DIVU,
    OP_MFHI, OP_MFLO, OP_MFC0,
    /* J形式 */
    OP_J, OP_JAL,
    /* 整数I形式 */
    OP_ADDI, OP_ADDIU, OP_ANDI, OP_ORI,
    OP_SLTI, OP_SLTIU, OP_LUI,
    OP_LW, OP_LHU, OP_LBU,
    OP_SW, OP_SH, OP_SB,
    OP_BEQ, OP_BNE,
    OP_LL, OP_SC,
    /* 浮動小数点(単精度/倍精度) */
    OP_ADD_S, OP_ADD_D, OP_SUB_S, OP_SUB_D,
    OP_MUL_S, OP_MUL_D, OP_DIV_S, OP_DIV_D,
    OP_C_EQ_S, OP_C_LT_S, OP_C_LE_S,
    OP_C_EQ_D, OP_C_LT_D, OP_C_LE_D,
    OP_LWC1, OP_LDC1, OP_SWC1, OP_SDC1,
    OP_BC1T, OP_BC1F
} Opcode;

typedef enum {
    FMT_R = 0,
    FMT_I,
    FMT_J,
    FMT_FR,
    FMT_FI
} InstrFormat;

/* ------------------------------------------------------------------------
 * パイプラインレジスタ（ステージ間でデータを受け渡すための構造体）
 * ----------------------------------------------------------------------*/
typedef struct {
    uint32_t instr;   /* フェッチした生の命令 */
    uint32_t pc4;      /* フェッチ時の PC + 4 */
} IFID_Reg;

typedef struct {
    Opcode      op;
    InstrFormat fmt;
    uint32_t rs, rt, rd, shamt, funct;
    uint32_t addr26;
    uint32_t raw_instr;
    uint32_t pc4;
    uint32_t imm;
    uint32_t rsval, rsval2, rtval, rtval2;
    int      wb_reg;   /* -1 ならば書き戻し無し */
} IDEX_Reg;

typedef struct {
    Opcode   op;
    int      wb_reg;
    uint32_t pc4;
    uint32_t alu_result, alu_result2;
    uint32_t store_val, store_val2;
    int      zero;            /* 分岐/比較が成立したか */
    uint32_t branch_target;
} EXMEM_Reg;

typedef struct {
    Opcode   op;
    int      wb_reg;
    uint32_t alu_result, alu_result2;
    uint32_t mem_data, mem_data2;
} MEMWB_Reg;

/* ------------------------------------------------------------------------
 * 大域状態
 * ----------------------------------------------------------------------*/
uint32_t GPR[NUM_GPR];
uint32_t PC;
uint32_t HI, LO;
uint32_t FPR[NUM_FPR];
int      FPcond;
uint32_t CR[NUM_CR];

MEMORY *MEM = NULL;
size_t  MEM_SIZE = 0;

int    LinkValid = 0;
MADDR  LinkAddr  = 0;

int  SimHalted   = 0;
int  SimExitCode = 0;
long long CycleCount = 0;

IFID_Reg  IFID;
IDEX_Reg  IDEX;
EXMEM_Reg EXMEM;
MEMWB_Reg MEMWB;

/* ------------------------------------------------------------------------
 * 命令フィールド抽出マクロ
 * ----------------------------------------------------------------------*/
#define F_OPCODE(i) (((i) >> 26) & 0x3F)
#define F_RS(i)     (((i) >> 21) & 0x1F)
#define F_RT(i)     (((i) >> 16) & 0x1F)
#define F_RD(i)     (((i) >> 11) & 0x1F)
#define F_SHAMT(i)  (((i) >> 6)  & 0x1F)
#define F_FUNCT(i)  ((i) & 0x3F)
#define F_IMM16(i)  ((i) & 0xFFFF)
#define F_ADDR26(i) ((i) & 0x3FFFFFF)

#define FMT_S   0x10   /* COP1 rs フィールド：単精度 */
#define FMT_D   0x11   /* COP1 rs フィールド：倍精度 */
#define FMT_BC  0x08   /* COP1 rs フィールド：条件分岐(bc1t/bc1f) */

/* ------------------------------------------------------------------------
 * 補助関数
 * ----------------------------------------------------------------------*/
static uint32_t SignExtImm(uint32_t imm16)
{
    return (uint32_t)(int32_t)(int16_t)(imm16 & 0xFFFF);
}
static uint32_t ZeroExtImm(uint32_t imm16)
{
    return imm16 & 0xFFFF;
}
static uint32_t BranchAddr(uint32_t imm16)
{
    return (uint32_t)(((int32_t)(int16_t)(imm16 & 0xFFFF)) << 2);
}
static uint32_t JumpAddr(uint32_t addr26, uint32_t pc4)
{
    return (pc4 & 0xF0000000u) | ((addr26 & 0x3FFFFFFu) << 2);
}

static float bits_to_float(uint32_t bits)
{
    float f;
    memcpy(&f, &bits, sizeof(f));
    return f;
}
static uint32_t float_to_bits(float f)
{
    uint32_t u;
    memcpy(&u, &f, sizeof(u));
    return u;
}
static double pair_to_double(uint32_t hi, uint32_t lo)
{
    uint64_t bits = ((uint64_t)hi << 32) | (uint64_t)lo;
    double d;
    memcpy(&d, &bits, sizeof(d));
    return d;
}
static void double_to_pair(double d, uint32_t *hi, uint32_t *lo)
{
    uint64_t bits;
    memcpy(&bits, &d, sizeof(bits));
    *hi = (uint32_t)(bits >> 32);
    *lo = (uint32_t)(bits & 0xFFFFFFFFu);
}

/* MEM_SIZE の範囲外アクセスを検出し、セグメンテーション違反ではなく
   分かりやすいエラーで安全に停止させる */
static int AddrOutOfRange(MADDR addr, size_t accesssize)
{
    return (addr + accesssize > MEM_SIZE) || (addr + accesssize < addr);
}

void Sim_Abort(const char *msg)
{
    fprintf(stderr, "*** Simulator Aborted: %s (PC=0x%08X, instr=0x%08X) ***\n",
            msg, IFID.pc4 - 4, IFID.instr);
    SimHalted = 1;
    SimExitCode = 1;
}

static void SetOverflowException(void)
{
    CR[CR_CAUSE] = CAUSE_OVERFLOW;
    CR[CR_EPC]   = IFID.pc4 - 4;
    fprintf(stderr,
            "[Warn] Overflow exception is caused (PC=0x%08X)\n",
            CR[CR_EPC]);
}

/* ==========================================================================
 * ステージ関数
 * ========================================================================*/
void IF_stage(void)
{
    if (SimHalted) return;

    if (AddrOutOfRange((MADDR)PC, 4)) {
        fprintf(stderr, "*** Simulator Aborted: Instruction fetch out of range (PC=0x%08X) ***\n", PC);
        SimHalted = 1;
        SimExitCode = 1;
        return;
    }

    uint32_t instr = MMreadWord(MEM, (MADDR)PC);
    IFID.instr = instr;
    PC = PC + 4;
    IFID.pc4 = PC;
}

void ID_stage(void)
{
    if (SimHalted) return;

    uint32_t instr = IFID.instr;
    uint32_t opcode = F_OPCODE(instr);
    uint32_t rs = F_RS(instr), rt = F_RT(instr), rd = F_RD(instr);
    uint32_t shamt = F_SHAMT(instr), funct = F_FUNCT(instr);
    uint32_t imm16 = F_IMM16(instr), addr26 = F_ADDR26(instr);

    Opcode op = OP_UNKNOWN;
    InstrFormat fmt = FMT_R;

    if (instr == 0x0000000Cu) {
        op = OP_BREAK;
        fmt = FMT_R;
    }
    else if (opcode == 0x00) {
        fmt = FMT_R;
        switch (funct) {
            case 0x20: op = OP_ADD;  break;
            case 0x21: op = OP_ADDU; break;
            case 0x22: op = OP_SUB;  break;
            case 0x23: op = OP_SUBU; break;
            case 0x24: op = OP_AND;  break;
            case 0x25: op = OP_OR;   break;
            case 0x27: op = OP_NOR;  break;
            case 0x00: op = OP_SLL;  break;
            case 0x02: op = OP_SRL;  break;
            case 0x03: op = OP_SRA;  break;
            case 0x2a: op = OP_SLT;  break;
            case 0x2b: op = OP_SLTU; break;
            case 0x08: op = OP_JR;   break;
            case 0x18: op = OP_MULT;  break;
            case 0x19: op = OP_MULTU; break;
            case 0x1a: op = OP_DIV;   break;
            case 0x1b: op = OP_DIVU;  break;
            case 0x10: op = OP_MFHI;  break;
            case 0x12: op = OP_MFLO;  break;
            default: op = OP_UNKNOWN; break;
        }
    }
    else if (opcode == 0x10) {
        fmt = FMT_R;
        op = OP_MFC0;
    }
    else if (opcode == 0x02) { fmt = FMT_J; op = OP_J;   }
    else if (opcode == 0x03) { fmt = FMT_J; op = OP_JAL; }
    else if (opcode == 0x11) {
        if (rs == FMT_BC) {
            fmt = FMT_FI;
            op = (rt == 1) ? OP_BC1T : OP_BC1F;
        } else {
            fmt = FMT_FR;
            int is_d = (rs == FMT_D);
            switch (funct) {
                case 0x00: op = is_d ? OP_ADD_D : OP_ADD_S; break;
                case 0x01: op = is_d ? OP_SUB_D : OP_SUB_S; break;
                case 0x02: op = is_d ? OP_MUL_D : OP_MUL_S; break;
                case 0x03: op = is_d ? OP_DIV_D : OP_DIV_S; break;
                case 0x32: op = is_d ? OP_C_EQ_D : OP_C_EQ_S; break;
                case 0x3c: op = is_d ? OP_C_LT_D : OP_C_LT_S; break;
                case 0x3e: op = is_d ? OP_C_LE_D : OP_C_LE_S; break;
                default: op = OP_UNKNOWN; break;
            }
        }
    }
    else {
        fmt = FMT_I;
        switch (opcode) {
            case 0x08: op = OP_ADDI;  break;
            case 0x09: op = OP_ADDIU; break;
            case 0x0c: op = OP_ANDI;  break;
            case 0x0d: op = OP_ORI;   break;
            case 0x0a: op = OP_SLTI;  break;
            case 0x0b: op = OP_SLTIU; break;
            case 0x23: op = OP_LW;    break;
            case 0x25: op = OP_LHU;   break;
            case 0x24: op = OP_LBU;   break;
            case 0x0f: op = OP_LUI;   break;
            case 0x2b: op = OP_SW;    break;
            case 0x29: op = OP_SH;    break;
            case 0x28: op = OP_SB;    break;
            case 0x04: op = OP_BEQ;   break;
            case 0x05: op = OP_BNE;   break;
            case 0x30: op = OP_LL;    break;
            case 0x38: op = OP_SC;    break;
            case 0x31: fmt = FMT_I; op = OP_LWC1; break;
            case 0x35: fmt = FMT_I; op = OP_LDC1; break;
            case 0x39: fmt = FMT_I; op = OP_SWC1; break;
            case 0x3d: fmt = FMT_I; op = OP_SDC1; break;
            default: op = OP_UNKNOWN; break;
        }
    }

    if (op == OP_UNKNOWN) {
        Sim_Abort("Unknown Command");
        return;
    }

    IDEX.op = op;
    IDEX.fmt = fmt;
    IDEX.rs = rs; IDEX.rt = rt; IDEX.rd = rd;
    IDEX.shamt = shamt; IDEX.funct = funct;
    IDEX.addr26 = addr26;
    IDEX.raw_instr = instr;
    IDEX.pc4 = IFID.pc4;

    switch (op) {
        case OP_ANDI: case OP_ORI:
            IDEX.imm = ZeroExtImm(imm16);
            break;
        case OP_BEQ: case OP_BNE: case OP_BC1T: case OP_BC1F:
            IDEX.imm = BranchAddr(imm16);
            break;
        case OP_LUI:
            IDEX.imm = imm16;
            break;
        default:
            IDEX.imm = SignExtImm(imm16);
            break;
    }

    if (fmt == FMT_FR || fmt == FMT_FI) {
        IDEX.rsval  = FPR[rd];
        IDEX.rsval2 = FPR[(rd + 1) & 0x1F];
        IDEX.rtval  = FPR[rt];
        IDEX.rtval2 = FPR[(rt + 1) & 0x1F];
    } else {
        IDEX.rsval = GPR[rs];
        IDEX.rtval = GPR[rt];
        IDEX.rsval2 = 0;
        IDEX.rtval2 = 0;
    }

    switch (op) {
        case OP_ADD: case OP_ADDU: case OP_SUB: case OP_SUBU:
        case OP_AND: case OP_OR: case OP_NOR:
        case OP_SLL: case OP_SRL: case OP_SRA:
        case OP_SLT: case OP_SLTU:
        case OP_MFHI: case OP_MFLO: case OP_MFC0:
            IDEX.wb_reg = rd; break;
        case OP_ADDI: case OP_ADDIU: case OP_ANDI: case OP_ORI:
        case OP_SLTI: case OP_SLTIU: case OP_LUI:
        case OP_LW: case OP_LHU: case OP_LBU: case OP_LL: case OP_SC:
            IDEX.wb_reg = rt; break;
        case OP_JAL:
            IDEX.wb_reg = 31; break;
        case OP_ADD_S: case OP_ADD_D: case OP_SUB_S: case OP_SUB_D:
        case OP_MUL_S: case OP_MUL_D: case OP_DIV_S: case OP_DIV_D:
            IDEX.wb_reg = shamt; break;
        case OP_LWC1: case OP_LDC1:
            IDEX.wb_reg = rt; break;
        default:
            IDEX.wb_reg = -1; break;
    }
}

void EX_stage(void)
{
    if (SimHalted) return;

    Opcode op = IDEX.op;
    uint32_t rs = IDEX.rsval, rt = IDEX.rtval;
    int32_t srs = (int32_t)rs, srt = (int32_t)rt;

    EXMEM.op = op;
    EXMEM.wb_reg = IDEX.wb_reg;
    EXMEM.pc4 = IDEX.pc4;
    EXMEM.store_val = rt;
    EXMEM.store_val2 = IDEX.rtval2;
    EXMEM.zero = 0;
    EXMEM.branch_target = 0;
    EXMEM.alu_result2 = 0;

    switch (op) {
        case OP_ADD: {
            int64_t r = (int64_t)srs + (int64_t)srt;
            if (r > INT32_MAX || r < INT32_MIN) SetOverflowException();
            EXMEM.alu_result = (uint32_t)(srs + srt);
            break;
        }
        case OP_ADDU:  EXMEM.alu_result = rs + rt; break;
        case OP_SUB: {
            int64_t r = (int64_t)srs - (int64_t)srt;
            if (r > INT32_MAX || r < INT32_MIN) SetOverflowException();
            EXMEM.alu_result = (uint32_t)(srs - srt);
            break;
        }
        case OP_SUBU:  EXMEM.alu_result = rs - rt; break;
        case OP_AND:   EXMEM.alu_result = rs & rt; break;
        case OP_OR:    EXMEM.alu_result = rs | rt; break;
        case OP_NOR:   EXMEM.alu_result = ~(rs | rt); break;
        case OP_SLL:   EXMEM.alu_result = rt << IDEX.shamt; break;
        case OP_SRL:   EXMEM.alu_result = rt >> IDEX.shamt; break;
        case OP_SRA:   EXMEM.alu_result = (uint32_t)(srt >> IDEX.shamt); break;
        case OP_SLT:   EXMEM.alu_result = (srs < srt) ? 1 : 0; break;
        case OP_SLTU:  EXMEM.alu_result = (rs < rt) ? 1 : 0; break;

        case OP_ADDI: {
            int32_t imm = (int32_t)IDEX.imm;
            int64_t r = (int64_t)srs + (int64_t)imm;
            if (r > INT32_MAX || r < INT32_MIN) SetOverflowException();
            EXMEM.alu_result = (uint32_t)(srs + imm);
            break;
        }
        case OP_ADDIU: EXMEM.alu_result = rs + IDEX.imm; break;
        case OP_ANDI:  EXMEM.alu_result = rs & IDEX.imm; break;
        case OP_ORI:   EXMEM.alu_result = rs | IDEX.imm; break;
        case OP_SLTI:  EXMEM.alu_result = (srs < (int32_t)IDEX.imm) ? 1 : 0; break;
        case OP_SLTIU: EXMEM.alu_result = (rs < IDEX.imm) ? 1 : 0; break;
        case OP_LUI:   EXMEM.alu_result = IDEX.imm << 16; break;

        case OP_LW: case OP_LHU: case OP_LBU:
        case OP_SW: case OP_SH: case OP_SB:
        case OP_LL: case OP_SC:
        case OP_LWC1: case OP_LDC1: case OP_SWC1: case OP_SDC1:
            EXMEM.alu_result = rs + IDEX.imm;
            break;

        case OP_BEQ:
            EXMEM.zero = (srs == srt) ? 1 : 0;
            EXMEM.branch_target = IDEX.pc4 + IDEX.imm;
            break;
        case OP_BNE:
            EXMEM.zero = (srs != srt) ? 1 : 0;
            EXMEM.branch_target = IDEX.pc4 + IDEX.imm;
            break;
        case OP_J:
            EXMEM.zero = 1;
            EXMEM.branch_target = JumpAddr(IDEX.addr26, IDEX.pc4);
            break;
        case OP_JAL:
            EXMEM.zero = 1;
            EXMEM.branch_target = JumpAddr(IDEX.addr26, IDEX.pc4);
            EXMEM.alu_result = IDEX.pc4;
            break;
        case OP_JR:
            EXMEM.zero = 1;
            EXMEM.branch_target = rs;
            break;

        case OP_MULT: {
            int64_t r = (int64_t)srs * (int64_t)srt;
            EXMEM.alu_result  = (uint32_t)((uint64_t)r & 0xFFFFFFFFu);
            EXMEM.alu_result2 = (uint32_t)(((uint64_t)r >> 32) & 0xFFFFFFFFu);
            break;
        }
        case OP_MULTU: {
            uint64_t r = (uint64_t)rs * (uint64_t)rt;
            EXMEM.alu_result  = (uint32_t)(r & 0xFFFFFFFFu);
            EXMEM.alu_result2 = (uint32_t)((r >> 32) & 0xFFFFFFFFu);
            break;
        }
        case OP_DIV:
            if (srt == 0) {
                fprintf(stderr, "[Warn] div: division by zero. Lo,Hi left undefined.\n");
                EXMEM.alu_result = 0; EXMEM.alu_result2 = 0;
            } else {
                EXMEM.alu_result  = (uint32_t)(srs / srt);
                EXMEM.alu_result2 = (uint32_t)(srs % srt);
            }
            break;
        case OP_DIVU:
            if (rt == 0) {
                fprintf(stderr, "[Warn] divu: division by zero. Lo,Hi left undefined.\n");
                EXMEM.alu_result = 0; EXMEM.alu_result2 = 0;
            } else {
                EXMEM.alu_result  = rs / rt;
                EXMEM.alu_result2 = rs % rt;
            }
            break;
        case OP_MFHI: EXMEM.alu_result = HI; break;
        case OP_MFLO: EXMEM.alu_result = LO; break;
        case OP_MFC0: EXMEM.alu_result = CR[IDEX.rs & 0x1F]; break;

        case OP_ADD_S: EXMEM.alu_result = float_to_bits(bits_to_float(IDEX.rsval) + bits_to_float(IDEX.rtval)); break;
        case OP_SUB_S: EXMEM.alu_result = float_to_bits(bits_to_float(IDEX.rsval) - bits_to_float(IDEX.rtval)); break;
        case OP_MUL_S: EXMEM.alu_result = float_to_bits(bits_to_float(IDEX.rsval) * bits_to_float(IDEX.rtval)); break;
        case OP_DIV_S: EXMEM.alu_result = float_to_bits(bits_to_float(IDEX.rsval) / bits_to_float(IDEX.rtval)); break;
        case OP_ADD_D: case OP_SUB_D: case OP_MUL_D: case OP_DIV_D: {
            double a = pair_to_double(IDEX.rsval, IDEX.rsval2);
            double b = pair_to_double(IDEX.rtval, IDEX.rtval2);
            double r = (op == OP_ADD_D) ? a + b :
                       (op == OP_SUB_D) ? a - b :
                       (op == OP_MUL_D) ? a * b : a / b;
            double_to_pair(r, &EXMEM.alu_result, &EXMEM.alu_result2);
            break;
        }

        case OP_C_EQ_S: EXMEM.zero = (bits_to_float(IDEX.rsval) == bits_to_float(IDEX.rtval)); break;
        case OP_C_LT_S: EXMEM.zero = (bits_to_float(IDEX.rsval) <  bits_to_float(IDEX.rtval)); break;
        case OP_C_LE_S: EXMEM.zero = (bits_to_float(IDEX.rsval) <= bits_to_float(IDEX.rtval)); break;
        case OP_C_EQ_D: EXMEM.zero = (pair_to_double(IDEX.rsval, IDEX.rsval2) == pair_to_double(IDEX.rtval, IDEX.rtval2)); break;
        case OP_C_LT_D: EXMEM.zero = (pair_to_double(IDEX.rsval, IDEX.rsval2) <  pair_to_double(IDEX.rtval, IDEX.rtval2)); break;
        case OP_C_LE_D: EXMEM.zero = (pair_to_double(IDEX.rsval, IDEX.rsval2) <= pair_to_double(IDEX.rtval, IDEX.rtval2)); break;

        case OP_BC1T:
            EXMEM.zero = FPcond ? 1 : 0;
            EXMEM.branch_target = IDEX.pc4 + IDEX.imm;
            break;
        case OP_BC1F:
            EXMEM.zero = (!FPcond) ? 1 : 0;
            EXMEM.branch_target = IDEX.pc4 + IDEX.imm;
            break;

        case OP_BREAK:
            break;

        default:
            break;
    }
}

void MEM_stage(void)
{
    if (SimHalted) return;

    Opcode op = EXMEM.op;
    MADDR addr = (MADDR)EXMEM.alu_result;

    /* このステージでメモリアクセスを伴う命令については、範囲外アドレスを
       ここで検出してから実際のアクセスを行う */
    size_t access_size = 0;
    switch (op) {
        case OP_LW: case OP_SW: case OP_LL: case OP_SC:
        case OP_LWC1: case OP_SWC1:
            access_size = 4; break;
        case OP_LHU: case OP_SH:
            access_size = 2; break;
        case OP_LBU: case OP_SB:
            access_size = 1; break;
        case OP_LDC1: case OP_SDC1:
            access_size = 8; break;
        default:
            access_size = 0; break;
    }
    if (access_size > 0 && AddrOutOfRange(addr, access_size)) {
        fprintf(stderr,
                "*** Simulator Aborted: Memory address out of range (addr=0x%08X, PC=0x%08X) ***\n",
                (uint32_t)addr, EXMEM.pc4 - 4);
        SimHalted = 1;
        SimExitCode = 1;
        return;
    }

    MEMWB.op = op;
    MEMWB.wb_reg = EXMEM.wb_reg;
    MEMWB.alu_result = EXMEM.alu_result;
    MEMWB.alu_result2 = EXMEM.alu_result2;
    MEMWB.mem_data = 0;
    MEMWB.mem_data2 = 0;

    switch (op) {
        case OP_LW:
            MEMWB.mem_data = MMreadWord(MEM, addr);
            break;
        case OP_LHU:
            MEMWB.mem_data = (uint32_t)MMreadHalfWord(MEM, addr);
            break;
        case OP_LBU:
            MEMWB.mem_data = (uint32_t)MMreadByte(MEM, addr);
            break;
        case OP_SW:
            MMwriteWord(MEM, addr, EXMEM.store_val);
            break;
        case OP_SH:
            MMwriteHalfWord(MEM, addr, (uint16_t)(EXMEM.store_val & 0xFFFF));
            break;
        case OP_SB:
            MMwriteByte(MEM, addr, (uint8_t)(EXMEM.store_val & 0xFF));
            break;

        case OP_LL:
            MEMWB.mem_data = MMreadWord(MEM, addr);
            LinkValid = 1;
            LinkAddr = addr;
            break;
        case OP_SC:
            if (LinkValid && LinkAddr == addr) {
                MMwriteWord(MEM, addr, EXMEM.store_val);
                MEMWB.mem_data = 1;
            } else {
                MEMWB.mem_data = 0;
            }
            LinkValid = 0;
            break;

        case OP_LWC1:
            MEMWB.mem_data = MMreadWord(MEM, addr);
            break;
        case OP_LDC1:
            MEMWB.mem_data  = MMreadWord(MEM, addr);
            MEMWB.mem_data2 = MMreadWord(MEM, addr + 4);
            break;
        case OP_SWC1:
            MMwriteWord(MEM, addr, EXMEM.store_val);
            break;
        case OP_SDC1:
            MMwriteWord(MEM, addr, EXMEM.store_val);
            MMwriteWord(MEM, addr + 4, EXMEM.store_val2);
            break;

        case OP_BEQ: case OP_BNE:
        case OP_J:   case OP_JAL: case OP_JR:
        case OP_BC1T: case OP_BC1F:
            if (EXMEM.zero) {
                PC = EXMEM.branch_target;
            }
            break;

        case OP_BREAK:
            SimHalted = 1;
            SimExitCode = 0;
            break;

        default:
            break;
    }
}

void WB_stage(void)
{
    if (SimHalted) return;

    Opcode op = MEMWB.op;
    int reg = MEMWB.wb_reg;

    switch (op) {
        case OP_ADD: case OP_ADDU: case OP_SUB: case OP_SUBU:
        case OP_AND: case OP_OR: case OP_NOR:
        case OP_SLL: case OP_SRL: case OP_SRA:
        case OP_SLT: case OP_SLTU:
        case OP_ADDI: case OP_ADDIU: case OP_ANDI: case OP_ORI:
        case OP_SLTI: case OP_SLTIU: case OP_LUI:
        case OP_MFHI: case OP_MFLO: case OP_MFC0: case OP_JAL:
            if (reg > 0 && reg < NUM_GPR) GPR[reg] = MEMWB.alu_result;
            break;

        case OP_LW: case OP_LHU: case OP_LBU: case OP_LL: case OP_SC:
            if (reg > 0 && reg < NUM_GPR) GPR[reg] = MEMWB.mem_data;
            break;

        case OP_MULT: case OP_MULTU: case OP_DIV: case OP_DIVU:
            LO = MEMWB.alu_result;
            HI = MEMWB.alu_result2;
            break;

        case OP_ADD_S: case OP_SUB_S: case OP_MUL_S: case OP_DIV_S:
            if (reg >= 0 && reg < NUM_FPR) FPR[reg] = MEMWB.alu_result;
            break;
        case OP_ADD_D: case OP_SUB_D: case OP_MUL_D: case OP_DIV_D:
            if (reg >= 0 && reg < NUM_FPR) {
                FPR[reg] = MEMWB.alu_result;
                FPR[(reg + 1) & 0x1F] = MEMWB.alu_result2;
            }
            break;

        case OP_LWC1:
            if (reg >= 0 && reg < NUM_FPR) FPR[reg] = MEMWB.mem_data;
            break;
        case OP_LDC1:
            if (reg >= 0 && reg < NUM_FPR) {
                FPR[reg] = MEMWB.mem_data;
                FPR[(reg + 1) & 0x1F] = MEMWB.mem_data2;
            }
            break;

        case OP_C_EQ_S: case OP_C_LT_S: case OP_C_LE_S:
        case OP_C_EQ_D: case OP_C_LT_D: case OP_C_LE_D:
            FPcond = EXMEM.zero ? 1 : 0;
            break;

        default:
            break;
    }

    CycleCount++;
}

/* ==========================================================================
 * アセンブラ（Asm.ipynb と同じ文法を C で実装したもの）
 *
 * SampleCode.txt / AllInstructions.txt のような MIPS アセンブリ・ソースを
 * 直接読み込み、機械語に変換してメモリへ書き込む。以前のバージョンは
 * 16進数の機械語列しか読めなかったため、ニーモニックの文字列
 * （"add" は 0xadd としてそのまま16進数と解釈できてしまう等）を
 * 誤ってロードしてしまうバグがあった。これを解消するため、
 * ラベル計算(パス1)とコード生成(パス2)を行う本物のアセンブラを実装する。
 *
 * 文法（readme/Asm.ipynb 準拠）:
 *   ラベル無し行: 空白 + オペコード + 空白 + オペランド
 *   ラベル付き行: ラベル + ":" + 空白 + オペコード + 空白 + オペランド
 *   疑似命令: START addr / DATA d1,d2,... / BREAK
 * ========================================================================*/

#define ASM_MAX_LINES   8192
#define ASM_MAX_LABELS  1024
#define ASM_LINE_LEN    512
#define ASM_OPERAND_LEN 256

typedef enum {
    OPF_RD_RS_RT,     /* add $rd,$rs,$rt              */
    OPF_RD_RT_SHAMT,  /* sll $rd,$rt,shamt             */
    OPF_RD_RS,        /* mfc0 $rd,$rs                  */
    OPF_RS_RT,        /* mult $rs,$rt                  */
    OPF_RD,           /* mfhi $rd                      */
    OPF_RS,           /* jr $rs                        */
    OPF_RT_RS_IMM,    /* addi $rt,$rs,imm               */
    OPF_RT_RS_ADDR,   /* beq $rt,$rs,label              */
    OPF_RT_IMM_RS,    /* lw $rt,imm($rs)                */
    OPF_RT_IMM,       /* lui $rt,imm                    */
    OPF_FT_IMM_RS,    /* lwc1 $ft,imm($rs)              */
    OPF_ADDR,         /* j label                        */
    OPF_FD_FS_FT,     /* add.s $fd,$fs,$ft              */
    OPF_FS_FT,        /* c.eq.s $fs,$ft                 */
    OPF_IMM           /* bc1t label                     */
} OperandFmt;

typedef struct {
    const char *mnemonic;
    uint32_t    opcode;
    uint32_t    funct;
    uint32_t    fmt;   /* rs field for floating instructions (FMT_S/FMT_D/FMT_BC) */
    uint32_t    ft;    /* fixed rt/ft field, used only by bc1t/bc1f                */
    OperandFmt  operand;
} AsmInstrDef;

static const AsmInstrDef AsmTable[] = {
    {"add",    0x00, 0x20, 0, 0, OPF_RD_RS_RT},
    {"addu",   0x00, 0x21, 0, 0, OPF_RD_RS_RT},
    {"sub",    0x00, 0x22, 0, 0, OPF_RD_RS_RT},
    {"subu",   0x00, 0x23, 0, 0, OPF_RD_RS_RT},
    {"and",    0x00, 0x24, 0, 0, OPF_RD_RS_RT},
    {"or",     0x00, 0x25, 0, 0, OPF_RD_RS_RT},
    {"nor",    0x00, 0x27, 0, 0, OPF_RD_RS_RT},
    {"slt",    0x00, 0x2a, 0, 0, OPF_RD_RS_RT},
    {"sltu",   0x00, 0x2b, 0, 0, OPF_RD_RS_RT},
    {"sll",    0x00, 0x00, 0, 0, OPF_RD_RT_SHAMT},
    {"srl",    0x00, 0x02, 0, 0, OPF_RD_RT_SHAMT},
    {"sra",    0x00, 0x03, 0, 0, OPF_RD_RT_SHAMT},
    {"jr",     0x00, 0x08, 0, 0, OPF_RS},
    {"mult",   0x00, 0x18, 0, 0, OPF_RS_RT},
    {"multu",  0x00, 0x19, 0, 0, OPF_RS_RT},
    {"div",    0x00, 0x1a, 0, 0, OPF_RS_RT},
    {"divu",   0x00, 0x1b, 0, 0, OPF_RS_RT},
    {"mfhi",   0x00, 0x10, 0, 0, OPF_RD},
    {"mflo",   0x00, 0x12, 0, 0, OPF_RD},
    {"mfc0",   0x10, 0x00, 0, 0, OPF_RD_RS},

    {"addi",   0x08, 0, 0, 0, OPF_RT_RS_IMM},
    {"addiu",  0x09, 0, 0, 0, OPF_RT_RS_IMM},
    {"andi",   0x0c, 0, 0, 0, OPF_RT_RS_IMM},
    {"ori",    0x0d, 0, 0, 0, OPF_RT_RS_IMM},
    {"slti",   0x0a, 0, 0, 0, OPF_RT_RS_IMM},
    {"sltiu",  0x0b, 0, 0, 0, OPF_RT_RS_IMM},

    {"lw",     0x23, 0, 0, 0, OPF_RT_IMM_RS},
    {"lhu",    0x25, 0, 0, 0, OPF_RT_IMM_RS},
    {"lbu",    0x24, 0, 0, 0, OPF_RT_IMM_RS},
    {"ll",     0x30, 0, 0, 0, OPF_RT_IMM_RS},
    {"sw",     0x2b, 0, 0, 0, OPF_RT_IMM_RS},
    {"sh",     0x29, 0, 0, 0, OPF_RT_IMM_RS},
    {"sb",     0x28, 0, 0, 0, OPF_RT_IMM_RS},
    {"sc",     0x38, 0, 0, 0, OPF_RT_IMM_RS},
    {"lui",    0x0f, 0, 0, 0, OPF_RT_IMM},

    {"beq",    0x04, 0, 0, 0, OPF_RT_RS_ADDR},
    {"bne",    0x05, 0, 0, 0, OPF_RT_RS_ADDR},
    {"j",      0x02, 0, 0, 0, OPF_ADDR},
    {"jal",    0x03, 0, 0, 0, OPF_ADDR},

    {"lwc1",   0x31, 0, 0, 0, OPF_FT_IMM_RS},
    {"ldc1",   0x35, 0, 0, 0, OPF_FT_IMM_RS},
    {"swc1",   0x39, 0, 0, 0, OPF_FT_IMM_RS},
    {"sdc1",   0x3d, 0, 0, 0, OPF_FT_IMM_RS},

    {"add.s",  0x11, 0x00, FMT_S, 0, OPF_FD_FS_FT},
    {"add.d",  0x11, 0x00, FMT_D, 0, OPF_FD_FS_FT},
    {"sub.s",  0x11, 0x01, FMT_S, 0, OPF_FD_FS_FT},
    {"sub.d",  0x11, 0x01, FMT_D, 0, OPF_FD_FS_FT},
    {"mul.s",  0x11, 0x02, FMT_S, 0, OPF_FD_FS_FT},
    {"mul.d",  0x11, 0x02, FMT_D, 0, OPF_FD_FS_FT},
    {"div.s",  0x11, 0x03, FMT_S, 0, OPF_FD_FS_FT},
    {"div.d",  0x11, 0x03, FMT_D, 0, OPF_FD_FS_FT},

    {"c.eq.s", 0x11, 0x32, FMT_S, 0, OPF_FS_FT},
    {"c.lt.s", 0x11, 0x3c, FMT_S, 0, OPF_FS_FT},
    {"c.le.s", 0x11, 0x3e, FMT_S, 0, OPF_FS_FT},
    {"c.eq.d", 0x11, 0x32, FMT_D, 0, OPF_FS_FT},
    {"c.lt.d", 0x11, 0x3c, FMT_D, 0, OPF_FS_FT},
    {"c.le.d", 0x11, 0x3e, FMT_D, 0, OPF_FS_FT},

    {"bc1t",   0x11, 0, FMT_BC, 1, OPF_IMM},
    {"bc1f",   0x11, 0, FMT_BC, 0, OPF_IMM},
};
#define ASM_TABLE_LEN (sizeof(AsmTable) / sizeof(AsmTable[0]))

static const char *AsmGprNames[32] = {
    "zero","at","v0","v1","a0","a1","a2","a3",
    "t0","t1","t2","t3","t4","t5","t6","t7",
    "s0","s1","s2","s3","s4","s5","s6","s7",
    "t8","t9","k0","k1","gp","sp","fp","ra"
};

typedef struct {
    char     name[64];
    uint32_t addr;
} AsmLabel;

static AsmLabel AsmLabels[ASM_MAX_LABELS];
static int      AsmLabelCount = 0;
static int      AsmErrorCount = 0;

typedef struct {
    int      has_label;
    char     label[64];
    char     opcode[24];
    char     operand[ASM_OPERAND_LEN];
    uint32_t addr;
} AsmLine;

static AsmLine AsmLines[ASM_MAX_LINES];
static int     AsmLineCount = 0;

static void AsmAddLabel(const char *name, uint32_t addr)
{
    if (AsmLabelCount >= ASM_MAX_LABELS) {
        fprintf(stderr, "asm error: too many labels\n");
        AsmErrorCount++;
        return;
    }
    snprintf(AsmLabels[AsmLabelCount].name, sizeof(AsmLabels[0].name), "%s", name);
    AsmLabels[AsmLabelCount].addr = addr;
    AsmLabelCount++;
}

static int AsmFindLabel(const char *name, uint32_t *addr_out)
{
    for (int i = 0; i < AsmLabelCount; i++) {
        if (strcmp(AsmLabels[i].name, name) == 0) {
            *addr_out = AsmLabels[i].addr;
            return 1;
        }
    }
    return 0;
}

/* ラベル名または数値（10進・0x接頭辞16進・負数）を評価する */
static long AsmEvalConst(const char *tok)
{
    uint32_t addr;
    if (AsmFindLabel(tok, &addr)) return (long)addr;
    char *end;
    long v = strtol(tok, &end, 0);
    if (end == tok || *end != '\0') {
        fprintf(stderr, "asm error: cannot evaluate '%s'\n", tok);
        AsmErrorCount++;
        return 0;
    }
    return v;
}

/* Python の "//"（負方向への切り捨て = floor除算）と同じ意味の除算 */
static long AsmFloorDiv(long a, long b)
{
    long q = a / b;
    long r = a % b;
    if (r != 0 && ((r < 0) != (b < 0))) q--;
    return q;
}

static int AsmRegNum(const char *tok)
{
    if (tok == NULL || tok[0] != '$') {
        fprintf(stderr, "asm error: bad register operand '%s'\n", tok ? tok : "(null)");
        AsmErrorCount++;
        return 0;
    }
    const char *name = tok + 1;
    for (int i = 0; i < 32; i++) {
        if (strcmp(name, AsmGprNames[i]) == 0) return i;
    }
    char *end;
    long v = strtol(name, &end, 10);
    if (*end == '\0' && v >= 0 && v < 32) return (int)v;
    fprintf(stderr, "asm error: unknown register '%s'\n", tok);
    AsmErrorCount++;
    return 0;
}

static int AsmFRegNum(const char *tok)
{
    if (tok == NULL || tok[0] != '$' || tok[1] != 'f') {
        fprintf(stderr, "asm error: bad float register operand '%s'\n", tok ? tok : "(null)");
        AsmErrorCount++;
        return 0;
    }
    char *end;
    long v = strtol(tok + 2, &end, 10);
    if (*end == '\0' && v >= 0 && v < 32) return (int)v;
    fprintf(stderr, "asm error: unknown float register '%s'\n", tok);
    AsmErrorCount++;
    return 0;
}

static uint32_t AsmTypeR(uint32_t op, uint32_t rs, uint32_t rt, uint32_t rd, uint32_t shamt, uint32_t funct)
{
    return (op << 26) | ((rs & 0x1F) << 21) | ((rt & 0x1F) << 16) |
           ((rd & 0x1F) << 11) | ((shamt & 0x1F) << 6) | (funct & 0x3F);
}
static uint32_t AsmTypeI(uint32_t op, uint32_t rs, uint32_t rt, uint32_t imm)
{
    return (op << 26) | ((rs & 0x1F) << 21) | ((rt & 0x1F) << 16) | (imm & 0xFFFF);
}
static uint32_t AsmTypeJ(uint32_t op, uint32_t addr)
{
    return (op << 26) | (addr & 0x3FFFFFF);
}
static uint32_t AsmTypeFR(uint32_t op, uint32_t fmt, uint32_t ft, uint32_t fs, uint32_t fd, uint32_t funct)
{
    return (op << 26) | ((fmt & 0x1F) << 21) | ((ft & 0x1F) << 16) |
           ((fs & 0x1F) << 11) | ((fd & 0x1F) << 6) | (funct & 0x3F);
}
static uint32_t AsmTypeFI(uint32_t op, uint32_t fmt, uint32_t ft, uint32_t imm)
{
    return (op << 26) | ((fmt & 0x1F) << 21) | ((ft & 0x1F) << 16) | (imm & 0xFFFF);
}

/* 空白（スペース/タブ）区切りでトークン化する（Python の str.split() 相当） */
static int AsmTokenize(char *line, char *tokens[], int maxtok)
{
    int n = 0;
    char *tok = strtok(line, " \t\r\n");
    while (tok != NULL && n < maxtok) {
        tokens[n++] = tok;
        tok = strtok(NULL, " \t\r\n");
    }
    return n;
}

/* "imm(rs)" 形式のオペランドを imm 部分とレジスタ部分に分割する */
static void AsmSplitMem(char *s, char **imm_out, char **reg_out)
{
    char *lp = strchr(s, '(');
    if (lp == NULL) {
        fprintf(stderr, "asm error: '(' is required in '%s'\n", s);
        AsmErrorCount++;
        *imm_out = s;
        *reg_out = "$zero";
        return;
    }
    *lp = '\0';
    char *rp = strchr(lp + 1, ')');
    if (rp == NULL) {
        fprintf(stderr, "asm error: ')' is required in '%s'\n", s);
        AsmErrorCount++;
    } else {
        *rp = '\0';
    }
    *imm_out = s;
    *reg_out = lp + 1;
}

/* カンマ区切りのオペランドを最大 maxparts 個のトークンに分割する */
static int AsmSplitCommas(char *s, char *parts[], int maxparts)
{
    int n = 0;
    char *tok = strtok(s, ",");
    while (tok != NULL && n < maxparts) {
        parts[n++] = tok;
        tok = strtok(NULL, ",");
    }
    return n;
}

static const AsmInstrDef *AsmFindInstr(const char *mnemonic)
{
    for (size_t i = 0; i < ASM_TABLE_LEN; i++) {
        if (strcmp(AsmTable[i].mnemonic, mnemonic) == 0) return &AsmTable[i];
    }
    return NULL;
}

/* ---- パス1: ソースを読み込み、ラベルのアドレスを計算する -------------- */
static int AsmPass1(const char *filename)
{
    FILE *fp = fopen(filename, "r");
    if (fp == NULL) {
        perror(filename);
        return 0;
    }

    char rawline[ASM_LINE_LEN];
    uint32_t pc = 0;
    AsmLineCount = 0;
    AsmLabelCount = 0;
    AsmErrorCount = 0;

    while (fgets(rawline, sizeof(rawline), fp) != NULL) {
        char work[ASM_LINE_LEN];
        snprintf(work, sizeof(work), "%s", rawline);

        /* 行頭文字（トークン化前）でラベル有無を判定する。
           ラベル無し行は空白から、ラベル付き行は英数字から始まる。 */
        int has_label = (work[0] != '\0' && isalnum((unsigned char)work[0]));

        char *tokens[64];
        int ntok = AsmTokenize(work, tokens, 64);
        if (ntok == 0) continue;   /* 空行 */

        if (AsmLineCount >= ASM_MAX_LINES) {
            fprintf(stderr, "asm error: too many lines (limit %d)\n", ASM_MAX_LINES);
            AsmErrorCount++;
            break;
        }
        AsmLine *L = &AsmLines[AsmLineCount];
        memset(L, 0, sizeof(*L));
        L->addr = pc;

        int idx = 0;
        if (has_label) {
            char label[64];
            snprintf(label, sizeof(label), "%s", tokens[0]);
            size_t len = strlen(label);
            if (len > 0 && label[len - 1] == ':') label[len - 1] = '\0';
            else { fprintf(stderr, "asm error: label error: %s\n", rawline); AsmErrorCount++; }
            snprintf(L->label, sizeof(L->label), "%s", label);
            L->has_label = 1;
            idx = 1;
        }
        if (idx >= ntok) { fprintf(stderr, "asm error: missing opcode: %s\n", rawline); AsmErrorCount++; continue; }
        snprintf(L->opcode, sizeof(L->opcode), "%s", tokens[idx]);
        idx++;

        L->operand[0] = '\0';
        for (int k = idx; k < ntok; k++) strncat(L->operand, tokens[k], sizeof(L->operand) - strlen(L->operand) - 1);

        if (L->has_label) AsmAddLabel(L->label, pc);

        if (strcmp(L->opcode, "START") == 0) {
            pc = (uint32_t)strtol(L->operand, NULL, 0);
        } else if (strcmp(L->opcode, "DATA") == 0) {
            int cnt = 1;
            for (char *p = L->operand; *p; p++) if (*p == ',') cnt++;
            pc += (uint32_t)cnt * 4;
        } else {
            pc += 4;
        }

        AsmLineCount++;
    }

    fclose(fp);
    return 1;
}

/* ---- パス2: 機械語を生成しメモリへ書き込む ----------------------------- */
static uint32_t AsmPass2(MEMORY *mem)
{
    uint32_t entry_pc = 0;
    int entry_set = 0;

    for (int i = 0; i < AsmLineCount; i++) {
        AsmLine *L = &AsmLines[i];
        uint32_t PCcur = L->addr;
        char operand[ASM_OPERAND_LEN];
        snprintf(operand, sizeof(operand), "%s", L->operand);

        if (strcmp(L->opcode, "START") == 0) {
            if (!entry_set) {
                entry_pc = (uint32_t)strtol(L->operand, NULL, 0);
                entry_set = 1;
            }
            continue;
        }
        if (strcmp(L->opcode, "BREAK") == 0) {
            MMwriteWord(mem, (MADDR)PCcur, 0x0000000Cu);
            continue;
        }
        if (strcmp(L->opcode, "DATA") == 0) {
            char *parts[64];
            int n = AsmSplitCommas(operand, parts, 64);
            uint32_t addr = PCcur;
            for (int k = 0; k < n; k++) {
                uint32_t val = (uint32_t)AsmEvalConst(parts[k]);
                MMwriteWord(mem, (MADDR)addr, val);
                addr += 4;
            }
            continue;
        }

        const AsmInstrDef *def = AsmFindInstr(L->opcode);
        if (def == NULL) {
            fprintf(stderr, "asm error: unknown mnemonic '%s' (line addr 0x%08X)\n", L->opcode, PCcur);
            AsmErrorCount++;
            continue;
        }

        uint32_t code = 0;
        char *parts[8];
        int n;

        switch (def->operand) {
            case OPF_RD_RS_RT:
                n = AsmSplitCommas(operand, parts, 3);
                if (n != 3) { fprintf(stderr, "asm error: %s expects rd,rs,rt\n", L->opcode); AsmErrorCount++; break; }
                code = AsmTypeR(def->opcode, AsmRegNum(parts[1]), AsmRegNum(parts[2]), AsmRegNum(parts[0]), 0, def->funct);
                break;
            case OPF_RD_RT_SHAMT:
                n = AsmSplitCommas(operand, parts, 3);
                if (n != 3) { fprintf(stderr, "asm error: %s expects rd,rt,shamt\n", L->opcode); AsmErrorCount++; break; }
                code = AsmTypeR(def->opcode, 0, AsmRegNum(parts[1]), AsmRegNum(parts[0]),
                                (uint32_t)AsmEvalConst(parts[2]) & 0x1F, def->funct);
                break;
            case OPF_RD_RS:
                n = AsmSplitCommas(operand, parts, 2);
                if (n != 2) { fprintf(stderr, "asm error: %s expects rd,rs\n", L->opcode); AsmErrorCount++; break; }
                code = AsmTypeR(def->opcode, AsmRegNum(parts[1]), 0, AsmRegNum(parts[0]), 0, def->funct);
                break;
            case OPF_RS_RT:
                n = AsmSplitCommas(operand, parts, 2);
                if (n != 2) { fprintf(stderr, "asm error: %s expects rs,rt\n", L->opcode); AsmErrorCount++; break; }
                code = AsmTypeR(def->opcode, AsmRegNum(parts[0]), AsmRegNum(parts[1]), 0, 0, def->funct);
                break;
            case OPF_RD:
                code = AsmTypeR(def->opcode, 0, AsmRegNum(operand), 0, 0, def->funct);
                break;
            case OPF_RS:
                code = AsmTypeR(def->opcode, AsmRegNum(operand), 0, 0, 0, def->funct);
                break;
            case OPF_RT_RS_IMM:
                n = AsmSplitCommas(operand, parts, 3);
                if (n != 3) { fprintf(stderr, "asm error: %s expects rt,rs,imm\n", L->opcode); AsmErrorCount++; break; }
                code = AsmTypeI(def->opcode, AsmRegNum(parts[1]), AsmRegNum(parts[0]),
                                (uint32_t)AsmEvalConst(parts[2]) & 0xFFFF);
                break;
            case OPF_RT_RS_ADDR: {
                n = AsmSplitCommas(operand, parts, 3);
                if (n != 3) { fprintf(stderr, "asm error: %s expects rt,rs,addr\n", L->opcode); AsmErrorCount++; break; }
                long target = AsmEvalConst(parts[2]);
                long imm = AsmFloorDiv(target - (long)PCcur - 2, 4) & 0xFFFF;
                code = AsmTypeI(def->opcode, AsmRegNum(parts[1]), AsmRegNum(parts[0]), (uint32_t)imm);
                break;
            }
            case OPF_RT_IMM_RS: {
                n = AsmSplitCommas(operand, parts, 2);
                if (n != 2) { fprintf(stderr, "asm error: %s expects rt,imm(rs)\n", L->opcode); AsmErrorCount++; break; }
                char *immtok, *regtok;
                AsmSplitMem(parts[1], &immtok, &regtok);
                code = AsmTypeI(def->opcode, AsmRegNum(regtok), AsmRegNum(parts[0]),
                                (uint32_t)AsmEvalConst(immtok) & 0xFFFF);
                break;
            }
            case OPF_RT_IMM:
                n = AsmSplitCommas(operand, parts, 2);
                if (n != 2) { fprintf(stderr, "asm error: %s expects rt,imm\n", L->opcode); AsmErrorCount++; break; }
                code = AsmTypeI(def->opcode, 0, AsmRegNum(parts[0]), (uint32_t)AsmEvalConst(parts[1]) & 0xFFFF);
                break;
            case OPF_FT_IMM_RS: {
                n = AsmSplitCommas(operand, parts, 2);
                if (n != 2) { fprintf(stderr, "asm error: %s expects ft,imm(rs)\n", L->opcode); AsmErrorCount++; break; }
                char *immtok, *regtok;
                AsmSplitMem(parts[1], &immtok, &regtok);
                code = AsmTypeI(def->opcode, AsmRegNum(regtok), AsmFRegNum(parts[0]),
                                (uint32_t)AsmEvalConst(immtok) & 0xFFFF);
                break;
            }
            case OPF_ADDR: {
                long target = AsmEvalConst(operand);
                long imm = AsmFloorDiv(target, 4) & 0x3FFFFFF;
                code = AsmTypeJ(def->opcode, (uint32_t)imm);
                break;
            }
            case OPF_FD_FS_FT:
                n = AsmSplitCommas(operand, parts, 3);
                if (n != 3) { fprintf(stderr, "asm error: %s expects fd,fs,ft\n", L->opcode); AsmErrorCount++; break; }
                code = AsmTypeFR(def->opcode, def->fmt, AsmFRegNum(parts[2]), AsmFRegNum(parts[1]),
                                 AsmFRegNum(parts[0]), def->funct);
                break;
            case OPF_FS_FT:
                n = AsmSplitCommas(operand, parts, 2);
                if (n != 2) { fprintf(stderr, "asm error: %s expects fs,ft\n", L->opcode); AsmErrorCount++; break; }
                code = AsmTypeFR(def->opcode, def->fmt, AsmFRegNum(parts[1]), AsmFRegNum(parts[0]), 0, def->funct);
                break;
            case OPF_IMM: {
                long target = AsmEvalConst(operand);
                long imm = AsmFloorDiv(target - (long)PCcur - 2, 4) & 0xFFFF;
                code = AsmTypeFI(def->opcode, def->fmt, def->ft, (uint32_t)imm);
                break;
            }
        }

        MMwriteWord(mem, (MADDR)PCcur, code);
    }

    return entry_pc;
}

/* ソースファイルをアセンブルしてメモリに配置し、開始アドレス(START)を返す */
static uint32_t AssembleFile(const char *filename, MEMORY *mem, int *ok)
{
    *ok = AsmPass1(filename);
    if (!*ok) return 0;
    uint32_t entry = AsmPass2(mem);
    if (AsmErrorCount > 0) {
        fprintf(stderr, "asm: finished with %d error(s)\n", AsmErrorCount);
    }
    printf("Assembled %d line(s) from \"%s\" (%d label(s), entry=0x%08X).\n",
           AsmLineCount, filename, AsmLabelCount, entry);
    return entry;
}

/* ==========================================================================
 * MIPS レジスタ名(表示用)
 * ========================================================================*/
static const char *RegName[NUM_GPR] = {
    "zero","at","v0","v1","a0","a1","a2","a3",
    "t0","t1","t2","t3","t4","t5","t6","t7",
    "s0","s1","s2","s3","s4","s5","s6","s7",
    "t8","t9","k0","k1","gp","sp","fp","ra"
};

static void PrintState(void)
{
    printf("\n===== Simulation finished (exit=%d, cycles=%lld) =====\n",
           SimExitCode, CycleCount);
    printf("PC = 0x%08X\n", PC);
    for (int i = 0; i < NUM_GPR; i++) {
        printf("$%-4s(%2d) = %-12u", RegName[i], i, GPR[i]);
        if (i % 4 == 3) printf("\n");
    }
    printf("\nHI = %u, LO = %u\n", HI, LO);
}

/* ==========================================================================
 * main:
 *   ./mips file.txt        file.txt を MIPS アセンブリとしてアセンブルして実行
 *   ./mips -x file.hex     file.hex を「1行1語の16進機械語」として読み込み実行
 * ========================================================================*/

int main(int argc, char *argv[])
{
    MEM_SIZE = 4096;
    MEM = MMalloc(MEM_SIZE);
    if (MEM == NULL) {
        fprintf(stderr, "error: failed to allocate simulator memory\n");
        return EXIT_FAILURE;
    }

    uint32_t entry_pc = 0;

    if (argc >= 3 && strcmp(argv[1], "-x") == 0) {
        /* 生の16進機械語ファイルを読み込むモード(デバッグ用) */
        FILE *fp = fopen(argv[2], "r");
        if (fp == NULL) {
            perror(argv[2]);
            free(MEM);
            return EXIT_FAILURE;
        }
        uint32_t *buf = (uint32_t *)malloc(sizeof(uint32_t) * (MEM_SIZE / 4));
        size_t n = 0;
        while (n < MEM_SIZE / 4 && fscanf(fp, "%x", &buf[n]) == 1) n++;
        fclose(fp);
        MMloadProgram(MEM, 0, buf, n);
        free(buf);
        printf("Loaded %zu word(s) from \"%s\" (raw hex mode).\n", n, argv[2]);
    } else if (argc >= 2) {
        /* MIPSアセンブリのソースファイルを直接アセンブルする */
        int ok = 0;
        entry_pc = AssembleFile(argv[1], MEM, &ok);
        if (!ok) { free(MEM); return EXIT_FAILURE; }
    } else {
        /* 引数無し(入力ファイル未指定)の場合は、命令が一つも無いので
           アセンブルもシミュレーションも行わずに終了する */
        fprintf(stderr, "usage: %s <file.txt> | -x <file.hex>\n",
                (argc >= 1) ? argv[0] : "mips");
        free(MEM);
        return EXIT_FAILURE;
    }

    memset(GPR, 0, sizeof(GPR));
    memset(FPR, 0, sizeof(FPR));
    memset(CR,  0, sizeof(CR));
    HI = LO = 0;
    FPcond = 0;
    PC = entry_pc;
    SimHalted = 0;
    SimExitCode = 0;
    CycleCount = 0;
    LinkValid = 0;
    LinkAddr = 0;

    /* マルチサイクル実行: 1回のループで1命令を IF->ID->EX->MEM->WB まで
       完全に処理する。分岐/ジャンプの結果は MEM ステージで PC に反映され、
       次のループの IF ステージが正しいアドレスをフェッチする。 */
    while (!SimHalted) {
        IF_stage();
        ID_stage();
        EX_stage();
        MEM_stage();
        WB_stage();
    }

    PrintState();

    free(MEM);
    return SimExitCode;
}
