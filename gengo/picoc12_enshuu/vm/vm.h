#ifndef VM_H_INCLUDED
#define VM_H_INCLUDED

#define VM_INSTRUCTION_MEMORY_SIZE      (10000)
#define VM_STACK_SIZE                   (10000)

typedef enum{
    HALT,
    PUSHL,
    STOREL,
    STORET,
    PUSHI,
    CALL,
    RET,
    ENTER,
    LEAVE,
    MVSP,
    JP,
    JT,
    JF,
    ADD,
    SUB,
    MUL,
    DIV,
    MOD,
    EQ,
    NE,
    GT,
    GE,
    LT,
    LE,
    RD,
    WR,
    WRLN
} opcode_t;

typedef struct{
    opcode_t    opcode;
    int         operand;
} instruction_t;

typedef enum{
    VM_RUNNING,
    VM_HALT,
    VM_PC_OUT_OF_RANGE,
    VM_STACK_OVERFLOW,
    VM_STACK_UNDERFLOW,
    VM_ILLEAGAL_INSTRUCTION
} vm_status_t;

typedef struct{
    instruction_t   imem[VM_INSTRUCTION_MEMORY_SIZE];
    int             stack[VM_STACK_SIZE];
    int             pc;
    int             sp;
    int             fp;
    int             next_pc;
    vm_status_t     status;
} vm_t;

extern vm_t *
vm_new(void);

extern void
vm_delete(vm_t *vm);

extern int
vm_load(vm_t *vm,char *file);

extern void
vm_step(vm_t *vm);

extern vm_status_t
vm_get_status(vm_t *vm);

extern void
vm_dump_imem(vm_t *vm,int start,int len);

extern void
vm_dump_stack(vm_t *vm,int size);

extern void
vm_dump_registers(vm_t *vm);

#endif
