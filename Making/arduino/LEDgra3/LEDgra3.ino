#include <Adafruit_NeoPixel.h>

// NeoPixelの接続ピン番号
#define PIN 6
#define SWI 12
#define MTP 3
int antichatter;

//色制御変数
int color=0;
float bright=0;
int r=0;
int g=0;
int b=0;

// NeoPixelのLEDの数
#define NUMPIXELS 150

// NeoPixelオブジェクトを作成
// 引数: LEDの数, 接続ピン, LEDのタイプ
// LEDのタイプ: NEO_GRB + NEO_KHZ800 (NeoPixel標準)
Adafruit_NeoPixel pixels(NUMPIXELS, PIN, NEO_GRB + NEO_KHZ800);

void setup() {
  pinMode(SWI, INPUT_PULLUP);
  // NeoPixelを初期化
  pixels.begin();
}

void loop() {
  // すべてのLEDを消灯
  for(int i=0;i<NUMPIXELS;i++) pixels.setPixelColor(i, pixels.Color(0, 0, 0));
  pixels.show();
  while('v'){
    if(digitalRead(SWI) == HIGH) antichatter+=1;
    else antichatter=0;
    if(antichatter>8) break;
  }

  while('v'){
    if(digitalRead(SWI) == LOW) antichatter+=1;
    else antichatter=0;
    if(antichatter>8) break;
  }
  // 根本から順番にLEDを点灯させるループ
  for(int i=NUMPIXELS + 30-1; i >= 0; i--) {
    if(i>=30) pixels.setPixelColor(i-30, pixels.Color(50*MTP, 50*MTP, 50*MTP));
    if(i<NUMPIXELS+30-4&&i>=30-4) pixels.setPixelColor(i-30+4, pixels.Color(0, 0, 0));
    if(i<NUMPIXELS)pixels.setPixelColor(i, pixels.Color(50*MTP, 50*MTP, 50*MTP));
    pixels.show();
    delay(30);
}

  for(int gb = 50; gb >= 0; gb--) {
    for(int i = 0; i < NUMPIXELS; i++) {
      pixels.setPixelColor(i, pixels.Color(50*MTP, gb*MTP, gb*MTP));
    }
    pixels.show();
    delay(30);
  }

  while('v'){
    if(color>=300) color-=300;
    if(color<50||color>=250) r=50;
    else if(50<=color&&color<100) r=100-color;
    else if(200<=color&&color<250) r=color-200;
    else r=0;
    if(color<150&&color>=50) g=50;
    else if(150<=color&&color<200) g=200-color;
    else if(color<50) g=color;
    else g=0;
    if(color<250&&color>=150) b=50;
    else if(250<=color) b=300-color;
    else if(100<=color&&color<150) b=color-100;
    else b=0;

    for(int i=0; i < NUMPIXELS; i++) {
      // LEDの色を設定 (R, G, B)
      pixels.setPixelColor(i, pixels.Color(r*(fabsf(1-bright))*MTP, g*(fabsf(1-bright))*MTP, b*(fabsf(1-bright))*MTP));
    }

    // 変更を反映させてLEDを点灯
    pixels.show();
    color+=1;
    bright+=0.05;
    if(bright>=2) bright=0;

    // 次のLEDを点灯するまでの待ち時間（ミリ秒）
    delay(100);
    if(digitalRead(SWI) == LOW) antichatter+=1;
    else antichatter=0;
    if(antichatter>8) break;
  }

//  delay(1000);
}