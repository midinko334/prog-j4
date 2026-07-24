#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void wordcheck(char str[]);
void wordreplace(char str[]);
void wordreplace2(char str[]);

int main(){

  char filename[256],enterkesi; for (int i=0;i<256;i++) filename[i]=0;
  printf("inputfilename:");
  scanf("%s%c",filename,&enterkesi);
  FILE *fp;
  char *gene;
  char buf[256];
  fp = fopen(filename, "r");
  int fsize=0;
  if(fp==NULL) {
    printf("file open error.\n");
    exit(1);
  }

  /* ファイルサイズの取得 */
  fseek(fp, 0L, SEEK_END);
  fsize = ftell(fp);
  
  /* メモリの動的確保 */
  gene = (char *)malloc(sizeof(char) * (fsize+1));

  /* シーク位置をファイルの先頭に戻す */
  fseek(fp, 0L, SEEK_SET);

  /* ファイルからデータを読み込む */
  gene[0] = '\0';
  while (fgets(buf, sizeof(buf), fp) != NULL) {
    strncat(gene, buf, strlen(buf) + 1);
  }



  wordreplace2(gene);

  fclose(fp);

}


void wordcheck(char str[]){
  char word[]="AGCTTA";
  int nagasa=0,flag=0,count=0;
  for(nagasa=0;word[nagasa]!='\0';nagasa++);
  nagasa--;

  for(int i=0;str[i+nagasa]!=0;i++){
    flag=1;
    for(int j=0;j<=nagasa;j++){
      if(str[i+j]!=word[j]) flag=0;
    }
    if(flag) count++;
  }

  printf("count=%d\n",count);
}

void wordreplace(char str[]){
  char word[]="GTACA";
  char replace[]="AAA";
  int nagasa=0,flag=0,count=0;
  for(nagasa=0;word[nagasa]!='\0';nagasa++);
  nagasa--;

  for(int i=0;str[i]!=0;i++){
    flag=1;
    for(int j=0;j<=nagasa;j++){
      if(str[i+j]!=word[j]) flag=0;
    }
    if(flag){
      printf("%s",replace);
      i+=nagasa;
    }
    else printf("%c",str[i]);
  }

  printf("\n");

}


void wordreplace2(char str[]){
  char* array;
  char* command;
  char word[128]; for(int i=0;i<128;i++) word[i]=0;
  char replace[128]; for(int i=0;i<128;i++) replace[i]=0;
  char file[128]; for(int i=0;i<128;i++) file[i]=0;
  int nagasa=0,flag=0,count=0,suc=1,dum=-1,youso=0,max=0,rep=0;
  char enterkesi;
  int m=0;
  for(max=0;str[max]!='\0';max++);

  array=(char*)malloc(sizeof(char)*max);
  command=(char*)malloc(sizeof(char)*(max+128));
  if(array==NULL||command==NULL){
   printf("sorry,error has occored.\n");
   abort();
  }

//  printf("checkpoint1\n");
  printf("replace from:");
  scanf("%s%c",word,&enterkesi);
  printf("replace for:");
  scanf("%s%c",replace,&enterkesi);
  printf("outputfilename:");
  scanf("%s%c",file,&enterkesi);
  for(nagasa=0;word[nagasa]!='\0';nagasa++);
  nagasa--;
  for(rep=0;replace[rep]!='\0';rep++);

//  printf("checkpoint2\n");

  sprintf(command,"ls %s 2> totemoiranaisakujyoyoteinofile.dum",file);
  dum=system(command);
  system("rm totemoiranaisakujyoyoteinofile.dum");

//  printf("checkpoint3\n");

  if(!dum){
    char ans=0;
    printf("%s already exists.\nAre you sure you want to replace it?(y/n)",file);
    scanf("%c",&ans);
    if(ans=='y') suc=2;
    else suc=0;
  }


  for(int i=0;str[i]!=0&&suc;i++){
    flag=1;
    for(int j=0;j<=nagasa;j++){
      if(str[i+j]!=word[j]) flag=0;
    }
    if(flag){
      for(int k=0;k<rep;k++){
        array[m]=replace[k];
        m++;
      }
      i+=nagasa;
    }
    else{
      array[m]=str[i];
      m++;
    }
  }

  if(suc){
    array[m]='\0';
    sprintf(command,"echo \"%s\" > \"%s\"",array,file);
    system(command);
    printf("create %s",file);
  }
  if(!suc) printf("Abort.\n");

  printf("\n");

}


/*    if(flag){
      sprintf(command,"echo %s >> %s",replace,file);
      system(command);
      i+=nagasa;
    }
    else{
      sprintf(command,"echo %c >> %s",str[i],file);
      system(command);
    }
*/
