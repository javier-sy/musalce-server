require 'unimidi'

require 'musa-dsl/midi/midi-voices'

class MIDIDevices
  include Enumerable

  def initialize(sequencer)
    @sequencer = sequencer
    @unimidi_devices = {}

    sync
  end

  def sync
    names = @unimidi_devices.keys

    UniMIDI::Output.all.each do |unimidi_device|
      next if @unimidi_devices.key?(unimidi_device.name)

      @unimidi_devices[unimidi_device.name] = MIDIDevice.new(@sequencer, unimidi_device)
      names.delete unimidi_device.name
    end

    # remove disconnected devices
    #
    names.each do |name|
      @unimidi_devices.delete name
    end
  end

  def [](name)
    @unimidi_devices[name]
  end

  def find(name)
    full_name = @unimidi_devices.keys.find { |_| _.end_with?(name) }
    @unimidi_devices[full_name]
  end

  def each(&block)
    if block_given?
      @unimidi_devices.values.each(&block)
    else
      @unimidi_devices.values.each
    end
  end
end

class MIDIDevice
  def initialize(sequencer, unimidi_device)
    @unimidi_device = unimidi_device
    @voices = Musa::MIDIVoices::MIDIVoices.new(sequencer: sequencer, output: unimidi_device, channels: 0..15, do_log: true)
  end

  def name
    @unimidi_device.name
  end

  def ports
    @voices.voices
  end
end
