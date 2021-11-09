require_relative 'live'

class Handler
  def initialize(osc_server, osc_client, tracks)
    super()

    @server = osc_server
    @client = osc_client

    @tracks = tracks

    @server.add_method '/musalce4live/tracks' do |message|
      @tracks.grant_registry_collection(message.to_a.each_slice(10).to_a)
    end

    @server.add_method '/musalce4live/track/routings' do |message|
      message.to_a.each_slice(5).to_a.each do |track_data|
        @tracks.grant_registry(track_data[0], *([nil] * 5), *track_data[1..])
      end
    end

    @server.add_method '/musalce4live/track/midi_audio' do |message|
      message.to_a.each_slice(5).to_a.each do |track_data|
        @tracks.grant_registry(track_data[0], *track_data[1..])
      end
    end

    @server.add_method '/musalce4live/track/name' do |message|
      message.to_a.each_slice(2).to_a.each do |track_data|
        @tracks.grant_registry(track_data[0], track_data[1])
      end
    end
  end

  def sync
    send '/musalce4live/tracks'
  end

  private def send(message, *args)
    @client.send OSC::Message.new(message, *args)
  end
end
