# frozen_string_literal: true

# PiPiper がインストールされていない環境でもテストできるようにモッククラスを定義
module PiPiper
  class Spi
    CHIP_SELECT_0 = 0
    CHIP_SELECT_1 = 1

    def self.begin(_chip)
      yield new
    end

    def write(*_args)
      [0, 0]
    end
  end
end

require 'bundler'

# Bundler.setup / Bundler.require のエラーを回避するためのスタブ
module Bundler
  class << self
    def setup; end
    def require(*_args); end
  end
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
