/* 2020-01-22 このファイルはもう使われていない */

#include	<stdio.h>
#include	"define.h"
#include	"codegen.h"

void
codegen_put_label(char *str)
{
	fprintf(stdout,"%s:\n",str);
}

void
codegen_put_code(char *opcode)
{
	fprintf(stdout,"\t%s",opcode);
	fputs("\n",stdout);
}

void
codegen_put_code_str(char *opcode, char *operand)
{
	fprintf(stdout,"\t%s",opcode);
	if (operand != NULL){
		fprintf(stdout,"\t%s",operand);
	}
	fputs("\n",stdout);
}

void
codegen_put_code_num(char *opcode, int operand)
{
	fprintf(stdout,"\t%s",opcode);
	fprintf(stdout,"\t%d",operand);
	fputs("\n",stdout);
}

void
codegen_put_comment(char *comment, int indent)
{
	while (indent > 0){
		fprintf(stdout,"\t");
		indent--;
	}
	fprintf(stdout,"#%s\n",comment);
}
