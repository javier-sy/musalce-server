require 'osc-ruby'

module MusaLCEServer
  # Bridge between the MusaLCE event system and the OSC channel that
  # carries event state to live coding UI surfaces — typically Stream
  # Deck buttons via the chain MusaLCEServer → MusaLCEforXXX → Pulso
  # Bridge → Stream Deck plugin.
  #
  # Holds the outbound OSC client (port 10001, shared with the active
  # {Daw} subclass) and exposes {#send_state} as the underlying
  # mechanism for the DSL +status+ command defined on
  # {MusaLCE_Context}.
  #
  # Single instance per server, accessible as
  # +MusaLCEServer.event_bridge+, set during {Daw} initialization.
  #
  # @api private
  class EventBridge
    # Creates a new event bridge.
    #
    # @param osc_client [OSC::Client] outbound OSC client to the DAW
    #   extension (the same one used by the active {Handler} subclass)
    # @param logger [Logger] the logger
    def initialize(osc_client, logger:)
      @client = osc_client
      @logger = logger
      @inbox = Queue.new
    end

    # Sends +/musalce/event/state+ to the DAW extension, which relays
    # it to Pulso Bridge and from there to the Stream Deck plugin.
    #
    # @param event [String, Symbol] event name (same identifier used
    #   with +on+ in user code and configured on the Stream Deck
    #   button)
    # @param enabled [Boolean, Symbol, String] one of +true+, +false+
    #   or +:inactive+ (also accepts equivalent strings)
    # @param message [String, nil] optional text to display on the
    #   button (empty string is sent when +nil+)
    # @return [void]
    def send_state(event:, enabled:, message: nil)
      send_osc '/musalce/event/state',
               event.to_s,
               normalize_enabled(enabled),
               (message || '').to_s
    end

    # Pushes a trigger received from the DAW extension into the
    # inbound queue. Called from the OSC server thread. Thread-safe.
    #
    # Triggers are later drained in the sequencer tick thread via
    # {#drain_triggers} — registered as a +before_tick+ callback by
    # {Daw} — and dispatched to user handlers via +sequencer.launch+.
    # Routing through the tick thread guarantees that handlers can
    # safely call any sequencer DSL method (+play+, +at+, +wait+,
    # +launch+, …) without race conditions against the tick loop.
    #
    # @param event [String] event name as received on the wire
    # @param payload [String] payload string (empty if not sent)
    # @return [void]
    def enqueue_trigger(event, payload)
      @inbox << [event, payload]
    end

    # Drains the inbound trigger queue, yielding +[event, payload]+
    # for each pending trigger. Called once per tick from the
    # sequencer tick thread via +before_tick+.
    #
    # Uses a non-blocking pop so the drainer never stalls the tick
    # thread if the queue becomes empty between the +empty?+ check
    # and the +pop+ (defensive against concurrent producers).
    #
    # @yield [event, payload] called once per pending trigger
    # @yieldparam event [String]
    # @yieldparam payload [String]
    # @return [void]
    def drain_triggers
      loop do
        event, payload = @inbox.pop(true)
        yield event, payload
      end
    rescue ThreadError
      # Queue empty — done draining.
    end

    private def normalize_enabled(value)
      case value
      when true, :true, 'true'        then 'true'
      when false, :false, 'false'     then 'false'
      when :inactive, 'inactive', nil then 'inactive'
      else
        raise ArgumentError,
              "enabled must be true, false or :inactive (got #{value.inspect})"
      end
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
