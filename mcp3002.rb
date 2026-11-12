# frozen_string_literal: true

require 'fiddle'

# Raspberry Pi 上の MCP3002 (10-bit A/D コンバータ) を制御するクラス
# Linux 標準の spidev インターフェース（IO#ioctl）を使用して通信を行います。
class MCP3002
  CE0 = '/dev/spidev0.0'
  CE1 = '/dev/spidev0.1'

  CH0 = 0b01101000
  CH1 = 0b01111000
  DIFF_CH0 = 0b01001000
  DIFF_CH1 = 0b01011000

  # Linux SPI ioctl 定義: _IOC(_IOC_WRITE, 'k', 0, 32)
  SPI_IOC_MESSAGE_1 = 0x40206B00
  DEFAULT_SPEED_HZ = 1_000_000

  attr_reader :device_path, :speed_hz

  class << self
    # ブロック構文による安全なオープンと自動クローズ
    def open(device = CE0, speed_hz: DEFAULT_SPEED_HZ)
      adc = new(device, speed_hz: speed_hz)
      return adc unless block_given?

      begin
        yield adc
      ensure
        adc.close
      end
    end
  end

  def initialize(device = CE0, speed_hz: DEFAULT_SPEED_HZ)
    @device_path = resolve_device(device)
    @speed_hz = speed_hz
    @io = File.open(@device_path, 'r+b')
  end

  # シングルエンド読み取り（0〜1023）
  def single(channel = CH0)
    transfer(channel, 0)
  end

  # 差動読み取り（0〜1023）
  def differential(channel = DIFF_CH0)
    transfer(channel, 0)
  end

  # デバイスのクローズ
  def close
    @io&.close unless closed?
  end

  # クローズ状態の確認
  def closed?
    @io.nil? || @io.closed?
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
    tx_data = bytes.pack('C*')
    len = tx_data.bytesize
    rx_ptr = Fiddle::Pointer.malloc(len, Fiddle::RUBY_FREE)

    @io.ioctl(SPI_IOC_MESSAGE_1, spi_transfer_msg(Fiddle::Pointer[tx_data], rx_ptr, len))
    raw = rx_ptr.to_str(len).bytes
    ((raw[0] << 8) | raw[1]) & 0x03FF
  end

  # struct spi_ioc_transfer (32バイト) のバイナリメッセージを生成
  def spi_transfer_msg(tx_ptr, rx_ptr, len)
    [
      tx_ptr.to_i, rx_ptr.to_i, len, @speed_hz,
      0, 8, 0, 0, 0, 0, 0
    ].pack('Q<Q<L<L<S<CCCCCC')
  end
end

if __FILE__ == $PROGRAM_NAME
  MCP3002.open do |adc|
    10.times do
      puts "CH0: #{adc.single}"
      sleep 1
    end
  end
end
