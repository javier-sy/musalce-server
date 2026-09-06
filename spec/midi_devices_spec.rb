require 'spec_helper'

# Load midi-devices in isolation: pulling in the full gem requires live
# MIDI/OSC sockets, which we want to avoid in a unit-test run.
require_relative '../lib/midi-devices'

RSpec.describe MusaLCEServer::MIDIDevices do
  # A MIDICommunications::Output as far as this class is concerned.
  def port(name)
    instance_double('MIDICommunications::Output', name: name)
  end

  # Stands in for the system's MIDI ports, so that a test can plug something in.
  def present(*names)
    allow(MIDICommunications::Output).to receive(:all).and_return(names.map { |name| port(name) })
  end

  let(:sequencer) { double('sequencer') }

  before do
    allow(MIDICommunications::Loader).to receive(:refresh)

    # A real MIDIDevice builds sixteen MIDIVoices against a live sequencer;
    # what matters here is which devices the collection ends up holding.
    allow(MusaLCEServer::MIDIDevice).to receive(:new) do |_sequencer, low_level_device|
      double('MIDIDevice', name: low_level_device.name)
    end
  end

  describe '#sync' do
    it 'finds the devices that are connected' do
      present 'Synth', 'Interface'

      expect(described_class.new(sequencer).map(&:name)).to contain_exactly('Synth', 'Interface')
    end

    it 'adds a device that appeared' do
      present 'Synth'
      devices = described_class.new(sequencer)

      present 'Synth', 'Interface'
      devices.sync

      expect(devices.map(&:name)).to contain_exactly('Synth', 'Interface')
    end

    it 'removes a device that went away' do
      present 'Synth', 'Interface'
      devices = described_class.new(sequencer)

      present 'Synth'
      devices.sync

      expect(devices.map(&:name)).to contain_exactly('Synth')
    end

    # The defect. `names.delete` sat after the guard that skips devices already
    # known, so it only ran for new ones -- and a new name was never in the list
    # of names known beforehand, making it a no-op in every case. Every device
    # still connected therefore stayed in that list and was deleted at the end,
    # and the enumeration had already passed, so nothing added it back.
    it 'keeps the devices it already had when nothing changed' do
      present 'Synth', 'Interface'
      devices = described_class.new(sequencer)

      devices.sync

      expect(devices.map(&:name)).to contain_exactly('Synth', 'Interface')
    end

    it 'survives being called repeatedly' do
      present 'Synth'
      devices = described_class.new(sequencer)

      5.times { devices.sync }

      expect(devices.map(&:name)).to contain_exactly('Synth')
    end

    it 'does not rebuild a device it already had' do
      present 'Synth'
      devices = described_class.new(sequencer)
      before = devices.first

      devices.sync

      expect(devices.first).to be(before)
      expect(MusaLCEServer::MIDIDevice).to have_received(:new).once
    end

    # Without re-enumerating, MIDICommunications answers from the list it built
    # the first time and no device plugged in later is ever seen.
    it 'asks MIDICommunications to enumerate again' do
      present 'Synth'
      described_class.new(sequencer).sync

      expect(MIDICommunications::Loader).to have_received(:refresh).twice
    end
  end

  describe '#[]' do
    it 'finds a device by its exact name' do
      present 'Synth'
      devices = described_class.new(sequencer)

      expect(devices['Synth']).not_to be_nil
      expect(devices['Syn']).to be_nil
    end
  end
end
