#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pigpiod_if2.h>

// ===== 定数 =====
#define PWMI2CADR 0x40
#define PWMI2CCH 1

#define ENA_PWM 8
#define IN1_PWM 9
#define IN2_PWM 10

#define ENB_PWM 13
#define IN3_PWM 11
#define IN4_PWM 12

#define SENSOR1 5
#define SENSOR2 6
#define SENSOR3 13
#define SENSOR4 19
#define SENSOR5 26

#define PWM_MODE1 0
#define PWM_0_ON_L 6
#define PWM_PRESCALE 254

// ===== PWM出力関数 =====
int set_pwm_output(int pd, int fd, int ch, int val)
{
    int reg = PWM_0_ON_L + ch * 4;
    if (val == 16){
        i2c_write_byte_data(pd, fd, reg+1, 0x10);
        i2c_write_byte_data(pd, fd, reg+3, 0);
    } else {
        i2c_write_byte_data(pd, fd, reg+1, 0);
        i2c_write_byte_data(pd, fd, reg+3, val);
    }
    return 0;
}

// ===== モーター制御 =====
void motor_drive(int pd, int fd, int lm, int rm)
{
    // 一旦停止
    set_pwm_output(pd, fd, ENA_PWM, 0);
    set_pwm_output(pd, fd, ENB_PWM, 0);

    // 右
    if (rm >= 0){
        set_pwm_output(pd, fd, IN1_PWM, 16);
        set_pwm_output(pd, fd, IN2_PWM, 0);
    } else {
        set_pwm_output(pd, fd, IN1_PWM, 0);
        set_pwm_output(pd, fd, IN2_PWM, 16);
        rm = -rm;
    }

    // 左
    if (lm >= 0){
        set_pwm_output(pd, fd, IN3_PWM, 16);
        set_pwm_output(pd, fd, IN4_PWM, 0);
    } else {
        set_pwm_output(pd, fd, IN3_PWM, 0);
        set_pwm_output(pd, fd, IN4_PWM, 16);
        lm = -lm;
    }

    if (lm > 16) lm = 16;
    if (rm > 16) rm = 16;

    // 駆動開始
    set_pwm_output(pd, fd, ENA_PWM, rm);
    set_pwm_output(pd, fd, ENB_PWM, lm);
}

int run1st(int pd, int fd, int s1, int s2, int s3, int s4, int s5){

  if(s3==1){
    motor_drive(pd, fd, 12, 12);
    printf("0\n");
  }
  else if(s5==1&&(s1==1||s2==1)){
    motor_drive(pd, fd, 12, 12);
    printf("1\n");
  }
  else if(s2==1){
    motor_drive(pd, fd, 6, 12);
    printf("2\n");
  }
  else if(s4==1){
    motor_drive(pd, fd, 12, 6);
    printf("3\n");
  }
  else if(s1==1){
    motor_drive(pd, fd, -8, 8);
    printf("4\n");
  }
  else if(s5==1){
    motor_drive(pd, fd, 8, -8);
    printf("5\n");
  }
  else{
    motor_drive(pd, fd, 16, 16);
    printf("6\n");
  }

}

// ===== メイン =====
int main(void)
{
    int pd = pigpio_start(NULL, NULL);
    if (pd < 0){
        printf("pigpiod接続失敗\n");
        return 1;
    }

    int fd = i2c_open(pd, PWMI2CCH, PWMI2CADR, 0);
    if (fd < 0){
        printf("I2C失敗\n");
        return 1;
    }

    // PWM初期化
    i2c_write_byte_data(pd, fd, PWM_PRESCALE, 61);
    i2c_write_byte_data(pd, fd, PWM_MODE1, 0x10);
    i2c_write_byte_data(pd, fd, PWM_MODE1, 0);
    time_sleep(0.01);
    i2c_write_byte_data(pd, fd, PWM_MODE1, 0x80);

    printf("waiting..\n");
    printf("press enter\n");
    getchar();
    printf("start\n");

    int s1=0,s2=0,s3=0,s4=0,s5=0;

/*
    printf("set stick\n");
    while(s1==0||s2==0||s3==0||s4==0||s5==0){
      s1 = gpio_read(pd,SENSOR1);
      s2 = gpio_read(pd,SENSOR2);
      s3 = gpio_read(pd,SENSOR3);
      s4 = gpio_read(pd,SENSOR4);
      s5 = gpio_read(pd,SENSOR5);
    }
    printf("remove stick to start\n");
    while(s1==1&&s2==1&&s3==1&&s4==1&&s5==1){
      s1 = gpio_read(pd,SENSOR1);
      s2 = gpio_read(pd,SENSOR2);
      s3 = gpio_read(pd,SENSOR3);
      s4 = gpio_read(pd,SENSOR4);
      s5 = gpio_read(pd,SENSOR5);
    }
*/
    int cpoint=0,antichatter=0,backflag=0;
    // start
    while(cpoint<3){
      s1 = gpio_read(pd,SENSOR1);
      s2 = gpio_read(pd,SENSOR2);
      s3 = gpio_read(pd,SENSOR3);
      s4 = gpio_read(pd,SENSOR4);
      s5 = gpio_read(pd,SENSOR5);
      run1st(pd,fd,s1,s2,s3,s4,s5);
      if(s1==0&&s2==0&&s3==0&&s4==0&&s5==0) antichatter++;
      else antichatter=0;
      if(antichatter>3){
	if(1){
	  motor_drive(pd, fd, 0, 0);
	  usleep(300000);
	}
	s3=0;
	while(s3==0){
	  s3 = gpio_read(pd,SENSOR3);
	  motor_drive(pd, fd, 8*(1-2*(cpoint%2)), -8*(1-2*(cpoint%2)));
          usleep(5000);
	}
	cpoint++;
      }
      usleep(5000);
    }

    // 停止
    motor_drive(pd, fd, 0, 0);
    
    printf("停止\n");
    
    i2c_close(pd, fd);
    pigpio_stop(pd);
    
    return 0;
}

