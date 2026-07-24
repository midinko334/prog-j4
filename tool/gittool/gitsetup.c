#include <stdio.h>
#include <stdlib.h>

int main(){
char a,b[50],c[50],d[255],e[50],duma,dumb,dumc;
printf("Githubレポジトリセットアップしますか？ (Y/n) ");
scanf("%c",&a);
if( (a=='y') || (a=='Y') ){
  a='1';
  system("mkdir ~/.ssh");
  system("cd ~/.ssh && ssh-keygen -t rsa");
  printf("\n\n次のコードをgithubのsettings/SSH and GPG keys のSSHkeysに入力してください\n\n");
  system("cd ~/.ssh && cat id_rsa.pub");
  printf("\n完了したら”Y”を入力してください");
  while ((a!='Y')&&(a!='y')) scanf("%c",&a);
  system("cd ~/.ssh && ssh -T git@github.com");
  system("cd");
  printf("ユーザー名を入力");
  scanf("%s%c",b,&dumb);
  printf("登録したメールアドレスを入力");
  scanf("%s%c",e,&duma);
  sprintf(d,"git config --global user.name \"%s\"",b);
  system(d);
  sprintf(d,"git config --global user.email \"%s\"",e);
  system(d);
  printf("セットアップ完了\n");
}
else if( (a=='n') || (a=='N') ) printf("end\n");
else printf("\n");
return 0;
}
