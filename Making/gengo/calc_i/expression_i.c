#include	<stdio.h>
#include	"define.h"
#include	"scanner.h"
#include	"parser.h"

main(void)
{
	printf("式: ");
	scanner_init(stdin);
	parser_init();

	printf("答え: %d\n",parser_parse_sentence());
}
