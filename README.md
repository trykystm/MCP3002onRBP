# MCP3002 on Raspberry Pi

Raspberry Pi 上で SPI 接続された 10-bit A/D コンバータ **MCP3002** を制御するための Ruby スクリプト・ライブラリです。  
外部 Gem に依存せず、Ruby 標準ライブラリ（`IO#ioctl` / `Fiddle`）のみで Linux カーネル標準の SPI ドライバ（`/dev/spidev0.x`）と直接全二重通信を行います。

シングルエンド（Single-ended）入力および擬似差動（Pseudo-Differential）入力によるアナログ電圧のデジタル読み取り（0〜1023）に対応しています。

---

## 前提条件

- Raspberry Pi (Raspberry Pi OS - Pi 3 / 4 / 5、32bit / 64bit 対応)
- Ruby 3.x / 4.x（外部 Gem のインストールは不要です）
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

---

## 使い方

外部 Gem のインストールは不要です。Ruby が導入されていればそのまま実行できます。

### 1. ライブラリとして使用する場合

#### ブロック構文を使用（推奨: 自動クローズ）
```ruby
require_relative 'mcp3002'

# CE0 (デフォルト) を使用
MCP3002.open do |adc|
  val_ch0 = adc.single # デフォルトは CH0 (0〜1023)
  puts "CH0: #{val_ch0}"

  # 電圧換算例 (基準電圧 3.3V の場合)
  voltage = (val_ch0 / 1023.0) * 3.3
  puts "Voltage: #{voltage.round(2)} V"
end
```

#### 通常のインスタンス生成
```ruby
require_relative 'mcp3002'

# インスタンス作成（デフォルトは CE0: '/dev/spidev0.0'）
# CE1 を使用する場合は MCP3002.new(MCP3002::CE1) または MCP3002.new(1)
adc = MCP3002.new

# --- シングルエンド（Single-ended）モード ---
val_ch0 = adc.single(MCP3002::CH0)
puts "CH0: #{val_ch0}"

val_ch1 = adc.single(MCP3002::CH1)
puts "CH1: #{val_ch1}"

# --- 差動（Pseudo-Differential）モード ---
# CH0 を (+) 、CH1 を (-) として測定
diff_ch0 = adc.differential(MCP3002::DIFF_CH0)
puts "Differential (CH0+ / CH1-): #{diff_ch0}"

# 終了時はクローズ
adc.close
```

### 2. サンプルスクリプトを直接実行する場合

`mcp3002.rb` を直接実行すると、CH0 の値を 1 秒おきに 10 回読み取って表示します。

```bash
ruby mcp3002.rb
```

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

RSpec を使用して単体テストを実行できます（SPI ioctl 通信部はモック化されているため、PC 上でも実行可能です）。

```bash
rspec
```
