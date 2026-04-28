#include    <stdio.h>
#include    <stdlib.h>
#include    <string.h>
#include    <ctype.h>
#include    "define.h"
#include    "vm.h"
#include    "label_table.h"

#define BUF_LEN         5000
#define N_TOKENS        10

static char *opcode_dic[] = {
    "halt",
    "pushl",
    "storel",
    "storet",
    "pushi",
    "call",
    "ret",
    "enter",
    "leave",
    "mvsp",
    "jp",
    "jt",
    "jf",
    "add",
    "sub",
    "mul",
    "div",
    "mod",
    "eq",
    "ne",
    "gt",
    "ge",
    "lt",
    "le",
    "rd",
    "wr",
    "wrln",
    NULL
};

static int
load_pass1(vm_t *vm,FILE *fp,label_table_t *label_table);

static int
load_pass2(vm_t *vm,FILE *fp,label_table_t *label_table);

static int
read_line(FILE *fp,char *label,char *opcode,char *operand);

static int
read_tokens(FILE *fp,char (*token)[BUF_LEN]);

static char *
skip_blank(char *b);

static int
str2opcode(char *op);

static void
tolower_str(char *str);

static void
exec_halt(vm_t *vm);

static void
exec_pushl(vm_t *vm);

static void
exec_storel(vm_t *vm);

static void
exec_storet(vm_t *vm);

static void
exec_pushi(vm_t *vm);

static void
exec_call(vm_t *vm);

static void
exec_ret(vm_t *vm);

static void
exec_enter(vm_t *vm);

static void
exec_leave(vm_t *vm);

static void
exec_mvsp(vm_t *vm);

static void
exec_jp(vm_t *vm);

static void
exec_jt(vm_t *vm);

static void
exec_jf(vm_t *vm);

static void
exec_add(vm_t *vm);

static void
exec_sub(vm_t *vm);

static void
exec_mul(vm_t *vm);

static void
exec_div(vm_t *vm);

static void
exec_mod(vm_t *vm);

static void
exec_eq(vm_t *vm);

static void
exec_ne(vm_t *vm);

static void
exec_gt(vm_t *vm);

static void
exec_ge(vm_t *vm);

static void
exec_lt(vm_t *vm);

static void
exec_le(vm_t *vm);

static void
exec_rd(vm_t *vm);

static void
exec_wr(vm_t *vm);

static void
exec_wrln(vm_t *vm);

static void
push(vm_t *vm,int d);

static int
pop(vm_t *vm);

static int
peek(vm_t *vm);

static void
inc_sp(vm_t *vm);

static void
dec_sp(vm_t *vm);

static void
inc_pc(vm_t *vm);

static void (*(func_table[]))(vm_t *vm) = {
    exec_halt,
    exec_pushl,
    exec_storel,
    exec_storet,
    exec_pushi,
    exec_call,
    exec_ret,
    exec_enter,
    exec_leave,
    exec_mvsp,
    exec_jp,
    exec_jt,
    exec_jf,
    exec_add,
    exec_sub,
    exec_mul,
    exec_div,
    exec_mod,
    exec_eq,
    exec_ne,
    exec_gt,
    exec_ge,
    exec_lt,
    exec_le,
    exec_rd,
    exec_wr,
    exec_wrln
};

#define OPERAND(vm)     ((vm)->imem[(vm)->pc].operand)
#define OPCODE(vm)      ((vm)->imem[(vm)->pc].opcode)

vm_t *
vm_new(void)
{
    vm_t    *vm;

    if ((vm = malloc(sizeof(*vm))) != NULL){
        vm->pc = 0;
        vm->sp = VM_STACK_SIZE;
        vm->fp = VM_STACK_SIZE;
    }
    return (vm);
}

void
vm_delete(vm_t *vm)
{
    free(vm);
}

int
vm_load(vm_t *vm,char *file)
{
    FILE    *fp;
    label_table_t   *label_table;
    int     size;

    if ((label_table = label_table_new()) == NULL){
        return (-1);
    }
    if ((fp = fopen(file,"r")) == NULL){
        return (-1);
    }
    load_pass1(vm,fp,label_table);
    rewind(fp);
    size = load_pass2(vm,fp,label_table);
    label_table_delete(label_table);
    fclose(fp);
    return (size);
}

int
load_pass1(vm_t *vm,FILE *fp,label_table_t *label_table)
{
    int     i;
    char    label[BUF_LEN], opcode[BUF_LEN], operand[BUF_LEN];
    opcode_t    op;

    i = 0;
    while (read_line(fp,label,opcode,operand)){
        if (strcmp(label,"") != 0){
            if (!label_table_add(label_table,label,i)){
                /* たぶん 2 重定義 */
                fprintf(stderr,"2 重定義? %s\n",label);
                return (-1);
            }
        }
        if (strcmp(opcode,"") != 0){
            if((op = str2opcode(opcode)) < 0){
                /* 不正な opcode */
                fprintf(stderr,"不正な opcode:%s\n",opcode);
                return (-1);
            }
            vm->imem[i].opcode = op;
            if (strcmp(operand,"") != 0){
                if (isdigit(*operand) || *operand == '-'){
                    vm->imem[i].operand = atoi(operand);
                }else{
                    /* ラベルの値は pass2 で決定する．とりあえず 0 をいれる */
                    vm->imem[i].operand = 0;
                }
            }else{
                vm->imem[i].operand = 0;
            }
            i++;
        }
    }
    return (i);
}

int
load_pass2(vm_t *vm,FILE *fp,label_table_t *label_table)
{
    int     i;
    char    label[BUF_LEN], opcode[BUF_LEN], operand[BUF_LEN];
    opcode_t    op;
    int         address;

    i = 0;
    while (read_line(fp,label,opcode,operand)){
        if (strcmp(opcode,"") != 0){
            if (strcmp(operand,"") != 0){
                if (!isdigit(*operand) && *operand != '-'){
                    if (!label_table_search(label_table,operand,&address)){
                        /* たぶん未定義ラベル */
                        fprintf(stderr,"未定義ラベル? %s\n",operand);
                        return (-1);
                    }
                    vm->imem[i].operand = address;
                }
            }
            i++;
        }
    }
    return (i);
}

int
read_line(FILE *fp,char *label,char *opcode,char *operand)
{
    char    token[N_TOKENS][BUF_LEN];
    int     i,n;

    *label = '\0';
    *opcode = '\0';
    *operand = '\0';
    if ((n = read_tokens(fp,token)) < 0){
        return (FALSE);
    }
    i = 0;
    if (n >=2){
        if (strcmp(token[1],":") == 0){
            strcpy(label,token[0]);
            i = 2;
        }
    }
    if (strcmp(token[i],"") != 0){
        strcpy(opcode,token[i]);
    }
    if (strcmp(token[i + 1],"") != 0){
        strcpy(operand,token[i + 1]);
    }
    return (TRUE);
}

int
read_tokens(FILE *fp,char (*token)[BUF_LEN])
{
    int n;
    char    buf[BUF_LEN];
    char    *b,*t;

    if (fgets(buf,BUF_LEN,fp) == NULL){
        return (-1);
    }
    b = buf;
    n = 0;
    while (*b != '\0' && *b != '#'){
        b = skip_blank(b);
        if (*b == ':'){
            strcpy(*token, ":");
            b++;
        }else{
            t = *token;
            while (*b != '\0' && *b != '\n' && *b != ':' && *b != '#' && !isspace(*b)){
                *t = *b;
                t++;
                b++;
            }
            *t = '\0';
        }
        token++;
        n++;
    }
    strcpy(*token,"");
    return (n);
}

char *skip_blank(char *b)
{
    while (isblank(*b) || *b == '\n'){
        b++;
    }
    return (b);
}

int
str2opcode(char *op)
{
    int i;

    tolower_str(op);
    i = 0;
    while (opcode_dic[i] != NULL){
        if (strcmp(opcode_dic[i], op) == 0){
            return (i);
        }
        i++;
    }
    return (-1);
}

void
tolower_str(char *str)
{
    while (*str != '\0'){
        *str = tolower((unsigned char)*str);
        str++;
    }
}

void
vm_step(vm_t *vm)
{
    vm->next_pc = (vm->pc + 1) % VM_INSTRUCTION_MEMORY_SIZE;
    (*func_table[OPCODE(vm)])(vm);
    vm->pc = vm->next_pc;
}

vm_status_t
vm_get_status(vm_t *vm)
{
    return (vm->status);
}

void
vm_dump_imem(vm_t *vm,int start,int len)
{
    int     i;

    for (i = start;i < start + len;i++){
        printf(
            "%4d: %s\t%4d(%2d %4d)\n",
            i,opcode_dic[vm->imem[i].opcode],vm->imem[i].operand,
            vm->imem[i].opcode,vm->imem[i].operand
        );
    }
}

void
vm_dump_stack(vm_t *vm, int size)
{
    int     p;

    if (size <= 0){
        size = VM_STACK_SIZE - vm->sp;
    }
    p = vm->sp + size - 1;
    while (size > 0){
        printf("%04d %05d",p,vm->stack[p]);
        if (p == vm->fp){
            printf(" <-- FP");
        }
        if (p == vm->sp){
            printf(" <-- SP");
        }
        printf("\n");
        p--;
        size--;
    } 
}

void
vm_dump_registers(vm_t *vm)
{
    printf(
        "pc=%05d sp=%05d fp=%05d status=%05d\t%s\t%4d(%2d %4d)\n",
        vm->pc,vm->sp,vm->fp,vm->status,
        opcode_dic[vm->imem[vm->pc].opcode],vm->imem[vm->pc].operand,
        vm->imem[vm->pc].opcode,vm->imem[vm->pc].operand
    );
}

void
exec_halt(vm_t *vm)
{
    vm->status = VM_HALT;
}

void
exec_pushl(vm_t *vm)
{
    push(vm,vm->stack[vm->fp + OPERAND(vm)]);
}

void
exec_storel(vm_t *vm)
{
    vm->stack[vm->fp + OPERAND(vm)] = peek(vm);
}

void
exec_storet(vm_t *vm)
{
    vm->stack[vm->sp + OPERAND(vm)] = peek(vm);
}

void
exec_pushi(vm_t *vm)
{
    push(vm,OPERAND(vm));
}

void
exec_call(vm_t *vm)
{
    push(vm,vm->pc + 1);
    vm->next_pc = OPERAND(vm);
}

void
exec_ret(vm_t *vm)
{
    vm->next_pc = pop(vm);
}

void
exec_enter(vm_t *vm)
{
    push(vm,vm->fp);
    vm->fp = vm->sp;
}

void
exec_leave(vm_t *vm)
{
    vm->sp = vm->fp;
    vm->fp = pop(vm);
}

void
exec_mvsp(vm_t *vm)
{
    vm->sp += OPERAND(vm);
}

void
exec_jp(vm_t *vm)
{
    vm->next_pc = OPERAND(vm);
}

void
exec_jt(vm_t *vm)
{
    if (pop(vm)){
        vm->next_pc = OPERAND(vm);
    }
}

void
exec_jf(vm_t *vm)
{
    if (!pop(vm)){
        vm->next_pc = OPERAND(vm);
    }
}


void
exec_add(vm_t *vm)
{
    int d1,d2;

    d2 = pop(vm);
    d1 = pop(vm);
    push(vm,d1 + d2);
}

void
exec_sub(vm_t *vm)
{
    int d1,d2;

    d2 = pop(vm);
    d1 = pop(vm);
    push(vm,d1 - d2);
}

void
exec_mul(vm_t *vm)
{
    int d1,d2;

    d2 = pop(vm);
    d1 = pop(vm);
    push(vm,d1 * d2);
}

void
exec_div(vm_t *vm)
{
    int d1,d2;

    d2 = pop(vm);
    d1 = pop(vm);
    push(vm,d1 / d2);
}

void
exec_mod(vm_t *vm)
{
    int d1,d2;

    d2 = pop(vm);
    d1 = pop(vm);
    push(vm,d1 % d2);
}

void
exec_eq(vm_t *vm)
{
    int d1,d2;

    d2 = pop(vm);
    d1 = pop(vm);
    push(vm,d1 == d2);
}

void
exec_ne(vm_t *vm)
{
    int d1,d2;

    d2 = pop(vm);
    d1 = pop(vm);
    push(vm,d1 != d2);
}

void
exec_gt(vm_t *vm)
{
    int d1,d2;

    d2 = pop(vm);
    d1 = pop(vm);
    push(vm,d1 > d2);
}

void
exec_ge(vm_t *vm)
{
    int d1,d2;

    d2 = pop(vm);
    d1 = pop(vm);
    push(vm,d1 >= d2);
}

void
exec_lt(vm_t *vm)
{
    int d1,d2;

    d2 = pop(vm);
    d1 = pop(vm);
    push(vm,d1 < d2);
}

void
exec_le(vm_t *vm)
{
    int d1,d2;

    d2 = pop(vm);
    d1 = pop(vm);
    push(vm,d1 <= d2);
}

void
exec_rd(vm_t *vm)
{
    int d;

    printf("? ");
    scanf("%d",&d);
    push(vm,d);
}

void
exec_wr(vm_t *vm)
{
    printf("%d ",pop(vm));
}

void
exec_wrln(vm_t *vm)
{
    printf("\n");
}

void
push(vm_t *vm,int d)
{
    dec_sp(vm);
    if (vm->sp >= 0){
        vm->stack[vm->sp] = d;
    }
}

int
pop(vm_t *vm)
{
    int d;

    if (vm->sp < VM_STACK_SIZE){
        d = vm->stack[vm->sp];
    }
    inc_sp(vm);
    return (d);
}

int
peek(vm_t *vm)
{
    return (vm->stack[vm->sp]);
}

void
inc_sp(vm_t *vm)
{
    vm->sp++;
    if (vm->sp > VM_STACK_SIZE){
        vm->status = VM_STACK_UNDERFLOW;
    }
}

void
dec_sp(vm_t *vm)
{
    vm->sp--;
    if (vm->sp < 0){
        vm->status = VM_STACK_OVERFLOW;
    }
}

void
inc_pc(vm_t *vm)
{
    vm->pc = (vm->pc + 1) % VM_INSTRUCTION_MEMORY_SIZE;
}
