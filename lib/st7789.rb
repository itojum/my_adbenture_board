# ST7789 液晶（240x240, SPI）のドライバ
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
