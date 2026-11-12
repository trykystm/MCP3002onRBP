# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MCP3002 do
  let(:io_mock) { instance_double(File, close: nil, closed?: false) }
  let(:mcp3002) do
    allow(File).to receive(:open).with(described_class::CE0, 'r+b').and_return(io_mock)
    described_class.new
  end

  # Fiddle を使用して ioctl 内で rx_ptr に模擬受信データを書き込むヘルパー
  def mock_spi_transfer(rx_bytes)
    allow(io_mock).to receive(:ioctl) do |cmd, msg|
      expect(cmd).to eq(described_class::SPI_IOC_MESSAGE_1)
      _tx_addr, rx_addr, len = msg.unpack('Q<Q<L<')
      rx_ptr = Fiddle::Pointer.new(rx_addr)
      rx_ptr[0, len] = rx_bytes.pack('C*')
      0
    end
  end

  describe '定数の定義' do
    it 'デバイスパス定数が正しく設定されていること' do
      expect(described_class::CE0).to eq('/dev/spidev0.0')
      expect(described_class::CE1).to eq('/dev/spidev0.1')
    end

    it 'コマンド定数が正しく設定されていること' do
      expect(described_class::CH0).to eq(0b01101000)
      expect(described_class::CH1).to eq(0b01111000)
      expect(described_class::DIFF_CH0).to eq(0b01001000)
      expect(described_class::DIFF_CH1).to eq(0b01011000)
    end
  end

  describe '.open' do
    it 'ブロックが与えられた場合、ブロック実行後に自動クローズされること' do
      allow(File).to receive(:open).with(described_class::CE0, 'r+b').and_return(io_mock)
      expect(io_mock).to receive(:close)

      yielded_instance = nil
      described_class.open do |adc|
        yielded_instance = adc
        expect(adc).to be_an_instance_of(described_class)
      end

      expect(yielded_instance).not_to be_nil
    end

    it 'ブロック内で例外が発生しても確実にクローズされること' do
      allow(File).to receive(:open).with(described_class::CE0, 'r+b').and_return(io_mock)
      expect(io_mock).to receive(:close)

      expect do
        described_class.open do
          raise StandardError, 'テスト例外'
        end
      end.to raise_error(StandardError, 'テスト例外')
    end

    it 'ブロックが与えられない場合、インスタンスを返すこと' do
      allow(File).to receive(:open).with(described_class::CE0, 'r+b').and_return(io_mock)
      adc = described_class.open
      expect(adc).to be_an_instance_of(described_class)
    end
  end

  describe '#initialize' do
    it '数値 0 またはシンボル :ce0 を CE0 パスに解決してオープンすること' do
      expect(File).to receive(:open).with('/dev/spidev0.0', 'r+b').and_return(io_mock)
      adc = described_class.new(0)
      expect(adc.device_path).to eq('/dev/spidev0.0')

      expect(File).to receive(:open).with('/dev/spidev0.0', 'r+b').and_return(io_mock)
      adc_sym = described_class.new(:ce0)
      expect(adc_sym.device_path).to eq('/dev/spidev0.0')
    end

    it '数値 1 またはシンボル :ce1 を CE1 パスに解決してオープンすること' do
      expect(File).to receive(:open).with('/dev/spidev0.1', 'r+b').and_return(io_mock)
      adc = described_class.new(1)
      expect(adc.device_path).to eq('/dev/spidev0.1')

      expect(File).to receive(:open).with('/dev/spidev0.1', 'r+b').and_return(io_mock)
      adc_sym = described_class.new(:ce1)
      expect(adc_sym.device_path).to eq('/dev/spidev0.1')
    end

    it '任意のデバイス文字列パスを渡してオープンできること' do
      expect(File).to receive(:open).with('/dev/spidev1.0', 'r+b').and_return(io_mock)
      adc = described_class.new('/dev/spidev1.0')
      expect(adc.device_path).to eq('/dev/spidev1.0')
    end
  end

  describe '#single' do
    it 'デフォルト引数で CH0 を指定して ioctl 通信を行うこと' do
      mock_spi_transfer([0x00, 0x00])
      expect(io_mock).to receive(:ioctl) do |_cmd, msg|
        tx_addr = msg.unpack1('Q<')
        tx_ptr = Fiddle::Pointer.new(tx_addr)
        expect(tx_ptr.to_str(2).bytes).to eq([described_class::CH0, 0])
        0
      end
      mcp3002.single
    end

    it 'CH1 を指定して ioctl 通信を行うこと' do
      mock_spi_transfer([0x00, 0x00])
      expect(io_mock).to receive(:ioctl) do |_cmd, msg|
        tx_addr = msg.unpack1('Q<')
        tx_ptr = Fiddle::Pointer.new(tx_addr)
        expect(tx_ptr.to_str(2).bytes).to eq([described_class::CH1, 0])
        0
      end
      mcp3002.single(described_class::CH1)
    end

    it '受信した生データを10ビット整数値に変換して返すこと' do
      mock_spi_transfer([0b00000011, 0b11111111])
      expect(mcp3002.single).to eq(1023)

      mock_spi_transfer([0b00000010, 0b00000000])
      expect(mcp3002.single).to eq(512)

      mock_spi_transfer([0x00, 0x00])
      expect(mcp3002.single).to eq(0)
    end
  end

  describe '#differential' do
    it 'デフォルト引数で DIFF_CH0 を指定して ioctl 通信を行うこと' do
      mock_spi_transfer([0x00, 0x00])
      expect(io_mock).to receive(:ioctl) do |_cmd, msg|
        tx_addr = msg.unpack1('Q<')
        tx_ptr = Fiddle::Pointer.new(tx_addr)
        expect(tx_ptr.to_str(2).bytes).to eq([described_class::DIFF_CH0, 0])
        0
      end
      mcp3002.differential
    end

    it 'DIFF_CH1 を指定して ioctl 通信を行うこと' do
      mock_spi_transfer([0x00, 0x00])
      expect(io_mock).to receive(:ioctl) do |_cmd, msg|
        tx_addr = msg.unpack1('Q<')
        tx_ptr = Fiddle::Pointer.new(tx_addr)
        expect(tx_ptr.to_str(2).bytes).to eq([described_class::DIFF_CH1, 0])
        0
      end
      mcp3002.differential(described_class::DIFF_CH1)
    end

    it '受信した生データを10ビット整数値に変換して返すこと' do
      mock_spi_transfer([0b00000011, 0b11111111])
      expect(mcp3002.differential).to eq(1023)

      mock_spi_transfer([0b00000010, 0b00000000])
      expect(mcp3002.differential).to eq(512)

      mock_spi_transfer([0x00, 0x00])
      expect(mcp3002.differential).to eq(0)
    end
  end

  describe '#close / #closed?' do
    it 'クローズ処理を行い、closed? が正しく判定されること' do
      is_closed = false
      allow(io_mock).to receive(:closed?) { is_closed }
      expect(mcp3002.closed?).to be false

      expect(io_mock).to receive(:close) { is_closed = true }
      mcp3002.close
      expect(mcp3002.closed?).to be true
    end
  end
end
