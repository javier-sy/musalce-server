require 'spec_helper'

# Load only the version file: the rest of the gem requires a live MIDI
# clock and OSC sockets, which would either fail in a CI-like
# environment or open ports we don't want bound during a unit test run.
require_relative '../lib/version'

RSpec.describe MusaLCEServer do
  it 'defines the module' do
    expect(defined?(MusaLCEServer)).to eq('constant')
    expect(MusaLCEServer).to be_a(Module)
  end

  describe 'VERSION' do
    it 'is defined' do
      expect(defined?(MusaLCEServer::VERSION)).to eq('constant')
    end

    it 'is a frozen string' do
      expect(MusaLCEServer::VERSION).to be_a(String)
      expect(MusaLCEServer::VERSION).to be_frozen
    end

    it 'follows semantic versioning' do
      expect(MusaLCEServer::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
