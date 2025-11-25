require_relative '../daw'

require_relative 'handler'
require_relative 'controllers'

module MusaLCEServer
  # Bitwig Studio integration module.
  #
  # Provides support for live coding with Bitwig Studio 5+ through
  # the MusaLCE for Bitwig controller extension.
  #
  # @see https://github.com/javier-sy/MusaLCEforBitwig Controller extension
  module Bitwig
    # DAW controller for Bitwig Studio.
    #
    # Implements the {Daw} interface for Bitwig Studio, providing
    # transport control, track management, and MIDI routing through
    # the MusaLCE for Bitwig controller extension.
    #
    # @example
    #   # Started via MusaLCEServer.run('bitwig')
    #   daw.track('Bass').out.note(60, velocity: 100, duration: 1)
    class Bitwig < Daw
      # @api private
      def daw_initialize(midi_devices:, clock:, osc_server:, osc_client:, logger:)
        super

        controllers = Controllers.new(midi_devices, clock: clock, logger: logger)
        handler = Handler.new(osc_server, osc_client, controllers, @sequencer, logger: logger)

        logger.info('Loaded Bitwig Studio driver')

        return controllers.tracks, handler
      end

      # Retrieves a track by name.
      #
      # @param name [String] the track name as configured in Bitwig
      # @param all [Boolean] if true, returns array; otherwise returns single track
      # @return [Track, Array<Track>] the track or array containing the track
      def track(name, all: false)
        if all
          [@tracks[name]]
        else
          @tracks[name]
        end
      end

      # Starts playback in Bitwig.
      # @return [void]
      def play
        @handler.play
        super
      end

      # Stops playback in Bitwig.
      # @return [void]
      def stop
        @handler.stop
        super
      end

      # Continues playback from current position.
      # @return [void]
      def continue
        @handler.continue
        super
      end

      # Moves playhead to specified bar position.
      # @param position [Numeric] the bar number (1-based)
      # @return [void]
      def goto(position)
        @handler.goto(position)
        super
      end

      # Starts recording in Bitwig.
      # @return [void]
      def record
        @handler.record
        super
      end
    end

    Daw.register :bitwig, Bitwig
  end
end

