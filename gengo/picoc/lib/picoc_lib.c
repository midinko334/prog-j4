/* picoc の入出力命令ライブラリ								*/
/*															*/
/* rd, wr, wrln の各命令を実装								*/
/*															*/
/* x64 の環境で												*/
/*   a = read();  #ユーザプログラムで組込み関数 read 呼出し	*/
/*															*/
/*   read:        #組込み関数 read							*/
/*     ...													*/
/*     call picoc_rd	#picoc_rd が呼び出される			*/
/*     ...													*/
/*															*/
/* のように呼び出される										*/
/*															*/
/* Q: なぜこんな面倒な手順？								*/
/*															*/
/* A: picoc と gcc で呼出し規約が違うから					*/
/*    read の中で呼出し規約の違いを吸収している				*/

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

int picoc_rd(void);
void picoc_wr(int d);
void picoc_wrln(void);

/* __attribute((weak, alias("picoc_rd"))) int read(void);	*/
/* picoc のプログラムを gcc でコンパイルするためのトリック	*/
/* read を picoc_rd の別名として，しかも weak symbol として	*/
/* 定義している（らしい）									*/
/*															*/
/* 関数 read が存在しないときだけ下の read が有効になる		*/
/* picoc でコンパイルしたときは read は組込み関数として定義	*/
/* されるので，ここで定義する read は呼ばれない				*/
/* そのかわりに rd 命令をエミュレートする picoc_rd() として	*/
/* 呼び出される												*/
/*															*/
/* write, writeln も同様									*/
/*															*/
/* 一方 gcc でふつうの C プログラムとしてコンパイルすると，	*/
/* read 関数は組込み関数として定義されない					*/
/* そのときは，この read が呼ばれる							*/
/*															*/
/* % gcc -c picoc_lib.c										*/
/*															*/
/* % picoc_x64 < program.c > program.s						*/
/* % gcc program.s picoc_lib.o -o program_picoc_x64			*/
/*															*/
/* % gcc program.c picoc_lib.o -o program_gcc_x64			*/
/*															*/
/* program_picoc_x64 も program_gcc_x64 もちゃんと動く		*/

__attribute((weak, alias("picoc_rd"))) int read(void);
int picoc_rd(void)
{
	int r;
	char s[100];

	/* scanf を使うと，環境によって動かない	*/
	/* 理由は不明							*/
	/* とりあえず scanf を使わない			*/
	printf("? ");
	fgets(s,100,stdin);
	r = atoi(s);

	return (r);
}

__attribute((weak, alias("picoc_wr"))) void write(int d);
void picoc_wr(int d)
{
	printf("%d ",d);
}

__attribute((weak, alias("picoc_wrln"))) void writeln(void);
void picoc_wrln(void)
{
	printf("\n");
}
