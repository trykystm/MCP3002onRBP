# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MCP3002 do
  let(:spi_mock) { instance_double(PiPiper::Spi) }
  let(:mcp3002) do
    allow(PiPiper::Spi).to receive(:begin).and_yield(spi_mock)
    described_class.new
  end

  describe '定数の定義' do
    it '差動モード用のコマンド定数が正しく設定されていること' do
      expect(described_class::DIFF_CH0).to eq(0b01001000)
      expect(described_class::DIFF_CH1).to eq(0b01011000)
    end
  end

  describe '#differential' do
    it 'デフォルト引数でDIFF_CH0を指定してSPI通信を行うこと' do
      expect(spi_mock).to receive(:write).with(described_class::DIFF_CH0, 0).and_return([0x00, 0x00])
      mcp3002.differential
    end

    it 'DIFF_CH1を指定してSPI通信を行うこと' do
      expect(spi_mock).to receive(:write).with(described_class::DIFF_CH1, 0).and_return([0x00, 0x00])
      mcp3002.differential(described_class::DIFF_CH1)
    end

    it 'SPIから受信した生データを10ビット整数値に変換して返すこと' do
      # 1023 (最大値: 0b11_11111111 -> [0b00000011, 0b11111111])
      allow(spi_mock).to receive(:write).and_return([0b00000011, 0b11111111])
      expect(mcp3002.differential).to eq(1023)

      # 512 (中間値: 0b10_00000000 -> [0b00000010, 0b00000000])
      allow(spi_mock).to receive(:write).and_return([0b00000010, 0b00000000])
      expect(mcp3002.differential).to eq(512)

      # 0 (最小値)
      allow(spi_mock).to receive(:write).and_return([0x00, 0x00])
      expect(mcp3002.differential).to eq(0)
    end
  end
end
