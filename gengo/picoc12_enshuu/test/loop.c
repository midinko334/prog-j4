/* time コマンドで実行時間を測定してみる    */
/*                                          */
/* % time test_vm loop.out                  */

int main()
{
    int     i;

    i = 0;
    while (i < 100000000){
        if (i % 10000000 == 0){
            write(i);
            writeln();
        }
        i = i + 1;
    }
}
