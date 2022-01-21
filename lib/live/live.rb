require_relative 'handler'
require_relative 'tracks'

class Live < Daw
  def daw_initialize(midi_devices:, logger:, osc_server:, osc_client:)
    super
    @tracks = Tracks.new(midi_devices, logger: logger)
    Handler.new(osc_server, osc_client, @tracks)
  end

  attr_reader :tracks

  def track(name, all: false)
    if all
      @tracks.find_by_name(name)
    else
      @tracks.find_by_name(name).first
    end
  end
end

Daw.register :live, Live
