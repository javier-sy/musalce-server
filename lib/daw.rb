require 'midi-communications'

require_relative 'midi-devices'

class Daw
  def self.register(daw_id, daw_class)
    @@daws ||= {}
    @@daws[daw_id] = daw_class
  end

  def self.daw_controller_for(daw_id)
    @@daws[daw_id].new
  end

  def initialize
    osc_server = OSC::EMServer.new(11_011)
    osc_client = OSC::Client.new('localhost', 10_001)

    Thread.new { osc_server.run }

    @sequencer = Musa::Sequencer::Sequencer.new 4, 24, do_log: true

    @clock = Musa::Clock::InputMidiClock.new do_log: true, logger: @sequencer.logger
    transport = Musa::Transport::Transport.new @clock, sequencer: @sequencer

    transport.after_stop do
      sequencer.reset
    end

    @midi_devices = MIDIDevices.new(@sequencer)

    @tracks, @handler = daw_initialize(midi_devices: @midi_devices, clock: @clock, osc_server: osc_server, osc_client: osc_client, logger: @sequencer.logger)

    @handler.sync

    Thread.new { transport.start }
  end

  protected def daw_initialize(midi_devices:, clock:, osc_server:, osc_client:, logger:); end
  def track(name, all: false); end

  attr_reader :clock, :sequencer, :tracks

  def midi_sync(midi_device_name, manufacturer: nil, model: nil, name: nil)
    name ||= midi_device_name

    @clock.input = MIDICommunications::Input.all.find do |_|
      (_.manufacturer == manufacturer || manufacturer.nil?) &&
        (_.model == model || model.nil?) &&
        (_.name == name || name.nil?)
    end
  end

  def sync
    @handler.sync
  end
end
