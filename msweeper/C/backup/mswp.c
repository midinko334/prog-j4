#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>

#ifdef _WIN32
  #define CLEAR "cls"
#else
  #define CLEAR "clear"
#endif

#define XY(size) ((size)*(size))

void swap(int *a,int *b){ int c; c=*a; *a=*b; *b=c; }

int openinput(int size){
  char input1,input2,c;
  while(1){
    printf("Open (x y) : ");
    scanf("%c",&input1);
    scanf(" %c",&input2);
    while((c = getchar()) != '\n' && c != ' ' && c != EOF);
    if(input1>='a') input1+='A'-'a';
    if(input2>='a') input2+='A'-'a';
    if((input1>='0'&&input1<='9'||input1>='A'&&input1<='Z')&&(input2>='0'&&input2<='9'||input2>='A'&&input2<='Z')) break;
  }

  int xy=0;
  if(input1>='A'&&input1<='Z') xy+=input1-'A'+10;
  else xy+=input1-'0';
  if(input2>='A'&&input2<='Z') xy+=(input2-'A'+10)*size;
  else xy+=(input2-'0')*size;
  return xy;
}

void opencell(int **cell,int x,int y,int size){
  int count=0;
  for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
   if((x+k>=0&&x+k<size)&&(y+j>=0&&y+j<size))
   if(cell[y+j][x+k]==-1) count++;
  cell[y][x]=count;
  if(count==0) for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
   if((x+k>=0&&x+k<size)&&(y+j>=0&&y+j<size)&&(cell[y+j][x+k]==9)) opencell(cell,x+k,y+j,size);
}

void board_print(int **cell,int size){
    system(CLEAR);
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
        else printf(". ");
      }
      printf("\n");
    }
}

void finish_game(int **cell,int size){
    system(CLEAR);
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
        else if(cell[i][j]==-1) printf("* ");
        else printf(". ");
      }
      printf("\n");
    }
}

int **setup(int *size){
  int mine=0,c,*senkei;
  printf("=== M Sweeper ===\n");
  while(*size<2||*size>36){
    printf("Board size (Max 36 Min 2): ");
    scanf("%d",size);
    while((c = getchar()) != '\n' && c != EOF);
    if(*size<2||*size>36) printf("Invalid Input\n");
  }
  while(mine>=XY(*size)||mine<=0){
    printf("Mine count : ");
    scanf("%d",&mine);
    while((c = getchar()) != '\n' && c != EOF);
    if(mine>=XY(*size)||mine<=0) printf("Invalid Input\n");
  }

  srand((unsigned)time(NULL));
  int **cell=(int**)malloc(sizeof(int*)*(*size));
  for(int i=0;i<*size;i++) cell[i]=(int*)malloc(sizeof(int)*(*size));
  senkei=(int*)malloc(sizeof(int)*XY(*size));

  for(int i=0;i<*size;i++) for(int j=0;j<*size;j++) cell[i][j]=9;
  for(int i=0;i<XY(*size);i++) senkei[i]=i;
  for(int i=XY(*size)-1;i>0;i--) swap(senkei+( rand()%(i+1) ),senkei+i);

  int input;
  board_print(cell,*size);
  input=openinput(*size);

  int cur=0;
  for(int i=0;i<XY(*size)-2-cur;i++){
    if(senkei[i]==input) swap(&senkei[i],&senkei[XY(*size)-1]);
    else for(int j=-1;j<2;j++) for(int k=-1;k<2;k++)
     if((input%(*size)+k>=0&&input%(*size)+k<(*size))&&(input/(*size)+j>=0&&input/(*size)+j<(*size)))
     if(senkei[i]+j+(k*(*size))==input){
      swap(&senkei[i],&senkei[XY(*size)-2-cur]);
      cur++;
      i--;
    }
  }

  int xy,x,y;
  for(int i=0;i<mine;i++){
    xy=senkei[i];
    x=xy%(*size);
    y=xy/(*size);
    cell[y][x]=-1;
  }

  x=input%(*size);
  y=input/(*size);
  opencell(cell,x,y,*size);

  free(senkei);
  return cell;
}

void gameloop(int **cell,int size){
  int input,finflag,lastflag=2,clflag=0,x,y;
  while(1){
    clflag=1;
    for(int i=0;i<size;i++) for(int j=0;j<size;j++) if(cell[i][j]==9) clflag=0;
    if(clflag){
      finflag=1;
      break;
    }

    board_print(cell,size);
    input=openinput(size);

    x=input%(size);
    y=input/(size);

    if(cell[y][x]==9){
      opencell(cell,x,y,size);
    }
    else if(cell[y][x]==-1){
      finflag=0;
      break;
    }
  }
  finish_game(cell,size);
  if(finflag==0) printf("*** GAME OVER ***\n");
  else if(finflag==1) printf("*** GAME CLEAR ***\n");
  else printf("*** GAME END ***\n");
}

int main(){
  int **cell;	//0-8:opened -1:mine 9:safe 10:firstopen(or near)
  int size;
  cell=setup(&size);
  gameloop(cell,size);

  for(int i=0;i<size;i++) free(cell[i]);
  free(cell);
}
