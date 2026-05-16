require 'midi-communications'

require_relative 'midi-devices'

module MusaLCEServer
  # @return [Surface, nil] active control surface, set during {Daw}
  #   initialization. Exposed to the DSL as +surface+ in
  #   {MusaLCE_Context}; mutating its controls (e.g.
  #   +surface[:foo].enabled = true+) emits OSC state outbound to
  #   the DAW extension and on to Pulso Bridge / Stream Deck.
  class << self
    attr_accessor :surface
  end

  # Base class for DAW (Digital Audio Workstation) controllers.
  #
  # This class provides the common infrastructure for communicating with
  # DAWs like Ableton Live and Bitwig Studio. It manages:
  # - OSC server/client for communication with DAW controller extensions
  # - MIDI clock synchronization
  # - Musa-DSL sequencer integration
  # - MIDI device management
  # - Transport controls (play, stop, record, etc.)
  #
  # Subclasses must implement {#daw_initialize} to set up DAW-specific
  # handlers and track management.
  #
  # @abstract Subclass and implement {#daw_initialize} and {#track}
  #
  # @see Bitwig::Bitwig Bitwig Studio implementation
  # @see Live::Live Ableton Live implementation
  class Daw
    # Registers a DAW driver class for a given identifier.
    #
    # @param daw_id [Symbol] the DAW identifier (:bitwig or :live)
    # @param daw_class [Class] the DAW controller class to register
    # @return [void]
    #
    # @example
    #   Daw.register(:bitwig, Bitwig::Bitwig)
    def self.register(daw_id, daw_class)
      @@daws ||= {}
      @@daws[daw_id] = daw_class
    end

    # Creates and returns a new DAW controller instance for the given identifier.
    #
    # @param daw_id [Symbol] the DAW identifier (:bitwig or :live)
    # @return [Daw] a new instance of the registered DAW controller
    def self.daw_controller_for(daw_id)
      @@daws[daw_id].new
    end

    # Creates a new DAW controller instance.
    #
    # Sets up OSC server (port 11011) and client (port 10001),
    # initializes the Musa-DSL sequencer, MIDI clock, and transport.
    # Calls {#daw_initialize} for DAW-specific setup.
    def initialize
      osc_server = OSC::EMServer.new(11_011)
      osc_client = OSC::Client.new('localhost', 10_001)

      Thread.new { osc_server.run }

      @sequencer = Musa::Sequencer::Sequencer.new 4, 24, dsl_context_class: MusaLCE_Context, do_log: true

      @clock = Musa::Clock::InputMidiClock.new do_log: true, logger: @sequencer.logger
      @transport = Musa::Transport::Transport.new @clock, sequencer: @sequencer

      @transport.after_stop do
        sequencer.reset
      end

      @midi_devices = MIDIDevices.new(@sequencer)

      # Build the surface side: inbound +/musalce/surface/*+
      # messages land on the EM reactor thread, are enqueued by the
      # bridge, then drained on the sequencer tick thread via
      # +before_tick+ — guaranteeing that inventory mutations and
      # user-defined trigger handlers can safely use any DSL method
      # (+play+, +at+, +launch+, …). Drainer latency is one tick
      # (≈20 ms at 120 BPM / 24 PPQN).
      surface_bridge = SurfaceBridge.new(osc_client, @sequencer, logger: @sequencer.logger)
      @surface = Surface.new(bridge: surface_bridge, logger: @sequencer.logger)
      surface_bridge.surface = @surface
      surface_bridge.register_inbound(osc_server)
      MusaLCEServer.surface = @surface

      @sequencer.before_tick do |_position|
        surface_bridge.drain
      end

      @tracks, @handler = daw_initialize(midi_devices: @midi_devices, clock: @clock, osc_server: osc_server, osc_client: osc_client, logger: @sequencer.logger)

      @handler.version
      @handler.sync

      # Ask Pulso Bridge (through the DAW extension) to dump its
      # current inventory. The reply re-establishes
      # +@surface.controls+ from scratch and triggers a full state
      # re-emit. Sent after +@handler.sync+ so the DAW extension is
      # known to be alive.
      surface_bridge.request_sync

      Thread.new { @transport.start }
    end

    # @!attribute [r] clock
    #   @return [Musa::Clock::InputMidiClock] the MIDI clock for synchronization
    # @!attribute [r] sequencer
    #   @return [Musa::Sequencer::Sequencer] the Musa-DSL sequencer instance
    # @!attribute [r] transport
    #   @return [Musa::Transport::Transport] the transport driving the
    #     sequencer. Exposed so REPL users can register callbacks
    #     ({Musa::Transport::Transport#on_start},
    #     {Musa::Transport::Transport#after_stop},
    #     {Musa::Transport::Transport#before_begin}) that survive across
    #     DAW Stop/Play cycles — useful for re-installing +on :event+
    #     handlers, +every+ loops or +at+ schedules that are wiped by
    #     the built-in +after_stop { sequencer.reset }+ callback.
    # @!attribute [r] tracks
    #   @return [Object] the DAW-specific tracks collection
    # @!attribute [r] surface
    #   @return [Surface] the control surface (Stream Deck etc.)
    attr_reader :clock, :sequencer, :transport, :tracks, :surface

    # DAW-specific initialization hook.
    #
    # Subclasses must implement this method to set up their specific
    # handlers and track management.
    #
    # @param midi_devices [MIDIDevices] the MIDI devices manager
    # @param clock [Musa::Clock::InputMidiClock] the MIDI clock
    # @param osc_server [OSC::EMServer] the OSC server for receiving messages
    # @param osc_client [OSC::Client] the OSC client for sending messages
    # @param logger [Logger] the logger instance
    # @return [Array(Object, Handler)] tuple of [tracks, handler]
    # @api private
    protected def daw_initialize(midi_devices:, clock:, osc_server:, osc_client:, logger:); end

    # Retrieves a track by name.
    #
    # @param name [String] the track name
    # @param all [Boolean] if true, returns all matching tracks; otherwise returns first match
    # @return [Object, Array<Object>] the track(s) matching the name
    # @raise [NotImplementedError] must be implemented by subclasses
    # @abstract
    def track(name, all: false)
      raise NotImplementedError
    end

    # Starts playback in the DAW.
    # @return [void]
    def play; end

    # Stops playback in the DAW.
    # @return [void]
    def stop; end

    # Continues playback from current position.
    # @return [void]
    def continue; end

    # Moves playhead to specified position.
    # @param position [Numeric] the bar position to go to
    # @return [void]
    def goto(position); end

    # Starts recording in the DAW.
    # @return [void]
    def record; end

    # Sends All Notes Off to all tracks.
    #
    # Use this to stop stuck notes after errors or interruptions.
    # @return [void]
    def panic!
      @tracks.each do |track|
        track.out.all_notes_off
      end
    end

    # Requests track synchronization from the DAW.
    # @return [void]
    def sync
      @handler.sync
    end

    # Requests the DAW controller extension to reload.
    # @return [void]
    def reload
      @handler.reload
    end
  end

  # Base class for DAW-specific OSC message handlers.
  #
  # Handles communication with DAW controller extensions via OSC.
  # Subclasses implement DAW-specific message handling.
  #
  # @abstract
  # @api private
  class Handler
    # Requests the DAW controller extension to reload its configuration.
    # @return [void]
    def reload
      @logger.info 'Asking controller reset and reload'
      send_osc '/reload'
    end

    # Sends the server version to the DAW controller extension.
    # @return [void]
    def version
      @logger.info "Sending version #{VERSION}"
      send_osc '/version', VERSION
    end

    # Sends panic (All Notes Off) to all tracks.
    # @return [void]
    # @raise [NotImplementedError] must be implemented by subclasses
    # @abstract
    def panic!
      raise NotImplementedError
    end

    # Sends an OSC message to the DAW controller.
    #
    # Includes retry logic for connection refused errors.
    #
    # @param message [String] the OSC address pattern
    # @param args [Array] optional arguments to send
    # @return [void]
    # @api private
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

  # DSL context for the MusaLCE REPL environment.
  #
  # Extends the Musa-DSL sequencer context with REPL customization
  # capabilities, allowing users to import additional modules and
  # access the binding for evaluation.
  #
  # @api private
  class MusaLCE_Context < Musa::Sequencer::Sequencer::DSLContext
    include Musa::REPL::CustomizableDSLContext

    # Returns the binding for this context.
    #
    # Used by the REPL for evaluating user code.
    #
    # @return [Binding] the context binding
    def binder
      @__binder ||= binding
    end

    # Imports modules into this context.
    #
    # Allows users to extend the REPL environment with additional
    # functionality by including modules.
    #
    # @param modules [Array<Module>] modules to include
    # @return [void]
    #
    # @example
    #   import(MyHelperModule, AnotherModule)
    def import(*modules)
      modules.each do |m|
        self.class.include(m)
      end
    end

    # @return [Surface] the active control surface (Stream Deck and
    #   similar hardware reached via Pulso Bridge).
    #
    # The surface holds typed controls keyed by event name. Controls
    # appear in the inventory once Pulso Bridge advertises them over
    # OSC; before that, +surface[:event]+ returns +nil+.
    #
    # @example single-line state write via {Control#set}
    #   on :launch_chorus do |payload|
    #     launch :chorus_section
    #     surface[:launch_chorus]&.set(enabled: true, message: "Chorus on")
    #   end
    #
    # @example reading state to toggle
    #   on :master_mute do
    #     surface[:master_mute]&.toggle!
    #   end
    def surface
      MusaLCEServer.surface or
        raise 'No Surface available (DAW not initialized)'
    end
  end
end
