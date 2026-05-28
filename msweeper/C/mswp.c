#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>

#ifdef _WIN32
  #include <conio.h>
  char getChar(void){
    return (char)_getch();
  }

#else
  #include <termios.h>
  char getChar(void){
    struct termios old_term, new_term;
    char c;

    /* 現在の設定を得る */
    tcgetattr(STDIN_FILENO, &old_term);

    /* 設定のコピーをつくる */
    new_term = old_term;

    /* 入力文字のエコーを抑止する場合 */
    new_term.c_lflag &= ~(ICANON | ECHO);

    /* エコーは止めない場合 */
    //new_term.c_lflag &= ~(ICANON);

    /* 新しい設定を反映する */
    tcsetattr(STDIN_FILENO, TCSANOW, &new_term);

    /* 1 文字入力 */
    c = getchar();

    /* 古い設定に戻す */
    tcsetattr(STDIN_FILENO, TCSANOW, &old_term);

    return c;
  }

#endif

#define XY(size) ((size)*(size))

void swap(int *a,int *b){ int c; c=*a; *a=*b; *b=c; }

int board_sel(int **cell,int size,int xy){
  char input;

  while(1){
    printf("\x1b[2J\x1b[H");
    printf("# | ");
    for(int i=0;i<size;i++){
      if(i<10) printf("%d ",i);
      else if(i>=10&&i<36) printf("%c ",i-10+'A');
    }
    printf("\n");
    printf("--+");
    for(int i=0;i<size;i++) printf("--");
    printf("\n");
    for(int i=0;i<size;i++){
      if(i<10) printf("%d | ",i);
      else if(i>=10&&i<36) printf("%c | ",i-10+'A');
      for(int j=0;j<size;j++){
        if(j+(i*size)==xy) printf("\x1b[7m");
        if(cell[i][j]>0&&cell[i][j]<=8) printf("%d ",cell[i][j]);
        else if(cell[i][j]==0) printf("  ");
        else if(cell[i][j]==10||cell[i][j]==-2) printf("M ");
        else if(cell[i][j]==11||cell[i][j]==-3) printf("? ");
        else printf(". ");
        printf("\x1b[0m");
      }
      printf("\n");
    }
    input=getChar();
    if(input=='\n'||input==' ') break;
    if(input=='w'&&xy-size>=0) xy-=size;
    if(input=='a'&&(xy%size)-1>=0) xy--;
    if(input=='s'&&xy+size<XY(size)) xy+=size;
    if(input=='d'&&(xy%size)+1<size) xy++;
    if(input=='m'){
      if(cell[xy/size][xy%size]==9) cell[xy/size][xy%size]=10;
      else if(cell[xy/size][xy%size]==-1) cell[xy/size][xy%size]=-2;
      else if(cell[xy/size][xy%size]==10) cell[xy/size][xy%size]=9;
      else if(cell[xy/size][xy%size]==-2) cell[xy/size][xy%size]=-1;
    }
    if(input=='q'){
      if(cell[xy/size][xy%size]==9) cell[xy/size][xy%size]=11;
      else if(cell[xy/size][xy%size]==-1) cell[xy/size][xy%size]=-3;
      else if(cell[xy/size][xy%size]==11) cell[xy/size][xy%size]=9;
      else if(cell[xy/size][xy%size]==-3) cell[xy/size][xy%size]=-1;
    }
  }

  return xy;
}

void opencell(int **cell,int x,int y,int size){
  int count=0;
  for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
   if((x+k>=0&&x+k<size)&&(y+j>=0&&y+j<size))
   if(cell[y+j][x+k]==-1||cell[y+j][x+k]==-2||cell[y+j][x+k]==-3) count++;
  cell[y][x]=count;
  if(count==0) for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
   if((x+k>=0&&x+k<size)&&(y+j>=0&&y+j<size)&&(cell[y+j][x+k]==9||cell[y+j][x+k]==10||cell[y+j][x+k]==11)) opencell(cell,x+k,y+j,size);
}

void finish_game(int **cell,int size){
    printf("\x1b[2J\x1b[H");
    printf("# | ");
    for(int i=0;i<size;i++){
      if(i<10) printf("%d ",i);
      else if(i>=10&&i<36) printf("%c ",i-10+'A');
    }
    printf("\n");
    printf("--+");
    for(int i=0;i<size;i++) printf("--");
    printf("\n");
    for(int i=0;i<size;i++){
      if(i<10) printf("%d | ",i);
      else if(i>=10&&i<36) printf("%c | ",i-10+'A');
      for(int j=0;j<size;j++){
        if(cell[i][j]>0&&cell[i][j]<=8) printf("%d ",cell[i][j]);
        else if(cell[i][j]==0) printf("  ");
        else if(cell[i][j]==-1||cell[i][j]==-2||cell[i][j]==-3) printf("* ");
        else printf(". ");
      }
      printf("\n");
    }
}

void gameloop(int **cell,int size,int xy){
  unsigned int sttime=(unsigned)time(NULL);
  int finflag=2,clflag=0,x,y;
  while(1){
    clflag=1;
    for(int i=0;i<size;i++) for(int j=0;j<size;j++) if(cell[i][j]==9||cell[i][j]==10||cell[i][j]==11) clflag=0;
    if(clflag){
      finflag=1;
      break;
    }

    xy=board_sel(cell,size,xy);

    x=xy%(size);
    y=xy/(size);

    if(cell[y][x]==9){
      opencell(cell,x,y,size);
    }
    if(cell[y][x]>=1&&cell[y][x]<=8){
      int count=0;
      for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
       if((x+k>=0&&x+k<size)&&(y+j>=0&&y+j<size))
       if(cell[y+j][x+k]==10||cell[y+j][x+k]==11||cell[y+j][x+k]==-2||cell[y+j][x+k]==-3) count++;
      if(count==cell[y][x]) for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
       if((x+k>=0&&x+k<size)&&(y+j>=0&&y+j<size)){
        if(cell[y+j][x+k]==9) opencell(cell,x+k,y+j,size);
        else if(cell[y+j][x+k]==-1) finflag=0;
      }
      if(finflag==0) break;
    }
    else if(cell[y][x]==-1){
      finflag=0;
      break;
    }
  }
  finish_game(cell,size);
  if(finflag==0) printf("*** GAME OVER ***\n");
  else if(finflag==1) printf("*** GAME CLEAR ***\nClear Time : %ds\n",(unsigned)time(NULL)-sttime);
  else printf("*** GAME END ***\n");
}

void game_start(){
  int size=0;
  int mine=0,c,*senkei;
  printf("=== M Sweeper ===\n");
  while(size<2||size>36){
    printf("Board size (Max 36 Min 2): ");
    scanf("%d",&size);
    while((c = getchar()) != '\n' && c != EOF);
    if(size<2||size>36) printf("Invalid Input\n");
  }
  while(mine>=XY(size)||mine<=0){
    printf("Mine count : ");
    scanf("%d",&mine);
    while((c = getchar()) != '\n' && c != EOF);
    if(mine>=XY(size)||mine<=0) printf("Invalid Input\n");
  }

  srand((unsigned)time(NULL));
  //0-8:opened -1:mine 9:safe 10:mine(marked) 11:safe(marked) 12:mine(q) 13:safe(q)
  int **cell=(int**)malloc(sizeof(int*)*(size));
  for(int i=0;i<size;i++) cell[i]=(int*)malloc(sizeof(int)*(size));
  senkei=(int*)malloc(sizeof(int)*XY(size));

  for(int i=0;i<size;i++) for(int j=0;j<size;j++) cell[i][j]=9;
  for(int i=0;i<XY(size);i++) senkei[i]=i;
  for(int i=XY(size)-1;i>0;i--) swap(senkei+( rand()%(i+1) ),senkei+i);

  int input;
  input=board_sel(cell,size,0);

  int cur=0;
  for(int i=0;i<XY(size)-2-cur;i++){
    if(senkei[i]==input) swap(&senkei[i],&senkei[XY(size)-1]);
    else for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
     if((input%(size)+k>=0&&input%(size)+k<(size))&&(input/(size)+j>=0&&input/(size)+j<(size)))
     if(input+k+(j*(size))==senkei[i]){
      swap(&senkei[i],&senkei[XY(size)-2-cur]);
      cur++;
      i--;
    }
  }

  int xy,x,y;
  for(int i=0;i<mine;i++){
    xy=senkei[i];
    x=xy%(size);
    y=xy/(size);
    cell[y][x]=-1;
  }

  x=input%(size);
  y=input/(size);
  opencell(cell,x,y,size);

  free(senkei);
  gameloop(cell,size,input);
  for(int i=0;i<size;i++) free(cell[i]);
  free(cell);

}

int main(){
  game_start();

  return 0;
}
