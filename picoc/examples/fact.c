int main()
{
	int	n,f;

	n = read();
	f = fact(n);
	write(f);
	writeln();
}

int fact(int n)
{
	if (n < 0){
		return (0);
	}else if (n <= 1){
		return (1);
	}else{
		return (n * fact(n - 1));
	}
}
