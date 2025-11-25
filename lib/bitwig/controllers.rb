require_relative 'tracks'

module MusaLCEServer
  module Bitwig
    # Manages Bitwig controller scripts and their MIDI channels.
    #
    # Controllers in Bitwig represent hardware MIDI devices configured
    # through the MusaLCE controller extension. Each controller has
    # 16 channels that can be named and mapped to tracks.
    #
    # @api private
    class Controllers
      # Creates a new controllers manager.
      #
      # @param midi_devices [MIDIDevices] the MIDI devices manager
      # @param clock [Musa::Clock::InputMidiClock] the MIDI clock
      # @param logger [Logger] the logger
      def initialize(midi_devices, clock:, logger:)
        @midi_devices = midi_devices
        @clock = clock
        @logger = logger
        @controllers = {}
        @tracks = Tracks.new(logger: logger)
      end

      # @!attribute [r] tracks
      #   @return [Tracks] the tracks collection
      attr_reader :tracks

      # Registers or updates the list of available controllers.
      #
      # @param controllers [Array<String>] controller names from Bitwig
      # @return [void]
      def register_controllers(controllers)
        to_delete = @controllers.keys - controllers

        controllers.each do |controller_name|
          if @controllers.key?(controller_name)
            @logger.info "Controller #{controller_name} already exists"
          else
            @logger.info "Added controller #{controller_name}"
            @controllers[controller_name] = Controller.new(controller_name, @midi_devices, @clock, @tracks, logger: @logger)
          end
        end

        to_delete.each do |controller_name|
          @controllers.delete(controller_name)
          @logger.info "Deleted controller #{controller_name}"
        end
      end

      # Registers a controller with its port and clock settings.
      #
      # @param name [String] the controller name
      # @param port_name [String] the MIDI port name
      # @param is_clock [Boolean] whether this controller provides MIDI clock
      # @return [void]
      def register_controller(name:, port_name:, is_clock:)
        controller = @controllers[name]
        controller.port_name = port_name
        controller.is_clock = is_clock
        @logger.info "Controller #{name} defined with port_name #{port_name} clock #{is_clock}"
      end

      # Updates a controller's name and settings.
      #
      # @param old_name [String] the current controller name
      # @param new_name [String] the new controller name
      # @param port_name [String] the MIDI port name
      # @param is_clock [Boolean] whether this controller provides MIDI clock
      # @return [void]
      def update_controller(old_name:, new_name:, port_name:, is_clock:)
        controller = @controllers.delete(old_name)
        @controllers[new_name] = controller
        controller.name = new_name

        controller.port_name = port_name
        controller.is_clock = is_clock

        @logger.info "Controller #{old_name} updated as #{new_name} with port_name #{port_name} clock #{is_clock}"
      end

      # Registers channel names for a controller.
      #
      # @param controller_name [String] the controller name
      # @param channels [Array<String>] channel names (up to 16)
      # @return [void]
      def register_channels(controller_name:, channels:)
        controller = @controllers[controller_name]

        @logger.info "Channels for controller #{controller_name} named #{channels}"

        channels.each.with_index do |name, i|
          controller.channels[i].name = name
        end
      end
    end

    # Represents a MIDI controller in Bitwig.
    #
    # A controller corresponds to a hardware MIDI device with 16 channels
    # that can be routed to tracks.
    #
    # @api private
    class Controller
      # Creates a new controller.
      #
      # @param name [String] the controller name
      # @param midi_devices [MIDIDevices] the MIDI devices manager
      # @param clock [Musa::Clock::InputMidiClock] the MIDI clock
      # @param tracks [Tracks] the tracks collection
      # @param logger [Logger] the logger
      def initialize(name, midi_devices, clock, tracks, logger:)
        @midi_devices = midi_devices
        @clock = clock
        @tracks = tracks
        @logger = logger

        @midi_device = nil

        self.name = name
        @channels = Array.new(16) { |channel| Channel.new(self, tracks, channel, logger: logger) }
      end

      # @!attribute port_name
      #   @return [String] the MIDI port name
      attr_accessor :port_name

      # @!attribute [r] name
      #   @return [String] the controller name
      # @!attribute [r] midi_device
      #   @return [MIDIDevice, nil] the associated MIDI device
      # @!attribute [r] channels
      #   @return [Array<Channel>] the 16 MIDI channels
      # @!attribute [r] is_clock
      #   @return [Boolean] whether this controller provides MIDI clock
      attr_reader :name, :midi_device, :channels, :is_clock

      # Sets whether this controller provides MIDI clock.
      #
      # @param new_is_clock [Boolean] the clock setting
      # @return [void]
      def is_clock=(new_is_clock)
        # TODO when new_is_clock is false look if another controller is true, else leave clock input as nil (the user has not selected any clock!)
        @is_clock = new_is_clock
        update_clock
      end

      # Sets the controller name and finds the associated MIDI device.
      #
      # @param new_name [String] the controller name
      # @return [void]
      def name=(new_name)
        @name = new_name
        @midi_device = @midi_devices.find(@name)

        update_clock

        if @midi_device
          @logger.info "Found midi device #{@midi_device.to_s} for #{@name}"
        else
          @logger.warn "Not found midi device for #{@name}"
        end
      end

      private def update_clock
        @clock.input = MIDICommunications::Input.find_by_name(@midi_device.low_level_device.name) if @is_clock
      end
    end

    # Represents a MIDI channel on a controller.
    #
    # Each channel can be named and mapped to a track for MIDI output.
    #
    # @api private
    class Channel
      # Creates a new channel.
      #
      # @param controller [Controller] the parent controller
      # @param tracks [Tracks] the tracks collection
      # @param channel_number [Integer] the MIDI channel (0-15)
      # @param logger [Logger] the logger
      def initialize(controller, tracks, channel_number, logger:)
        @controller = controller
        @tracks = tracks
        @channel_number = channel_number
        @logger = logger
      end

      # @!attribute [r] channel_number
      #   @return [Integer] the MIDI channel number (0-15)
      # @!attribute [r] name
      #   @return [String, nil] the channel name
      attr_reader :channel_number, :name

      # Sets the channel name and associates it with a track.
      #
      # @param new_name [String] the channel name
      # @return [void]
      def name=(new_name)
        @tracks[@name]&._forget_channel
        @name = new_name
        @tracks.create(@name)
        @tracks[@name]._channel = self
      end

      # Returns the MIDI voice for this channel.
      #
      # @return [Musa::MIDIVoices::MIDIVoice] the MIDI voice for output
      def output
        @controller.midi_device.channels[@channel_number]
      end

      # Returns a string representation of this channel.
      #
      # @return [String] description including channel number, name, port, and controller
      def to_s
        "<Channel #{@channel_number} '#{@name}' on port '#{@controller.port_name}' (controller '#{@controller.name}')>"
      end
    end
  end
end
