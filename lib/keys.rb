# A / B ボタンだけを GPIO で直接読む。
# AdventureBoard.buttons は 6 個すべてを割り込みで見るぶんメモリを約 20KB 使うので、
# 使うボタンだけをループの中で読む。押すと 0、離すと 1（基板でプルアップ）
class Keys
  def initialize
    @a = GPIO.new(22, GPIO::IN | GPIO::PULL_UP)
    @b = GPIO.new(21, GPIO::IN | GPIO::PULL_UP)
    @last_a = 1
    @last_b = 1
  end

  # 押された瞬間だけ :a / :b を返す。20ms ごとに呼べばチャタリングも拾わない
  def take_press
    a = @a.read
    b = @b.read
    press = nil
    press = :a if a == 0 && @last_a == 1
    press = :b if b == 0 && @last_b == 1
    @last_a = a
    @last_b = b
    press
  end
end
