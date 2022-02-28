require_relative 'tracks'

module MusaLCEServer
  module Bitwig
    class Controllers
      def initialize(midi_devices, clock:, logger:)
        @midi_devices = midi_devices
        @clock = clock
        @logger = logger
        @controllers = {}
        @tracks = Tracks.new(logger: logger)
      end

      attr_reader :tracks

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

      def register_controller(name:, port_name:, is_clock:)
        controller = @controllers[name]
        controller.port_name = port_name
        controller.is_clock = is_clock
        @logger.info "Controller #{name} defined with port_name #{port_name} clock #{is_clock}"
      end

      def update_controller(old_name:, new_name:, port_name:, is_clock:)
        controller = @controllers.delete(old_name)
        @controllers[new_name] = controller
        controller.name = new_name

        controller.port_name = port_name
        controller.is_clock = is_clock

        @logger.info "Controller #{old_name} updated as #{new_name} with port_name #{port_name} clock #{is_clock}"
      end

      def register_channels(controller_name:, channels:)
        controller = @controllers[controller_name]

        @logger.info "Channels for controller #{controller_name} named #{channels}"

        channels.each.with_index do |name, i|
          controller.channels[i].name = name
        end
      end
    end

    class Controller
      def initialize(name, midi_devices, clock, tracks, logger:)
        @midi_devices = midi_devices
        @clock = clock
        @tracks = tracks
        @logger = logger

        @midi_device = nil

        self.name = name
        @channels = Array.new(16) { |channel| Channel.new(self, tracks, channel, logger: logger) }
      end

      attr_accessor :port_name
      attr_reader :name, :midi_device, :channels, :is_clock

      def is_clock=(new_is_clock)
        # TODO when new_is_clock is false look if another controller is true, else leave clock input as nil (the user has not selected any clock!)
        @is_clock = new_is_clock
        update_clock
      end

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

    class Channel
      def initialize(controller, tracks, channel_number, logger:)
        @controller = controller
        @tracks = tracks
        @channel_number = channel_number
        @logger = logger
      end

      attr_reader :channel_number, :name

      def name=(new_name)
        @tracks[@name]&._forget_channel
        @name = new_name
        @tracks.create(@name)
        @tracks[@name]._channel = self
      end

      def output
        @controller.midi_device.channels[@channel_number]
      end

      def to_s
        "<Channel #{@channel_number} '#{@name}' on port '#{@controller.port_name}' (controller '#{@controller.name}')>"
      end
    end
  end
end
