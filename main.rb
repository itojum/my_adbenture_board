require 'spi'
require 'adventure_board'
GC.start

# 大きいコードやデータは /lib に分けて 1 ファイルずつ読む
# （ボード上でコンパイルするときのメモリのピークを下げるため）
require 'st7789'
GC.start
require 'icon_images'
GC.start
require 'twitter_images'
GC.start

matrix = AdventureBoard.matrix

BRIGHT = 100
DIM = 25

def plot_mask(m, rows, level)
  y = 0
  while y < 16
    bits = rows[y]
    x = 0
    while x < 16
      m.set(x + 1, y + 1, level) if (bits >> (15 - x)) & 1 == 1
      x += 1
    end
    y += 1
  end
end

spi = SPI.new(unit: :RP2040_SPI1, frequency: 20_000_000,
              sck_pin: 14, copi_pin: 15, cipo_pin: 12, mode: 3)
lcd = ST7789.new(spi, 16, 9, 26)

QR_SCALE = 7
QR_SIZE = 25

def show_ruby(m, lcd)
  m.clear
  plot_mask(m, RUBY_BRIGHT, BRIGHT)
  plot_mask(m, RUBY_DIM, DIM)
  m.show
  lcd.draw_rle(0, 0, 40, 40, RUBY_PAL, ICON_IMG, 6)
end

def show_twitter(m, lcd)
  m.clear
  plot_mask(m, TWITTER_ART, BRIGHT)
  m.show
  lcd.fill_rect(0, 0, 240, 240, 0xFFFF)
  off = (240 - QR_SIZE * QR_SCALE) / 2
  y = 0
  while y < QR_SIZE
    bits = QR_DATA[y]
    x = 0
    while x < QR_SIZE
      if (bits >> (QR_SIZE - 1 - x)) & 1 == 1
        x0 = x
        while x < QR_SIZE && (bits >> (QR_SIZE - 1 - x)) & 1 == 1
          x += 1
        end
        lcd.fill_rect(off + x0 * QR_SCALE, off + y * QR_SCALE,
                      (x - x0) * QR_SCALE, QR_SCALE, 0x0000)
      else
        x += 1
      end
    end
    y += 1
  end
end

buttons = AdventureBoard.buttons
twitter = false
show_ruby(matrix, lcd)
GC.start

# A ボタンで切り替え
while true
  if buttons.take_press == :a
    twitter = !twitter
    if twitter
      show_twitter(matrix, lcd)
    else
      show_ruby(matrix, lcd)
    end
    GC.start
  end
  sleep_ms(20)
end
