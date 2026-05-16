require 'osc-ruby'

module MusaLCEServer
  # OSC bridge between the server-side {Surface} and the physical
  # control surface (Stream Deck, …) reached through the chain
  # MusaLCEServer ↔ MusaLCEforXXX ↔ Pulso Bridge ↔ plugin.
  #
  # Two responsibilities:
  #
  # 1. **Outbound emission** — translates {Surface} state changes
  #    and sync requests into +/musalce/surface/*+ OSC messages
  #    sent on the existing UDP client (port 10001, shared with
  #    {Daw}).
  #
  # 2. **Inbound dispatch** — receives +/musalce/surface/*+ messages
  #    on the OSC server (EM reactor thread), enqueues them, and
  #    drains the queue on the sequencer tick thread via
  #    {#drain}. This is critical: inventory mutations and trigger
  #    dispatch may invoke arbitrary user DSL code (+play+, +at+,
  #    +launch+, …) which must run on the sequencer thread.
  #
  # Wired up by {Daw#initialize}; expected to be the sole emitter
  # of +/musalce/surface/*+ on the server side.
  class SurfaceBridge
    # @return [Surface] the surface this bridge dispatches inbound
    #   messages to; set during {Daw} initialization after both
    #   instances exist.
    attr_accessor :surface

    # @param osc_client [OSC::Client] outbound OSC client (shared
    #   with the active {Handler})
    # @param sequencer [Musa::Sequencer::Sequencer] used to launch
    #   user-defined event handlers in response to surface triggers
    # @param logger [Logger] the logger
    def initialize(osc_client, sequencer, logger:)
      @client = osc_client
      @sequencer = sequencer
      @logger = logger
      @inbox = Queue.new
    end

    # Sends +/musalce/surface/sync_request+ outbound. Used on
    # server startup to ask Pulso Bridge (via the DAW extension) to
    # dump its current inventory. The reply arrives as a sequence
    # of +inventory/begin+, +inventory/add+ ..., +inventory/end+.
    # @return [void]
    def request_sync
      send_osc '/musalce/surface/sync_request'
    end

    # Sends +/musalce/surface/state/<prop>+ for a property change.
    #
    # One address per property so the Java relay and the surface
    # plugin can dispatch on a fixed argument layout per address
    # (event + N typed args). All values are serialized to strings
    # on the wire — receivers parse them based on the address.
    # Keeps the Java forwarder generic without inspecting typetags.
    #
    # @param event [Symbol] the event the control is bound to
    # @param prop [Symbol] the property name (+:message+,
    #   +:enabled+, +:value+, +:range+, …)
    # @param value [Array<Object>] one or more values for the
    #   property (e.g. one for +:message+, two for +:range+)
    # @return [void]
    def send_state(event:, prop:, value:)
      args = value.map { |v| serialize_arg(v) }
      send_osc "/musalce/surface/state/#{prop}", event.to_s, *args
    end

    # Registers all inbound +/musalce/surface/*+ handlers on the
    # given OSC server. Each handler enqueues the message; actual
    # processing happens on {#drain}.
    #
    # @param osc_server [OSC::EMServer]
    # @return [void]
    def register_inbound(osc_server)
      osc_server.add_method('/musalce/surface/inventory/begin') do |_msg|
        @inbox << [:inventory_begin]
      end

      osc_server.add_method('/musalce/surface/inventory/add') do |msg|
        args = msg.to_a
        @inbox << [:inventory_add, args[0], args[1]]
      end

      osc_server.add_method('/musalce/surface/inventory/remove') do |msg|
        @inbox << [:inventory_remove, msg.to_a[0]]
      end

      osc_server.add_method('/musalce/surface/inventory/end') do |_msg|
        @inbox << [:inventory_end]
      end

      osc_server.add_method('/musalce/surface/state_request') do |_msg|
        @inbox << [:state_request]
      end

      osc_server.add_method('/musalce/surface/trigger') do |msg|
        args = msg.to_a
        @inbox << [:trigger, args[0], (args[1] || '').to_s]
      end
    end

    # Drains the inbound queue. Called from the sequencer tick
    # thread (via +before_tick+) so every dispatched action runs in
    # a context where DSL methods like +launch+, +play+, +at+ are
    # safe to invoke.
    # @return [void]
    # @api private
    def drain
      loop do
        msg = @inbox.pop(true)
        dispatch(msg)
      end
    rescue ThreadError
      # Queue empty — done draining.
    end

    private def dispatch(msg)
      kind = msg[0]
      case kind
      when :inventory_begin
        @surface.begin_inventory
      when :inventory_add
        event, type = msg[1], msg[2]
        if event.nil? || type.nil?
          @logger.warn "/musalce/surface/inventory/add missing event or type (#{msg.inspect})"
        else
          @surface.add_control(event, type)
        end
      when :inventory_remove
        event = msg[1]
        @surface.remove_control(event) unless event.nil?
      when :inventory_end
        @surface.end_inventory
      when :state_request
        @surface.emit_full_state
      when :trigger
        event, payload = msg[1], msg[2]
        if event.nil? || event.to_s.empty?
          @logger.warn '/musalce/surface/trigger received without event'
        elsif !@surface.known?(event)
          @logger.warn "/musalce/surface/trigger for unknown event #{event.inspect}; ignoring"
        else
          @sequencer.launch(event.to_sym, payload)
        end
      end
    rescue StandardError => e
      @logger.error "Error dispatching surface message #{msg.inspect}: #{e.class}: #{e.message}"
    end

    # All values cross the wire as strings: this lets the Java
    # relay forward generically without inspecting OSC typetags,
    # and lets the plugin parse per-property. Receivers know how
    # to interpret each value from the OSC address.
    private def serialize_arg(v)
      v.nil? ? '' : v.to_s
    end

    private def send_osc(address, *args)
      counter = 0
      begin
        @client.send OSC::Message.new(address, *args)
      rescue Errno::ECONNREFUSED
        counter += 1
        @logger.warn "Errno::ECONNREFUSED sending #{address} #{args}. Retrying... (#{counter})"
        retry if counter < 3
      end
    end
  end
end
