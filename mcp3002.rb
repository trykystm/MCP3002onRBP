require 'bundler'
Bundler.setup
Bundler.require # require 'pi_piper'

class MCP3002 < PiPiper::Spi
  CE0 = CHIP_SELECT_0
  CE1 = CHIP_SELECT_1
  CH0 = 0b01101000
  CH1 = 0b01111000
  DIFF_CH0 = 0b01001000
  DIFF_CH1 = 0b01011000

  def initialize(chip = CE0)
    PiPiper::Spi.begin(chip) do |spi|
      @spi = spi
    end
  end

  def single(ch = CH0)
    raw = @spi.write ch, 0
    ((raw[0] << 8) + raw[1]) & 0b001111111111
  end

  def differential(ch = DIFF_CH0)
    raw = @spi.write ch, 0
    ((raw[0] << 8) + raw[1]) & 0b001111111111
  end

  if __FILE__ == $PROGRAM_NAME
    mcp3002 = new
    10.times do
      p mcp3002.single CH0
      sleep 1
    end
  end
end
