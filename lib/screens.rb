# 各表示を描く処理（main.rb を小さくするために分けている）

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

QR_SCALE = 7
QR_SIZE = 25

def show_ruby(m, lcd)
  m.clear
  plot_mask(m, RUBY_BRIGHT, BRIGHT)
  plot_mask(m, RUBY_DIM, DIM)
  m.show
  lcd.draw_image(0, 0, "/home/icon.img", 3) # 80x80 を 3 倍
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

# 表紙 170x240 を液晶の真ん中に、マトリクスでは文字を右から左へ流す
COVER_W = 170
WELCOME = "いらっしゃいませ！"
WELCOME_W = WELCOME.size * 16 # 全角 1 文字 = 16 ドット

def show_cover(m, lcd)
  m.clear
  m.show
  lcd.fill_rect(0, 0, 240, 240, 0x0000)
  lcd.draw_image((240 - COVER_W) / 2, 0, "/home/cover.img")
end

def scroll_text(m, x)
  m.clear_drawing
  m.draw_text(WELCOME, x, 0)
  m.blit
  m.show
end
