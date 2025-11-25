require 'musa-dsl/core-ext/dynamic-proxy'

module MusaLCEServer
  module Live
    # Represents a track in Ableton Live.
    #
    # Tracks in Live are identified by their internal ID and can have
    # MIDI input routing configured. The output is dynamically proxied
    # to allow routing changes without recreating the track object.
    class Track
      # Creates a new track.
      #
      # @param id [Integer] the Live track ID
      # @param midi_devices [MIDIDevices] the MIDI devices manager
      # @param logger [Logger] the logger
      def initialize(id, midi_devices, logger:)
        @id = id
        @midi_devices = midi_devices
        @logger = logger

        @output = Musa::Extension::DynamicProxy::DynamicProxy.new
      end

      # @!attribute [r] id
      #   @return [Integer] the Live track ID
      # @!attribute [r] name
      #   @return [String, nil] the track name
      attr_reader :id, :name

      # Returns the MIDI output for this track.
      #
      # @return [Musa::Extension::DynamicProxy::DynamicProxy] proxy to the MIDI voice
      def out
        @output
      end

      # @api private
      def _update_name(value)
        @name = value
        @logger.info "track #{@id} assigned name #{@name}"
      end

      # @api private
      def _update_has_midi_input(value);
      @has_midi_input = value == 1;
      end
      # @api private
      def _update_has_midi_output(value);
      @has_midi_output = value == 1;
      end
      # @api private
      def _update_has_audio_input(value);
      @has_audio_input = value == 1;
      end
      # @api private
      def _update_has_audio_output(value);
      @has_audio_output = value == 1;
      end

      # @api private
      def _update_current_input_routing(value)
        @current_input_routing = value
        _update_current_input_sub_routing(@current_input_sub_routing)
      end

      # @api private
      def _update_current_input_sub_routing(value)
        @current_input_sub_routing = value

        effective_midi_voice = nil

        if @has_midi_input
          device = @midi_devices.find(@current_input_routing)

          if device
            channel = /Ch\. (?<channel>\d+)/.match(@current_input_sub_routing)&.[](:channel)
            effective_midi_voice = device.channels[channel.to_i - 1] if channel

            @logger.info "track #{@id} assigned new input: device '#{device.name}' #{effective_midi_voice}"
          end
        end

        @output.receiver = effective_midi_voice
      end

      # @api private
      def _update_current_output_routing(value);
      @current_output_routing = value
      end

      # @api private
      def _update_current_output_sub_routing(value);
      @current_output_sub_routing = value
      end
    end

    # Collection of tracks for Ableton Live.
    #
    # Manages track registration and lookup, automatically creating
    # and updating tracks based on OSC messages from the MIDI Remote Script.
    #
    # @api private
    class Tracks
      include Enumerable

      # Creates a new tracks collection.
      #
      # @param midi_devices [MIDIDevices] the MIDI devices manager
      # @param logger [Logger] the logger
      def initialize(midi_devices, logger:)
        @midi_devices = midi_devices
        @logger = logger
        @tracks = {}
      end

      # Processes a batch of track data, creating, updating, and deleting tracks.
      #
      # @param tracks_data [Array<Array>] array of track data arrays
      # @return [void]
      def grant_registry_collection(tracks_data)
        tracks_to_delete = Set[*@tracks.keys]

        tracks_data.each do |track_data|
          grant_registry(*track_data)
          tracks_to_delete.delete track_data[0]
        end

        tracks_to_delete.each do |id|
          @tracks.delete(id)
          @logger.info "deleted track #{id}"
        end
      end

      # Registers or updates a track with the provided data.
      #
      # @param id [Integer] the track ID
      # @param name [String, nil] the track name
      # @param has_midi_input [Integer, nil] 1 if track has MIDI input
      # @param has_midi_output [Integer, nil] 1 if track has MIDI output
      # @param has_audio_input [Integer, nil] 1 if track has audio input
      # @param has_audio_output [Integer, nil] 1 if track has audio output
      # @param current_input_routing [String, nil] input routing device name
      # @param current_input_sub_routing [String, nil] input sub-routing (channel)
      # @param current_output_routing [String, nil] output routing device name
      # @param current_output_sub_routing [String, nil] output sub-routing
      # @return [void]
      def grant_registry(id, name = nil,
                         has_midi_input = nil, has_midi_output = nil,
                         has_audio_input = nil, has_audio_output = nil,
                         current_input_routing = nil, current_input_sub_routing = nil,
                         current_output_routing = nil, current_output_sub_routing = nil)

        track = @tracks[id]

        unless track
          track = Track.new(id, @midi_devices, logger: @logger)
          @tracks[id] = track
        end

        track._update_name(name) if name
        track._update_has_midi_input(has_midi_input) if has_midi_input
        track._update_has_midi_output(has_midi_output) if has_midi_output
        track._update_has_audio_input(has_audio_input) if has_audio_input
        track._update_has_audio_output(has_audio_output) if has_audio_output
        track._update_current_input_routing(parse_device_name(current_input_routing)) if current_input_routing
        track._update_current_input_sub_routing(current_input_sub_routing) if current_input_sub_routing
        track._update_current_output_routing(parse_device_name(current_output_routing)) if current_output_routing
        track._update_current_output_sub_routing(current_output_sub_routing) if current_output_sub_routing
      end

      # Iterates over all tracks.
      #
      # @yield [Track] each track
      # @return [Enumerator] if no block given
      def each(&block)
        if block_given?
          @tracks.values.each(&block)
        else
          @tracks.values.each
        end
      end

      # Retrieves a track by ID.
      #
      # @param id [Integer] the track ID
      # @return [Track, nil] the track or nil if not found
      def [](id)
        @tracks[id]
      end

      # Finds all tracks with the given name.
      #
      # @param name [String] the track name
      # @return [Array<Track>] matching tracks
      #
      # @todo Adapt to Bitwig semantics where track names are unique
      def find_by_name(name)
        @tracks.values.select { |_| _.name == name }
      end

      private def parse_device_name(name)
        match = name.match(/Driver IAC \((?<name>.+)\)/)
        match ? match[:name] : name
      end
    end
  end
end
