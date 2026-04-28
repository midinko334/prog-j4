/* 乗算と除算と最大公約数							*/
/*													*/
/* 加減算とシフト(2 倍，1/2 倍)だけを使って計算する	*/
/* (N. Wirth の PL/0 サンプルプログラムから借用)	*/

int main()
{
	int	x,y;

	x = read();
	y = read();
	write(multiply(x,y));
	write(divide(x,y));
	write(gcd(x,y));
	writeln();
}

int multiply(int x, int y)
{
	int	m;

	m = 0;
	while (y > 0){
		if (y - y / 2 * 2){		// y % 2 は使わない
			m = m + x;
		}
		x = x * 2;
		y = y / 2;
	}
	return (m);
}

int divide(int x,int y)
{
	int d,w;

	d = 0;
	w = y;
	while (w <= x) w = 2 * w;
	while (w > y){
		d = 2 * d;
		w = w / 2;
		if (w <= x){
			x = x - w;
			d = d + 1;
		}
	}
	return (d);
}

int gcd(int x,int y)
{
	while (x != y){
		if (x < y){
			 y = y - x;
		}else{
			 x = x - y;
		}
	}
	return (x);
}
