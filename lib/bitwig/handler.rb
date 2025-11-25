require_relative '../daw'

module MusaLCEServer
  module Bitwig
    # OSC message handler for Bitwig Studio.
    #
    # Handles communication with the MusaLCE for Bitwig controller extension,
    # processing incoming OSC messages for controller and channel registration,
    # and sending transport commands.
    #
    # @api private
    class Handler < ::MusaLCEServer::Handler
      # Creates a new Bitwig handler.
      #
      # @param osc_server [OSC::EMServer] the OSC server for receiving messages
      # @param osc_client [OSC::Client] the OSC client for sending messages
      # @param controllers [Controllers] the controllers manager
      # @param sequencer [Musa::Sequencer::Sequencer] the sequencer instance
      # @param logger [Logger] the logger
      def initialize(osc_server, osc_client, controllers, sequencer, logger:)
        super()

        @server = osc_server
        @client = osc_client

        @controllers = controllers
        @sequencer = sequencer

        @logger = logger

        @server.add_method '/hello' do |message|
          @logger.info "Received /hello #{message.to_a}!"
          version
          sync
        end

        @server.add_method '/musalce4bitwig/controllers' do |message|
          @logger.info("Received /musalce4bitwig/controllers #{message.to_a}")
          @controllers.register_controllers(message.to_a)
        end

        @server.add_method '/musalce4bitwig/controller' do |message|
          @logger.info("Received /musalce4bitwig/controller #{message.to_a}")
          a = message.to_a
          @controllers.register_controller(name: a[0], port_name: a[1], is_clock: a[2] == 1)
        end

        @server.add_method '/musalce4bitwig/controller/update' do |message|
          @logger.info("Received /musalce4bitwig/controller/update #{message.to_a}")
          a = message.to_a
          @controllers.update_controller(old_name: a[0], new_name: a[1], port_name: a[2], is_clock: a[3] == 1)
        end

        @server.add_method '/musalce4bitwig/channels' do |message|
          @logger.info("Received /musalce4bitwig/channels #{message.to_a}")
          a = message.to_a
          @controllers.register_channels(controller_name: a[0], channels: a[1..])
        end
      end

      # Requests synchronization of controllers and channels from Bitwig.
      # @return [void]
      def sync
        @logger.info 'Asking sync'
        send_osc '/musalce4bitwig/sync'
      end

      # Sends play command to Bitwig.
      # @return [void]
      def play
        @logger.info 'Asking play'
        send_osc '/musalce4bitwig/play'
      end

      # Sends stop command to Bitwig.
      # @return [void]
      def stop
        @logger.info 'Asking stop'
        send_osc '/musalce4bitwig/stop'
      end

      # Sends continue command to Bitwig.
      # @return [void]
      def continue
        @logger.info 'Asking continue'
        send_osc '/musalce4bitwig/continue'
      end

      # Moves playhead to specified position.
      #
      # @param position [Numeric] the bar number (1-based)
      # @return [void]
      def goto(position)
        @logger.info "Asking goto #{position}"
        send_osc '/musalce4bitwig/goto', OSC::OSCDouble64.new(((position - 1) * @sequencer.beats_per_bar).to_f)
      end

      # Sends record command to Bitwig.
      # @return [void]
      def record
        @logger.info 'Asking record'
        send_osc '/musalce4bitwig/record'
      end

      # Sends panic to all tracks.
      # @return [void]
      def panic!
        @controllers.tracks.each(:panic!)
      end
    end
  end
end
