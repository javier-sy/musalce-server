require 'midi-communications'

require 'musa-dsl/midi/midi-voices'

module MusaLCEServer
  class MIDIDevices
    include Enumerable

    def initialize(sequencer)
      @sequencer = sequencer
      @low_level_devices = {}

      sync
    end

    def sync
      names = @low_level_devices.keys

      MIDICommunications::Output.all.each do |low_level_device|
        next if @low_level_devices.key?(low_level_device.name)

        @low_level_devices[low_level_device.name] = MIDIDevice.new(@sequencer, low_level_device)
        names.delete low_level_device.name
      end

      # remove disconnected devices
      #
      names.each do |name|
        @low_level_devices.delete name
      end
    end

    def [](name)
      @low_level_devices[name]
    end

    def find(name)
      full_name = @low_level_devices.keys.find { |_| _.end_with?(name) }
      @low_level_devices[full_name]
    end

    def each(&block)
      if block_given?
        @low_level_devices.values.each(&block)
      else
        @low_level_devices.values.each
      end
    end
  end
  
  class MIDIDevice
    def initialize(sequencer, low_level_device)
      @low_level_device = low_level_device
      @voices = Musa::MIDIVoices::MIDIVoices.new(sequencer: sequencer, output: low_level_device, channels: 0..15, do_log: true)
    end

    attr_reader :low_level_device

    def name
      @low_level_device.name
    end

    def channels
      @voices.voices
    end

    def to_s
      @low_level_device.display_name
    end
  end
end

