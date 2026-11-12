# frozen_string_literal: true

begin
  require 'spi'
rescue LoadError
  # spi gem がインストールされていない開発環境（Windows等）でもテストできるようにスタブクラスを定義
  class SPI
    attr_accessor :speed

    def initialize(device:); end

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
