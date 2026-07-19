#ifndef SCANNER2_H_INCLUDED

#define	SCANNER2_H_INCLUDED

#include <stdio.h>

#define	MAX_INDENTIFIER_LEN (256)

typedef enum {
	SYM_INVALID,
	SYM_IDENTIFIER,		/* function name */
	SYM_CONSTANT_REAL,	/* static number */
	SYM_PLUS,			/* + */
	SYM_MINUS,			/* - */
	SYM_ASTERISK,		/* * */
	SYM_SLASH,			/* / */
	SYM_CARET,			/* ^ */
	SYM_SEMICOLON,		/* ; */
	SYM_LPAREN,			/* ( */
	SYM_RPAREN,			/* ) */
	SYM_EOF				/* EOF */
} symbol_kind_t;

typedef struct{
	symbol_kind_t	sym;
	union{
		int	invalid_char;
		double	real;
		char	identifier[MAX_INDENTIFIER_LEN];
	};
} token_t;

extern void
scanner_init(FILE *s);

extern token_t
scanner_get_next_sym(void);

#endif
