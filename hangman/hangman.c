#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <string.h>

char *Defword[]={
  "Singularity",
  "Immolation",
  "Transfiguration",
  "Resonance",
  "Division",
  "Hippopotomonstrosesquipedaliophobia",
  "Information",
  "Relationship",
  "Communication",
  "Environment",
  "Organization",
  "Understanding",
  "Performance",
  "Development",
  "Infrastructure",
  "Architecture",
  "Collaboration",
  "Satisfaction",
  "Professional",
  "Alternative",
  "Significant",
  "Implementation",
  "Supercalifragilistic",
  "Recommendation",
  "Transformation",
  "Responsibility",
  "Identification",
  "Characterization",
  "Sustainability",
  "Multiplication",
  "Experimentation",
  "Sophistication",
  "Countermeasures",
  "Intercontinental",
  "Telecommunication",
  "Incomprehensible",
  "Anhedonia",
  "Annihilation",
  "Sabaton",
  "Restitution",
  "Eschaton",
  "Vengeance",
  "Reincarnation",
  NULL
};

char *Easword[]={
  "Apple",
  "Banana",
  "Carrot",
  NULL
};

char *gene[256];
int curgene = 0;

void hangman(char *words[]){

  

}

int main(){

  int mode;
  char enterkesi;

  printf("Sellect Gamemode\n");
  printf("- 0 Default Words\n");
  printf("- 1 Custom Words (need words file)\n");

  scanf("%d",&mode);

  if(mode==1){

    char filename[256]; for (int i=0;i<256;i++) filename[i]=0;
    printf("Input wordfile name:");
    scanf(" %255s",filename);
    FILE *fp;
    char buf[256];
    fp = fopen(filename, "r");
    int fsize=0;
    if(fp==NULL){
      printf("file open error.\n");
      return 0;
    }

    // サイズ確認
    fseek(fp, 0L, SEEK_END);
    fsize = ftell(fp);
    if(fsize==0){
      fclose(fp);
      char ans[256];
      printf("Your file is empty. Will you use default words?(Y/n)");
      scanf(" %255s",ans);
      getchar();

      if(ans[0]=='n'||ans[0]=='N'){
        printf("Program Finished\n");
        for(int freei=0;freei<curgene;freei++) free(gene[freei]);
        return 0;
      }
      else{
        printf("Sellect Difficulty\n");
        printf("- 0 Normal\n");
        printf("- 1 Easy\n");

        scanf("%d",&mode);

        if(mode==0) hangman(Defword);
        else if(mode==1) hangman(Easword);
        else printf("Invalid\n");
      }
    }
    else{
      fseek(fp, 0L, SEEK_SET);

      while (fgets(buf, sizeof(buf), fp) != NULL && curgene < 255) {
          // 改行文字を削除する処理（末尾が \n なら \0 に置き換える）
          buf[strcspn(buf, "\r\n")] = '\0';

          // 空行でなければ配列に格納
          if (strlen(buf) > 0) {
              // その行の長さ分だけメモリを確保してコピー
              gene[curgene] = (char *)malloc(strlen(buf) + 1);
              if (gene[curgene] != NULL) {
                strcpy(gene[curgene], buf);
                curgene++; // 次の配列インデックスへ
              }
          }
      }
      fclose(fp);
      gene[curgene] = NULL;
      hangman(gene);
    }
  }

  else if(mode==0){
    printf("Sellect Difficulty\n");
    printf("- 0 Normal\n");
    printf("- 1 Easy\n");

    scanf("%d",&mode);

    if(mode==0) hangman(Defword);
    else if(mode==1) hangman(Easword);
    else printf("Invalid\n");
  }
  else printf("Invalid\n");


  for(int freei=0;freei<curgene;freei++) free(gene[freei]);
}
