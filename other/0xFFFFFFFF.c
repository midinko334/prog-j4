#include <stdio.h>

int main(){

  unsigned int a=0xFFFFFFFF;
  char b[]="0xFFFFFFFF";
  printf("%u,%s\n",a,b);
  char c[11]={0};

  int j=1000000000;
  for(int i=0;i<10;i++){
    c[i]=b[i]+a/j%10;
    j/=10;
  }

  printf("%s\n",c);

}
