#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <string.h>
#include "hangman.h"

#define CHARTYPES 64
#define LIFE 7

#ifdef _WIN32
  #include <conio.h>
  #define CLEAR "cls"
  char getChar(void){ return (char)_getch(); }
#else
  #include <termio.h>
  #define CLEAR "clear"
#endif


char *gene[256];
int curgene = 0;

char getChar(void){
	struct termio old_term, new_term;

	char	c;

	/* 現在の設定を得る */
	ioctl(0, TCGETA, &old_term);

	/* 設定のコピーをつくる */
	new_term = old_term;

	/* 入力文字のエコーを抑止する場合 */
	new_term.c_lflag &= ~(ICANON | ECHO);

	/* エコーは止めない場合 */
	//new_term.c_lflag &= ~(ICANON);

	/* 新しい設定を反映する */
	ioctl(0, TCSETAW, &new_term);

	/* 1 文字入力 */
	c = getchar();

	/* 古い設定に戻す */
	ioctl(0, TCSETAW, &old_term);

	return (c);
}

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
  int game=1,flag=0,endflag=0,sttflag,cur=1;
  char ans=0;
  char word[256];
  int k=0,isPafe=1;
  for(k=0;words[SEL][k]!='\0';k++) word[k]=words[SEL][k];
  word[k]='\0';
  char input[CHARTYPES];
  for(int j=0;j<CHARTYPES;j++) input[j]='\0';
  int wlen=strlen(words[SEL]);
  input[0]=' ';

  while(game){
    system(CLEAR);
    for(int i=0;i<wlen;i++){
      sttflag=0;
      for(int j=0;input[j]!='\0'&&j<CHARTYPES;j++) if(input[j]==word[i]||( input[j]==word[i]-'A'+'a' && (input[j]<='z'&&input[j]>='a') )) sttflag=1;
      if(sttflag==1) printf("%c",word[i]);
      else printf("-");
    }
    printf("\n\n");

    printf("Using letter:");
    for(int j=1;input[j]!='\0'&&j<CHARTYPES;j++) printf("%c,",input[j]);
    printf("\n");

    if(input[1]=='\0') printf("\n");
    else if(flag==1) printf("%c is included\n",ans);
    else if(flag==2) printf("%c is already used\n",ans);
    else if(flag==0) printf("%c is not included\n",ans);
    else printf("Error!!");

    printf("Input alphabet(%d life remain):",life);
    ans=getChar();

    if(ans!=' '&&ans!='\n'){
      flag=0;
      for(int j=0;input[j]!='\0'&&j<CHARTYPES;j++) if(input[j]==ans) flag=2;
      if(flag==0){
        input[cur]=ans;
        cur++;
        flag=0;
        for(int i=0;i<wlen;i++) if(ans==word[i]||ans==word[i]-'A'+'a') flag=1;
        if(flag==0){
          life--;
          isPafe=0;
        }
      }
    }

    if(life<1){
      system(CLEAR);
      game=0;
      printf("Failure (answer:%s)\n",word);
      break;
    }
    endflag=1;
    for(int i=0;i<wlen;i++){
      int cflag=0;
      for(int j=0;input[j]!='\0'&&j<CHARTYPES;j++) if(input[j]==word[i]||input[j]==word[i]-'A'+'a') cflag=1;
      if(cflag==0) endflag=0;
    }
    if(endflag==1){
      system(CLEAR);
      if(isPafe==1) printf("PERFECT!!!! (answer:%s)\n",word);
      else{
        printf("Success!! (answer:%s)\n",word);
        printf("%d life remain\n",life);
      }
      game=0;
      break;
    }

  }
  printf("retry?(y/N):\n");
  ans=getchar();

  if(ans=='y'||ans=='Y'){
    char c;
    while((c = getchar()) != '\n');
    hangman(words,inputlife);
  }

}

int leadfile(char *words[]){
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
        return -1;
      }
      else return 1;
    }
    else{
      // size check
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
          return -1;
        }
        else return 1;
      }
      else{
        fseek(fp, 0L, SEEK_SET);

        while (fgets(buf, sizeof(buf), fp) != NULL && curgene < 255) {
          // delete indent
          buf[strcspn(buf, "\r\n")] = '\0';

          // insert if not blank
          if (strlen(buf) > 0) {
            gene[curgene] = (char *)malloc(strlen(buf) + 1);
            if (gene[curgene] != NULL) {
              strcpy(gene[curgene], buf);
              curgene++;
            }
          }
        }
        gene[curgene] = NULL;

        // delete if not include word but if covered with "", include it
        char temp[256];

        for(curgene=0;gene[curgene]!=NULL;curgene++){
          for(int i=0;i<256;i++) temp[i]='\0';
          int j=0;
          int alpflag=0;
          int tyomeflag=0;
          for(int i=0;gene[curgene][i]!='\0';i++){
            if(gene[curgene][i]=='"'){
              if(tyomeflag) break;
              tyomeflag=1;
              i++;
            }
            if( ((gene[curgene][i]>='a'&&gene[curgene][i]<='z')||(gene[curgene][i]>='A'&&gene[curgene][i]<='Z')) && tyomeflag==0){
              alpflag=1;
//              printf("alpflag:on/%c\n",gene[curgene][i]);
            }
            if(gene[curgene][i]==' ' && tyomeflag==0){
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
          words[curgene] = (char *)malloc(strlen(temp)+1);
          for(int i=0;temp[i]!='\0';i++){
            words[curgene][i]=temp[i];
//            printf("Input:%c\n",temp[i]);
          }
        }

      }
    }
    fclose(fp);

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

    char *words[256];
    modechanged=leadfile(words);
    if(modechanged==-1) return -1;

    words[curgene] = NULL;
//    sleep(3);
    hangman(words,LIFE);
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


  printf("bye\n");

  for(int freei=0;freei<curgene;freei++) free(gene[freei]);
}
