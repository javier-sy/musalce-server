require 'set'

module MusaLCEServer
  # Authoritative model of the physical control surface (Stream Deck
  # buttons, encoders, …) as seen from the server.
  #
  # The surface is **the abstraction shared with hardware** but
  # surface-agnostic: it knows only about named controls with a type
  # and dynamic state. Each control is referenced by a Symbol id
  # (e.g. +:launch_chorus+) which doubles as the event name used with
  # the sequencer's +on+/+launch+ mechanism when the control fires.
  #
  # Ownership of the two data axes:
  #
  # - **Inventory** (which controls exist and their type) flows
  #   inbound from Pulso Bridge through the DAW extension; the server
  #   trusts what it receives (Pulso validates type consistency
  #   across physical instances).
  # - **State** (message, enabled, value, …) is owned by the server:
  #   the score writes to +surface[:id]+ and changes propagate
  #   outbound on +/musalce/surface/state+.
  #
  # Inventory may arrive as a full dump (between
  # +inventory/begin+ and +inventory/end+, in which case ids absent
  # from the dump are purged at end) or as runtime deltas
  # (+inventory/add+ / +inventory/remove+). Re-adding an id with the
  # same type preserves its state; a type change replaces the
  # control and resets state.
  #
  # All mutating methods are expected to run on the sequencer tick
  # thread (inbound OSC messages are routed there by
  # {SurfaceBridge}). Score code writing +surface[:id].xxx +=+ ...
  # also runs on that thread (inside +at+/+every+/+on+ blocks),
  # which keeps access serial without explicit locking.
  class Surface
    # @param bridge [SurfaceBridge] the bridge used to emit state outbound
    # @param logger [Logger] the logger
    def initialize(bridge:, logger:)
      @bridge = bridge
      @logger = logger
      @controls = {}
      @pending_ids = nil
    end

    # Returns the control for the given id, or +nil+ if unknown.
    #
    # A control becomes known once its inventory entry has been
    # received from the surface. Score code that runs before that
    # should use safe navigation (+surface[:foo]&.enabled = true+)
    # or guard with {#known?}.
    #
    # @param id [Symbol, String]
    # @return [Control, nil]
    def [](id)
      @controls[id.to_sym]
    end

    # @return [Array<Symbol>] all known control ids
    def ids
      @controls.keys
    end

    # @param id [Symbol, String]
    # @return [Boolean] whether a control with this id is in the inventory
    def known?(id)
      @controls.key?(id.to_sym)
    end

    # Begins a full inventory dump. Ids that are not re-added before
    # {#end_inventory} are purged.
    # @return [void]
    # @api private
    def begin_inventory
      @pending_ids = Set.new
    end

    # Registers (or refreshes) a control in the inventory.
    #
    # If a control with the same id and type already exists, its
    # state is preserved. If the type differs, the existing control
    # is replaced with a fresh instance (state reset).
    #
    # @param id [Symbol, String]
    # @param type [Symbol, String] one of +:toggle+, +:trigger+, +:encoder+
    # @return [Control] the (possibly new) control
    # @api private
    def add_control(id, type)
      id = id.to_sym
      type = type.to_sym
      existing = @controls[id]

      if existing && existing.class.type_name == type
        ctrl = existing
      else
        ctrl = Control.create(type, id: id, surface: self)
        @controls[id] = ctrl
        @logger.info "Surface: added control #{id} (#{type})"
      end

      @pending_ids << id if @pending_ids
      ctrl
    end

    # Removes a control from the inventory and drops its state.
    # @param id [Symbol, String]
    # @return [Control, nil] the removed control, or nil if unknown
    # @api private
    def remove_control(id)
      id = id.to_sym
      removed = @controls.delete(id)
      @logger.info "Surface: removed control #{id}" if removed
      removed
    end

    # Ends a full inventory dump. Any id present before the dump but
    # not re-added between {#begin_inventory} and this call is
    # purged. Re-emits all state so the surface re-syncs after the
    # round-trip.
    # @return [void]
    # @api private
    def end_inventory
      if @pending_ids
        stale = @controls.keys - @pending_ids.to_a
        stale.each do |id|
          @controls.delete(id)
          @logger.info "Surface: purged stale control #{id}"
        end
        @pending_ids = nil
      end
      emit_full_state
    end

    # Re-emits state for every known control. Used after an
    # inventory dump or in response to a +state_request+ from the
    # surface side.
    # @return [void]
    # @api private
    def emit_full_state
      @controls.each_value(&:emit_all_state)
    end

    # Called by a Control when one of its properties changes; relays
    # to the bridge.
    # @param id [Symbol]
    # @param prop [Symbol]
    # @param value [Array<Object>] OSC-serializable values
    # @return [void]
    # @api private
    def emit_state(id, prop, *value)
      @bridge.send_state(id: id, prop: prop, value: value)
    end
  end

  # Abstract base for all controls on a {Surface}.
  #
  # Subclasses declare a {.type_name} matching the inventory string
  # received from the surface, expose typed state accessors, and
  # implement {#emit_all_state} to push their current state outbound.
  #
  # Setting a property emits exactly one OSC +/musalce/surface/state+
  # message; the setter is therefore the canonical mutation point.
  # Direct manipulation of instance variables bypasses emission.
  class Control
    # @return [Symbol] the control id
    attr_reader :id

    # @return [String, nil] the displayable message, +nil+ if unset
    attr_reader :message

    def initialize(id:, surface:)
      @id = id
      @surface = surface
      @message = nil
    end

    # Sets the displayable message. Two-line text is allowed; the
    # surface side is responsible for truncation/wrapping.
    # @param value [String, nil]
    # @return [void]
    def message=(value)
      @message = value
      emit(:message, value.to_s)
    end

    # Re-emits every state property of this control. Called by the
    # surface during +state_request+ or after inventory dumps.
    # @return [void]
    # @api private
    def emit_all_state
      emit(:message, @message.to_s) unless @message.nil?
    end

    # @return [Symbol] the inventory type identifier
    def self.type_name
      raise NotImplementedError, "#{self} must implement .type_name"
    end

    # Instantiates the right subclass for the given type.
    # @param type [Symbol]
    # @return [Control]
    # @raise [ArgumentError] if the type is unknown
    # @api private
    def self.create(type, **kwargs)
      case type.to_sym
      when :toggle  then Toggle.new(**kwargs)
      when :trigger then Trigger.new(**kwargs)
      when :encoder then Encoder.new(**kwargs)
      else raise ArgumentError, "Unknown control type: #{type.inspect}"
      end
    end

    protected def emit(prop, *value)
      @surface.emit_state(@id, prop, *value)
    end
  end

  # A stateful on/off control with a three-valued enabled property:
  # +true+ (on), +false+ (off available), +:inactive+ (control is
  # known but currently not actionable, typically rendered dimmed).
  class Toggle < Control
    def self.type_name = :toggle

    # @return [Boolean, Symbol] +true+, +false+, or +:inactive+
    attr_reader :enabled

    def initialize(**kwargs)
      super
      @enabled = :inactive
    end

    # Sets the enabled state. Accepts +true+, +false+, +:inactive+
    # and their string equivalents.
    # @param value [Boolean, Symbol, String]
    # @raise [ArgumentError] on any other value
    def enabled=(value)
      @enabled = normalize_enabled(value)
      emit(:enabled, @enabled.to_s)
    end

    # @return [Boolean] true iff +enabled+ is exactly +true+
    def enabled?
      @enabled == true
    end

    # @return [Boolean] true iff +enabled+ is +:inactive+
    def inactive?
      @enabled == :inactive
    end

    # Convenience: set to +true+.
    def on!  = (self.enabled = true)
    # Convenience: set to +false+.
    def off! = (self.enabled = false)
    # Convenience: set to +:inactive+.
    def inactive! = (self.enabled = :inactive)

    # Toggles between +true+ and +false+. From +:inactive+ goes to
    # +true+ (entering active service).
    def toggle!
      case @enabled
      when true  then off!
      when false then on!
      else            on!
      end
    end

    def emit_all_state
      super
      emit(:enabled, @enabled.to_s)
    end

    private def normalize_enabled(v)
      case v
      when true,  :true,  'true'     then true
      when false, :false, 'false'    then false
      when :inactive, 'inactive', nil then :inactive
      else
        raise ArgumentError,
              "enabled must be true, false or :inactive (got #{v.inspect})"
      end
    end
  end

  # A momentary, stateless control. Pressing it fires the
  # corresponding sequencer event; the control itself carries no
  # persistent on/off state beyond an optional {#message}.
  class Trigger < Control
    def self.type_name = :trigger
  end

  # An absolute-value rotary or fader control with an integer
  # +value+ inside an inclusive +range+. Range defaults to
  # +0..127+ (standard MIDI 7-bit).
  class Encoder < Control
    def self.type_name = :encoder

    # @return [Integer]
    attr_reader :value
    # @return [Range]
    attr_reader :range

    def initialize(**kwargs)
      super
      @range = 0..127
      @value = 0
    end

    # @param v [Integer, Numeric] clamped to {#range}
    def value=(v)
      @value = clamp_to_range(v.to_i)
      emit(:value, @value)
    end

    # @param r [Range] inclusive integer range; +value+ is re-clamped
    def range=(r)
      raise ArgumentError, "range must be a Range (got #{r.inspect})" unless r.is_a?(Range)
      @range = r
      @value = clamp_to_range(@value)
      emit(:range, r.min, r.max)
      emit(:value, @value)
    end

    def emit_all_state
      super
      emit(:range, @range.min, @range.max)
      emit(:value, @value)
    end

    private def clamp_to_range(v)
      [[v, @range.min].max, @range.max].min
    end
  end
end
