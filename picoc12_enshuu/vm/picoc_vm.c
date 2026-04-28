#include    <stdio.h>
#include    <stdlib.h>
#include    "define.h"
#include    "vm.h"

static int
get_args(
    int argc,char **argv,char **file_name,int *dump_imem,
    int *trace_regs,int *trace_stack
);

int main(int argc,char **argv)
{
    vm_t    *vm;
    int     size;
    int     dump_imem = FALSE, trace_regs = FALSE, trace_stack = FALSE;
    char    *file_name;

    if (!get_args(argc,argv,&file_name,&dump_imem,&trace_regs,&trace_stack)){
        fprintf(stderr,"使い方: %s [-drs] 実行プログラム\n", argv[0]);
        exit(1);
    }

    vm = vm_new();
    size = vm_load(vm, file_name);
    printf("program size=%d\n\n",size);
    if (dump_imem){
        vm_dump_imem(vm,0,size);
    }
    fprintf(stderr,"\n");
    while (vm_get_status(vm) == VM_RUNNING){
        if (trace_stack){
            vm_dump_stack(vm,0);
            printf("\n");
        }
        if (trace_regs){
            vm_dump_registers(vm);
        }
        vm_step(vm);
    }
    //vm_dump_registers(vm);
}

int
get_args(
    int argc,char **argv,char **file_name,int *dump_imem,
    int *trace_regs,int *trace_stack
)
{
    argc--;
    argv++;
    while (argc > 1 && **argv == '-'){
        switch((*argv)[1]){
        case 'd':
            *dump_imem = TRUE;
            break;
        case 'r':
            *trace_regs = TRUE;
            break;
        case 's':
            *trace_stack = TRUE;
            break;
        }
        argc--;
        argv++;
    }
    if (argc == 1){
        *file_name = *argv;
        return (TRUE);
    }else{
        return (FALSE);
    }
}
