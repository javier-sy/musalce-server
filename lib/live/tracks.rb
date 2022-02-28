require 'musa-dsl/core-ext/dynamic-proxy'

module MusaLCEServer
  module Live
    class Track
      def initialize(id, midi_devices, logger:)
        @id = id
        @midi_devices = midi_devices
        @logger = logger

        @output = Musa::Extension::DynamicProxy::DynamicProxy.new
      end

      attr_reader :id, :name

      def out
        @output
      end

      def _update_name(value)
        @name = value
        @logger.info "track #{@id} assigned name #{@name}"
      end

      def _update_has_midi_input(value);
      @has_midi_input = value == 1;
      end
      def _update_has_midi_output(value);
      @has_midi_output = value == 1;
      end
      def _update_has_audio_input(value);
      @has_audio_input = value == 1;
      end
      def _update_has_audio_output(value);
      @has_audio_output = value == 1;
      end

      def _update_current_input_routing(value)
        @current_input_routing = value
        _update_current_input_sub_routing(@current_input_sub_routing)
      end

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

      def _update_current_output_routing(value);
      @current_output_routing = value
      end

      def _update_current_output_sub_routing(value);
      @current_output_sub_routing = value
      end
    end

    class Tracks
      include Enumerable

      def initialize(midi_devices, logger:)
        @midi_devices = midi_devices
        @logger = logger
        @tracks = {}
      end

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

      def each(&block)
        if block_given?
          @tracks.values.each(&block)
        else
          @tracks.values.each
        end
      end

      def [](id)
        @tracks[id]
      end

      # TODO adaptar a contrato y semántica de Bitwig (en bitwig sólo hay un track con un nombre determinado, el id no existe)

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
