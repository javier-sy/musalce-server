require_relative '../daw'

require_relative 'handler'
require_relative 'controllers'

module MusaLCEServer
  module Bitwig
    class Bitwig < Daw
      def daw_initialize(midi_devices:, clock:, osc_server:, osc_client:, logger:)
        super

        controllers = Controllers.new(midi_devices, clock: clock, logger: logger)
        handler = Handler.new(osc_server, osc_client, controllers, @sequencer, logger: logger)

        logger.info('Loaded Bitwig Studio driver')

        return controllers.tracks, handler
      end

      def track(name, all: false)
        if all
          [@tracks[name]]
        else
          @tracks[name]
        end
      end

      def play
        @handler.play
        super
      end

      def stop
        @handler.stop
        super
      end

      def continue
        @handler.continue
        super
      end

      def goto(position)
        @handler.goto(position)
        super
      end

      def record
        @handler.record
        super
      end
    end

    Daw.register :bitwig, Bitwig
  end
end

