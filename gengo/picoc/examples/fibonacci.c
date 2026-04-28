/* fibonacci 数列を計算するプログラム	*/
/*   F0 = 0								*/
/*   F1 = 1								*/
/*   Fn = F(n-2) + F(n-1) (n >= 2)		*/
/*										*/
/* F50 は...							*/

int main()
{
	int		n,f;

	n = read();
	f = fib(n);
	write(f);
	writeln();
}

int fib(int n)
{
	if (n == 0){
		return (0);
	}else if (n == 1){
		return (1);
	}else{
		return (fib(n - 2) + fib(n - 1));
	}
}
