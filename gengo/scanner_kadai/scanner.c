/* 課題                                     */
/* (1) キーワードとして else を追加しなさい */
/*     ※test_scanner.c も修正すること      */
/* (2) scan_const_number を完成させなさい	*/
/* (3) コメントに対応しなさい(/ * * /)      */
/*     ※変数line(行番号)に注意             */

#include    <stdio.h>
#include    <ctype.h>
#include    <stdlib.h>
#include    <string.h>
#include    "define.h"
#include    "scanner.h"

static int nextch;
static int buf_full;
static token_t token_buf;
static FILE *stream;
static int line;

static void
skip_blank(void);

static void
skip_c_style_comment(void);

static void
skip_cpp_style_comment(void);

static token_t
scan_identifier(void);

static token_t
scan_const_number(void);

void
scanner_init(FILE *s)
{
    stream = s;
    nextch = fgetc(stream);
    line = 1;
    buf_full = FALSE;
}

token_t
scanner_get_next_sym(void)
{
    token_t sym;

    if (buf_full){
        /* token_buf にシンボルがあれば，それを返す */
        buf_full = FALSE;
        return (token_buf);
    }

    /* token_buf が空なら，次の新しいシンボルを切り出す */
    skip_blank();
    if (isalpha(nextch) || nextch == '_'){
        sym = scan_identifier();
    }else if (isdigit(nextch)){
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
        if (nextch == '*'){
            nextch = fgetc(stream);
            skip_c_style_comment();
            sym = scanner_get_next_sym();
        }else if (nextch == '/'){
            nextch = fgetc(stream);
            skip_cpp_style_comment();
            sym = scanner_get_next_sym();
        }else{
            sym.sym = SYM_SLASH;
        }
    }else if (nextch == '%'){
        nextch = fgetc(stream);
        sym.sym = SYM_PERCENT;
    }else if (nextch == '<'){
        nextch = fgetc(stream);
        if (nextch == '='){
            nextch = fgetc(stream);
            sym.sym = SYM_LE;
        }else{
            sym.sym = SYM_LT;
        }
    }else if (nextch == '>'){
        nextch = fgetc(stream);
        if (nextch == '='){
            nextch = fgetc(stream);
            sym.sym = SYM_GE;
        }else{
            sym.sym = SYM_GT;
        }
    }else if (nextch == '='){
        nextch = fgetc(stream);
        if (nextch == '='){
            nextch = fgetc(stream);
            sym.sym = SYM_EQ;
        }else{
            sym.sym = SYM_EQUAL;
        }
    }else if (nextch == '!'){
        nextch = fgetc(stream);
        if (nextch == '='){
            nextch = fgetc(stream);
            sym.sym = SYM_NE;
        }else{
            sym.sym = SYM_INVALID;
            sym.invalid_char = '!';
        }
    }else if (nextch == ';'){
        nextch = fgetc(stream);
        sym.sym = SYM_SEMICOLON;
    }else if (nextch == ','){
        nextch = fgetc(stream);
        sym.sym = SYM_COMMA;
    }else if (nextch == '('){
        nextch = fgetc(stream);
        sym.sym = SYM_LPAREN;
    }else if (nextch == ')'){
        nextch = fgetc(stream);
        sym.sym = SYM_RPAREN;
    }else if (nextch == '{'){
        nextch = fgetc(stream);
        sym.sym = SYM_LBRACE;
    }else if (nextch == '}'){
        nextch = fgetc(stream);
        sym.sym = SYM_RBRACE;
    }else if (nextch == '['){
        nextch = fgetc(stream);
        sym.sym = SYM_LBRACKET;
    }else if (nextch == ']'){
        nextch = fgetc(stream);
        sym.sym = SYM_RBRACKET;
    }else if (nextch == EOF){
        sym.sym = SYM_EOF;
    }else{
        sym.sym = SYM_INVALID;
        sym.invalid_char = nextch;
        nextch = fgetc(stream);
    }
    //fprintf(stderr,"line:%d sym:%d\n",line,sym.sym);
    return (sym);
}

void
scanner_push_back_sym(token_t t)
{
    token_buf = t;
    buf_full = TRUE;
}

int scanner_get_current_line_number(void)
{
    return (line);
}

static void
skip_blank(void)
{
    while (isblank(nextch) || nextch == '\n'){
        if (nextch == '\n'){
            line++;
        }
        nextch = fgetc(stream);
    }
}

/* コメントを読み飛ばす  */
static void
skip_c_style_comment(void)
{

}

static void
skip_cpp_style_comment(void)
{
    while (nextch != '\n' && nextch != EOF){
        nextch = fgetc(stream);
    }
    nextch = fgetc(stream);
    line++;
}

static token_t
scan_identifier(void)
{
    char    id[MAX_IDENTIFIER_LEN];
    int     i;
    token_t sym;

    i = 0;
    while (isalpha(nextch) || isdigit(nextch) || nextch == '_'){
        id[i] = nextch;
        i++;
        nextch = fgetc(stream);
    }
    id[i] = '\0';
    if (strcmp(id,"if") == 0){
        sym.sym = SYM_IF;
    }else if (strcmp(id,"while") == 0){
        sym.sym = SYM_WHILE;
    }else if (strcmp(id,"do") == 0){
        sym.sym = SYM_DO;
    }else if (strcmp(id,"return") == 0){
        sym.sym = SYM_RETURN;
    }else if (strcmp(id,"int") == 0){
        sym.sym = SYM_INT;
    }else if (strcmp(id,"for") == 0){
        sym.sym = SYM_FOR;
    }else{
        sym.sym = SYM_IDENTIFIER;
        strncpy(sym.identifier,id,MAX_IDENTIFIER_LEN);
        sym.identifier[MAX_IDENTIFIER_LEN - 1] = '\0';
    }
    return (sym);
}

static token_t
scan_const_number(void)
{
    int n;
    token_t sym;

    n = 0;
    while (isdigit(nextch)){
		/* "123" → 123 変換して n に格納 */
    }
    sym.sym = SYM_CONSTANT_INT;
    sym.integer = n;
    return (sym);
}
