#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(){


  system("systemctl disable --user kill_caps.service");

  system("rm -rf ~/killcaps/");

  printf("Program Finished\n");

  return 0;

}
