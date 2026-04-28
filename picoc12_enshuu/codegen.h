/* 2020-01-22 このファイルはもう使われていない */

#ifndef CODEGEN_H_INCLUDED
#define CODEGEN_H_INCLUDED

extern void
codegen_put_label(char *str);

extern void
codegen_put_code(char *opcode);

extern void
codegen_put_code_str(char *opcode, char *operand);

extern void
codegen_put_code_num(char *opcode, int operand1);

extern void
codegen_put_comment(char *comment, int indent);

#endif
