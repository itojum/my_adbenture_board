require 'spi'
require 'adventure_board'
GC.start

matrix = AdventureBoard.matrix

# 16x16 ドット絵: 1 行 = 16bit（左端が最上位ビット）
RUBY_BRIGHT = [
  0x0000, 0x0000, 0x1FF8, 0x2424, 0x4812, 0xFFFF, 0x4422, 0x2244,
  0x1188, 0x0990, 0x05A0, 0x03C0, 0x0180, 0x0000, 0x0000, 0x0000
]
RUBY_DIM = [
  0x0000, 0x0000, 0x0000, 0x1BD8, 0x37EC, 0x0000, 0x3BDC, 0x1DB8,
  0x0E70, 0x0660, 0x0240, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
]
TWITTER_ART = [
  0x0000, 0x0000, 0x001A, 0x203E, 0x307E, 0x3C7C, 0x1F7C, 0x3FFC,
  0x1FF8, 0x0FF8, 0x0FF0, 0x07E0, 0x1FC0, 0x7E00, 0x0000, 0x0000
]
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

class ST7789
  def initialize(spi, cs, dc, rst)
    @spi = spi
    @cs = GPIO.new(cs, GPIO::OUT)
    @cs.write(1)
    @dc = GPIO.new(dc, GPIO::OUT)
    r = GPIO.new(rst, GPIO::OUT)
    r.write(0); sleep_ms(10)
    r.write(1); sleep_ms(120)
    cmd(0x11); sleep_ms(120) # SLPOUT
    cmd(0x3A, [0x55])        # 16bit color
    cmd(0x36, [0x00])        # MADCTL
    cmd(0x21)                # INVON
    cmd(0x29)                # DISPON
  end

  def fill_rect(x, y, w, h, c)
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

  # ランレングス圧縮画像を描く
  # '0'-'F' = 色番号 1 ドット / 'a'-'z' + 色 = 同じ色が 2〜27 ドット続く
  def draw_rle(x, y, w, h, pal, img, s)
    tbl = Array.new(71)
    i = 0
    while i < 16
      c = pal[i]
      tbl[i < 10 ? 48 + i : 55 + i] = ((c >> 8).chr + (c & 0xFF).chr) * s
      i += 1
    end
    @cs.write(0)
    win(x, y, w * s, h * s)
    buf = ""
    n = 0
    i = 0
    len = img.size
    while i < len
      b = img.getbyte(i)
      run = 1
      if b >= 97
        run = b - 95
        i += 1
        b = img.getbyte(i)
      end
      px = tbl[b]
      while run > 0
        buf << px
        n += 1
        run -= 1
        if n == w
          k = 0
          while k < s
            @spi.write(buf)
            k += 1
          end
          buf = ""
          n = 0
        end
      end
      i += 1
    end
    @cs.write(1)
  end

  def cmd(c, d = nil)
    @cs.write(0)
    reg(c, d)
    @cs.write(1)
  end

  private

  def win(x, y, w, h)
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

# 画像 40x40 / 16色 / 拡大 x6
RUBY_PAL = [
  0x83AF, 0x18E4, 0xE6DD, 0x5A69, 0x8518, 0x4BB4, 0xCE7D, 0xBD97,
  0xEF5E, 0x3B11, 0x6C55, 0x0000, 0x9C51, 0xDB90, 0x730C, 0x39C8
]

ICON_IMG =
  'zBzBaBa1bFa1zBbB1F9cAb59FyB19aA4b595b0591vBF54Aa590aDaCb7A9tB19A4b50aDC7' \
  'e67FrB154Aa5EaDCi6A1pB154b5EDCf6b2b6FoB194a590D7d6g26AoB94Aa5E07b6b2e8a2' \
  '641mBFaAa5ECc6b2g82a6FlB154a59Cb6b2h8a286FlB94a594b6a2l8a2FkBFaAa5Aa6b2m' \
  '8a29jB154a5Ab6a2n82701iBF4b5b6a2n8240CEhB154a5Aa6a2m862A0bC1gBFAb5b62m8a' \
  '74EcCFaBFEFbB945a9a62m86ACaEcC3BEC3F31BAa5F9A2n8Ca3Ec0CEF01bB3BAa597Am84' \
  'E7gCaEFcBFBAa595A2j840aCa7gCa0aE1B1Bb567a2i8ACa0cCE0fC0aCFaBAa56a2i8ACE0' \
  'aCa0307eC0C0aC1BA5A62i86a03a0E0E0a7aC0aCa0Ca0C3BA5462i87030aEa07aC7C0E0a' \
  'A5aCa0CBA546j87303C3E20bCE3C0a4A0C0EC1a56a2i86CE30E260aC0Ea07b4AC0E03a5a' \
  '6j847aEC7270C03ECE0c40aEaCa562i8673E0F36bCaE70E0Ac40EaCa562j84C0CAEC7C0a' \
  'Cb0CFAa4A0Ea05A62i87EC7674C87aC702ECF9aA4028C5A62i8a0C2b78b7aE72ECFb05A4' \
  '8C9A62h8670E2d8780E36CaEbC0C8679Aa6g8687030a8768a6aC9373bC0Ca2a79462f847' \
  'A64a30276a8b7aCa0bCE0b7C976f8a7C7A7CE3E72b86b7aC0E3CEb0EAa2f847b4a640EA7' \
  '6a8267ECE03E0bEa1a2g870a4c67aAa0C7Ca0bE3ECECE01Ba2g86CAg674A0aE3E3cECEC0' \
  'aB'

# QR（https://x.com/itojum1230）1 行 = 25bit
QR_DATA = [
  0x1FCE47F, 0x105F941, 0x175D15D, 0x1758B5D, 0x174455D,
  0x1044441, 0x1FD557F, 0x0019500, 0x105BFCE, 0x08AFE1E,
  0x074F78B, 0x0110419, 0x02D9541, 0x1998722, 0x16CF37B,
  0x139A2AD, 0x11739F4, 0x0015510, 0x1FC3551, 0x1049111,
  0x1749BF4, 0x17453C3, 0x174D90D, 0x10455B1, 0x1FDA509
]
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
