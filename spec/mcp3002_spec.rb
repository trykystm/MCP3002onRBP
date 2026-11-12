# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MCP3002 do
  let(:spi_mock) { instance_double(SPI, 'speed=': nil) }
  let(:mcp3002) do
    allow(SPI).to receive(:new).with(device: described_class::CE0).and_return(spi_mock)
    described_class.new
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

  describe '#initialize' do
    it 'デフォルトで CE0 と 1MHz のクロック速度を設定すること' do
      expect(SPI).to receive(:new).with(device: '/dev/spidev0.0').and_return(spi_mock)
      expect(spi_mock).to receive(:speed=).with(1_000_000)

      adc = described_class.new
      expect(adc.device_path).to eq('/dev/spidev0.0')
      expect(adc.speed_hz).to eq(1_000_000)
    end

    it '数値 0 またはシンボル :ce0 を CE0 パスに解決すること' do
      expect(SPI).to receive(:new).with(device: '/dev/spidev0.0').twice.and_return(spi_mock)

      expect(described_class.new(0).device_path).to eq('/dev/spidev0.0')
      expect(described_class.new(:ce0).device_path).to eq('/dev/spidev0.0')
    end

    it '数値 1 またはシンボル :ce1 を CE1 パスに解決すること' do
      expect(SPI).to receive(:new).with(device: '/dev/spidev0.1').twice.and_return(spi_mock)

      expect(described_class.new(1).device_path).to eq('/dev/spidev0.1')
      expect(described_class.new(:ce1).device_path).to eq('/dev/spidev0.1')
    end

    it '任意のデバイス文字列パスを渡して初期化できること' do
      expect(SPI).to receive(:new).with(device: '/dev/spidev1.0').and_return(spi_mock)
      adc = described_class.new('/dev/spidev1.0')
      expect(adc.device_path).to eq('/dev/spidev1.0')
    end
  end

  describe '#single' do
    it 'デフォルト引数で CH0 を指定して SPI 通信を行うこと' do
      expected_tx = [described_class::CH0, 0].pack('C*')
      expect(spi_mock).to receive(:xfer).with(txdata: expected_tx).and_return("\x00\x00".b)
      mcp3002.single
    end

    it 'CH1 を指定して SPI 通信を行うこと' do
      expected_tx = [described_class::CH1, 0].pack('C*')
      expect(spi_mock).to receive(:xfer).with(txdata: expected_tx).and_return("\x00\x00".b)
      mcp3002.single(described_class::CH1)
    end

    it 'SPI から受信した生データを10ビット整数値に変換して返すこと' do
      allow(spi_mock).to receive(:xfer).and_return([0b00000011, 0b11111111].pack('C*'))
      expect(mcp3002.single).to eq(1023)

      allow(spi_mock).to receive(:xfer).and_return([0b00000010, 0b00000000].pack('C*'))
      expect(mcp3002.single).to eq(512)

      allow(spi_mock).to receive(:xfer).and_return("\x00\x00".b)
      expect(mcp3002.single).to eq(0)
    end
  end

  describe '#differential' do
    it 'デフォルト引数で DIFF_CH0 を指定して SPI 通信を行うこと' do
      expected_tx = [described_class::DIFF_CH0, 0].pack('C*')
      expect(spi_mock).to receive(:xfer).with(txdata: expected_tx).and_return("\x00\x00".b)
      mcp3002.differential
    end

    it 'DIFF_CH1 を指定して SPI 通信を行うこと' do
      expected_tx = [described_class::DIFF_CH1, 0].pack('C*')
      expect(spi_mock).to receive(:xfer).with(txdata: expected_tx).and_return("\x00\x00".b)
      mcp3002.differential(described_class::DIFF_CH1)
    end

    it 'SPI から受信した生データを10ビット整数値に変換して返すこと' do
      allow(spi_mock).to receive(:xfer).and_return([0b00000011, 0b11111111].pack('C*'))
      expect(mcp3002.differential).to eq(1023)

      allow(spi_mock).to receive(:xfer).and_return([0b00000010, 0b00000000].pack('C*'))
      expect(mcp3002.differential).to eq(512)

      allow(spi_mock).to receive(:xfer).and_return("\x00\x00".b)
      expect(mcp3002.differential).to eq(0)
    end
  end
end
