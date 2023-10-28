require 'midi-communications'

require_relative 'midi-devices'

module MusaLCEServer
  class Daw
    def self.register(daw_id, daw_class)
      @@daws ||= {}
      @@daws[daw_id] = daw_class
    end

    def self.daw_controller_for(daw_id)
      @@daws[daw_id].new
    end

    def initialize
      osc_server = OSC::EMServer.new(11_011)
      osc_client = OSC::Client.new('localhost', 10_001)

      Thread.new { osc_server.run }

      @sequencer = Musa::Sequencer::Sequencer.new 4, 24, dsl_context_class: MusaLCE_Context, do_log: true

      @clock = Musa::Clock::InputMidiClock.new do_log: true, logger: @sequencer.logger
      transport = Musa::Transport::Transport.new @clock, sequencer: @sequencer

      transport.after_stop do
        sequencer.reset
      end

      @midi_devices = MIDIDevices.new(@sequencer)

      @tracks, @handler = daw_initialize(midi_devices: @midi_devices, clock: @clock, osc_server: osc_server, osc_client: osc_client, logger: @sequencer.logger)

      @handler.version
      @handler.sync

      Thread.new { transport.start }
    end

    attr_reader :clock, :sequencer, :tracks

    protected def daw_initialize(midi_devices:, clock:, osc_server:, osc_client:, logger:); end

    def track(name, all: false)
      raise NotImplementedError
    end

    def play; end

    def stop; end

    def continue; end

    def goto(position); end

    def record; end

    def panic!
      @tracks.each do |track|
        track.out.all_notes_off
      end
    end

    def sync
      @handler.sync
    end

    def reload
      @handler.reload
    end
  end

  class Handler
    def reload
      @logger.info 'Asking controller reset and reload'
      send_osc '/reload'
    end

    def version
      @logger.info "Sending version #{VERSION}"
      send_osc '/version', VERSION
    end

    def panic!
      raise NotImplementedError
    end

    private def send_osc(message, *args)
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

  class MusaLCE_Context < Musa::Sequencer::Sequencer::DSLContext
    include Musa::REPL::CustomizableDSLContext

    def binder
      @__binder ||= binding
    end

    def import(*modules)
      modules.each do |m|
        self.class.include(m)
      end
    end
  end
end
