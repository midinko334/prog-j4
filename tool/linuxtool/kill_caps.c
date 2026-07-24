#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(){

  system("mkdir ~/killcaps");

  system("echo \"[Unit]\" | sudo tee ~/killcaps/kill_caps.service");
  system("echo \"Description=Kill Caps Service\" | sudo tee -a ~/killcaps/kill_caps.service");
  system("echo \"After=graphical-session.target\" | sudo tee -a ~/killcaps/kill_caps.service");
  
  system("echo \"\n[Service]\" | sudo tee -a ~/killcaps/kill_caps.service");
  system("echo \"Type=oneshot\" | sudo tee -a ~/killcaps/kill_caps.service");
  system("echo \"ExecStartPre=/usr/bin/sleep 3\" | sudo tee -a ~/killcaps/kill_caps.service");
  system("echo \"Environment=DISPLAY=:0\" | sudo tee -a ~/killcaps/kill_caps.service");
  system("echo \"ExecStart=/usr/bin/setxkbmap -option ctrl:nocaps\" | sudo tee -a ~/killcaps/kill_caps.service");
  system("echo \"RemainAfterExit=yes\" | sudo tee -a ~/killcaps/kill_caps.service");
  
  system("echo \"\n[Install]\" | sudo tee -a ~/killcaps/kill_caps.service");
  system("echo \"WantedBy=default.target\" | sudo tee -a ~/killcaps/kill_caps.service");

  system("systemctl --user enable ~/killcaps/kill_caps.service");

  printf("Program Finished\nPlease Reboot\n");

  return 0;

}
