# MCP3002 on Raspberry Pi

Raspberry Pi 上で SPI 接続された 10-bit A/D コンバータ **MCP3002** を制御するための Ruby スクリプト・ライブラリです。  
`spi` gem を使用し、Linux カーネル標準の SPI ドライバ（`/dev/spidev0.x`）経由で全二重通信を行います。

シングルエンド（Single-ended）入力および擬似差動（Pseudo-Differential）入力によるアナログ電圧のデジタル読み取り（0〜1023）に対応しています。

---

## 前提条件

- Raspberry Pi (Raspberry Pi OS - Pi 3 / 4 / 5、32bit / 64bit 対応)
- Ruby 3.x / 4.x
- `spi` gem
- Raspberry Pi の SPI インターフェースが有効化されていること
  ```bash
  sudo raspi-config
  # [Interface Options] -> [SPI] -> 有効化 (Yes)
  ```
  ※ 一般ユーザーで実行する場合は、ユーザーが `spi` グループに所属している必要があります（デフォルトの `pi` ユーザー等は通常設定済みです）。

---

## ハードウェア接続（配線例）

MCP3002 と Raspberry Pi のピン接続対応表です。

| MCP3002 ピン | ピン名 | Raspberry Pi ピン（例: CE0利用時） | 備考 |
|---|---|---|---|
| 1 | $\overline{\text{CS}}\text{/SHDN}$ | GPIO 8 (Pin 24 / SPI0 CE0) | チップセレクト |
| 2 | CH0 | 測定対象アナログ入力 0 | |
| 3 | CH1 | 測定対象アナログ入力 1 | |
| 4 | $\text{V}_{\text{SS}}$ | GND (Pin 6 等) | グランド |
| 5 | $\text{D}_{\text{IN}}$ | GPIO 10 (Pin 19 / SPI0 MOSI) | データ入力 |
| 6 | $\text{D}_{\text{OUT}}$ | GPIO 9 (Pin 21 / SPI0 MISO) | データ出力 |
| 7 | CLK | GPIO 11 (Pin 23 / SPI0 SCLK) | クロック |
| 8 | $\text{V}_{\text{DD}}\text{/V}_{\text{REF}}$ | 3.3V (Pin 1 等) | 電源 / 基準電圧 |

※ CE1 (GPIO 7 / Pin 26) を使用する場合は、初期化時に `MCP3002::CE1`（または `1`）を指定してください。

### 動作確認用テスト回路（ブレッドボード配線例）

可変抵抗（ボリューム）と固定抵抗2本を使うことで、シングルエンド（CH0 / CH1）および擬似差動モード（DIFF_CH0 / DIFF_CH1）の全4パターンを同時にテストできます。

> **⚠️ 注意**: Raspberry Pi の GPIO は 3.3V 耐圧です。MCP3002 の $\text{V}_{\text{DD}}\text{/V}_{\text{REF}}$ (Pin 8) には **必ず 3.3V** を接続してください（5V は接続しないでください）。

```text
          +---v---+
 /CS (1) -|       |- (8) VDD/VREF  --> RPi 3.3V (Pin 1)
 CH0 (2) -|MCP3002|- (7) CLK       --> RPi SCLK (Pin 23 / GPIO 11)
 CH1 (3) -|       |- (6) DOUT      --> RPi MISO (Pin 21 / GPIO 9)
 VSS (4) -|       |- (5) DIN       --> RPi MOSI (Pin 19 / GPIO 10)
          +-------+
```

- **CH0 (Pin 2)：可変抵抗（10kΩ 程度）**
  - 左足：`3.3V`
  - 真ん中の足（出力）：MCP3002 `Pin 2 (CH0)`
  - 右足：`GND`
  - ツマミを回すことで `0`（0.0V）〜 `1023`（3.3V）まで連続的に変化します。
- **CH1 (Pin 3)：同じ抵抗値の固定抵抗 2 本による分圧（1kΩ〜10kΩ × 2本）**
  - `3.3V` ── `[抵抗A]` ── **接続点** ── `[抵抗B]` ── `GND` と直列に接続し、中間の**接続点**を MCP3002 `Pin 3 (CH1)` に繋ぎます。
  - 3.3V が半分（約 1.65V）に分圧され、読み取り値が常に **`512` 前後**で安定します。

| 可変抵抗 (CH0) の位置 | `single(CH0)` | `single(CH1)` | `differential(DIFF_CH0)`<br>*(CH0 - CH1)* | `differential(DIFF_CH1)`<br>*(CH1 - CH0)* |
|---|:---:|:---:|:---:|:---:|
| **3.3V 側（最大）** | `1023` (3.3V) | `512` (1.65V) | `511` 付近 (+1.65V差) | `0` (負電位は0に飽和) |
| **中央（約 1.65V）** | `512` (1.65V) | `512` (1.65V) | `0` (電位差なし) | `0` (電位差なし) |
| **GND 側（最小）** | `0` (0.0V) | `512` (1.65V) | `0` (負電位は0に飽和) | `512` 付近 (+1.65V差) |

---

## インストール・環境設定

### 依存 Gem のインストール

Bundler を使用して依存 Gem（`spi`, `rspec`, `rubocop`）をインストールします：

```bash
bundle install
```

※ Raspberry Pi 実機で開発・テスト用 Gem（`rspec`, `rubocop`）を除外してインストールする場合は以下を実行してください：

```bash
bundle config set --local without 'development test'
bundle install
```

---

## 使い方

### 1. ライブラリとして使用する場合

```ruby
require_relative 'mcp3002'

# インスタンス作成（デフォルトは CE0: '/dev/spidev0.0'）
# CE1 を使用する場合は MCP3002.new(MCP3002::CE1) または MCP3002.new(1)
adc = MCP3002.new

# --- シングルエンド（Single-ended）モード ---
# CH0 の読み取り（デフォルト引数は CH0）
val_ch0 = adc.single(MCP3002::CH0) # 0〜1023
puts "CH0: #{val_ch0}"

# CH1 の読み取り
val_ch1 = adc.single(MCP3002::CH1)
puts "CH1: #{val_ch1}"

# 電圧値（V）への換算例（電源電圧 3.3V の場合）
voltage = (val_ch0 / 1023.0) * 3.3
puts "Voltage: #{voltage.round(2)} V"

# --- 差動（Pseudo-Differential）モード ---
# CH0 を (+) 、CH1 を (-) として測定（デフォルト引数は DIFF_CH0）
diff_ch0 = adc.differential(MCP3002::DIFF_CH0)
puts "Differential (CH0+ / CH1-): #{diff_ch0}"

# CH1 を (+) 、CH0 を (-) として測定
diff_ch1 = adc.differential(MCP3002::DIFF_CH1)
puts "Differential (CH1+ / CH0-): #{diff_ch1}"
```

### 2. サンプルスクリプトを直接実行する場合

`mcp3002.rb` を直接実行すると、CH0 の値を 1 秒おきに 10 回読み取って表示します。  
ファイル先頭にシェバン（`#!/usr/bin/env ruby`）と `require 'bundler/setup'` を記述しているため、`ruby` や `bundle exec` を省略して直接実行できます。

```bash
chmod +x mcp3002.rb # 実行権限がない場合のみ
./mcp3002.rb
```

### 3. 全モード同時確認・トラブルシューティング用ワンライナー

#### 全4モード（CH0 / CH1 / DIFF_CH0 / DIFF_CH1）のリアルタイムモニター

上記のテスト回路を組んだ状態で、4つの測定値をリアルタイム表示（0.2秒間隔）して動作確認するコマンドです（終了は `Ctrl + C`）：

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

#### SPI 通信・配線診断（生バイト列の確認）

値が常に `0` になるなど通信不良が疑われる場合、SPI の受信生データ（2バイト・2進数）を表示して接触不良箇所を切り分けるコマンドです：

```bash
bundle exec ruby -r ./mcp3002 -e '
spi = SPI.new(device: MCP3002::CE0)
spi.speed = 1_000_000
raw = spi.xfer(txdata: [MCP3002::CH0, 0])
printf "Raw bytes: [%08b, %08b] -> Value: %d\n", raw[0], raw[1], ((raw[0] << 8) | raw[1]) & 0x03FF
'
```
- **ループバック確認**: MCP3002 の Pin 6 (DOUT / RPi MISO) のジャンパ線を抜き、Pin 5 (DIN / RPi MOSI) と直結して実行したときに `Raw bytes: [01101000, 00000000]` が返れば、Raspberry Pi 側の SPI 機能および MOSI/MISO ジャンパ線は正常です。

---

## 定数一覧

| 定数名 | デフォルト値 | 説明 |
|---|---|---|
| `CE0` | `'/dev/spidev0.0'` | SPI チップセレクト 0 デバイスパス |
| `CE1` | `'/dev/spidev0.1'` | SPI チップセレクト 1 デバイスパス |
| `CH0` | `0b01101000` | シングルエンド CH0 読み取りコマンド |
| `CH1` | `0b01111000` | シングルエンド CH1 読み取りコマンド |
| `DIFF_CH0` | `0b01001000` | 差動モード（IN+ = CH0, IN- = CH1）コマンド |
| `DIFF_CH1` | `0b01011000` | 差動モード（IN+ = CH1, IN- = CH0）コマンド |

---

## テストの実行

RSpec を使用して単体テストを実行できます（SPI 通信部はモック化されているため、PC 上でも実行可能です）。

```bash
bundle exec rspec
```
