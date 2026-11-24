# frozen_string_literal: true

begin
  require 'spi'
  # spi gem (0.1.1) は initialize メソッド実行時に初めて speed / speed= / xfer を定義する実装のため、
  # SPI.new をモック化するテスト環境でも instance_double(SPI) が検証できるようダミーの driver で一度初期化する
  SPI.new(driver: :mock) unless SPI.method_defined?(:xfer)
rescue LoadError
  # spi gem がインストールされていない環境でもテストできるようにスタブクラスを定義
  class SPI
    attr_accessor :speed

    def initialize(device: nil, driver: nil); end

    def xfer(txdata:)
      "\x00" * txdata.bytesize
    end
  end

  $LOADED_FEATURES << 'spi.rb'
end

require_relative '../mcp3002'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
