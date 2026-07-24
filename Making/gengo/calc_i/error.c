#include	<stdio.h>
#include	<stdlib.h>
#include	"error.h"

/* エラーメッセージ str を表示する				*/
/* 引数 func, int はおもにデバッグ用であり，	*/
/* error() を呼び出した関数と行番号を表示する	*/
void
error(char *str,char *file,char *func,int line)
{
	fprintf(
		stderr,"Error:%s(%s:%s:%d)\n",str,file,func,line
	);
	exit(1);
}
