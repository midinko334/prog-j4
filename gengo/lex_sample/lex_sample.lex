/* コンパイル＆実行					*/
/*									*/
/* $ lex lex_sample.lex				*/
/* $ cc lex.yy.c					*/
/* $ ./a.out						*/
/*    文字列を入力．終了は Ctrl+C	*/

%{
#include <stdio.h>
#include <stdlib.h>

/* 字句のシンボルを定義 */
enum {
	  LT,		/* <		*/
	  LE,		/* <=		*/
	  LSHIFT,	/* <<		*/
	  LSFT_ASGN,	/* <<=		*/
	  ID,		/* 識別子	*/
	  ERR
};

%}

/* 入力ファイルが一つであることを示す */
%option noyywrap

/* 字句の定義．正規表現による字句定義とマッチしたときのアクションのペア */
%%
[a-zA-Z_][a-zA-Z0-9_]* {printf("ID:%s\n",yytext); return ID; }
"<"		{ printf("LT\n"); return LT; }
"<="		{ printf("LE\n"); return LE; }
"<<"		{ printf("LSHIFT\n"); return LSHIFT; }
"<<="		{ printf("LSFT_ASGN\n"); return LSFT_ASGN; }
\/\/.*\n	{ printf("comment(//)\n"); }
.		{ printf("Unknown char\n"); return ERR; }
%%

int main(void)
{
	FILE *yyin = stdin;

	printf("lex のサンプルです．なにか入力してください．^\n終了は Ctrl+C\n");

	/* yylex は次の字句をとってくる関数 */
	while (1) printf("[%d]\n",yylex());
	return 0;
}
