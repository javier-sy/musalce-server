require_relative '../daw'

module MusaLCEServer
  module Live
    # OSC message handler for Ableton Live.
    #
    # Handles communication with the MusaLCE for Live MIDI Remote Script,
    # processing incoming OSC messages for track registration and routing.
    #
    # @api private
    class Handler < ::MusaLCEServer::Handler
      # Creates a new Live handler.
      #
      # @param osc_server [OSC::EMServer] the OSC server for receiving messages
      # @param osc_client [OSC::Client] the OSC client for sending messages
      # @param tracks [Tracks] the tracks manager
      # @param logger [Logger] the logger
      def initialize(osc_server, osc_client, tracks, logger:)
        super()

        @server = osc_server
        @client = osc_client

        @tracks = tracks

        @logger = logger

        @server.add_method '/hello' do |message|
          @logger.info "Received /hello #{message.to_a}!"
          sync
        end

        @server.add_method '/musalce4live/tracks' do |message|
          @tracks.grant_registry_collection(message.to_a.each_slice(10).to_a)
        end

        @server.add_method '/musalce4live/track/name' do |message|
          message.to_a.each_slice(2).to_a.each do |track_data|
            @tracks.grant_registry(track_data[0], track_data[1])
          end
        end

        @server.add_method '/musalce4live/track/midi' do |message|
          message.to_a.each_slice(3).to_a.each do |track_data|
            @tracks.grant_registry(track_data[0], *([nil] * 1), *track_data[1..])
          end
        end

        @server.add_method '/musalce4live/track/audio' do |message|
          message.to_a.each_slice(3).to_a.each do |track_data|
            @tracks.grant_registry(track_data[0], *([nil] * 3), *track_data[1..])
          end
        end

        @server.add_method '/musalce4live/track/routings' do |message|
          message.to_a.each_slice(5).to_a.each do |track_data|
            @tracks.grant_registry(track_data[0], *([nil] * 5), *track_data[1..])
          end
        end
      end

      # Requests track information from Live.
      # @return [void]
      def sync
        send_osc '/musalce4live/tracks'
      end
    end
  end
end
