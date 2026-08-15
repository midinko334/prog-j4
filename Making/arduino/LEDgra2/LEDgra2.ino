#include <Adafruit_NeoPixel.h>

// NeoPixelの接続ピン番号
#define PIN 6
#define SWI 12

//色制御変数
int color=0;
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
  // すべてのLEDを消灯
  pixels.show();
}

void loop() {
  while (digitalRead(SWI) == HIGH);
  // 根本から順番にLEDを点灯させるループ
  for(int i=0; i < NUMPIXELS; i++) {
    // LEDの色を設定 (R, G, B)
    pixels.setPixelColor(i, pixels.Color(50, 50, 50));
    //pixels.setPixelColor((i-1+NUMPIXELS)%NUMPIXELS, pixels.Color(0, 0, 0));

    // 変更を反映させてLEDを点灯
    pixels.show();

    // 次のLEDを点灯するまでの待ち時間（ミリ秒）
    delay(20);
  }

  for(int gb = 50; gb >= 0; gb--) {
    for(int i = 0; i < NUMPIXELS; i++) {
      pixels.setPixelColor(i, pixels.Color(50, gb, gb));
    }
    pixels.show();
    delay(30);
  }

  while('v'){
    color+=1;
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
      pixels.setPixelColor(i, pixels.Color(r, g, b));
    }

    // 変更を反映させてLEDを点灯
    pixels.show();
    
    // 次のLEDを点灯するまでの待ち時間（ミリ秒）
    delay(100);
  }

//  delay(1000);
}