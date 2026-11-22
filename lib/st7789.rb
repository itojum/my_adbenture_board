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

  # 画像ファイル（tools/pack_image で作る）を少しずつ読んで展開しながら描く。
  # 画像全体をメモリに載せないので、大きな画像でもメモリを食わない。s: 拡大率
  # 画素は PackBits 圧縮: n < 128 なら続く n+1 バイトをそのまま、
  # n > 128 なら次の 1 バイトを 257-n 回くり返す
  def draw_image(x, y, path, s = 1)
    f = File.open(path, "r")
    hd = f.read(6)
    w = (hd.getbyte(0) << 8) | hd.getbyte(1)
    h = (hd.getbyte(2) << 8) | hd.getbyte(3)
    bpp = hd.getbyte(4)
    n = hd.getbyte(5)
    pal = f.read(n * 2)
    tbl = Array.new(n)
    i = 0
    while i < n
      tbl[i] = (pal.getbyte(i * 2).chr + pal.getbyte(i * 2 + 1).chr) * s
      i += 1
    end
    pal = nil
    row_bytes = (w * bpp + 7) / 8
    @cs.write(0)
    win(x, y, w * s, h * s)
    chunk = ""
    ci = 0
    lit = 0     # そのまま出すバイトの残り
    rep = 0     # くり返す回数（次のバイトを待っている）
    nb = 0      # 今の行に出したバイト数
    buf = ""
    r = 0
    while r < h
      if ci >= chunk.bytesize # size は文字数を数えるので使わない
        chunk = f.read(64)
        break unless chunk
        ci = 0
      end
      b = chunk.getbyte(ci)
      ci += 1
      if lit > 0
        cnt = 1
        lit -= 1
      elsif rep > 0
        cnt = rep
        rep = 0
      else
        if b < 128
          lit = b + 1
        elsif b > 128
          rep = 257 - b
        end
        cnt = 0
      end
      while cnt > 0
        if bpp == 4
          buf << tbl[b >> 4]
          buf << tbl[b & 0x0F] if nb * 2 + 1 < w
        else
          buf << tbl[b]
        end
        nb += 1
        if nb == row_bytes
          k = 0
          while k < s
            @spi.write(buf)
            k += 1
          end
          buf = ""
          nb = 0
          r += 1
        end
        cnt -= 1
      end
    end
    @cs.write(1)
    f.close
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
