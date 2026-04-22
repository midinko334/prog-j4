#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <string.h>

int main(){

  int mode;
  char enterkesi;

  printf("Sellect Gamemode\n");
  printf("- 0 Default Words\n");
  printf("- 1 Custom Words (need words file)\n");

  scanf("%d%c",&mode,&enterkesi);

  if(mode=1){

    char filename[256]; for (int i=0;i<256;i++) filename[i]=0;
    printf("Input wordfile name:");
    scanf("%s%c",filename,&enterkesi);
    FILE *fp;
    char *gene;
    char buf[256];
    fp = fopen(filename, "r");
    int fsize=0;
    if(fp==NULL){
      printf("file open error.\n");
      exit(1);
    }

    // サイズ確認
    fseek(fp, 0L, SEEK_END);
    fsize = ftell(fp);
    if(fsize==0){
      char ans[256];
      printf("Your file is empty. Will you use default words?(Y/n)");
      scanf("%s%c",ans,&enterkesi);

      if(ans[0]='n'){
        printf("Program Finished\n");
        return 0;
    }

    gene = (char *)malloc(sizeof(char) * (fsize+1));

    // 読み込み
    fseek(fp, 0L, SEEK_SET);

    gene[0] = '\0';
    while (fgets(buf, sizeof(buf), fp) != NULL) {
      strncat(gene, buf, strlen(buf) + 1);
    }

}
