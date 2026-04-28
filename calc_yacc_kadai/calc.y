/*

電卓インタプリタプログラムの yacc 定義

文法
<statement>		::= <expression>.
<expression>	::= <expression> '+' <term> | <expression> '-' <term> | <term>.
<term>			::= <term> '*' <factor> | <term> '/' <factor> | <factor>.
<factor>		::= '+' <factor> | '-' <factor> | '(' <expression> ')' | NUMBER.


課題
(1) 割り算に対応しなさい
(2) () に対応しなさい
(3) 電卓コンパイラを作成しなさい

*/

%{
#include <stdio.h>
#include <string.h>

/* 宣言がないと警告が出てしまう？ */
extern int yyparse(void);
extern int yylex(void);
  
void yyerror(const char *str)
{
  fprintf(stderr,"error: %s\n",str);
}

int yywrap()
{
  return 1;
}

int main(void)
{
	return yyparse();
}

%}

%token NUMBER
%%
statement:
	expression
		{
			printf("= %d\n",$1);
		}
	;

expression:
	expression '+' term
		{
			$$ = $1 + $3;
		}
	|
	expression '-' term
		{
			$$ = $1 - $3;
		}
	|
	term
		{
			$$ = $1;
		}
	;

term:
	term '*' factor
		{
			$$ = $1 * $3;
		}
	|
	factor
		{
			$$ = $1;
		}
	;

factor:
	'+' factor
		{
			$$ = $2;
		}
	|
	'-' factor
		{
			$$ = - $2;
		}
	|
	NUMBER
		{
			$$ = $1;
		}
	;
%%
