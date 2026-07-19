#include	<stdio.h>
#include	<stdlib.h>
#include	"define.h"
#include	"scanner.h"
#include	"parser.h"
#include	"error.h"

/* 次の字句を先読みするための変数 */
static token_t	nextsym;

static int
parse_expression(void);

static int
parse_term(void);

static int
parse_factor(void);

static int
parse_number(void);

void
parser_init(void)
{
	nextsym = scanner_get_next_sym();
}

/* S ::= E ; */
int parser_parse_sentence(void)
{
	int r;
	r = parse_expression();
	if (nextsym.sym != SYM_SEMICOLON){
		ERROR("';' が必要です");
	}
	/* ';' は式の終わりの記号なので，それ以上先読みをしない */
	/*nextsym = scanner_get_next_sym();*/
	return r;
}

/* E ::= [+|-] T { (+|-) T } */
static int
parse_expression(void)
{
	int r;
	int minus = FALSE;

	if (nextsym.sym == SYM_PLUS || nextsym.sym == SYM_MINUS){
		minus = (nextsym.sym == SYM_MINUS);
		nextsym = scanner_get_next_sym();
	}
	r = parse_term();
	if (minus) r = -r;

	while (nextsym.sym == SYM_PLUS || nextsym.sym == SYM_MINUS){
		int p = nextsym.sym;
		nextsym = scanner_get_next_sym();
		if (p == SYM_PLUS){
			r += parse_term();
		}else{
			r -= parse_term();
		}
	}
	return r;
}

/* T ::= F { (*|/) F } */
static int
parse_term(void)
{
	int r;
	r = parse_factor();
	while (nextsym.sym == SYM_ASTERISK || nextsym.sym == SYM_SLASH){
		int p = nextsym.sym;
		nextsym = scanner_get_next_sym();
		if (p == SYM_ASTERISK){
			r *= parse_factor();
		}else{
			r /= parse_factor();
		}
	}
	return r;
}

/* F ::= N | ( E ) */
static int
parse_factor(void)
{
	int r;
	if (nextsym.sym == SYM_LPAREN){
		nextsym = scanner_get_next_sym();
		r = parse_expression();
		if (nextsym.sym != SYM_RPAREN){
			ERROR("')' が必要です");
		}
		nextsym = scanner_get_next_sym();
	}else{
		r = parse_number();
	}
	return r;
}

static int
parse_number(void)
{
	int r;
	if (nextsym.sym == SYM_CONSTANT_INT){
		r = nextsym.integer;
		nextsym = scanner_get_next_sym();
	}else{
		ERROR("<N> が必要です");
	}
	return r;
}
