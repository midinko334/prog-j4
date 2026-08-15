#include	<stdio.h>
#include	<ctype.h>
#include	<stdlib.h>
#include	<string.h>
#include	"define.h"
#include	"scanner.h"

static int nextch;
static FILE *stream;

static void
skip_blank(void);

static token_t
scan_const_number(void);

void
scanner_init(FILE *s)
{
	stream = s;
	nextch = fgetc(stream);
}

token_t
scanner_get_next_sym(void)
{
	token_t	sym;

	skip_blank();
	if (isdigit(nextch)){
		sym = scan_const_number();
	}else if (nextch == '+'){
		nextch = fgetc(stream);
		sym.sym = SYM_PLUS;
	}else if (nextch == '-'){
		nextch = fgetc(stream);
		sym.sym = SYM_MINUS;
	}else if (nextch == '*'){
		nextch = fgetc(stream);
		sym.sym = SYM_ASTERISK;
	}else if (nextch == '/'){
		nextch = fgetc(stream);
		sym.sym = SYM_SLASH;
	}else if (nextch == ';'){
		nextch = fgetc(stream);
		sym.sym = SYM_SEMICOLON;
	}else if (nextch == '('){
		nextch = fgetc(stream);
		sym.sym = SYM_LPAREN;
	}else if (nextch == ')'){
		nextch = fgetc(stream);
		sym.sym = SYM_RPAREN;
	}else if (nextch == EOF){
		sym.sym = SYM_EOF;
	}else{
		sym.sym = SYM_INVALID;
		nextch = fgetc(stream);
		sym.invalid_char = nextch;
	}
	return (sym);
}

static void
skip_blank(void)
{
	while (isblank(nextch) || nextch == '\n'){
		nextch = fgetc(stream);
	}
}

static token_t
scan_const_number(void)
{
	int	n;
	token_t	sym;

	n = 0;
	while (isdigit(nextch)){
		n =  n * 10 + nextch - '0';
		nextch = fgetc(stream);
	}
	sym.sym = SYM_CONSTANT_INT;
	sym.integer = n;
	return (sym);
}
