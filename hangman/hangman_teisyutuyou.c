#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <string.h>

#define LIFE 7

char *Defword[]={
  "Singularity",
  "Immolation",
  "Transfiguration",
  "Resonance",
  "Monster",
  "Toxoplasmosis",
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
  "Division",
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
  "Sodium",
  "Ascendancy",
  "Fatality",
  "Halcyon",
  "Revolution",
  "Riptide",
  "Convergence",
  "Divergence",
  "Labyrinth",
  "Distortion",
  "Destruction",
  "Quetzalcoatl",
  "Oblivion",
  "Stratiformis",
  "Teleport",
  "Absolute",
  "Collapse",
  "Inferno",
  "Cataclysm",
  "Fantasia",
  "Nullification",
  "Guardian",
  "Olympic",
  "Apocalypse",
  "Archangel",
  NULL
};

char *Easword[]={
  "Apple",
  "Banana",
  "Carrot",
  "Donut",
  "Egg",
  "Fish",
  NULL
};

char *gene[256];
int curgene = 0;


// hangman-setup
void hangman(char *words[],int life){

  int length=0,inputlife=life;
  for(;words[length]!=NULL;length++);
  int SEL=rand()%length;

/*
// output test
  printf("%d\n",length);
  printf("%d\n",SEL);
  printf("%s\n",words[SEL]);
// */

// main
  int game=1,flag=0,endflag=0,sttflag,cur=0;
  char ans[256];
  for(int i=0;i<256;i++) ans[i]=0;
  char word[256];
  int k=0,isPafe=1;
  for(k=0;words[SEL][k]!='\0';k++) word[k]=words[SEL][k];
  word[k]='\0';
  char input[32];
  for(int j=0;j<32;j++) input[j]='\0';
  int wlen=strlen(words[SEL]);

  while(game){
    system("clear");
    for(int i=0;i<wlen;i++){
      sttflag=0;
      for(int j=0;input[j]!='\0'&&j<32;j++) if(input[j]==word[i]||input[j]==word[i]-'A'+'a') sttflag=1;
      if(sttflag==1) printf("%c",word[i]);
      else printf("-");
    }
    printf("\n\n");

    printf("Using letter:");
    for(int j=0;input[j]!='\0'&&j<32;j++) printf("%c,",input[j]);
    printf("\n");

    if(input[0]=='\0') printf("\n");
    else if(ans[1]!='\0') printf("The answer is not \"%s\"\n",ans);
    else if(flag==1) printf("%c is included\n",ans[0]);
    else if(flag==2) printf("%c is already used\n",ans[0]);
    else if(flag==0) printf("%c is not included\n",ans[0]);
    else printf("Error!!");

    printf("Input alphabet(%d life remain):",life);
    for(int i=0;ans[i]!=0;i++) ans[i]=0;
    while(ans[0]==0||ans[0]=='\n'){
      scanf("%s",ans);
    }
    int c;
    while((c = getchar()) != '\n');

    for(int k=0;ans[k]!=0;k++){

      if(ans[k]!=' '){
        flag=0;
        for(int j=0;input[j]!='\0'&&j<32;j++) if(input[j]==ans[k]) flag=2;
        if(flag==0){
          input[cur]=ans[k];
          cur++;
          flag=0;
          for(int i=0;i<wlen;i++) if(ans[k]==word[i]||ans[k]==word[i]-'A'+'a') flag=1;
          if(flag==0){
            life--;
            isPafe=0;
          }
        }
      }

      if(life<1){
        system("clear");
        game=0;
        printf("Failure (answer:%s)\n",word);
        break;
      }
      endflag=1;
      for(int i=0;i<wlen;i++){
        int cflag=0;
        for(int j=0;input[j]!='\0'&&j<32;j++) if(input[j]==word[i]||input[j]==word[i]-'A'+'a') cflag=1;
        if(cflag==0) endflag=0;
      }
      if(endflag==1){
        system("clear");
        if(isPafe==1) printf("PERFECT!!!! (answer:%s)\n",word);
        else{
          printf("Success!! (answer:%s)\n",word);
          printf("%d life remain\n",life);
        }
        game=0;
        break;
      }
    }

  }
  printf("retry?(y/N):");
  for(int i=0;ans[i]!=0;i++) ans[i]=0;
  while(ans[0]==0||ans[0]=='\n'){
    scanf("%s",ans);
  }
  int c;
  while((c = getchar()) != '\n');

  if(ans[0]=='y'||ans[0]=='Y') hangman(words,inputlife);
}


int main(){

  srand((unsigned int)time(NULL));
  int mode,modechanged=0;
  char enterkesi;

  printf("Sellect Gamemode\n");
  printf("- 0 Default Words\n");
  printf("- 1 Custom Words (need words file)\n");

  scanf("%d",&mode);

  if(mode==1){

    char filename[256]; for (int i=0;i<256;i++) filename[i]=0;
    char ans[256];
    printf("Input wordfile name:");
    scanf(" %255s",filename);
    char c;
    while((c = getchar()) != '\n');
    FILE *fp;
    char buf[256];
    fp = fopen(filename, "r");
    int fsize=0;
    if(fp==NULL){
      printf("Can't open the file. Will you use default words?(Y/n)");
      scanf(" %255s",ans);
      getchar();

      if(ans[0]=='n'||ans[0]=='N'){
        printf("Program Finished\n");
        for(int freei=0;freei<curgene;freei++) free(gene[freei]);
        return 0;
      }
      else modechanged=1;
    }
    else{
      // サイズ確認
      fseek(fp, 0L, SEEK_END);
      fsize = ftell(fp);
      if(fsize==0){
        fclose(fp);
        printf("Your file is empty. Will you use default words?(Y/n)");
        scanf(" %255s",ans);
        getchar();

        if(ans[0]=='n'||ans[0]=='N'){
          printf("Program Finished\n");
          for(int freei=0;freei<curgene;freei++) free(gene[freei]);
          return 0;
        }
        else modechanged=1;
      }
      else{
        fseek(fp, 0L, SEEK_SET);

        while (fgets(buf, sizeof(buf), fp) != NULL && curgene < 255) {
          // 改行文字を削除する処理（末尾が \n か空白なら \0 に置き換える）
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
        gene[curgene] = NULL;

        //番号や意味の解説を無視
        char *word[256];
        char temp[256];

        for(curgene=0;gene[curgene]!=NULL;curgene++){
          for(int i=0;i<256;i++) temp[i]='\0';
          int j=0;
          int alpflag=0;
          for(int i=0;gene[curgene][i]!='\0';i++){
            if((gene[curgene][i]>='a'&&gene[curgene][i]<='z')||(gene[curgene][i]>='A'&&gene[curgene][i]<='Z')){
              alpflag=1;
//              printf("alpflag:on/%c\n",gene[curgene][i]);
            }
            if(gene[curgene][i]==' '){
//              printf("Blank is detected\n");
              gene[curgene][i]='\0';
              j=0;
              if(alpflag) break;
              for(int i=0;i<256;i++) temp[i]='\0';
            }
            else{
              temp[j]=gene[curgene][i];
              j++;
            }
          }
          word[curgene] = (char *)malloc(strlen(temp)+1);
          for(int i=0;temp[i]!='\0';i++){
            word[curgene][i]=temp[i];
//            printf("Input:%c\n",temp[i]);
          }
        }
        fclose(fp);
        word[curgene] = NULL;
//        sleep(3);
        hangman(word,LIFE);
      }
    }
  }

  if(mode==0||modechanged==1){
    printf("Sellect Difficulty\n");
    printf("- 0 Normal(6-35 letter)\n");
    printf("- 1 Easy(3-10 letter)\n");

    int c;
    scanf("%d",&mode);
    while((c = getchar()) != '\n');

    if(mode==0) hangman(Defword,LIFE);
    else if(mode==1) hangman(Easword,LIFE+4);
    else printf("Invalid\n");
  }
  else if(mode!=1) printf("Invalid\n");


  for(int freei=0;freei<curgene;freei++) free(gene[freei]);
}
