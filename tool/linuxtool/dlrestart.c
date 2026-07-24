#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(){

  system("echo \"\nalias monitor-restart=\\\"systemctl restart displaylink-driver\\\"\" >> ~/.bashrc");

}
