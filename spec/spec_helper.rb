# frozen_string_literal: true

# Windows など IO#ioctl が標準で提供されない環境で RSpec のモック検証を通すための定義
unless IO.method_defined?(:ioctl)
  class IO
    def ioctl(_cmd, _arg)
      0
    end
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
