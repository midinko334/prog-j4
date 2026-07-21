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

    tcgetattr(STDIN_FILENO, &old_term);

    new_term = old_term;
    new_term.c_lflag &= ~(ICANON | ECHO);
    //new_term.c_lflag &= ~(ICANON);

    tcsetattr(STDIN_FILENO, TCSANOW, &new_term);
    c = getchar();
    tcsetattr(STDIN_FILENO, TCSANOW, &old_term);

    return c;
  }

#endif

#define XY(size) ((size)*(size))
#define CELLINIT (*cell)
#define BOARDSIZE 50
#define MINE -1
#define MMINE -2
#define QMINE -3
#define SAFE 9
#define MSAFE 10
#define QSAFE 11

void swap(int *a,int *b){ int c; c=*a; *a=*b; *b=c; }

int board_print(int **cell,int size,int xy){
    printf("\x1b[2J\x1b[H");
    for(int i=0;i<size;i++){
      for(int j=0;j<size;j++){
        if(j+(i*size)==xy) printf("\x1b[7m");
        if(cell[i][j]>0&&cell[i][j]<=8) printf("%d",cell[i][j]);
        else if(cell[i][j]==0) printf(" ");
        else if(cell[i][j]==MSAFE||cell[i][j]==MMINE) printf("M");
        else if(cell[i][j]==QSAFE||cell[i][j]==QMINE) printf("?");
        else printf(".");

        if(j+(i*size)==xy) printf("@");
        else printf(" ");
        printf("\x1b[0m");
      }
      printf("\n");
    }
    printf("move:wasd, mark:m, question:q, open:space or enter, abort:g\n");
}

int board_sel(int **cell,int size,int xy){
  char input;

  while(1){
    board_print(cell,size,xy);
    input=getChar();
    if(input=='\n'||input==' ') break;
    if(input=='w'&&xy-size>=0) xy-=size;
    if(input=='a'&&(xy%size)-1>=0) xy--;
    if(input=='s'&&xy+size<XY(size)) xy+=size;
    if(input=='d'&&(xy%size)+1<size) xy++;
    if(input=='g'){ xy=-1; break;}
    if(input=='m'){
      if(cell[xy/size][xy%size]==SAFE) cell[xy/size][xy%size]=MSAFE;
      else if(cell[xy/size][xy%size]==MINE) cell[xy/size][xy%size]=MMINE;
      else if(cell[xy/size][xy%size]==MSAFE) cell[xy/size][xy%size]=SAFE;
      else if(cell[xy/size][xy%size]==MMINE) cell[xy/size][xy%size]=MINE;
    }
    if(input=='q'){
      if(cell[xy/size][xy%size]==SAFE) cell[xy/size][xy%size]=QSAFE;
      else if(cell[xy/size][xy%size]==MINE) cell[xy/size][xy%size]=QMINE;
      else if(cell[xy/size][xy%size]==QSAFE) cell[xy/size][xy%size]=SAFE;
      else if(cell[xy/size][xy%size]==QMINE) cell[xy/size][xy%size]=MINE;
    }
  }

  return xy;
}

void opencell(int **cell,int x,int y,int size){
  int count=0;
  for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
   if((x+k>=0&&x+k<size)&&(y+j>=0&&y+j<size))
   if(cell[y+j][x+k]==MINE||cell[y+j][x+k]==MMINE||cell[y+j][x+k]==QMINE) count++;
  cell[y][x]=count;
  if(count==0) for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
   if((x+k>=0&&x+k<size)&&(y+j>=0&&y+j<size)&&(cell[y+j][x+k]==SAFE||cell[y+j][x+k]==MSAFE||cell[y+j][x+k]==QSAFE)) opencell(cell,x+k,y+j,size);
}

int opencell_near(int **cell,int x,int y,int size){
  int count=0;
  for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
   if((x+k>=0&&x+k<size)&&(y+j>=0&&y+j<size))
   if(cell[y+j][x+k]==MSAFE||cell[y+j][x+k]==QSAFE||cell[y+j][x+k]==MMINE||cell[y+j][x+k]==QMINE) count++;
  if(count==cell[y][x]) for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
   if((x+k>=0&&x+k<size)&&(y+j>=0&&y+j<size)){
    if(cell[y+j][x+k]==SAFE) opencell(cell,x+k,y+j,size);
    else if(cell[y+j][x+k]==MINE) return 0;
  }
  return 2;
}

void fg_opencell(int **cell,int x,int y,int size){
  int count=0;
  for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
   if((x+k>=0&&x+k<size)&&(y+j>=0&&y+j<size))
   if(cell[y+j][x+k]==MINE||cell[y+j][x+k]==MMINE||cell[y+j][x+k]==QMINE) count++;
  cell[y][x]=count;
}

void finish_game(int **cell,int size){
    printf("\x1b[2J\x1b[H");
    for(int i=0;i<size;i++){
      for(int j=0;j<size;j++){
        if(cell[i][j]==SAFE||cell[i][j]==QSAFE) fg_opencell(cell,j,i,size);
        if(cell[i][j]>0&&cell[i][j]<=8) printf("%d ",cell[i][j]);
        else if(cell[i][j]==MSAFE) printf("\x1b[31mM \x1b[39m");
        else if(cell[i][j]==0) printf("  ");
        else if(cell[i][j]==MINE||cell[i][j]==MMINE||cell[i][j]==QMINE) printf("* ");
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
    for(int i=0;i<size;i++) for(int j=0;j<size;j++) if(cell[i][j]==SAFE||cell[i][j]==MSAFE||cell[i][j]==QSAFE) clflag=0;
    if(clflag){
      finflag=1;
      break;
    }

    xy=board_sel(cell,size,xy);
    if(xy==-1) break;
    x=xy%(size);
    y=xy/(size);

    if(cell[y][x]==SAFE||cell[y][x]==QSAFE) opencell(cell,x,y,size);
    if(cell[y][x]>=1&&cell[y][x]<=8){
      finflag=opencell_near(cell,x,y,size);
      if(finflag==0) break;
    }
    else if(cell[y][x]==MINE||cell[y][x]==QMINE){
      finflag=0;
      break;
    }
  }
  finish_game(cell,size);
  if(finflag==0) printf("*** GAME OVER ***\n");
  else if(finflag==1) printf("*** GAME CLEAR ***\nClear Time : %ds\n",(unsigned)time(NULL)-sttime);
  else printf("*** GAME END ***\n");
}

int setup(int ***cell,int mine,int size){
  int *senkei;
  srand((unsigned)time(NULL));
  CELLINIT=(int**)malloc(sizeof(int*)*(size));
  for(int i=0;i<size;i++) CELLINIT[i]=(int*)malloc(sizeof(int)*(size));
  senkei=(int*)malloc(sizeof(int)*XY(size));
  for(int i=0;i<size;i++) for(int j=0;j<size;j++) CELLINIT[i][j]=SAFE;
  for(int i=0;i<XY(size);i++) senkei[i]=i;
  for(int i=XY(size)-1;i>0;i--) swap(senkei+( rand()%(i+1) ),senkei+i);

  int input,cur=0;
  input=board_sel(CELLINIT,size,0);
  for(int i=0;i<XY(size);i++) if(senkei[i]==input) swap(&senkei[i],&senkei[XY(size)-1]);
  for(int i=0;i<XY(size)-1-cur;i++){
    for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
     if( (input%size+k>=0&&input%size+k<size) && (input/size+j>=0&&input/size+j<size) )
     if(senkei[i]%size==input%size+k && senkei[i]/size==input/size+j){
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
    CELLINIT[y][x]=-1;
  }
  x=input%(size);
  y=input/(size);
  opencell(CELLINIT,x,y,size);

  free(senkei);
  return input;
}

int main(){
  int size=0,mine=0;
  int c,**cell;
  printf("=== M Sweeper ===\n");
  while(size<2||size>BOARDSIZE){
    printf("Board size (Max %d Min 2): ",BOARDSIZE);
    scanf("%d",&size);
    while((c = getchar()) != '\n' && c != EOF);
    if(size<2||size>BOARDSIZE) printf("Invalid Input\n");
  }
  while(mine>=XY(size)||mine<=0){
    printf("Mine count : ");
    scanf("%d",&mine);
    while((c = getchar()) != '\n' && c != EOF);
    if(mine>=XY(size)||mine<=0) printf("Invalid Input\n");
  }

  int sttxy=setup(&cell,mine,size);
  gameloop(cell,size,sttxy);
  for(int i=0;i<size;i++) free(cell[i]);
  free(cell);
  return 0;

}
