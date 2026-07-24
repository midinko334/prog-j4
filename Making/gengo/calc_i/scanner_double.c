#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include "define.h"
#include "scanner_double.h"

static int  nextch;
static FILE *stream;

static void
skip_blank(void);

static token_t
scan_const_number(void);

static token_t
scan_identifier(void);

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
	}else if (isalpha(nextch)){
		sym = scan_identifier();
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
	}else if (nextch == '^'){
		nextch = fgetc(stream);
		sym.sym = SYM_CARET;
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
		sym.invalid_char = nextch;
		nextch = fgetc(stream);
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
	double	n;
	double	scale;
	token_t	sym;

	n = 0.0;
	while (isdigit(nextch)){
		n = n * 10.0 + (nextch - '0');
		nextch = fgetc(stream);
	}

	if (nextch == '.'){
		nextch = fgetc(stream);
		scale = 0.1;
		while (isdigit(nextch)){
			n = n + (nextch - '0') * scale;
			scale = scale * 0.1;
			nextch = fgetc(stream);
		}
	}

	sym.sym = SYM_CONSTANT_REAL;
	sym.real = n;
	return (sym);
}

static token_t
scan_identifier(void)
{
	token_t	sym;
	int		i;

	i = 0;
	while ((isalnum(nextch) || nextch == '_') && i < MAX_INDENTIFIER_LEN - 1){
		sym.identifier[i] = (char)nextch;
		i++;
		nextch = fgetc(stream);
	}
	sym.identifier[i] = '\0';
	sym.sym = SYM_IDENTIFIER;
	return (sym);
}
