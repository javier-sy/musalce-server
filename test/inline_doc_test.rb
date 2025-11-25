$LOAD_PATH.prepend(File.expand_path('../lib', __dir__))

require 'minitest/autorun'
require 'shoulda-context'

# Note: Full musalce-server requires DAW connections and MIDI devices.
# These tests verify the module structure and basic documentation examples
# that don't require actual hardware or DAW connections.

# Load only the version file to avoid DAW/OSC initialization
require_relative '../lib/version'

class MusaLCEServer::InlineDocTest < Minitest::Test
  context 'VERSION constant' do
    should 'be defined' do
      assert defined?(MusaLCEServer::VERSION)
    end

    should 'be a string' do
      assert_kind_of String, MusaLCEServer::VERSION
    end

    should 'follow semantic versioning format' do
      assert_match(/\A\d+\.\d+\.\d+\z/, MusaLCEServer::VERSION)
    end

    should 'be version 0.6.0' do
      assert_equal '0.6.0', MusaLCEServer::VERSION
    end
  end
end

# Test module structure without loading full server
# (which requires musa-dsl, osc-ruby, and DAW connections)
class MusaLCEServerModuleStructureTest < Minitest::Test
  context 'MusaLCEServer module' do
    should 'be defined' do
      assert defined?(MusaLCEServer)
    end

    should 'be a module' do
      assert_kind_of Module, MusaLCEServer
    end
  end
end
