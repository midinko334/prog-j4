#include	<stdio.h>
#include	"define.h"
#include	"scanner_double.h"
#include	"parser_double.h"

int
main(void)
{
	double	r;

	printf("式: ");

	scanner_init(stdin);
	parser_init();

	r = parser_parse_sentence();

	printf("答え: %g\n", r);

	return (0);
}
