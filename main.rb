require 'spi'
require 'adventure_board'
GC.start

# 大きなメモリを使うもの（マトリクス・SPI）を先に作る。
# ライブラリを読んだ後だとメモリが細切れになり、確保できないことがある
matrix = AdventureBoard.matrix
spi = SPI.new(unit: :RP2040_SPI1, frequency: 20_000_000,
              sck_pin: 14, copi_pin: 15, cipo_pin: 12, mode: 3)
GC.start

# 大きいコードやデータは /lib に分けて 1 ファイルずつ読む
# （ボード上でコンパイルするときのメモリのピークを下げるため）
require 'st7789'
GC.start
lcd = ST7789.new(spi, 16, 9, 26)
require 'icon_images'
GC.start
require 'twitter_images'
GC.start
require 'screens'
GC.start
require 'keys'
GC.start
buttons = Keys.new

ICON = 0
TWITTER = 1
COVER = 2

matrix.pen = BRIGHT
mode = ICON
show_ruby(matrix, lcd)
GC.start

# A: アイコン <-> Twitter / B: 表紙 <-> アイコン
scroll_x = 16
tick = 0
while true
  btn = buttons.take_press
  if btn == :a || btn == :b
    if btn == :a
      mode = mode == ICON ? TWITTER : ICON
    else
      mode = mode == COVER ? ICON : COVER
    end
    if mode == ICON
      show_ruby(matrix, lcd)
    elsif mode == TWITTER
      show_twitter(matrix, lcd)
    else
      show_cover(matrix, lcd)
      scroll_x = 16 # 右の外から流しはじめる
    end
    GC.start
  end

  # 表紙のときは 40ms ごとに 1 ドット左へ流す
  if mode == COVER
    tick += 1
    if tick >= 2
      tick = 0
      scroll_text(matrix, scroll_x)
      scroll_x -= 1
      scroll_x = 16 if scroll_x < -WELCOME_W
    end
  end
  sleep_ms(20)
end
