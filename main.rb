require 'spi'
require 'adventure_board'
GC.start

matrix = AdventureBoard.matrix

ART = [
  "................",
  "................",
  "...##########...",
  "..#++#++++#++#..",
  ".#++#++++++#++#.",
  "################",
  ".#+++#++++#+++#.",
  "..#+++#++#+++#..",
  "...#+++##+++#...",
  "....#++##++#....",
  ".....#+##+#.....",
  "......####......",
  ".......##.......",
  "................",
  "................",
  "................"
]
BRIGHT = 100
DIM = 25

matrix.clear
y = 0
while y < 16
  row = ART[y]
  x = 0
  while x < 16
    ch = row[x]
    if ch == "#"
      matrix.set(x + 1, y + 1, BRIGHT)
    elsif ch == "+"
      matrix.set(x + 1, y + 1, DIM)
    end
    x += 1
  end
  y += 1
end
matrix.show


class ST7789
  attr_reader :width, :height

  def initialize(spi, cs, dc, rst, width = 240, height = 240, xo = 0, yo = 0)
    @spi = spi
    @cs = GPIO.new(cs, GPIO::OUT)
    @cs.write(1)
    @dc = GPIO.new(dc, GPIO::OUT)
    r = GPIO.new(rst, GPIO::OUT)
    r.write(0); sleep_ms(10)
    r.write(1); sleep_ms(120)
    @width = width
    @height = height
    @xo = xo
    @yo = yo
    cmd(0x11); sleep_ms(120) # SLPOUT
    cmd(0x3A, [0x55])        # 16bit color
    cmd(0x36, [0x00])        # MADCTL
    cmd(0x21)                # INVON (色が反転したら 0x20)
    cmd(0x29)                # DISPON
  end

  def self.rgb(r, g, b)
    ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
  end

  def fill(c)
    fill_rect(0, 0, @width, @height, c)
  end

  def fill_rect(x, y, w, h, c)
    w = @width - x if x + w > @width
    h = @height - y if y + h > @height
    return if x < 0 || y < 0 || w <= 0 || h <= 0
    row = ((c >> 8).chr + (c & 0xFF).chr) * w
    @cs.write(0)
    win(x, y, w, h)
    i = 0
    while i < h
      @spi.write(row)
      i += 1
    end
    @cs.write(1)
  end

  # 画像コンバータの出力を描く
  # pal: RGB565 の配列（最大 64 色）, rows: 1 行 1 文字列, s: 拡大率
  CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+-"

  def draw_indexed(x, y, w, h, pal, rows, s = 1)
    return if x < 0 || y < 0 || x + w * s > @width || y + h * s > @height
    tbl = Array.new(128)
    i = 0
    while i < pal.size
      c = pal[i]
      tbl[CHARS.getbyte(i)] = ((c >> 8).chr + (c & 0xFF).chr) * s
      i += 1
    end
    @cs.write(0)
    win(x, y, w * s, h * s)
    r = 0
    while r < h
      line = rows[r]
      buf = ""
      j = 0
      while j < w
        buf << tbl[line.getbyte(j)]
        j += 1
      end
      k = 0
      while k < s
        @spi.write(buf)
        k += 1
      end
      r += 1
    end
    @cs.write(1)
  end

  def cmd(c, d = nil)
    @cs.write(0)
    reg(c, d)
    @cs.write(1)
  end

  private

  # CS を下げた状態で呼ぶ。終わるとデータ送信モード
  def win(x, y, w, h)
    x += @xo
    y += @yo
    reg(0x2A, [x >> 8, x & 0xFF, (x + w - 1) >> 8, (x + w - 1) & 0xFF])
    reg(0x2B, [y >> 8, y & 0xFF, (y + h - 1) >> 8, (y + h - 1) & 0xFF])
    @dc.write(0)
    @spi.write(0x2C)
    @dc.write(1)
  end

  def reg(c, d)
    @dc.write(0)
    @spi.write(c)
    return unless d
    @dc.write(1)
    @spi.write(d)
  end
end

spi = SPI.new(unit: :RP2040_SPI1, frequency: 20_000_000,
              sck_pin: 14, copi_pin: 15, cipo_pin: 12, mode: 3)
lcd = ST7789.new(spi, 16, 9, 26)

# 画像 40x40 / 16色 / 拡大 x6（液晶 240x240）
pal = [
  0x83AF, 0x18E4, 0xE6DD, 0x5A69, 0x8518, 0x4BB4, 0xCE7D, 0xBD97,
  0xEF5E, 0x3B11, 0x6C55, 0x0000, 0x9C51, 0xDB90, 0x730C, 0x39C8
]
data = [
  'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBBBBB11FFF11BBBBBBBBBBBBBBBBB',
  'BBBBBBBBBBBBB1F9AAAA5559FBBBBBBBBBBBBBBB',
  'BBBBBBBBBBB19AA455595000591BBBBBBBBBBBBB',
  'BBBBBBBBBBF54A5590DDCC777A9BBBBBBBBBBBBB',
  'BBBBBBBB19A45550DDC76666667FBBBBBBBBBBBB',
  'BBBBBBB154A55EDDC6666666666A1BBBBBBBBBBB',
  'BBBBBB154555EDC6666666222666FBBBBBBBBBBB',
  'BBBBB1945590D766666222222226ABBBBBBBBBBB',
  'BBBBB94A55E0766622288888822641BBBBBBBBBB',
  'BBBBFAA55EC666622288888888266FBBBBBBBBBB',
  'BBB154559C6662228888888882286FBBBBBBBBBB',
  'BBB94559466622888888888888822FBBBBBBBBBB',
  'BBFAA55A6622288888888888888229BBBBBBBBBB',
  'B15455A666228888888888888882701BBBBBBBBB',
  'BF455566622888888888888888240CEBBBBBBBBB',
  '15455A66228888888888888862A0CCC1BBBBBBBB',
  'FA555666288888888888888774ECCCCFBBFEFBBB',
  '94599662888888888888886ACEECCCC3BEC3F31B',
  'A55F9A2888888888888888C33E0000CEF01BBB3B',
  'A5597A888888888888884E7CCCCCCCCEEFBBBBFB',
  'A5595A28888888888840CC77CCCCCCCC00EE1B1B',
  '55567228888888888AC00CCCCE0CCCCCCC0CCFBB',
  'A556228888888888ACE0CC00307CCCCCC0C0CC1B',
  'A5A628888888888600300E0E077CC0CC00C00C3B',
  'A546288888888887030EE007CC7C0E0AA5CC00CB',
  'A546888888888887303C3E20CCCE3C044A0C0EC1',
  '5562288888888886CE30E260CC0E007444AC0E03',
  '55668888888888847EEC7270C03ECE044440EECC',
  '55628888888888673E0F36CCCEE70E0A44440ECC',
  '5562888888888884C0CAEC7C0CC000CFA44A0E00',
  '5A6288888888887EC7674C87CC702ECF9AA4028C',
  '5A62888888888800C27778777EE72ECF0005A48C',
  '9A62888888888670E288888780E36CEECCC0C867',
  '9A66888888886870308876866CC9373CCC0C2277',
  '9462888888847A6433027688777CC00CCCE0777C',
  '976888888877C7A7CE3E728886777CC0E3CE000E',
  'A228888888474446640EA7688267ECE03E0EEE11',
  '2288888888704466667AA00C7C00EEE3ECECE01B',
  '22888888886CA6666666674A0EE3E3EEEECEC0BB'
]

lcd.fill(0x0000)
lcd.draw_indexed(0, 0, 40, 40, pal, data, 6)
pal = nil
data = nil
GC.start
