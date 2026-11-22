# my_adbenture_board

PicoRuby の [Adventure Board](https://picorubykaigi.org/adventure-board/) で動かすプログラムです。
ボードで動かすコードは `main.rb` で、`require` で読み込むファイルは `lib/` に置きます。

ボードは `.rb` をボード上でコンパイルするので、1 つのファイルが大きいと `NoMemoryError` になります。
大きなクラスやデータは `lib/` に分けると、1 ファイルずつコンパイルされるのでメモリのピークが下がります。

## 画像

液晶に出す画像は、Ruby のコードに埋め込まずにバイナリファイルにしてボードに置きます。
描くときに 1 行ずつ読むので、画像が大きくてもメモリを食いません。

1. 画像コンバータの出力（`IMG_PAL = [...]` と `IMG_DATA = [...]` を含む Ruby コード）を `images/` に置く
2. `tools/pack_image` で圧縮バイナリに変換して `data/` に出力する（可逆圧縮なので画質は変わらない）

```bash
tools/pack_image images/icon.rb data/icon.img
```

3. コードからは `lcd.draw_image(x, y, "/home/icon.img", 拡大率)` で描く

16 色以下なら 1 バイトに 2 ドット詰め、さらに同じバイトが続くところを PackBits でまとめます。
ボードでは少しずつ読んで展開しながら描きます。

## board: Mac から書き込む・実行する

`board` は、Web コンソールを使わずに Mac のターミナルからボードを操作する Ruby スクリプトです。
Mac に入っている Ruby の標準ライブラリだけで動きます（gem のインストールは不要）。

### 準備

1. ボードを USB で Mac につなぐ
2. ブラウザの [Web コンソール](https://picorubykaigi.org/adventure-board-console/) を開いているなら、切断するかタブを閉じる
   （コンソールがポートを使っていると `board` から開けません）

### 使い方

```bash
./board push
```

`lib/*.rb` をボードの `/lib/` に、`data/` のファイルを `/home/` に、`main.rb` を `/home/run.rb` に書き込み、ボードを再起動してから実行します。
`/lib/` のファイルは `main.rb` から `require 'ファイル名'`（拡張子なし）で読み込めます。
ボードの出力がそのまま表示され、Ctrl-C でボードのプログラムも止まります。
プログラムを動かしたままにしたいときは `-d` を付けます（`./board push -d`）。起動直後の出力を数秒表示して終わります。

| コマンド | 内容 |
| --- | --- |
| `./board push [LOCAL]` | `lib/*.rb` を `/lib/` に、`data/*` を `/home/` に、LOCAL（既定: `main.rb`）を `/home/run.rb` に書き込み、再起動して実行 |
| `./board put LOCAL [REMOTE]` | 1 ファイルだけ書き込む（REMOTE 既定: `/home/run.rb`） |
| `./board run [REMOTE]` | 再起動して REMOTE（既定: `/home/run.rb`）を実行 |
| `./board push -d` / `./board run -d` | 実行したら、プログラムを動かしたまま終わる |
| `./board app [LOCAL]` | `lib/*.rb` を `/lib/` に、`data/*` を `/home/` に、LOCAL を `/home/app.rb` に書き込む（ボードの起動時に自動で実行される） |
| `./board stop` | 実行中のプログラムを止める |
| `./board sh "COMMAND"` | ボードのシェルでコマンドを実行して結果を表示（例: `./board sh "ls /home"`） |
| `./board ports` | ボードのシェルのポートを探して表示 |

### 仕組みと注意

- ボードは USB のシリアルポートを 3 つ出します（`/dev/cu.usbmodem*`）。
  `board` は Ctrl-C を送ってシェルのプロンプト `$> ` が返ってくるポートを使います。
  そのため、ポートを探すだけでも実行中のプログラムは止まります。
  決まったポートを使うなら `BOARD_PORT=/dev/cu.usbmodem1101 ./board push` のように指定します。
- `lib/` と `data/` の下のサブフォルダは送りません（ボード側でフォルダを作れないため）。
- ファイルは Web コンソールと同じ PicoModem プロトコルで送り、ボードが返す CRC32 で中身を照合します。
- `push` と `run` は実行の前にボードを再起動します。
  Ctrl-C で止めたプログラムが SPI などをつかんだままだと、次の実行で `RuntimeError` になるためです。
- 再起動中にポートを開け閉めしたりキーを送ったりすると、ボードが再起動を繰り返すことがあります。
  `board` は再起動後、プロンプトが出るまで何も送らずに待ちます。
