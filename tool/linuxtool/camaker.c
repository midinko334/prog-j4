#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(){

  system("echo \"\nfunction ca(){\n    if [ \\$# == 0 ]; then\n        ./a.out\n    else\n        cc \\$@ && ./a.out\n    fi\n}\" >> ~/.bashrc");
  printf("source ~/.bashrc")

}
