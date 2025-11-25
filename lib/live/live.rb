require_relative '../daw'

require_relative 'handler'
require_relative 'tracks'

module MusaLCEServer
  # Ableton Live integration module.
  #
  # Provides support for live coding with Ableton Live 11+ through
  # the MusaLCE for Live MIDI Remote Script.
  #
  # @see https://github.com/javier-sy/MusaLCEforLive MIDI Remote Script
  module Live
    # DAW controller for Ableton Live.
    #
    # Implements the {Daw} interface for Ableton Live, providing
    # track management and MIDI routing through the MusaLCE for Live
    # MIDI Remote Script.
    #
    # @note Transport controls (play, stop, etc.) are not implemented
    #   for Live as the MIDI Remote Script API doesn't support them.
    #
    # @example
    #   # Started via MusaLCEServer.run('live')
    #   daw.track('Bass').out.note(60, velocity: 100, duration: 1)
    class Live < Daw
      # @api private
      def daw_initialize(midi_devices:, clock:, osc_server:, osc_client:, logger:)
        super
        tracks = Tracks.new(midi_devices, logger: logger)
        handler = Handler.new(osc_server, osc_client, tracks, logger: logger)

        logger.info('Loaded Ableton Live driver')

        return tracks, handler
      end

      # Retrieves track(s) by name.
      #
      # Unlike Bitwig, Live can have multiple tracks with the same name.
      #
      # @param name [String] the track name
      # @param all [Boolean] if true, returns all matching tracks; otherwise returns first match
      # @return [Track, Array<Track>] the track(s) matching the name
      def track(name, all: false)
        if all
          @tracks.find_by_name(name)
        else
          @tracks.find_by_name(name).first
        end
      end

      # Sets the MIDI device to use for clock synchronization.
      #
      # @param midi_device_name [String] default device name to search for
      # @param manufacturer [String, nil] optional manufacturer filter
      # @param model [String, nil] optional model filter
      # @param name [String, nil] optional name filter (overrides midi_device_name)
      # @return [void]
      #
      # @example
      #   daw.midi_sync('IAC Driver Bus 1')
      def midi_sync(midi_device_name, manufacturer: nil, model: nil, name: nil)
        name ||= midi_device_name

        @clock.input = MIDICommunications::Input.all.find do |_|
          (_.manufacturer == manufacturer || manufacturer.nil?) &&
            (_.model == model || model.nil?) &&
            (_.name == name || name.nil?)
        end
      end
    end

    Daw.register :live, Live
  end
end
