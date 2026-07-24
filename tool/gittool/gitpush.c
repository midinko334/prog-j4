#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int main(){
char a,b[50],b1[50],b2[50],c[512];
char dumb,dumc;
dumb='1';
printf("Githubにデータをプッシュしますか？ (Y/n) ");
scanf("%c",&a);
if( (a=='y') || (a=='Y') ){
  time_t t1;
  struct tm *local;
  int yea,mon,day,hou,min;
  t1=time(NULL);
  local=localtime(&t1);
  yea=(local->tm_year)+1900;
  mon=(local->tm_mon)+1;
  day=(local->tm_mday);
  hou=(local->tm_hour);
  min=(local->tm_min);
  printf("レポジトリのパスを入力");
  scanf("%s%c",b,&dumb);
  printf("ファイルがあるディレクトリのパスを入力");
  scanf("%s%c",b1,&dumc);
  printf("ファイル名を入力(*を使用可能)");
  scanf("%s%c",b2,&dumc);
  sprintf(c,"cd %s && cp %s %s ; cd %s ; git add . && git commit -m %d/%d/%d && git config pull.rebase false && git pull --no-edit && git push -u origin main && cd",b1,b2,b,b,yea,mon,day);
  system(c);
  printf("end\n");
}
else if( (a=='n') || (a=='N') ) printf("end\n");
else printf("\n");
return 0;
}
