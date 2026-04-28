int main()
{
	int	s,t,u;

	s = t = u = 1;
	s = t = add(s,t,u * s) + c() * u;
	write(s);
	writeln();
	write(t);
	writeln();
}

int add(int x,int y,int z)
{
	int	r;

	r = x + y + z;
	return (r);
}

int c()
{
	return (1);
}
