require_relative '../daw'

module MusaLCEServer
  module Bitwig
    class Handler < ::MusaLCEServer::Handler
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

      def sync
        @logger.info 'Asking sync'
        send_osc '/musalce4bitwig/sync'
      end

      def play
        @logger.info 'Asking play'
        send_osc '/musalce4bitwig/play'
      end

      def stop
        @logger.info 'Asking stop'
        send_osc '/musalce4bitwig/stop'
      end

      def continue
        @logger.info 'Asking continue'
        send_osc '/musalce4bitwig/continue'
      end

      def goto(position)
        @logger.info "Asking goto #{position}"
        send_osc '/musalce4bitwig/goto', OSC::OSCDouble64.new(((position - 1) * @sequencer.beats_per_bar).to_f)
      end

      def record
        @logger.info 'Asking record'
        send_osc '/musalce4bitwig/record'
      end

      def panic!
        @controllers.tracks.each(:panic!)
      end
    end
  end
end
