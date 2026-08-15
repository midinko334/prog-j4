#ifndef SCANNER_H_INCLUDED

#define	SCANNER_H_INCLUDED

#include	<stdio.h>

#define	MAX_INDENTIFIER_LEN	(256)

typedef enum {
	SYM_INVALID,	
	SYM_IDENTIFIER,
	SYM_CONSTANT_INT,
	SYM_IF,				/* if */
	SYM_ELSE,			/* else */
	SYM_WHILE,			/* while */
	SYM_RETURN,			/* return */
	SYM_INT,			/* int */
	SYM_PLUS,			/* + */
	SYM_MINUS,			/* - */
	SYM_ASTERISK,		/* * */
	SYM_SLASH,			/* / */
	SYM_PERCENT,		/* % */
	SYM_LT,				/* < */
	SYM_LE,				/* <= */
	SYM_GT,				/* > */
	SYM_GE,				/* >= */
	SYM_EQ,				/* == */
	SYM_NE,				/* != */
	SYM_EQUAL,			/* = */
	SYM_SEMICOLON,		/* ; */
	SYM_COMMA,			/* , */
	SYM_LPAREN,			/* ( */
	SYM_RPAREN,			/* ) */
	SYM_LBRACE,			/* { */
	SYM_RBRACE,			/* } */
	SYM_EOF				/* EOF */
} symbol_kind_t;

typedef struct{
	symbol_kind_t	sym;
	union{
		int invalid_char;
		int integer;
		char *identifier;
	};
} token_t;

extern void
scanner_init(FILE *s);

extern token_t
scanner_get_next_sym(void);

#endif
