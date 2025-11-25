require 'midi-communications'

require 'musa-dsl/midi/midi-voices'

module MusaLCEServer
  # Manages available MIDI output devices.
  #
  # Provides enumeration and lookup of MIDI devices, automatically
  # synchronizing with the system's available devices.
  #
  # @example Iterating over devices
  #   midi_devices.each { |device| puts device.name }
  #
  # @example Finding a device by name suffix
  #   device = midi_devices.find('IAC Driver Bus 1')
  class MIDIDevices
    include Enumerable

    # Creates a new MIDI devices manager.
    #
    # @param sequencer [Musa::Sequencer::Sequencer] the sequencer for MIDI voice management
    def initialize(sequencer)
      @sequencer = sequencer
      @low_level_devices = {}

      sync
    end

    # Synchronizes the device list with system MIDI devices.
    #
    # Adds newly connected devices and removes disconnected ones.
    #
    # @return [void]
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

    # Retrieves a device by exact name.
    #
    # @param name [String] the exact device name
    # @return [MIDIDevice, nil] the device or nil if not found
    def [](name)
      @low_level_devices[name]
    end

    # Finds a device by name suffix.
    #
    # Useful when device names include prefixes that vary by system.
    #
    # @param name [String] the name suffix to match
    # @return [MIDIDevice, nil] the first matching device or nil
    #
    # @example
    #   device = midi_devices.find('Bus 1')  # Matches 'IAC Driver Bus 1'
    def find(name)
      full_name = @low_level_devices.keys.find { |_| _.end_with?(name) }
      @low_level_devices[full_name]
    end

    # Iterates over all MIDI devices.
    #
    # @yield [MIDIDevice] each device
    # @return [Enumerator] if no block given
    def each(&block)
      if block_given?
        @low_level_devices.values.each(&block)
      else
        @low_level_devices.values.each
      end
    end
  end

  # Wrapper for a MIDI output device with voice management.
  #
  # Provides access to individual MIDI channels as voices and
  # panic functionality.
  class MIDIDevice
    # Creates a new MIDI device wrapper.
    #
    # @param sequencer [Musa::Sequencer::Sequencer] the sequencer for voice management
    # @param low_level_device [MIDICommunications::Output] the underlying MIDI device
    def initialize(sequencer, low_level_device)
      @low_level_device = low_level_device
      @voices = Musa::MIDIVoices::MIDIVoices.new(sequencer: sequencer, output: low_level_device, channels: 0..15, do_log: true)
    end

    # @!attribute [r] low_level_device
    #   @return [MIDICommunications::Output] the underlying MIDI output device
    attr_reader :low_level_device

    # Returns the device name.
    #
    # @return [String] the device name
    def name
      @low_level_device.name
    end

    # Sends All Notes Off and reset to all channels.
    #
    # @return [void]
    def panic!
      @voices.panic reset: true
    end

    # Returns the MIDI channels/voices for this device.
    #
    # @return [Array<Musa::MIDIVoices::MIDIVoice>] the 16 MIDI channels
    def channels
      @voices.voices
    end

    # Returns the display name of the device.
    #
    # @return [String] the display name
    def to_s
      @low_level_device.display_name
    end
  end
end

