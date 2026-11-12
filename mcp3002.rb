# frozen_string_literal: true

require 'spi'

# Raspberry Pi 上の MCP3002 (10-bit A/D コンバータ) を制御するクラス
# spi gem を使用して Linux 標準の spidev インターフェースと通信を行います。
class MCP3002
  CE0 = '/dev/spidev0.0'
  CE1 = '/dev/spidev0.1'

  CH0 = 0b01101000
  CH1 = 0b01111000
  DIFF_CH0 = 0b01001000
  DIFF_CH1 = 0b01011000

  DEFAULT_SPEED_HZ = 1_000_000

  attr_reader :device_path, :speed_hz

  def initialize(device = CE0, speed_hz: DEFAULT_SPEED_HZ)
    @device_path = resolve_device(device)
    @speed_hz = speed_hz
    @spi = SPI.new(device: @device_path)
    @spi.speed = @speed_hz
  end

  # シングルエンド読み取り（0〜1023）
  def single(channel = CH0)
    transfer(channel, 0)
  end

  # 差動読み取り（0〜1023）
  def differential(channel = DIFF_CH0)
    transfer(channel, 0)
  end

  private

  # デバイス名または番号からデバイスパスを解決
  def resolve_device(device)
    case device
    when 0, :ce0 then CE0
    when 1, :ce1 then CE1
    else device.to_s
    end
  end

  # SPI 全二重通信（Full Duplex transfer）
  def transfer(*bytes)
    raw = @spi.xfer(txdata: bytes.pack('C*')).bytes
    ((raw[0] << 8) | raw[1]) & 0x03FF
  end
end

if __FILE__ == $PROGRAM_NAME
  mcp3002 = MCP3002.new
  10.times do
    puts "CH0: #{mcp3002.single}"
    sleep 1
  end
end
