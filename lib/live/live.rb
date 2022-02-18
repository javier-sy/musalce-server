require_relative '../daw'

require_relative 'handler'
require_relative 'tracks'

module Live
  class Live < Daw
    def daw_initialize(midi_devices:, clock:, osc_server:, osc_client:, logger:)
      super
      tracks = Tracks.new(midi_devices, logger: logger)
      handler = Handler.new(osc_server, osc_client, tracks, logger: logger)

      logger.info('Loaded Ableton Live driver')

      return tracks, handler
    end

    def track(name, all: false)
      if all
        @tracks.find_by_name(name)
      else
        @tracks.find_by_name(name).first
      end
    end
  end

  Daw.register :live, Live
end
