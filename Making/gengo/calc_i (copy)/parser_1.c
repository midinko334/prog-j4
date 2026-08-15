#include	<stdio.h>
#include	<stdlib.h>
#include	"define.h"
#include	"scanner.h"
#include	"parser.h"
#include	"error.h"

/* 次の字句を先読みするための変数 */
static token_t	nextsym;

static void
parse_expression();

static void
parse_term(void);

static void
parse_number(void);

void
parser_init(void)
{
	nextsym = scanner_get_next_sym();
}

/* S ::= E ; */
int parser_parse_sentence(void)
{
	parse_expression();
	if (nextsym.sym != SYM_SEMICOLON){
		ERROR("';' が必要です");
	}
	/* ';' は式の終わりの記号なので，それ以上先読みをしない */
	/*nextsym = scanner_get_next_sym();*/
}
  
/* E ::= T { + T } */
static void
parse_expression(void)
{
	parse_term();
	while (nextsym.sym == SYM_PLUS){
		if (nextsym.sym == SYM_PLUS){
			nextsym = scanner_get_next_sym();
		}else{
			ERROR("'+' が必要です");
		}
		parse_term();
	}
}

/* T ::= N */
void
parse_term(void)
{
	parse_number();
}

void
parse_number(void)
{
	if (nextsym.sym == SYM_CONSTANT_INT){
		nextsym = scanner_get_next_sym();
	}else{
		ERROR("<N> が必要です");
	}
}
