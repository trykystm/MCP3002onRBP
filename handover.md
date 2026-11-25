# 引継ぎドキュメント (Handover)

## 1. プロジェクト概要
Raspberry Pi 上で SPI 接続された 10-bit A/D コンバータ **MCP3002** を Ruby (`spi` gem) から制御するライブラリおよびサンプルスクリプトです。
シングルエンド（CH0 / CH1）および擬似差動（DIFF_CH0 / DIFF_CH1）の 4 モードに対応しています。

---

## 2. 現在のステータスと完了事項

### 完了した実装・修正（直近コミット: `6630376`）
1. **Ruby 3.2+ / 4.x 互換パッチの追加 ([mcp3002.rb](mcp3002.rb))**
   - `spi` gem (v0.1.1) の `SPI::Driver::SPIdev#initialize` が、Ruby 3.2 以降で削除された `File.exists?` を呼び出して `NoMethodError` になる問題を解消するため、`File.singleton_class.alias_method(:exists?, :exist?)` による互換パッチを追加。
2. **`SPI#xfer` 入出力データ形式の修正 ([mcp3002.rb](mcp3002.rb) / [spec/mcp3002_spec.rb](spec/mcp3002_spec.rb))**
   - `spi` gem の `SPI::Driver::SPIdev#xfer` は引数 `txdata:` にバイト整数の配列 (`Array`) を受け取り、メソッド内部で `.pack('C*')` を呼び出し、戻り値も `.unpack('C*')` されたバイト配列 (`Array`) を返す仕様であることを実機検証で確認。
   - `MCP3002#transfer` が `bytes` 配列をそのまま `@spi.xfer(txdata: bytes)` に渡すよう修正し、RSpec のモック期待値も配列形式に統一。
3. **実機（Raspberry Pi ＋ ブレッドボード）での動作検証完了**
   - 可変抵抗（CH0）と固定抵抗分圧（CH1）を用いたテスト回路にて、シングルエンドおよび擬似差動モードが正常に動作することを実機確認済み。
4. **ドキュメント整備 ([README.md](README.md))**
   - ブレッドボードでの動作確認用テスト回路図、各モードの期待値表、4モード同時リアルタイムモニター用ワンライナー、および SPI ループバック・生バイト診断ワンライナーを追記済み。

---

## 3. ファイル構成

| ファイル | 役割 |
|---|---|
| `mcp3002.rb` | `MCP3002` クラス本体および直接実行時のサンプル処理（CH0 を 1 秒間隔で 10 回読み取り） |
| `spec/mcp3002_spec.rb` | `MCP3002` の RSpec 単体テスト（全 13 サンプル、SPI 通信モック化済み） |
| `spec/spec_helper.rb` | RSpec 設定ファイル |
| `README.md` | 配線表、テスト回路、使い方、トラブルシューティング用ワンライナーの解説 |
| `Gemfile` / `Gemfile.lock` | 依存 Gem 定義（`spi`, `rspec`, `rubocop`） |

---

## 4. テスト・静的解析・実機実行コマンド

### PC / 開発環境でのテスト・Lint
```bash
bundle exec rspec
bundle exec rubocop
```

### Raspberry Pi 実機での全モード同時モニター
```bash
bundle exec ruby -r ./mcp3002 -e '
adc = MCP3002.new
loop do
  c0 = adc.single(MCP3002::CH0)
  c1 = adc.single(MCP3002::CH1)
  d0 = adc.differential(MCP3002::DIFF_CH0)
  d1 = adc.differential(MCP3002::DIFF_CH1)
  printf "\rCH0:%4d (%.2fV) | CH1:%4d (%.2fV) | DIFF0(0-1):%4d | DIFF1(1-0):%4d", c0, c0*3.3/1023, c1, c1*3.3/1023, d0, d1
  sleep 0.2
end
'
```

### SPI 配線トラブル時の切り分け（生バイト列確認）
```bash
bundle exec ruby -r ./mcp3002 -e '
spi = SPI.new(device: MCP3002::CE0)
spi.speed = 1_000_000
raw = spi.xfer(txdata: [MCP3002::CH0, 0])
printf "Raw bytes: [%08b, %08b] -> Value: %d\n", raw[0], raw[1], ((raw[0] << 8) | raw[1]) & 0x03FF
'
```
- **値が常に `0` になる場合**:
  1. MISO (RPi Pin 21) を MOSI (RPi Pin 19) に直結して `[01101000, 00000000]` が返るか確認（ループバックテスト）。
  2. MISO を 3.3V に直結して `[11111111, 11111111]` が返るか確認。
  3. 上記が正常なら MCP3002 の電源 (Pin 8: 3.3V, Pin 4: GND)、チップセレクト (Pin 1: CE0 / RPi Pin 24)、クロック (Pin 7: SCLK / RPi Pin 23) の接触を確認。

---

## 5. 今後の拡張アイデア（Next Steps）
- 光センサー（CdS セルやフォトトランジスタ）、温度センサー（アナログ出力型）などを接続した応用スクリプトの作成
- 読み取った電圧値を移動平均フィルタ等で平滑化するヘルパーメソッドや、基準電圧（`vref: 3.3`）から直接ボルト（`Float`）を返す `#read_voltage` メソッドの追加
