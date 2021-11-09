require 'unimidi'

require_relative 'handler'

require_relative 'midi-devices'
require_relative 'tracks'

class Live
  def self.default
    @@default ||= Live.new
  end

  def initialize
    osc_server = OSC::EMServer.new(11_011)
    osc_client = OSC::Client.new('localhost', 10_001)

    Thread.new { osc_server.run }

    @clock = Musa::Clock::InputMidiClock.new do_log: true

    @sequencer = Musa::Sequencer::Sequencer.new 4, 24, do_log: true

    transport = Musa::Transport::Transport.new clock, sequencer: @sequencer

    transport.after_stop do
      sequencer.reset
    end

    @midi_devices = MIDIDevices.new(@sequencer)
    @tracks = Tracks.new(@midi_devices)
    @handler = Handler.new(osc_server, osc_client, @tracks)

    @handler.sync

    Thread.new { transport.start }
  end

  attr_reader :clock, :tracks, :sequencer

  def clock=(clock_midi_port_name)
    @clock.input = UniMIDI::Input.all.find { |_| _.name.end_with?(clock_midi_port_name) }
  end

  def sync
    @handler.sync
  end

  def track(name, all: false)
    if all
      @tracks.find_by_name(name)
    else
      @tracks.find_by_name(name).first
    end
  end
end
