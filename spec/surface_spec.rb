require 'spec_helper'
require 'logger'

# Load surface in isolation: pulling in the full gem requires live
# MIDI/OSC sockets, which we want to avoid in a unit-test run.
require_relative '../lib/surface'

# Captures every state emission so tests can assert what was sent
# outbound without spinning up OSC.
class FakeBridge
  attr_reader :sent

  def initialize
    @sent = []
  end

  def send_state(event:, prop:, value:)
    @sent << { event: event, prop: prop, value: value }
  end

  def clear
    @sent.clear
  end
end

RSpec.describe MusaLCEServer::Surface do
  let(:bridge) { FakeBridge.new }
  let(:logger) { instance_double(Logger, info: nil, warn: nil, error: nil) }
  let(:surface) { described_class.new(bridge: bridge, logger: logger) }

  describe 'lookup' do
    it 'returns nil for unknown events' do
      expect(surface[:nope]).to be_nil
      expect(surface).not_to be_known(:nope)
    end

    it 'accepts strings and symbols interchangeably' do
      surface.add_control('foo', 'toggle')
      expect(surface[:foo]).to be_a(MusaLCEServer::Toggle)
      expect(surface['foo']).to be_a(MusaLCEServer::Toggle)
      expect(surface).to be_known(:foo)
    end
  end

  describe 'inventory deltas' do
    it 'creates a Toggle of the right class' do
      surface.add_control(:foo, :toggle)
      expect(surface[:foo]).to be_a(MusaLCEServer::Toggle)
      expect(surface[:foo].event).to eq(:foo)
    end

    it 'creates a Trigger of the right class' do
      surface.add_control(:bar, :trigger)
      expect(surface[:bar]).to be_a(MusaLCEServer::Trigger)
    end

    it 'creates an Encoder of the right class' do
      surface.add_control(:enc, :encoder)
      expect(surface[:enc]).to be_a(MusaLCEServer::Encoder)
    end

    it 'preserves state when re-adding the same event with the same type' do
      surface.add_control(:foo, :toggle)
      surface[:foo].on!
      original = surface[:foo]

      surface.add_control(:foo, :toggle)

      expect(surface[:foo]).to equal(original)
      expect(surface[:foo].enabled).to eq(true)
    end

    it 'replaces and resets state when re-adding the same event with a different type' do
      surface.add_control(:foo, :toggle)
      surface[:foo].on!
      original = surface[:foo]

      surface.add_control(:foo, :encoder)

      expect(surface[:foo]).not_to equal(original)
      expect(surface[:foo]).to be_a(MusaLCEServer::Encoder)
    end

    it 'rejects unknown control types' do
      expect { surface.add_control(:foo, :spaceship) }.to raise_error(ArgumentError)
    end

    it 'removes controls and forgets their state' do
      surface.add_control(:foo, :toggle)
      surface[:foo].on!

      surface.remove_control(:foo)

      expect(surface[:foo]).to be_nil
    end
  end

  describe 'full inventory dump' do
    before do
      surface.add_control(:keep_same_type,    :toggle)
      surface.add_control(:change_type,       :toggle)
      surface.add_control(:disappears,        :toggle)
      surface[:keep_same_type].on!
      surface[:change_type].on!
      surface[:disappears].on!
      bridge.clear
    end

    it 'purges events absent from the dump and emits state for survivors' do
      surface.begin_inventory
      surface.add_control(:keep_same_type, :toggle)
      surface.add_control(:change_type,    :encoder)
      surface.add_control(:fresh_one,      :trigger)
      surface.end_inventory

      expect(surface[:keep_same_type]).to be_a(MusaLCEServer::Toggle)
      expect(surface[:keep_same_type].enabled).to eq(true) # preserved
      expect(surface[:change_type]).to be_a(MusaLCEServer::Encoder) # reset
      expect(surface[:fresh_one]).to be_a(MusaLCEServer::Trigger)
      expect(surface[:disappears]).to be_nil # purged

      # A bare Trigger has no state to emit (message defaults to
      # nil), so :fresh_one is intentionally absent from emissions.
      emitted_events = bridge.sent.map { |m| m[:event] }.uniq
      expect(emitted_events).to contain_exactly(:keep_same_type, :change_type)
    end
  end
end

RSpec.describe MusaLCEServer::Toggle do
  let(:bridge) { FakeBridge.new }
  let(:logger) { instance_double(Logger, info: nil, warn: nil, error: nil) }
  let(:surface) { MusaLCEServer::Surface.new(bridge: bridge, logger: logger) }
  let(:toggle) { surface.add_control(:foo, :toggle) }

  before { toggle; bridge.clear }

  it 'defaults to :inactive' do
    expect(toggle.enabled).to eq(:inactive)
    expect(toggle).not_to be_enabled
    expect(toggle).to be_inactive
  end

  it 'emits one state message on enabled=' do
    toggle.enabled = true
    expect(bridge.sent).to eq([{ event: :foo, prop: :enabled, value: ['true'] }])
  end

  it 'normalizes string/symbol equivalents' do
    expect { toggle.enabled = 'true' }.not_to raise_error
    expect(toggle.enabled).to eq(true)

    toggle.enabled = :false
    expect(toggle.enabled).to eq(false)

    toggle.enabled = nil
    expect(toggle.enabled).to eq(:inactive)
  end

  it 'rejects invalid values' do
    expect { toggle.enabled = 'maybe' }.to raise_error(ArgumentError)
  end

  it 'provides on!/off!/inactive! shortcuts' do
    toggle.on!
    expect(toggle.enabled).to eq(true)
    toggle.off!
    expect(toggle.enabled).to eq(false)
    toggle.inactive!
    expect(toggle.enabled).to eq(:inactive)
  end

  it 'cycles with toggle! between true and false, lifting :inactive to true' do
    toggle.toggle!
    expect(toggle.enabled).to eq(true)
    toggle.toggle!
    expect(toggle.enabled).to eq(false)
    toggle.toggle!
    expect(toggle.enabled).to eq(true)

    toggle.inactive!
    toggle.toggle!
    expect(toggle.enabled).to eq(true)
  end

  it 'emits message and enabled in emit_all_state' do
    toggle.message = 'Chorus on'
    toggle.on!
    bridge.clear

    toggle.emit_all_state

    props = bridge.sent.map { |m| m[:prop] }
    expect(props).to include(:message, :enabled)
  end

  describe '#set' do
    it 'sets multiple attributes in one call and emits one message per property' do
      toggle.set(enabled: true, message: 'Chorus on')

      expect(toggle.enabled).to eq(true)
      expect(toggle.message).to eq('Chorus on')
      props = bridge.sent.map { |m| m[:prop] }
      expect(props).to contain_exactly(:enabled, :message)
    end

    it 'returns self for chaining' do
      expect(toggle.set(enabled: true)).to equal(toggle)
    end

    it 'raises ArgumentError on unknown attributes' do
      expect { toggle.set(value: 64) }.to raise_error(ArgumentError, /toggle.*value/)
    end
  end
end

RSpec.describe MusaLCEServer::Encoder do
  let(:bridge) { FakeBridge.new }
  let(:logger) { instance_double(Logger, info: nil, warn: nil, error: nil) }
  let(:surface) { MusaLCEServer::Surface.new(bridge: bridge, logger: logger) }
  let(:encoder) { surface.add_control(:fader, :encoder) }

  before { encoder; bridge.clear }

  it 'defaults to value 0 in range 0..127' do
    expect(encoder.value).to eq(0)
    expect(encoder.range).to eq(0..127)
  end

  it 'clamps value to the current range on assignment' do
    encoder.value = 200
    expect(encoder.value).to eq(127)

    encoder.value = -10
    expect(encoder.value).to eq(0)
  end

  it 're-clamps current value when the range narrows' do
    encoder.value = 100
    bridge.clear

    encoder.range = 0..50

    expect(encoder.value).to eq(50)
    props = bridge.sent.map { |m| m[:prop] }
    expect(props).to include(:range, :value)
  end

  it 'rejects non-Range arguments to range=' do
    expect { encoder.range = [0, 127] }.to raise_error(ArgumentError)
  end

  describe '#set' do
    it 'sets range, value and message in one call' do
      encoder.set(range: 0..200, value: 150, message: 'Cutoff')
      expect(encoder.range).to eq(0..200)
      expect(encoder.value).to eq(150)
      expect(encoder.message).to eq('Cutoff')
    end
  end
end

RSpec.describe MusaLCEServer::Trigger do
  let(:bridge) { FakeBridge.new }
  let(:logger) { instance_double(Logger, info: nil, warn: nil, error: nil) }
  let(:surface) { MusaLCEServer::Surface.new(bridge: bridge, logger: logger) }
  let(:trigger) { surface.add_control(:panic, :trigger) }

  before { trigger; bridge.clear }

  it 'accepts set with message only' do
    trigger.set(message: 'Sent')
    expect(trigger.message).to eq('Sent')
  end

  it 'rejects set with enabled (toggle-only attribute)' do
    expect { trigger.set(enabled: true) }.to raise_error(ArgumentError, /trigger.*enabled/)
  end
end
