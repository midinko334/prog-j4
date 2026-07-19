#include	<stdio.h>
#include	"define.h"
#include	"scanner.h"
#include	"parser.h"

main(void)
{
	printf("式: ");

	scanner_init(stdin);
	parser_init();

	parser_parse_sentence();
}
