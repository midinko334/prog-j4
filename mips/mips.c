#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mips_sim.h"

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

#define F_OPCODE(i) (((i) >> 26) & 0x3F)
#define F_RS(i)     (((i) >> 21) & 0x1F)
#define F_RT(i)     (((i) >> 16) & 0x1F)
#define F_RD(i)     (((i) >> 11) & 0x1F)
#define F_SHAMT(i)  (((i) >> 6)  & 0x1F)
#define F_FUNCT(i)  ((i) & 0x3F)
#define F_IMM16(i)  ((i) & 0xFFFF)
#define F_ADDR26(i) ((i) & 0x3FFFFFF)

#define FMT_S   0x10
#define FMT_D   0x11
#define FMT_BC  0x08

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

void IF_stage(void)
{
    if (SimHalted) return;

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
                fprintf(stderr, "[警告] div: ゼロ除算です。Lo,Hi は不定とします。\n");
                EXMEM.alu_result = 0; EXMEM.alu_result2 = 0;
            } else {
                EXMEM.alu_result  = (uint32_t)(srs / srt);
                EXMEM.alu_result2 = (uint32_t)(srs % srt);
            }
            break;
        case OP_DIVU:
            if (rt == 0) {
                fprintf(stderr, "[警告] divu: ゼロ除算です。Lo,Hi は不定とします。\n");
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
