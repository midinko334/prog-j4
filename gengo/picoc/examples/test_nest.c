int main()
{
	int	s,t;

	s = f(10);
	t = f(10);
	{
		int s;

		s = f(5);
		t = f(5);
		write(s);
		write(t);
	}
	write(s);
	write(t);
	writeln();
}

int f(int x)
{
	int	n,s;

	n = x;
	s = 0;
	while (n > 0){
		s = s + n;
		n = n - 1;
	}
	return (s);
}
