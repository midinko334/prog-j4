calc: calc.y calc.lex
	yacc -d -y calc.y
	lex calc.lex
	cc y.tab.c lex.yy.c -o calc

clean:
	rm -f y.tab.* lex.yy.* calc

