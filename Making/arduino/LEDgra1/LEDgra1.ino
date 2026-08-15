#include <Adafruit_NeoPixel.h>

#define PIN        6
#define NUMPIXELS 150
#define MULTIPLE  150
#define BRIGHT    2.5 // MIN:0.0 MAX:5.0

int color = 0;

Adafruit_NeoPixel pixels(NUMPIXELS, PIN, NEO_GRB + NEO_KHZ800);

void setup() {
  pixels.begin();
  pixels.show();
}

int counter(int color, char c) {
  color = ((color % 300) + 300) % 300;
  int r = 0, g = 0, b = 0;
  if (color >= 300) color = 0;
  
  if (color < 50 || color >= 250) r = 50;
  else if (50 <= color && color < 100) r = 100 - color;
  else if (200 <= color && color < 250) r = color - 200;
  else r = 0;
  
  if (color < 150 && color >= 50) g = 50;
  else if (150 <= color && color < 200) g = 200 - color;
  else if (color < 50) g = color;
  else g = 0;
  
  if (color < 250 && color >= 150) b = 50;
  else if (250 <= color) b = 300 - color;
  else if (100 <= color && color < 150) b = color - 100;
  else b = 0;

  if (c == 'r') return r;
  if (c == 'g') return g;
  if (c == 'b') return b;
  return 0;
}

int mod300(int x) {
  int m = x % 300;
  if (m < 0) m += 300;
  return m;
}

void loop() {
  for (int i = 0; i < NUMPIXELS; i++) {
    // 全体を一旦クリア（消灯）
    pixels.clear();

    for (int j = 0; j < MULTIPLE; j++) {
      // 浮動小数点数でLEDのインデックスを計算して丸める
      int targetPixel = (int)(i + (float)NUMPIXELS / MULTIPLE * j) % NUMPIXELS;
      
      // 浮動小数点数で計算してからキャスト（割り算による0化を防止）
      int r = (int)((float)counter(mod300(color - 10 * j), 'r') / MULTIPLE * BRIGHT * (j + 1));
      int g = (int)((float)counter(mod300(color - 10 * j), 'g') / MULTIPLE * BRIGHT * (j + 1));
      int b = (int)((float)counter(mod300(color - 10 * j), 'b') / MULTIPLE * BRIGHT * (j + 1));

      // 範囲制限 (0〜255)
      r = constrain(r, 0, 255);
      g = constrain(g, 0, 255);
      b = constrain(b, 0, 255);

      pixels.setPixelColor(targetPixel, pixels.Color(r, g, b));
    }

    pixels.show();
    color += 2;
    delay(100);
  }
}