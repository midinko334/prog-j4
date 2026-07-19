#include	<stdio.h>
#include	<stdlib.h>
#include	<string.h>
#include	<math.h>
#include	"define.h"
#include	"scanner_double.h"
#include	"parser_double.h"
#include	"error.h"

/* 次の字句を先読みするための変数 */
static token_t	nextsym;

static double
parse_expression(void);

static double
parse_term(void);

static double
parse_factor(void);

static double
parse_primary(void);

static double
parse_function_call(void);

static double
apply_function(const char *name, double arg);

void
parser_init(void)
{
	nextsym = scanner_get_next_sym();
}

/* S ::= E ; */
double
parser_parse_sentence(void)
{
	double	r;

	r = parse_expression();
	if (nextsym.sym != SYM_SEMICOLON){
		ERROR("';' が必要です");
	}
	/* ';' は式の終わりの記号なので，それ以上先読みをしない */
	return r;
}

/* E ::= [+|-] T { (+|-) T } */
static double
parse_expression(void)
{
	double	r;
	int	minus;

	minus = FALSE;
	if (nextsym.sym == SYM_PLUS || nextsym.sym == SYM_MINUS){
		minus = (nextsym.sym == SYM_MINUS);
		nextsym = scanner_get_next_sym();
	}

	r = parse_term();
	if (minus) r = -r;

	while (nextsym.sym == SYM_PLUS || nextsym.sym == SYM_MINUS){
		if (nextsym.sym == SYM_PLUS){
			nextsym = scanner_get_next_sym();
			r += parse_term();
		}else{
			nextsym = scanner_get_next_sym();
			r -= parse_term();
		}
	}
	return r;
}

/* T ::= F { (*|/) F } */
static double
parse_term(void)
{
	double	r;

	r = parse_factor();
	while (nextsym.sym == SYM_ASTERISK || nextsym.sym == SYM_SLASH){
		if (nextsym.sym == SYM_ASTERISK){
			nextsym = scanner_get_next_sym();
			r *= parse_factor();
		}else{
			nextsym = scanner_get_next_sym();
			r /= parse_factor();
		}
	}
	return r;
}

/* F ::= P [ ^ F ] */
static double
parse_factor(void)
{
	double	base;
	double	exponent;

	base = parse_primary();
	if (nextsym.sym == SYM_CARET){
		nextsym = scanner_get_next_sym();
		exponent = parse_factor();
		return (pow(base, exponent));
	}
	return base;
}

/* P ::= N | ( E ) | id ( E ) */
static double
parse_primary(void)
{
	double	r;

	if (nextsym.sym == SYM_LPAREN){
		nextsym = scanner_get_next_sym();
		r = parse_expression();
		if (nextsym.sym != SYM_RPAREN){
			ERROR("')' が必要です");
		}
		nextsym = scanner_get_next_sym();
	}else if (nextsym.sym == SYM_IDENTIFIER){
		r = parse_function_call();
	}else if (nextsym.sym == SYM_CONSTANT_REAL){
		r = nextsym.real;
		nextsym = scanner_get_next_sym();
	}else{
		ERROR("数値か '(' か 関数名 が必要です");
		r = 0.0;
	}
	return r;
}

static double
parse_function_call(void)
{
	char	name[MAX_INDENTIFIER_LEN];
	double	arg;

	strcpy(name, nextsym.identifier);
	nextsym = scanner_get_next_sym();

	if (nextsym.sym != SYM_LPAREN){
		ERROR("'(' が必要です");
	}
	nextsym = scanner_get_next_sym();

	arg = parse_expression();

	if (nextsym.sym != SYM_RPAREN){
		ERROR("')' が必要です");
	}
	nextsym = scanner_get_next_sym();

	return apply_function(name, arg);
}

static double
apply_function(const char *name, double arg)
{
	if (strcmp(name, "sin") == 0){
		return (sin(arg));
	}else if (strcmp(name, "cos") == 0){
		return (cos(arg));
	}else{
		ERROR("未知の関数です（sin, cos のみ対応）");
	}
	return (0.0);
}
