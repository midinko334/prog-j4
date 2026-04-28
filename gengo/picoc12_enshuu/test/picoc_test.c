/* picoc のレポート課題プログラム  */
/* 必須課題だけで動く              */

int main()
{
    int a,b,c;

    //while ((a = read()) < 0);
    do {
        a = read();
    }while (a < 0);
    a = a % 10;
    b = fact_recursive(a);
    c = fact_loop(a);
    write(b);
    write(c);
    writeln();
}

int fact_recursive(int n)
{
    if (n < 0){
        return (0);
    }
    if (n <= 1){
        return (1);
    }
    return (n * fact_recursive(n - 1));
}

int fact_loop(int n)
{
    int f;

    f = 1;
    while (n >= 1){
        f = f * n;
        n = n - 1;
    }
    return (f);
}

/* ふつうの C でコンパイル，実行する場合，下のコメントを外す */
/*
int read()
{
    int a;

    scanf("%d",&a);
    return (a);
}

int write(int n)
{
    printf("%d ",n);
}

int writeln()
{
    printf("\n");
}
*/
