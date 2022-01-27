module Bitwig
  class Handler
    def initialize(osc_server, osc_client, controllers, logger:)
      super()

      @server = osc_server
      @client = osc_client

      @controllers = controllers

      @logger = logger

      @server.add_method '/hello' do |message|
        @logger.info "Received /hello #{message.to_a}!"
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
      send '/musalce4bitwig/controllers'
    end

    private def send(message, *args)
      counter = 0
      begin
        @client.send OSC::Message.new(message, *args)
      rescue Errno::ECONNREFUSED
        counter += 1
        @logger.warn "Errno::ECONNREFUSED when sending message #{message} #{args}. Retrying... (#{counter})"
        retry if counter < 3
      end
    end
  end
end
